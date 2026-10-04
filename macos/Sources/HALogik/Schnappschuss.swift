import Foundation

/// Alles, was die Widgets auf dem Schreibtisch zeigen. Die App schreibt es als JSON-Datei,
/// die Widgets lesen es nur (sie haben keinen Zugang zu Home Assistant selbst).
public struct Schnappschuss: Codable, Equatable, Sendable {
    public struct Lampe: Codable, Equatable, Sendable, Identifiable {
        public let id: String, name: String, an: Bool, verfuegbar: Bool, helligkeit: Int?, farbe: String?, raum: String
    }
    public struct Steckdose: Codable, Equatable, Sendable, Identifiable {
        public let id: String, name: String, an: Bool, verfuegbar: Bool, watt: Double?, raum: String
    }
    public struct Heizung: Codable, Equatable, Sendable, Identifiable {
        public let id: String, name: String, klima: [String], ist: Double?, ziel: Double?, feuchte: Double?
        public let heizt: Bool, aus: Bool, min: Double, max: Double, schritt: Double
        public var fensterOffen: Bool = false
    }
    public struct Raum: Codable, Equatable, Sendable, Identifiable {
        public let id: String, name: String, lampen: [String], steckdosen: [String], heizung: String?
    }
    public struct Tag: Codable, Equatable, Sendable, Identifiable {
        public let art: String, heute: Double, gestern: Double?, einheit: String
        public var id: String { art }
    }
    public struct Verbraucher: Codable, Equatable, Sendable, Identifiable {
        public let id: String, name: String, watt: Double
    }
    public struct PersonKurz: Codable, Equatable, Sendable, Identifiable {
        public let id: String, name: String, ort: String, zuhause: Bool, km: Double?, farbe: String, lat: Double?, lon: Double?
    }
    public struct Wert: Codable, Equatable, Sendable, Identifiable {
        public let id: String, name: String, text: String, schaltbar: Bool, an: Bool
    }

    public var instanz: String = ""
    public var stand: Date = .distantPast
    public var verbunden = false
    public var lampen: [Lampe] = []
    public var lichterAn = 0
    public var lichterGesamt = 0
    public var steckdosen: [Steckdose] = []
    public var heizungen: [Heizung] = []
    public var raeume: [Raum] = []
    public var watt: Double?
    public var verlauf: [Double] = []
    public var tage: [Tag] = []
    public var verbraucher: [Verbraucher] = []
    public var personen: [PersonKurz] = []
    public var heimLat: Double?
    public var heimLon: Double?
    public var werte: [Wert] = []

    public init() {}

    /// Ort der Datei (die App schreibt, die Widgets lesen)
    public static var datei: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/HA Leiste", isDirectory: true)
            .appendingPathComponent("widgets.json")
    }

    public static func lesen() -> Schnappschuss? {
        // In der Sandbox der Widgets zeigt homeDirectoryForCurrentUser in den Container –
        // darum den echten Pfad aus dem Benutzerverzeichnis zusammensetzen.
        let echt = URL(fileURLWithPath: "/Users/\(NSUserName())/Library/Application Support/HA Leiste/widgets.json")
        for url in [echt, datei] {
            if let d = try? Data(contentsOf: url) {
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .secondsSince1970
                if let s = try? dec.decode(Schnappschuss.self, from: d) { return s }
            }
        }
        return nil
    }

    public func schreiben() throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        let d = try enc.encode(self)
        try FileManager.default.createDirectory(at: Self.datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        try d.write(to: Self.datei, options: .atomic)
    }

    // MARK: Befehle der Widgets an die App (als verteilte Mitteilung, ohne Token im Widget)

    public static let befehlsName = "de.teyro.haleiste.befehl"
    public static let neuLadenName = "de.teyro.haleiste.widgets"

    /// "schalte|light.x|1", "temp|climate.x|21.5", "alleaus"
    public static func befehl(_ teile: String...) -> String { teile.joined(separator: "|") }
}

public extension Logik {
    /// Schnappschuss aus dem aktuellen Zustand bauen
    static func schnappschuss(instanz: String, verbunden: Bool, z: [String: Entitaet], anzeige: Anzeige,
                              heizungen: [HeizRaum], personen: [Person], zonen: [Zone], verlauf: [Punkt],
                              tage: [VerbrauchsArt: Tageswert]) -> Schnappschuss {
        var s = Schnappschuss()
        s.instanz = instanz
        s.stand = Date()
        s.verbunden = verbunden
        var raumVon: [String: String] = [:]
        for r in anzeige.raeume { for id in r.lichter + r.schalter { raumVon[id] = r.name } }
        s.lichterAn = anzeige.lichterAn
        s.lichterGesamt = anzeige.lichter.count
        let lampenIds = anzeige.gruppen.map(\.id) + anzeige.lichter
        s.lampen = lampenIds.compactMap { id in
            guard let e = z[id] else { return nil }
            return .init(id: id, name: e.name, an: e.istAn, verfuegbar: e.istVerfuegbar,
                         helligkeit: dimmbar(e) ? helligkeit(e) : nil, farbe: lampenFarbe(e)?.hex, raum: raumVon[id] ?? "")
        }
        s.steckdosen = anzeige.schalter.compactMap { sch in
            guard let e = z[sch.id] else { return nil }
            return .init(id: sch.id, name: sch.name, an: e.istAn, verfuegbar: e.istVerfuegbar,
                         watt: sch.leistung.isEmpty ? nil : wattVon(z[sch.leistung]), raum: sch.raum)
        }
        s.heizungen = heizungen.map { h in
            let k = raumKlima(h, z)
            return .init(id: h.id, name: h.name, klima: h.klima, ist: k.ist, ziel: k.ziel, feuchte: k.feuchte, heizt: k.heizt, aus: k.aus,
                         min: k.thermostat?.min ?? 5, max: k.thermostat?.max ?? 30, schritt: k.thermostat?.schritt ?? 0.5,
                         fensterOffen: k.fensterOffen)
        }
        var raumIds = Set<String>()
        s.raeume = anzeige.raeume.map { r in
            raumIds.insert("raum:" + r.id)
            return .init(id: "raum:" + r.id, name: r.name, lampen: r.lichter, steckdosen: r.schalter,
                         heizung: heizungen.first { $0.id == "raum:" + r.id }?.id)
        } + heizungen.filter { $0.id.hasPrefix("raum:") && !raumIds.contains($0.id) }.map {
            .init(id: $0.id, name: $0.name, lampen: [], steckdosen: [], heizung: $0.id)
        }
        s.watt = anzeige.hauptWatt ?? (anzeige.leistung.isEmpty ? nil : anzeige.summeWatt)
        // Verlauf auf höchstens 48 Werte verdichten
        if verlauf.count > 1 {
            let schritt = Swift.max(1, verlauf.count / 48)
            s.verlauf = stride(from: 0, to: verlauf.count, by: schritt).map { verlauf[$0].w }
        }
        s.tage = VerbrauchsArt.allCases.compactMap { art in
            guard let w = tage[art], w.gueltig else { return nil }
            return .init(art: art.rawValue, heute: w.heute, gestern: w.gestern, einheit: w.einheit)
        }
        s.verbraucher = anzeige.leistung.filter { $0.watt > 0 }.prefix(6).map { .init(id: $0.id, name: $0.name, watt: $0.watt) }
        let heim = zonen.first { $0.heim }
        s.heimLat = heim?.lat
        s.heimLon = heim?.lon
        s.personen = personen.map {
            .init(id: $0.id, name: $0.name, ort: ortText($0.zustand), zuhause: $0.zustand == "home",
                  km: entfernung($0.lat, $0.lon, heim?.lat, heim?.lon), farbe: $0.farbe, lat: $0.lat, lon: $0.lon)
        }
        // Beliebige Entitäten für das Widget "Entität"
        s.werte = z.values.filter { !["zone", "group"].contains(domain($0.id)) }.sorted { vorher($0.name, $1.name) }.map { e in
            let d = domain(e.id)
            let schaltbar = d == "light" || d == "switch"
            let text: String
            if schaltbar { text = e.istAn ? "an" : (e.state == "off" ? "aus" : e.state) }
            else if d == "climate" { text = formatTemp(klimaStatus(e)?.ist) }
            else if d == "person" { text = ortText(e.state) }
            else if let w = e.wert {
                if e.einheit == "W" || e.einheit == "kW" { text = formatWatt(e.einheit == "kW" ? w * 1000 : w) }
                else { text = (abs(w) >= 100 ? "\(Int(w.rounded()))" : komma(w, 1)) + (e.einheit.isEmpty ? "" : " " + e.einheit) }
            } else { text = e.state }
            return .init(id: e.id, name: e.name, text: text, schaltbar: schaltbar, an: e.istAn)
        }
        return s
    }
}
