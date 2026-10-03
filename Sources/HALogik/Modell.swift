import Foundation

/// Ein Zustand aus Home Assistant (light.*, switch.*, sensor.* …).
public struct Entitaet: Equatable, Sendable {
    public let id: String
    public var state: String
    public var attribute: [String: JSON]
    public var zuletzt: String

    public init(id: String, state: String, attribute: [String: JSON] = [:], zuletzt: String = "") {
        self.id = id
        self.state = state
        self.attribute = attribute
        self.zuletzt = zuletzt
    }

    public init?(json: JSON?) {
        guard let json, let id = json["entity_id"]?.text else { return nil }
        self.id = id
        state = json["state"]?.text ?? ""
        attribute = json["attributes"]?.objekt ?? [:]
        zuletzt = json["last_changed"]?.text ?? ""
    }

    public var name: String { attribute["friendly_name"]?.text ?? id }
    public var einheit: String { attribute["unit_of_measurement"]?.text ?? "" }
    public var klasse: String? { attribute["device_class"]?.text }
    /// Mitglieder einer Gruppe (Attribut entity_id), sonst nil
    public var mitglieder: [String]? {
        guard let l = attribute["entity_id"]?.liste, !l.isEmpty else { return nil }
        return l.compactMap { $0.text }
    }
    public var istAn: Bool { state == "on" }
    public var istVerfuegbar: Bool { state != "unavailable" && state != "unknown" }
    public var wert: Double? { Double(state.trimmingCharacters(in: .whitespaces)) }
}

public struct LichtGruppe: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let mitglieder: [String]
    public let alt: Bool
}

public struct Raum: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let lichter: [String]
    public let schalter: [String]
}

public struct Schalter: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let raum: String
    public let leistung: String
}

public struct SchalterGruppe: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    /// Entität zum gemeinsamen Schalten; leer bei Geräten mit mehreren Dosen
    public let steuerId: String
    public var mitglieder: [String]
    public let art: String
    public var leistung: [String] = []
    public var raum: String = ""
}

public struct Messung: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let watt: Double
}

public struct Zaehlerstand: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let kwh: Double
}

public struct RegisterEintrag: Equatable, Sendable {
    /// Einstellungs- oder Diagnose-Entität
    public let ec: Bool
    /// In Home Assistant versteckt
    public let hb: Bool
    public init(ec: Bool, hb: Bool) { self.ec = ec; self.hb = hb }
}

/// Ergebnis des Bereiche-Templates: Räume, Leistungssensoren je Schalter, Gerät je Schalter.
public struct Bereiche: Equatable, Sendable {
    public struct Bereich: Equatable, Sendable { public let id: String; public let name: String; public let entitaeten: [String] }
    public struct Geraet: Equatable, Sendable { public let schalter: String; public let geraet: String; public let name: String }
    public var bereiche: [Bereich] = []
    public var leistung: [(String, String)] = []
    public var geraete: [Geraet] = []

    public init() {}

    public init(json: JSON?) {
        guard let json else { return }
        bereiche = (json["bereiche"]?.liste ?? []).map {
            Bereich(id: $0["id"]?.text ?? "", name: $0["name"]?.text ?? "", entitaeten: ($0["e"]?.liste ?? []).compactMap { $0.text })
        }
        leistung = (json["leistung"]?.liste ?? []).compactMap {
            guard let a = $0[0]?.text, let b = $0[1]?.text else { return nil }
            return (a, b)
        }
        geraete = (json["geraete"]?.liste ?? []).compactMap {
            guard let s = $0[0]?.text, let d = $0[1]?.text else { return nil }
            return Geraet(schalter: s, geraet: d, name: $0[2]?.text ?? "")
        }
    }

    public static func == (a: Bereiche, b: Bereiche) -> Bool {
        a.bereiche == b.bereiche && a.geraete == b.geraete
            && a.leistung.map { $0.0 + "|" + $0.1 } == b.leistung.map { $0.0 + "|" + $0.1 }
    }
}

public struct Optionen: Equatable, Sendable {
    public var alteGruppen = true
    public var nurSteckdosen = false
    public var hauptzaehler = ""
    public var ausgeblendet = ""
    public init(alteGruppen: Bool = true, nurSteckdosen: Bool = false, hauptzaehler: String = "", ausgeblendet: String = "") {
        self.alteGruppen = alteGruppen
        self.nurSteckdosen = nurSteckdosen
        self.hauptzaehler = hauptzaehler
        self.ausgeblendet = ausgeblendet
    }
}

/// Das fertige Anzeigemodell (wie baueModell() im Plasma-Widget).
public struct Anzeige: Equatable, Sendable {
    public var gruppen: [LichtGruppe] = []
    public var raeume: [Raum] = []
    public var ohneRaum: [String] = []
    public var lichter: [String] = []
    public var lichterAn = 0
    public var schalter: [Schalter] = []
    public var schalterAn = 0
    public var schalterGruppen: [SchalterGruppe] = []
    public var einzelneSchalter: [String] = []
    public var leistung: [Messung] = []
    public var energie: [Zaehlerstand] = []
    public var hauptWatt: Double?
    public var summeWatt: Double = 0
    public init() {}
}

public struct GruppenStatus: Equatable, Sendable {
    public let an: Int
    public let gesamt: Int
    public let verfuegbar: Int
    public let helligkeit: Int
    public let dimmbar: Bool
}

public struct SchalterGruppenStatus: Equatable, Sendable {
    public let an: Int
    public let gesamt: Int
    public let verfuegbar: Int
    public let watt: Double?
}

public struct Punkt: Equatable, Sendable, Identifiable {
    public let t: Date
    public let w: Double
    public var id: Date { t }
    public init(t: Date, w: Double) { self.t = t; self.w = w }
}

public struct Kennzahlen: Equatable, Sendable {
    public let kwh: Double
    public let spitze: Punkt
    public let minimum: Punkt
    public let schnitt: Double
}

public enum VerbrauchsArt: String, CaseIterable, Sendable, Identifiable {
    case strom, wasser, gas
    public var id: String { rawValue }
}

public struct Tageswert: Equatable, Sendable {
    public var heute: Double
    public var gestern: Double?
    public var einheit: String
    public var zaehler: [String]
    public var gueltig: Bool
    public init(heute: Double, gestern: Double?, einheit: String, zaehler: [String], gueltig: Bool) {
        self.heute = heute
        self.gestern = gestern
        self.einheit = einheit
        self.zaehler = zaehler
        self.gueltig = gueltig
    }
}

/// Farbe als RGB 0…255
public struct RGB: Equatable, Sendable {
    public let r: Double, g: Double, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    public var hex: String {
        func h(_ x: Double) -> String { String(format: "%02x", Int(max(0, min(255, x.rounded())))) }
        return "#" + h(r) + h(g) + h(b)
    }
}
