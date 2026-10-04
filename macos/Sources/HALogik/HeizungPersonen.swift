import Foundation

// MARK: - Heizung

/// Ein Raum mit Thermostat(en) und/oder Temperatursensor – oder ein Thermostat ohne Raum.
public struct HeizRaum: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let name: String
    public let klima: [String]
    public let temperatur: String
    public let feuchte: String
    public init(id: String, name: String, klima: [String], temperatur: String = "", feuchte: String = "") {
        self.id = id; self.name = name; self.klima = klima; self.temperatur = temperatur; self.feuchte = feuchte
    }
}

/// Zustand eines Thermostats (climate.*)
public struct KlimaStatus: Equatable, Sendable {
    public let modus: String
    public let aktion: String
    public let heizt: Bool
    public let ist: Double?
    public let ziel: Double?
    public let min: Double
    public let max: Double
    public let schritt: Double
    public let modi: [String]
    public let presets: [String]
    public let preset: String
    public let verfuegbar: Bool
}

/// Zusammenfassung eines Raums: Ist-Temperatur (Raumsensor vor Thermostat), Ziel, heizt?
public struct RaumKlima: Equatable, Sendable {
    public let ist: Double?
    public let ziel: Double?
    public let feuchte: Double?
    public let heizt: Bool
    public let aus: Bool
    public let thermostat: KlimaStatus?
}

public struct Person: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let name: String
    public let zustand: String
    public let lat: Double?
    public let lon: Double?
    public let seit: Date?
    public let farbe: String
}

public struct Zone: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let name: String
    public let lat: Double
    public let lon: Double
    public let radius: Double
    public var heim: Bool { id == "zone.home" }
}

/// Eine Home-Assistant-Instanz (der Token liegt getrennt im Schlüsselbund)
public struct Instanz: Equatable, Identifiable, Sendable, Codable {
    public var id: String
    public var name: String
    public var adresse: String
    public var favorit: Bool
    public var hauptzaehler: String
    public var zaehlerStrom: String
    public var zaehlerWasser: String
    public var zaehlerGas: String
    public init(id: String, name: String = "", adresse: String = "", favorit: Bool = false, hauptzaehler: String = "",
                zaehlerStrom: String = "", zaehlerWasser: String = "", zaehlerGas: String = "") {
        self.id = id; self.name = name; self.adresse = adresse; self.favorit = favorit; self.hauptzaehler = hauptzaehler
        self.zaehlerStrom = zaehlerStrom; self.zaehlerWasser = zaehlerWasser; self.zaehlerGas = zaehlerGas
    }
    /// Anzeigename: eigener Name, sonst der Rechnername aus der Adresse
    public var anzeigename: String {
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return URL(string: adresse)?.host() ?? (adresse.isEmpty ? "Neue Instanz" : adresse)
    }
}

/// Laufendes "Extra heizen": Temperatur bis zu einem Zeitpunkt, danach zurück
public struct Boost: Equatable, Sendable, Codable {
    public let instanz: String
    public let id: String
    public let bis: Date
    public let vorher: Double
    public let modus: String
    public init(instanz: String, id: String, bis: Date, vorher: Double, modus: String) {
        self.instanz = instanz; self.id = id; self.bis = bis; self.vorher = vorher; self.modus = modus
    }
}

public extension Logik {

    /// Räume mit Thermostat oder Temperatursensor; Thermostate ohne Raum als eigene Einträge.
    static func heizungen(_ z: [String: Entitaet], _ bereiche: Bereiche?, versteckt: [String] = []) -> [HeizRaum] {
        var liste: [HeizRaum] = []
        var vergeben = Set<String>()
        func sichtbar(_ id: String) -> Bool { z[id] != nil && !ausgeblendet(id, versteckt) }
        for b in bereiche?.bereiche ?? [] {
            let klima = b.entitaeten.filter { domain($0) == "climate" && sichtbar($0) }
            let temp = b.temperatur.filter(sichtbar)
            let feuchte = b.feuchte.filter(sichtbar)
            if klima.isEmpty && temp.isEmpty { continue }
            klima.forEach { vergeben.insert($0) }
            liste.append(HeizRaum(id: "raum:" + b.id, name: b.name.isEmpty ? b.id : b.name, klima: klima,
                                  temperatur: temp.first ?? "", feuchte: feuchte.first ?? ""))
        }
        for id in z.keys.sorted() where domain(id) == "climate" && !vergeben.contains(id) && sichtbar(id) {
            let n = z[id]!.name.replacingOccurrences(of: #"^(heizung|thermostat|heizkörper)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            liste.append(HeizRaum(id: id, name: n, klima: [id]))
        }
        return liste.sorted { vorher($0.name, $1.name) }
    }

    static func klimaStatus(_ e: Entitaet?) -> KlimaStatus? {
        guard let e else { return nil }
        let a = e.attribute
        let aktion = a["hvac_action"]?.text ?? (e.state == "off" ? "off" : "")
        return KlimaStatus(
            modus: e.state, aktion: aktion, heizt: aktion == "heating" || aktion == "preheating",
            ist: a["current_temperature"]?.zahl, ziel: a["temperature"]?.zahl,
            min: a["min_temp"]?.zahl ?? 7, max: a["max_temp"]?.zahl ?? 30, schritt: a["target_temp_step"]?.zahl ?? 0.5,
            modi: (a["hvac_modes"]?.liste ?? []).compactMap { $0.text },
            presets: (a["preset_modes"]?.liste ?? []).compactMap { $0.text }.filter { $0 != "none" },
            preset: a["preset_mode"]?.text.flatMap { $0 == "none" ? nil : $0 } ?? "",
            verfuegbar: e.istVerfuegbar)
    }

    static func raumKlima(_ r: HeizRaum, _ z: [String: Entitaet]) -> RaumKlima {
        let t = r.klima.first.flatMap { klimaStatus(z[$0]) }
        let sensor = r.temperatur.isEmpty ? nil : z[r.temperatur]?.wert
        let feuchte = r.feuchte.isEmpty ? nil : z[r.feuchte]?.wert
        let heizt = r.klima.contains { klimaStatus(z[$0])?.heizt == true }
        let aus = t != nil && r.klima.allSatisfy { z[$0]?.state == "off" }
        return RaumKlima(ist: sensor ?? t?.ist, ziel: (t != nil && t!.modus != "off") ? t!.ziel : nil,
                         feuchte: feuchte, heizt: heizt, aus: aus, thermostat: t)
    }

    static func formatTemp(_ t: Double?, stellen: Int = 1) -> String {
        guard let t, !t.isNaN else { return "–" }
        return komma(t, stellen) + " °C"
    }

    static func modusName(_ m: String) -> String {
        [ "off": "Aus", "heat": "Heizen", "auto": "Automatik", "heat_cool": "Heizen/Kühlen", "cool": "Kühlen", "dry": "Entfeuchten",
          "fan_only": "Lüfter", "eco": "Eco", "comfort": "Komfort", "boost": "Boost", "away": "Abwesend", "home": "Zuhause",
          "sleep": "Schlafen", "activity": "Aktiv" ][m] ?? m
    }

    /// Temperatur auf den Schritt des Thermostats runden und begrenzen
    static func rundeZiel(_ t: Double, _ k: KlimaStatus?) -> Double {
        let s = k?.schritt ?? 0.5
        let r = (t / s).rounded() * s
        return Swift.max(k?.min ?? 5, Swift.min(k?.max ?? 30, (r * 10).rounded() / 10))
    }

    static func formatDauer(_ sekunden: TimeInterval) -> String {
        let min = Int((sekunden / 60).rounded(.up))
        if min < 60 { return "\(min) min" }
        let h = min / 60, m = min % 60
        return m > 0 ? "\(h) h \(m) min" : "\(h) h"
    }

    // MARK: Personen

    static let personenFarben = ["#3daee9", "#f67400", "#9b59b6", "#1cdc9a", "#da4453", "#fdbc4b", "#2980b9", "#27ae60"]

    static func personen(_ z: [String: Entitaet], versteckt: [String] = []) -> [Person] {
        let liste = z.values.filter { domain($0.id) == "person" && !ausgeblendet($0.id, versteckt) }
            .sorted { vorher($0.name, $1.name) }
        return liste.enumerated().map { i, e in
            Person(id: e.id, name: e.name, zustand: e.state, lat: e.attribute["latitude"]?.zahl, lon: e.attribute["longitude"]?.zahl,
                   seit: datum(e.zuletzt), farbe: personenFarben[i % personenFarben.count])
        }
    }

    static func zonen(_ z: [String: Entitaet]) -> [Zone] {
        z.values.filter { domain($0.id) == "zone" }.compactMap { e in
            guard let lat = e.attribute["latitude"]?.zahl, let lon = e.attribute["longitude"]?.zahl else { return nil }
            return Zone(id: e.id, name: e.name, lat: lat, lon: lon, radius: e.attribute["radius"]?.zahl ?? 100)
        }.sorted { $0.id < $1.id }
    }

    static func ortText(_ zustand: String) -> String {
        switch zustand {
        case "home": "Zuhause"
        case "not_home": "Unterwegs"
        case "unknown", "unavailable": "Unbekannt"
        default: zustand
        }
    }

    /// Entfernung in km (Haversine)
    static func entfernung(_ lat1: Double?, _ lon1: Double?, _ lat2: Double?, _ lon2: Double?) -> Double? {
        guard let lat1, let lon1, let lat2, let lon2 else { return nil }
        let g = Double.pi / 180
        let dLat = (lat2 - lat1) * g, dLon = (lon2 - lon1) * g
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * g) * cos(lat2 * g) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * 6371 * asin(sqrt(a))
    }

    static func formatEntfernung(_ km: Double?) -> String {
        guard let km else { return "" }
        if km < 1 { return "\(Int((km * 100).rounded()) * 10) m" }
        return km < 10 ? komma(km, 1) + " km" : "\(Int(km.rounded())) km"
    }

    static func formatSeit(_ d: Date?, jetzt: Date = Date()) -> String {
        guard let d else { return "" }
        let min = Swift.max(0, Int((jetzt.timeIntervalSince(d) / 60).rounded()))
        if min < 1 { return "gerade eben" }
        if min < 60 { return "seit \(min) min" }
        let h = min / 60
        return h < 24 ? "seit \(h) h" : "seit \(h / 24) d"
    }

    static func initialen(_ name: String) -> String {
        let teile = name.split(separator: " ")
        let a = teile.first?.first.map(String.init) ?? "?"
        let b = teile.count > 1 ? (teile.last?.first.map(String.init) ?? "") : ""
        return (a + b).uppercased()
    }

    // MARK: Instanzen

    static func favorit(_ liste: [Instanz]) -> Instanz? { liste.first { $0.favorit } ?? liste.first }

    static func neueInstanzId(_ liste: [Instanz]) -> String {
        var n = 1
        while liste.contains(where: { $0.id == "i\(n)" }) { n += 1 }
        return "i\(n)"
    }
}
