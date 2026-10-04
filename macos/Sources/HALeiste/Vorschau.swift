import SwiftUI
import HALogik

/// Testlauf für die automatischen Bildschirmfotos (GitHub Actions):
/// `HALeiste --vorschau Dark|Light` mit HA_ADRESSE, HA_TOKEN, HA_HAUPTZAEHLER, HA_BILDER
/// (optional HA_ADRESSE2/HA_TOKEN2 für eine zweite Instanz).
@MainActor
enum Vorschau {
    static var fenster: [NSWindow] = []

    static func starten(_ kern: Kern) {
        let args = CommandLine.arguments
        let modus = args.firstIndex(of: "--vorschau").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "Light"
        NSApp.appearance = NSAppearance(named: modus == "Dark" ? .darkAqua : .aqua)
        let ordner = ProcessInfo.processInfo.environment["HA_BILDER"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: ordner, withIntermediateDirectories: true)

        // Hintergrund wie ein Schreibtisch, damit das Glas etwas zum Durchscheinen hat
        let panel = PanelAnsicht(kern: kern) {}.background(Hintergrund())
        let f = fensterMit(panel, titel: "HA Leiste", groesse: NSSize(width: 470, height: 700))
        f.setFrameOrigin(NSPoint(x: 60, y: 80))

        Task {
            func warte(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
            @MainActor func foto(_ name: String) { speichern(f, "\(ordner)/\(modus)_\(name).png") }
            await warte(5)
            print("verbunden:", kern.ha.verbunden, "live:", kern.ha.live, "lichter:", kern.ha.lichter.count, "fehler:", kern.ha.fehler)
            if let name = ProcessInfo.processInfo.environment["HA_NUR_ERSTES"] {
                // Fehlerfall: nur ein Bild, dann noch 20 s laufen lassen (darf nicht weiter anfragen)
                foto(name)
                await warte(20)
                NSApp.terminate(nil)
                return
            }
            foto("1_lampen")
            if let g = kern.ha.gruppen.first { kern.panel.offen.insert("g:" + g.id) }
            kern.ha.dimme("light.wz_stehlampe", 80)
            await warte(1.5)
            foto("2_aufgeklappt")
            kern.panel.reiter = .steckdosen
            if let g = kern.ha.schalterGruppen.first { kern.panel.offen.insert(g.id) }
            await warte(1.5)
            foto("3_steckdosen")
            kern.panel.reiter = .heizung
            kern.panel.offen.insert("h:raum:wohnzimmer")
            await warte(1.5)
            kern.boostStarten(["climate.bad"], grad: 24, minuten: 60)
            await warte(1.5)
            print("heizungen:", kern.ha.heizungen.map(\.name), "boosts:", kern.einstellungen.boosts.count)
            foto("4_heizung")
            kern.panel.reiter = .energie
            await warte(4)
            print("verbrauch heute:", kern.ha.verbrauchHeute.map { "\($0.key.rawValue)=\($0.value.heute)" }, "verlauf:", kern.ha.verlauf.count)
            foto("5_energie")
            kern.panel.reiter = .personen
            await warte(5)
            print("personen:", kern.ha.personen.map { "\($0.name)=\($0.zustand)" })
            foto("6_personen")

            // Widgets wie auf dem Schreibtisch (gleiche Ansichten wie in der Widget-Erweiterung)
            kern.widgetsAktualisieren(sofort: true)
            await warte(1)
            let daten = Schnappschuss.lesen() ?? Schnappschuss()
            print("schnappschuss:", daten.lampen.count, "lampen,", daten.heizungen.count, "heizungen,", daten.werte.count, "werte")
            let w = fensterMit(WidgetVorschau(daten: daten).background(Hintergrund()), titel: "Widgets", groesse: NSSize(width: 800, height: 840))
            w.setFrameOrigin(NSPoint(x: 560, y: 40))
            await warte(2)
            speichern(w, "\(ordner)/\(modus)_8_widgets.png")
            w.orderOut(nil)

            let e = fensterMit(EinstellungenAnsicht(kern: kern), titel: "HA Leiste – Einstellungen", groesse: NSSize(width: 560, height: 900))
            e.setFrameOrigin(NSPoint(x: 560, y: 40))
            await warte(1.5)
            speichern(e, "\(ordner)/\(modus)_9_einstellungen.png")
            e.orderOut(nil)

            // Zweite Instanz
            if kern.einstellungen.instanzen.count > 1 {
                kern.panel.reiter = .lampen
                kern.wechseln("i2")
                await warte(5)
                print("nach Wechsel:", kern.ha.basis, "lichter:", kern.ha.lichter.count, "name:", kern.aktiv?.anzeigename ?? "")
                foto("7_zweite_instanz")
                kern.wechseln("i1")
                await warte(1)
            }
            NSApp.terminate(nil)
        }
    }

    private static func fensterMit<V: View>(_ inhalt: V, titel: String, groesse: NSSize) -> NSWindow {
        let f = NSWindow(contentRect: NSRect(origin: .zero, size: groesse), styleMask: [.titled, .fullSizeContentView],
                         backing: .buffered, defer: false)
        f.title = titel
        f.titlebarAppearsTransparent = true
        f.contentView = NSHostingView(rootView: inhalt)
        f.makeKeyAndOrderFront(nil)
        fenster.append(f)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        return f
    }

    /// Fenster als Bild speichern: per screencapture (echtes Glas), sonst aus der Ansicht selbst
    private static func speichern(_ f: NSWindow, _ pfad: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l\(f.windowNumber)", pfad]
        try? p.run()
        p.waitUntilExit()
        if p.terminationStatus == 0, FileManager.default.fileExists(atPath: pfad) {
            print("Bild", pfad)
            return
        }
        guard let v = f.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: pfad))
        print("Bild (Ansicht)", pfad)
    }
}

/// Alle Widgets in ihren echten Größen (klein 170×170, mittel 364×170, groß 364×382)
private struct WidgetVorschau: View {
    let daten: Schnappschuss

    var body: some View {
        let raum = daten.raeume.first { $0.id == "raum:wohnzimmer" } ?? daten.raeume.first
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    kachel(170, 170) { LampeKachel(lampe: daten.lampen.first { $0.id == "light.wz_stehlampe" } ?? daten.lampen.first) }
                    kachel(170, 170) { SteckdoseKachel(dose: daten.steckdosen.first { $0.id == "switch.pc" } ?? daten.steckdosen.first) }
                    kachel(170, 170) { HeizungKachel(heizung: daten.heizungen.first { $0.id == "raum:wohnzimmer" } ?? daten.heizungen.first) }
                    kachel(170, 170) { WertKachel(wert: daten.werte.first { $0.id == "sensor.temperatur" } ?? daten.werte.first) }
                }
                HStack(alignment: .top, spacing: 16) {
                    kachel(364, 170) { UebersichtKachel(daten: daten) }
                    kachel(364, 170) { EnergieKachel(daten: daten) }
                }
                HStack(alignment: .top, spacing: 16) {
                    kachel(364, 170) { RaumKachel(daten: daten, raum: raum) }
                    kachel(364, 170) { PersonenKachel(daten: daten) }
                }
                HStack(alignment: .top, spacing: 16) {
                    kachel(364, 382) { EnergieKachel(daten: daten, groesse: .gross) }
                    kachel(364, 382) { RaumKachel(daten: daten, raum: raum, groesse: .gross) }
                }
            }
            .padding(20)
        }
    }

    private func kachel<V: View>(_ b: CGFloat, _ h: CGFloat, @ViewBuilder inhalt: () -> V) -> some View {
        inhalt()
            .padding(14)
            .frame(width: b, height: h, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }
}

/// Farbverlauf als Ersatz für das Schreibtischbild
private struct Hintergrund: View {
    @Environment(\.colorScheme) private var schema
    var body: some View {
        LinearGradient(colors: schema == .dark
                       ? [Color(red: 0.12, green: 0.14, blue: 0.3), Color(red: 0.25, green: 0.1, blue: 0.3), Color(red: 0.05, green: 0.2, blue: 0.25)]
                       : [Color(red: 0.75, green: 0.85, blue: 1.0), Color(red: 0.95, green: 0.8, blue: 0.9), Color(red: 0.8, green: 0.95, blue: 0.9)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}
