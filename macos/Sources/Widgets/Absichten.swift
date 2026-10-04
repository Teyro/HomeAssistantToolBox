import AppIntents
import Foundation
import HALogik

// Aktionen in den Widgets. Die Widgets haben keinen Token – sie schicken der laufenden App
// eine Mitteilung, die App schaltet und schreibt den neuen Stand für die Widgets.

private func anApp(_ befehl: String) {
    DistributedNotificationCenter.default().postNotificationName(.init(Schnappschuss.befehlsName), object: befehl,
                                                                 userInfo: nil, deliverImmediately: true)
}

/// Lampe oder Steckdose schalten
struct SchalteAbsicht: AppIntent {
    static var title: LocalizedStringResource = "Schalten"
    static var isDiscoverable = false

    @Parameter(title: "Entität") var entitaet: String
    @Parameter(title: "An") var an: Bool

    init() {}
    init(_ entitaet: String, an: Bool) {
        self.entitaet = entitaet
        self.an = an
    }

    func perform() async throws -> some IntentResult {
        anApp(Schnappschuss.befehl("schalte", entitaet, an ? "1" : "0"))
        // der App kurz Zeit geben, den neuen Stand zu schreiben – danach lädt WidgetKit neu
        try? await Task.sleep(for: .seconds(1.3))
        return .result()
    }
}

/// Zieltemperatur eines Raums ändern
struct TemperaturAbsicht: AppIntent {
    static var title: LocalizedStringResource = "Temperatur einstellen"
    static var isDiscoverable = false

    @Parameter(title: "Thermostate") var thermostate: String   // durch Komma getrennt
    @Parameter(title: "Grad") var grad: Double

    init() {}
    init(_ thermostate: [String], grad: Double) {
        self.thermostate = thermostate.joined(separator: ",")
        self.grad = grad
    }

    func perform() async throws -> some IntentResult {
        for id in thermostate.split(separator: ",") { anApp(Schnappschuss.befehl("temp", String(id), String(grad))) }
        try? await Task.sleep(for: .seconds(1.3))
        return .result()
    }
}

/// Alle Lampen aus
struct AlleAusAbsicht: AppIntent {
    static var title: LocalizedStringResource = "Alle Lampen aus"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        anApp("alleaus")
        try? await Task.sleep(for: .seconds(1.3))
        return .result()
    }
}

// MARK: - Auswahl in den Widget-Einstellungen ("Widget bearbeiten")

struct LampenWahl: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Lampe"
    static var defaultQuery = Abfrage()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    struct Abfrage: EntityQuery {
        func entities(for ids: [String]) async throws -> [LampenWahl] { try await suggestedEntities().filter { ids.contains($0.id) } }
        func suggestedEntities() async throws -> [LampenWahl] {
            (Schnappschuss.lesen()?.lampen ?? []).map { LampenWahl(id: $0.id, name: $0.raum.isEmpty ? $0.name : "\($0.name) · \($0.raum)") }
        }
    }
}

struct SteckdosenWahl: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Steckdose"
    static var defaultQuery = Abfrage()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    struct Abfrage: EntityQuery {
        func entities(for ids: [String]) async throws -> [SteckdosenWahl] { try await suggestedEntities().filter { ids.contains($0.id) } }
        func suggestedEntities() async throws -> [SteckdosenWahl] {
            (Schnappschuss.lesen()?.steckdosen ?? []).map { SteckdosenWahl(id: $0.id, name: $0.raum.isEmpty ? $0.name : "\($0.name) · \($0.raum)") }
        }
    }
}

struct HeizungsWahl: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Heizung"
    static var defaultQuery = Abfrage()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    struct Abfrage: EntityQuery {
        func entities(for ids: [String]) async throws -> [HeizungsWahl] { try await suggestedEntities().filter { ids.contains($0.id) } }
        func suggestedEntities() async throws -> [HeizungsWahl] {
            (Schnappschuss.lesen()?.heizungen ?? []).map { HeizungsWahl(id: $0.id, name: $0.name) }
        }
    }
}

struct RaumWahl: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Raum"
    static var defaultQuery = Abfrage()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    struct Abfrage: EntityQuery {
        func entities(for ids: [String]) async throws -> [RaumWahl] { try await suggestedEntities().filter { ids.contains($0.id) } }
        func suggestedEntities() async throws -> [RaumWahl] {
            (Schnappschuss.lesen()?.raeume ?? []).map { RaumWahl(id: $0.id, name: $0.name) }
        }
    }
}

struct WertWahl: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Entität"
    static var defaultQuery = Abfrage()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(id)") }
    struct Abfrage: EntityStringQuery {
        func entities(for ids: [String]) async throws -> [WertWahl] { try await suggestedEntities().filter { ids.contains($0.id) } }
        func suggestedEntities() async throws -> [WertWahl] {
            (Schnappschuss.lesen()?.werte ?? []).map { WertWahl(id: $0.id, name: $0.name) }
        }
        func entities(matching text: String) async throws -> [WertWahl] {
            try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(text) || $0.id.localizedCaseInsensitiveContains(text) }
        }
    }
}

// Einstellungen der einzelnen Widgets

protocol Auswahl { var auswahlId: String? { get } }

struct LampeEinstellung: WidgetConfigurationIntent, Auswahl {
    static var title: LocalizedStringResource = "Lampe"
    static var description = IntentDescription("Welche Lampe oder Lichtgruppe das Widget zeigt.")
    @Parameter(title: "Lampe") var lampe: LampenWahl?
    var auswahlId: String? { lampe?.id }
}

struct SteckdoseEinstellung: WidgetConfigurationIntent, Auswahl {
    static var title: LocalizedStringResource = "Steckdose"
    static var description = IntentDescription("Welche Steckdose das Widget zeigt.")
    @Parameter(title: "Steckdose") var steckdose: SteckdosenWahl?
    var auswahlId: String? { steckdose?.id }
}

struct HeizungEinstellung: WidgetConfigurationIntent, Auswahl {
    static var title: LocalizedStringResource = "Heizung"
    static var description = IntentDescription("Welche Heizung bzw. welcher Raum.")
    @Parameter(title: "Heizung") var heizung: HeizungsWahl?
    var auswahlId: String? { heizung?.id }
}

struct RaumEinstellung: WidgetConfigurationIntent, Auswahl {
    static var title: LocalizedStringResource = "Raum"
    static var description = IntentDescription("Welcher Raum: Temperatur, Lampen und Steckdosen.")
    @Parameter(title: "Raum") var raum: RaumWahl?
    var auswahlId: String? { raum?.id }
}

struct WertEinstellung: WidgetConfigurationIntent, Auswahl {
    static var title: LocalizedStringResource = "Entität"
    static var description = IntentDescription("Eine beliebige Entität mit großem Wert.")
    @Parameter(title: "Entität") var wert: WertWahl?
    var auswahlId: String? { wert?.id }
}
