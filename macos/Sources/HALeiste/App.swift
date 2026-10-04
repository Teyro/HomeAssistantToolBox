import SwiftUI
import HALogik

/// Menüleisten-App für Home Assistant: Lampen, Steckdosen und Energie mit einem Klick.
@main
struct HALeisteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var kern = Kern.shared

    var body: some Scene {
        MenuBarExtra {
            PanelMitFenster(kern: kern)
        } label: {
            MenueSymbol(ha: kern.ha, einstellungen: kern.einstellungen)
        }
        .menuBarExtraStyle(.window)

        Window("HA Leiste – Einstellungen", id: "einstellungen") {
            EinstellungenAnsicht(ha: kern.ha, einstellungen: kern.einstellungen)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// Alles, was die App einmal braucht: Einstellungen, Verbindung, Panelzustand.
@MainActor
@Observable
final class Kern {
    static let shared = Kern()

    let vorschau = CommandLine.arguments.contains("--vorschau")
    let einstellungen: Einstellungen
    let ha = HaVerbindung()
    let panel = PanelZustand()
    @ObservationIgnored private var verzoegert: Task<Void, Never>?

    private init() {
        einstellungen = Einstellungen(vorschau: vorschau)
        einstellungen.geaendert = { [weak self] in self?.uebernehmen() }
        let env = ProcessInfo.processInfo.environment
        if vorschau {
            // Testlauf: Verbindung und Hauptzähler aus Umgebungsvariablen
            einstellungen.adresse = env["HA_ADRESSE"] ?? "http://127.0.0.1:8123"
            einstellungen.hauptzaehler = env["HA_HAUPTZAEHLER"] ?? ""
        }
        uebernehmen(sofort: true)
    }

    private var token: String {
        vorschau ? (ProcessInfo.processInfo.environment["HA_TOKEN"] ?? "") : einstellungen.token
    }

    /// Einstellungen an die Verbindung geben (Adresse/Token kurz verzögert)
    func uebernehmen(sofort: Bool = false) {
        ha.setzeOptionen(einstellungen.optionen)
        ha.abfrageSekunden = einstellungen.abfrageSekunden
        verzoegert?.cancel()
        if sofort {
            ha.verbinde(adresse: einstellungen.adresse, token: token)
        } else {
            verzoegert = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                self.ha.verbinde(adresse: self.einstellungen.adresse, token: self.token)
            }
        }
    }
}

/// Panel mit Zugriff auf openWindow (für "Einstellungen …")
struct PanelMitFenster: View {
    let kern: Kern
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        PanelAnsicht(ha: kern.ha, einstellungen: kern.einstellungen, zustand: kern.panel) {
            openWindow(id: "einstellungen")
            NSApp.activate(ignoringOtherApps: true)
        }
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
