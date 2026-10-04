import Foundation
import AppKit
import Observation
import HALogik

/// Updates: fragt die Releases auf GitHub ab, merkt sich die Änderungen ("Was ist neu?") und
/// installiert auf Wunsch die neue Version: ZIP laden, prüfen, App austauschen, neu starten.
@MainActor
@Observable
final class Aktualisierer {
    struct Notiz: Identifiable, Equatable {
        let version: String
        let titel: String
        let text: String
        var id: String { version }
    }
    enum Zustand: Equatable { case nichts, suche, aktuell, laedt, installiert, fehler(String) }

    var quelle = URL(string: "https://api.github.com/repos/Teyro/homeassistant-leiste/releases?per_page=20")!
    let aktuelleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private(set) var neueVersion: String?
    private(set) var downloadURL: URL?
    private(set) var seite = URL(string: "https://github.com/Teyro/homeassistant-leiste/releases")!
    /// Änderungen der neueren Versionen – oder, ohne Update, der letzten Versionen
    private(set) var notizen: [Notiz] = []
    private(set) var zustand: Zustand = .nichts
    @ObservationIgnored private var letztePruefung = Date.distantPast

    var updateDa: Bool { neueVersion != nil }

    func pruefen() async {
        zustand = .suche
        letztePruefung = Date()
        var anfrage = URLRequest(url: quelle)
        anfrage.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        anfrage.timeoutInterval = 20
        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage),
              (antwort as? HTTPURLResponse)?.statusCode == 200, let liste = JSON.lesen(daten)?.liste else {
            zustand = .fehler("Updates konnten nicht abgefragt werden.")
            return
        }
        let releases = liste.filter { $0["draft"]?.bool != true && $0["prerelease"]?.bool != true }
        let neuer = releases.filter { Logik.versionNeuer($0["tag_name"]?.text ?? "", aktuelleVersion) }
            .sorted { Logik.versionNeuer($0["tag_name"]?.text ?? "", $1["tag_name"]?.text ?? "") }
        func notiz(_ r: JSON) -> Notiz {
            let v = (r["tag_name"]?.text ?? "").replacingOccurrences(of: "v", with: "", options: .anchored)
            return Notiz(version: v, titel: r["name"]?.text ?? v, text: r["body"]?.text ?? "")
        }
        if let erste = neuer.first {
            neueVersion = notiz(erste).version
            notizen = neuer.map(notiz)
            if let s = erste["html_url"]?.text, let u = URL(string: s) { seite = u }
            // nur Downloads aus diesem Projekt
            downloadURL = (erste["assets"]?.liste ?? []).compactMap { a -> URL? in
                guard let n = a["name"]?.text, n.hasPrefix("HA-Leiste-"), n.hasSuffix(".zip"),
                      let s = a["browser_download_url"]?.text, s.hasPrefix("https://github.com/Teyro/homeassistant-leiste/releases/download/") else { return nil }
                return URL(string: s)
            }.first
            zustand = .nichts
        } else {
            neueVersion = nil
            downloadURL = nil
            notizen = releases.prefix(6).map(notiz)
            zustand = .aktuell
        }
    }

    /// Beim Start und dann alle 12 Stunden
    func automatischPruefen() async {
        while true {
            if Date().timeIntervalSince(letztePruefung) > 12 * 3600 { await pruefen() }
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    /// Neue Version laden, prüfen und die laufende App austauschen
    func installieren() async {
        guard let url = downloadURL else { return }
        zustand = .laedt
        do {
            let (datei, antwort) = try await URLSession.shared.download(from: url)
            guard (antwort as? HTTPURLResponse)?.statusCode == 200 else { throw Fehler("Download fehlgeschlagen") }
            let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("HA-Leiste-Update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            let zip = ordner.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: datei, to: zip)
            try ausfuehren("/usr/bin/ditto", ["-x", "-k", zip.path, ordner.path])
            let neu = ordner.appendingPathComponent("HA Leiste.app")
            // Ist es wirklich HA Leiste, und ist die Signatur in Ordnung?
            guard Bundle(url: neu)?.bundleIdentifier == "de.teyro.haleiste" else { throw Fehler("Die geladene Datei ist nicht HA Leiste.") }
            try ausfuehren("/usr/bin/codesign", ["--verify", "--deep", "--strict", neu.path])
            try? ausfuehren("/usr/bin/xattr", ["-dr", "com.apple.quarantine", neu.path])
            zustand = .installiert
            austauschenUndNeuStarten(neu)
        } catch {
            zustand = .fehler((error as? Fehler)?.text ?? error.localizedDescription)
        }
    }

    /// Kleines Skript: wartet, bis die App beendet ist, tauscht sie aus und startet die neue
    private func austauschenUndNeuStarten(_ neu: URL) {
        let ziel = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier
        let skript = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done
        rm -rf "$ZIEL.alt"
        mv "$ZIEL" "$ZIEL.alt" && mv "$NEU" "$ZIEL" && rm -rf "$ZIEL.alt" || mv "$ZIEL.alt" "$ZIEL"
        open "$ZIEL"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", skript]
        p.environment = ["ZIEL": ziel.path, "NEU": neu.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        do {
            try p.run()
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                NSApp.terminate(nil)
            }
        } catch {
            zustand = .fehler("Neustart nicht möglich: \(error.localizedDescription)")
        }
    }

    private struct Fehler: Error { let text: String; init(_ t: String) { text = t } }

    private func ausfuehren(_ programm: String, _ argumente: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: programm)
        p.arguments = argumente
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw Fehler("\(URL(fileURLWithPath: programm).lastPathComponent) meldet Fehler \(p.terminationStatus).") }
    }
}
