import Foundation

// "Wo ist?": Personen und Ortungsgeräte (device_tracker mit GPS) wie in Apples „Wo ist?“ – auf Wunsch aus
// mehreren Installationen auf einer Karte (wie logik.js). Einträge weiterer Installationen bekommen den
// Schlüssel "<entität>@<instanz>", damit gleiche Namen (person.anna hier und dort) nicht kollidieren.

public enum OrtArt: String, CaseIterable, Identifiable, Sendable, Codable {
    case personen, geraete, objekte
    public var id: String { rawValue }
}

/// Person oder Ortungsgerät mit Standort
public struct Ort: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let entitaet: String
    public let instanz: String
    public let name: String
    public let art: OrtArt
    public let zustand: String
    /// "Zuhause", Zonenname, "Unterwegs" – bei weiteren Installationen "Zuhause · <Name>"
    public let ort: String
    public let lat: Double
    public let lon: Double
    public let genau: Double
    public let seit: Date?
    public let akku: Int?
    public let farbe: String
}

public struct SpurPunkt: Equatable, Sendable {
    public let t: Date
    public let lat: Double
    public let lon: Double
    public init(t: Date, lat: Double, lon: Double) { self.t = t; self.lat = lat; self.lon = lon }
}

extension Logik {
    /// Minuten: aus, 30 min, 3 h, 6 h
    public static let verlaufStufen = [0, 30, 180, 360]
    static let ortGeraet = try! NSRegularExpression(pattern: "iphone|ipad|handy|phone|pixel|galaxy|smartphone|watch|uhr|macbook|imac|laptop|notebook|tablet|computer",
                                                    options: .caseInsensitive)

    public static func ortArt(_ id: String, _ name: String) -> OrtArt {
        if domain(id) == "person" { return .personen }
        let s = id + " " + name
        return ortGeraet.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil ? .geraete : .objekte
    }

    /// Akkustand in % aus dem Attribut oder dem Sensor der Companion-App (sensor.<gerät>_battery_level)
    public static func ortAkku(_ e: Entitaet, _ z: [String: Entitaet]) -> Int? {
        let quelle = e.attribute["source"]?.text.flatMap { z[$0] }
        for k in [e, quelle].compactMap({ $0 }) {
            if let w = k.attribute["battery_level"]?.zahl ?? k.attribute["battery"]?.zahl { return Int(w.rounded()) }
            if let s = k.attribute["battery_level"]?.text, let w = Double(s) { return Int(w.rounded()) }
        }
        let basis = (quelle ?? e).id.split(separator: ".").dropFirst().first.map(String.init) ?? ""
        if let s = (z["sensor." + basis + "_battery_level"] ?? z["sensor." + basis + "_battery"])?.wert { return Int(s.rounded()) }
        return nil
    }

    /// Alle Personen und Ortungsgeräte mit Standort einer Installation
    public static func orter(_ z: [String: Entitaet], versteckt: [String] = [], instanz: String = "", instanzName: String = "", weitere: Bool = false) -> [Ort] {
        z.values.filter { ["person", "device_tracker"].contains(domain($0.id)) && !ausgeblendet($0.id, versteckt) }
            .compactMap { e -> Ort? in
                guard let lat = e.attribute["latitude"]?.zahl, let lon = e.attribute["longitude"]?.zahl else { return nil }
                var ort = ortText(e.state)
                if weitere && e.state == "home" && !instanzName.isEmpty { ort = T("Zuhause") + " · " + instanzName }
                return Ort(id: weitere ? e.id + "@" + instanz : e.id, entitaet: e.id, instanz: instanz, name: e.name, art: ortArt(e.id, e.name),
                           zustand: e.state, ort: ort, lat: lat, lon: lon, genau: e.attribute["gps_accuracy"]?.zahl ?? 0,
                           seit: datum(e.zuletzt), akku: ortAkku(e, z), farbe: personFarbe(e.name))
            }
            .sorted { vorher($0.name, $1.name) }
    }

    /// Weg aus der History-API (ohne minimal_response); ungenaue Ortungen (> 250 m) und Stillstand weggelassen
    public static func ortSpur(_ antwort: JSON?, entitaet: String, ab: Date) -> [SpurPunkt] {
        let reihe = (antwort?.liste ?? []).compactMap(\.liste).first { $0.first?["entity_id"]?.text == entitaet } ?? []
        var spur: [SpurPunkt] = []
        for p in reihe {
            let a = p["attributes"]
            guard let lat = a?["latitude"]?.zahl, let lon = a?["longitude"]?.zahl, (a?["gps_accuracy"]?.zahl ?? 0) <= 250 else { continue }
            if let v = spur.last, abs(v.lat - lat) < 2e-5, abs(v.lon - lon) < 2e-5 { continue }
            let t = (p["last_updated"]?.text).flatMap(datum) ?? zeitVon(p) ?? ab
            spur.append(SpurPunkt(t: Swift.max(t, ab), lat: lat, lon: lon))
        }
        return spur
    }

    /// Spur auf die letzten minuten kürzen und den aktuellen Standort anhängen (leer, wenn kein Weg)
    public static func spurSeit(_ spur: [SpurPunkt], minuten: Int, jetzt: Date = Date(), aktuell: Ort?) -> [SpurPunkt] {
        guard minuten > 0 else { return [] }
        let ab = jetzt.addingTimeInterval(-Double(minuten) * 60)
        var teil = spur.filter { $0.t >= ab }
        if let o = aktuell, teil.last.map({ $0.lat != o.lat || $0.lon != o.lon }) ?? true {
            teil.append(SpurPunkt(t: o.seit ?? jetzt, lat: o.lat, lon: o.lon))
        }
        return teil.count > 1 ? teil : []
    }

    public static func streckeKm(_ spur: [SpurPunkt]) -> Double {
        zip(spur, spur.dropFirst()).reduce(0) { $0 + (entfernung($1.0.lat, $1.0.lon, $1.1.lat, $1.1.lon) ?? 0) }
    }

    public static func verlaufStufeText(_ minuten: Int) -> String {
        if minuten == 0 { return T("Aus") }
        return minuten < 60 ? T("%1 min", "\(minuten)") : T("%1 h", "\(minuten / 60)")
    }

    /// Gleichbleibende Farbe aus dem Namen (wie personFarbe in logik.js)
    public static func personFarbe(_ name: String) -> String {
        let farben = ["#3daee9", "#f67400", "#1cdc9a", "#da4453", "#9b59b6", "#fdbc4b", "#2980b9", "#27ae60"]
        var h = 0
        for c in name.utf16 { h = (h * 31 + Int(c)) % 997 }
        return farben[h % farben.count]
    }
}
