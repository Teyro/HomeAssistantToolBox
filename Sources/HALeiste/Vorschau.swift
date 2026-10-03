import SwiftUI
import HALogik

/// Testlauf für die automatischen Bildschirmfotos (GitHub Actions):
/// `HALeiste --vorschau Dark|Light` mit HA_ADRESSE, HA_TOKEN, HA_HAUPTZAEHLER, HA_BILDER.
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
        let panel = PanelAnsicht(ha: kern.ha, einstellungen: kern.einstellungen, zustand: kern.panel) {}
            .background(Hintergrund())
        let f = fensterMit(panel, titel: "HA Leiste", groesse: NSSize(width: 400, height: 640))
        f.setFrameOrigin(NSPoint(x: 60, y: 120))

        Task {
            func warte(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
            func foto(_ name: String) { speichern(f, "\(ordner)/\(modus)_\(name).png") }
            await warte(5)
            print("verbunden:", kern.ha.verbunden, "live:", kern.ha.live, "lichter:", kern.ha.lichter.count, "fehler:", kern.ha.fehler)
            foto("1_lampen")
            if let g = kern.ha.gruppen.first { kern.panel.offen.insert("g:" + g.id) }
            kern.ha.dimme("light.wz_stehlampe", 80)
            await warte(1.5)
            foto("2_aufgeklappt")
            kern.panel.reiter = .steckdosen
            if let g = kern.ha.schalterGruppen.first { kern.panel.offen.insert(g.id) }
            await warte(1.5)
            foto("3_steckdosen")
            kern.panel.einzelneSteckdosenOffen = true
            await warte(1)
            foto("4_steckdosen_einzeln")
            kern.panel.reiter = .energie
            await warte(4)
            print("verbrauch heute:", kern.ha.verbrauchHeute.map { "\($0.key.rawValue)=\($0.value.heute)" }, "verlauf:", kern.ha.verlauf.count)
            foto("5_energie")

            let e = fensterMit(EinstellungenAnsicht(ha: kern.ha, einstellungen: kern.einstellungen), titel: "HA Leiste – Einstellungen",
                               groesse: NSSize(width: 520, height: 900))
            e.setFrameOrigin(NSPoint(x: 520, y: 60))
            await warte(1.5)
            speichern(e, "\(ordner)/\(modus)_6_einstellungen.png")
            await warte(0.5)
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
