import SwiftUI
import WidgetKit
import HALogik

/// Menüleisten-App für Home Assistant: Lampen, Steckdosen, Heizung, Energie und Personen.
@main
struct HAToolBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var kern = Kern.shared

    var body: some Scene {
        MenuBarExtra {
            PanelMitFenster(kern: kern)
        } label: {
            MenueSymbol(ha: kern.ha, einstellungen: kern.einstellungen)
        }
        .menuBarExtraStyle(.window)

        Window(T("Home Assistant ToolBox – Einstellungen"), id: "einstellungen") {
            EinstellungenAnsicht(kern: kern)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window(T("Home Assistant ToolBox – Was ist neu?"), id: "neuigkeiten") {
            NeuigkeitenAnsicht(akt: kern.aktualisierer)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// Alles, was die App einmal braucht: Einstellungen, Verbindung, Panelzustand, Instanzen.
@MainActor
@Observable
final class Kern {
    static let shared = Kern()

    let vorschau = CommandLine.arguments.contains("--vorschau")
    let einstellungen: Einstellungen
    let ha = HaVerbindung()
    let panel = PanelZustand()
    let aktualisierer = Aktualisierer()
    /// Gewählte Instanz (bis zum Neustart; danach wieder der Favorit)
    var gewaehlteId = "" { didSet { if gewaehlteId != oldValue { uebernehmen(sofort: true) } } }
    @ObservationIgnored private var verzoegert: Task<Void, Never>?
    @ObservationIgnored private var letzterSchnappschuss: Schnappschuss?
    @ObservationIgnored private var letztesNeuLaden = Date.distantPast

    var aktiv: Instanz? {
        einstellungen.instanzen.first { $0.id == gewaehlteId } ?? Logik.favorit(einstellungen.instanzen)
    }

    private init() {
        Sprache.laden()
        einstellungen = Einstellungen(vorschau: vorschau)
        einstellungen.geaendert = { [weak self] in self?.uebernehmen() }
        // Ohne eigenen Namen gleich den Namen der Installation aus Home Assistant übernehmen
        ha.standortGeladen = { [weak self] name in
            guard let self, let i = self.aktiv, i.name.isEmpty else { return }
            self.einstellungen.aendern(i.id) { $0.name = name }
        }
        if vorschau {
            // Testlauf: Instanzen aus Umgebungsvariablen (HA_ADRESSE/HA_TOKEN, optional HA_ADRESSE2/HA_TOKEN2)
            let env = ProcessInfo.processInfo.environment
            var liste = [Instanz(id: "i1", name: T("Zuhause"), adresse: env["HA_ADRESSE"] ?? "http://127.0.0.1:8123", favorit: true,
                                 hauptzaehler: env["HA_HAUPTZAEHLER"] ?? "")]
            einstellungen.vorschauToken["i1"] = env["HA_TOKEN"] ?? ""
            if let a2 = env["HA_ADRESSE2"] {
                liste.append(Instanz(id: "i2", name: "", adresse: a2))
                einstellungen.vorschauToken["i2"] = env["HA_TOKEN2"] ?? ""
            }
            einstellungen.instanzen = liste
        }
        uebernehmen(sofort: true)
        befehleEmpfangen()
        Task { await self.dauerlauf() }
        // Nur für die Testbilder: Release-Liste vom nachgebauten Home Assistant (Downloads bleiben auf GitHub beschränkt)
        if vorschau, let u = ProcessInfo.processInfo.environment["HA_UPDATE_URL"], let url = URL(string: u) { aktualisierer.quelle = url }
        if einstellungen.updatesSuchen && !vorschau {
            Task {
                try? await Task.sleep(for: .seconds(20))
                await self.aktualisierer.automatischPruefen()
            }
        }
    }

    func wechseln(_ id: String) { gewaehlteId = id }

    /// Einstellungen an die Verbindung geben (Adresse/Token kurz verzögert)
    func uebernehmen(sofort: Bool = false) {
        var o = einstellungen.optionenBasis
        o.hauptzaehler = aktiv?.hauptzaehler ?? ""
        ha.setzeOptionen(o)
        ha.abfrageSekunden = einstellungen.abfrageSekunden
        verzoegert?.cancel()
        let verbinden = { [weak self] in
            guard let self else { return }
            let i = self.aktiv
            self.ha.verbinde(adresse: i?.adresse ?? "", token: i.map { self.einstellungen.token($0.id) } ?? "")
        }
        if sofort {
            verbinden()
        } else {
            verzoegert = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                verbinden()
            }
        }
    }

    // MARK: Extra heizen

    func boostStarten(_ ids: [String], grad: Double, minuten: Int) {
        guard let instanz = aktiv?.id else { return }
        var liste = einstellungen.boosts.filter { !($0.instanz == instanz && ids.contains($0.id)) }
        let bis = Date().addingTimeInterval(Double(minuten) * 60)
        for id in ids {
            guard let k = Logik.klimaStatus(ha.zustaende[id]) else { continue }
            liste.append(Boost(instanz: instanz, id: id, bis: bis, vorher: k.ziel ?? grad, modus: k.modus))
            ha.setzeTemperatur(id, grad)
        }
        einstellungen.boosts = liste
    }

    func boostBeenden(_ b: Boost) {
        // alle Thermostate, die gemeinsam gestartet wurden, zurücksetzen
        let betroffen = einstellungen.boosts.filter { $0.instanz == b.instanz && abs($0.bis.timeIntervalSince(b.bis)) < 1 }
        if b.instanz == aktiv?.id {
            for x in betroffen {
                if x.modus == "off" { ha.setzeModus(x.id, "off") } else { ha.setzeTemperatur(x.id, x.vorher) }
            }
        }
        einstellungen.boosts.removeAll { x in betroffen.contains(x) }
    }

    func boost(fuer klima: [String]) -> Boost? {
        einstellungen.boosts.first { klima.contains($0.id) && $0.instanz == aktiv?.id }
    }

    // MARK: Alle paar Sekunden: abgelaufenes Extra heizen, Instanzname, Widgets

    private func dauerlauf() async {
        while true {
            try? await Task.sleep(for: .seconds(5))
            if ha.verbunden, let b = einstellungen.boosts.first(where: { $0.instanz == aktiv?.id && $0.bis <= Date() }) {
                boostBeenden(b)
            }
            // Ohne eigenen Namen den Namen der Installation aus Home Assistant übernehmen
            if let i = aktiv, i.name.isEmpty, !ha.standortName.isEmpty {
                einstellungen.aendern(i.id) { $0.name = ha.standortName }
            }
            widgetsAktualisieren()
        }
    }

    /// Datenpaket für die Widgets schreiben und sie neu laden lassen (gebremst)
    func widgetsAktualisieren(sofort: Bool = false) {
        guard ha.verbunden else { return }
        let s = Logik.schnappschuss(instanz: aktiv?.anzeigename ?? "", verbunden: ha.verbunden, z: ha.zustaende, anzeige: ha.anzeige,
                                    heizungen: ha.heizungen, personen: ha.personen, zonen: ha.zonen, verlauf: ha.verlauf,
                                    tage: ha.verbrauchHeute)
        var vergleich = s
        vergleich.stand = letzterSchnappschuss?.stand ?? s.stand
        guard sofort || vergleich != letzterSchnappschuss else { return }
        letzterSchnappschuss = s
        try? s.schreiben()
        if sofort || Date().timeIntervalSince(letztesNeuLaden) > 15 {
            letztesNeuLaden = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Befehle der Widgets (Lampe schalten, Temperatur …)

    private func befehleEmpfangen() {
        DistributedNotificationCenter.default().addObserver(forName: .init(Schnappschuss.befehlsName), object: nil, queue: .main) { n in
            guard let text = n.object as? String else { return }
            MainActor.assumeIsolated { Kern.shared.ausfuehren(text) }
        }
    }

    func ausfuehren(_ befehl: String) {
        let teile = befehl.split(separator: "|").map(String.init)
        switch teile.first {
        // Nur bekannte Lampen/Steckdosen/Thermostate und gültige Temperaturen annehmen –
        // die Mitteilungen kann jedes Programm auf dem Mac schicken.
        case "schalte" where teile.count >= 3:
            guard ["light", "switch", "group"].contains(Logik.domain(teile[1])), ha.zustaende[teile[1]] != nil else { return }
            ha.schalte(teile[1], teile[2] == "1")
        case "temp" where teile.count >= 3:
            guard Logik.domain(teile[1]) == "climate", let k = Logik.klimaStatus(ha.zustaende[teile[1]]), let t = Double(teile[2]) else { return }
            ha.setzeTemperatur(teile[1], Logik.rundeZiel(t, k))
        case "alleaus":
            ha.alleLichterAus()
        default:
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            self.widgetsAktualisieren(sofort: true)
        }
    }
}

/// Panel mit Zugriff auf openWindow (für "Einstellungen …")
struct PanelMitFenster: View {
    let kern: Kern
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        PanelAnsicht(kern: kern, einrichten: {
            openWindow(id: "einstellungen")
            NSApp.activate(ignoringOtherApps: true)
        }, neuigkeiten: {
            openWindow(id: "neuigkeiten")
            NSApp.activate(ignoringOtherApps: true)
        })
    }
}

/// Symbol in der Menüleiste: Glühbirne, daneben die Zahl der eingeschalteten Lampen.
struct MenueSymbol: View {
    let ha: HaVerbindung
    let einstellungen: Einstellungen

    var body: some View {
        let symbol = !ha.eingerichtet || (!ha.verbunden && !ha.fehler.isEmpty) ? "lightbulb.slash"
            : ha.lichterAn > 0 ? "lightbulb.fill" : "lightbulb"
        if einstellungen.zeigeAnzahl && ha.lichterAn > 0 {
            Label("\(ha.lichterAn)", systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .monospacedDigit()
        } else {
            Image(systemName: symbol)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            if Kern.shared.vorschau { Vorschau.starten(Kern.shared) }
        }
    }
}
