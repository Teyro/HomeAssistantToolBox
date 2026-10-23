import Foundation

// MARK: - Szenen, Skripte, Rollläden (1.2)

/// Eine Szene oder ein Skript (Reiter „Szenen“).
public struct Startbar: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

/// Ein Rollladen, eine Markise, ein Tor (cover.*) mit Raum.
public struct Rollladen: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let name: String
    public let raum: String
    public init(id: String, name: String, raum: String) { self.id = id; self.name = name; self.raum = raum }
}

/// Position 0–100 (100 = ganz offen) und was das Gerät kann.
public struct RollladenStatus: Equatable, Sendable {
    public let position: Int?
    public let zustand: String
    public let verfuegbar: Bool
    public let bewegt: Bool
    public let kannPosition: Bool
    public let kannStopp: Bool
    public let kannAuf: Bool
    public let kannZu: Bool
}

public extension Logik {
    /// Szenen und Skripte, alphabetisch (in Home Assistant versteckte und ausgeblendete nicht).
    static func szenen(_ z: [String: Entitaet], versteckt: [String] = [], register: [String: RegisterEintrag] = [:]) -> (szenen: [Startbar], skripte: [Startbar]) {
        var szenen: [Startbar] = [], skripte: [Startbar] = []
        for (id, e) in z {
            let d = domain(id)
            guard d == "scene" || d == "script", !ausgeblendet(id, versteckt), register[id]?.hb != true else { continue }
            if d == "scene" { szenen.append(Startbar(id: id, name: e.name)) } else { skripte.append(Startbar(id: id, name: e.name)) }
        }
        return (szenen.sorted { vorher($0.name, $1.name) }, skripte.sorted { vorher($0.name, $1.name) })
    }

    /// Rollläden nach Raum, dann Name; ohne Raum zuletzt.
    static func rolllaeden(_ z: [String: Entitaet], _ bereiche: Bereiche?, versteckt: [String] = [], register: [String: RegisterEintrag] = [:]) -> [Rollladen] {
        var raumVon: [String: String] = [:]
        for b in bereiche?.bereiche ?? [] {
            for id in b.entitaeten where domain(id) == "cover" { raumVon[id] = b.name.isEmpty ? b.id : b.name }
        }
        let liste = z.compactMap { (id, e) -> Rollladen? in
            guard domain(id) == "cover", !ausgeblendet(id, versteckt), register[id]?.hb != true, register[id]?.ec != true else { return nil }
            return Rollladen(id: id, name: e.name, raum: raumVon[id] ?? "")
        }
        return liste.sorted { a, b in
            if a.raum != b.raum {
                if a.raum.isEmpty { return false }
                if b.raum.isEmpty { return true }
                return vorher(a.raum, b.raum)
            }
            return vorher(a.name, b.name)
        }
    }

    static func rollladenStatus(_ e: Entitaet?) -> RollladenStatus {
        let f = Int(e?.attribute["supported_features"]?.zahl ?? 0)
        let pos: Int? = e?.attribute["current_position"]?.zahl.map { Int($0) }
            ?? (e?.state == "open" ? 100 : e?.state == "closed" ? 0 : nil)
        return RollladenStatus(
            position: pos, zustand: e?.state ?? "unavailable", verfuegbar: istVerfuegbar(e),
            bewegt: e?.state == "opening" || e?.state == "closing",
            kannPosition: f & 4 != 0, kannStopp: f & 8 != 0, kannAuf: f & 1 != 0 || f == 0, kannZu: f & 2 != 0 || f == 0)
    }

    /// Tore und Türen (Garage, Hoftor …) nie über „Alle auf/zu“ mitbewegen.
    static func istTor(_ e: Entitaet?) -> Bool { ["garage", "gate", "door"].contains(e?.klasse ?? "") }

    /// „offen“, „geschlossen“, „40 % offen“, „öffnet …“
    static func rollladenText(_ e: Entitaet?) -> String {
        let s = rollladenStatus(e)
        if !s.verfuegbar { return T("nicht erreichbar") }
        if s.zustand == "opening" { return T("öffnet …") }
        if s.zustand == "closing" { return T("schließt …") }
        if let p = s.position, p > 0, p < 100 { return T("%1 % offen", "\(p)") }
        return s.zustand == "closed" || s.position == 0 ? T("geschlossen") : T("offen")
    }

    /// Wie lange her: „gerade eben“, „vor 5 min“, „vor 3 h“, „vor 2 d“.
    static func formatVor(_ d: Date?, jetzt: Date = Date()) -> String {
        guard let d else { return "" }
        let min = Swift.max(0, Int((jetzt.timeIntervalSince(d) / 60).rounded()))
        if min < 1 { return T("gerade eben") }
        if min < 60 { return T("vor %1 min", "\(min)") }
        let h = min / 60
        return h < 24 ? T("vor %1 h", "\(h)") : T("vor %1 d", "\(h / 24)")
    }
}
