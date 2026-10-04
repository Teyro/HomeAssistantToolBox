import Foundation
import Observation
import Security
import ServiceManagement
import HALogik

/// Einstellungen der App. Alles in den Benutzereinstellungen, der Token im Schlüsselbund.
@MainActor
@Observable
final class Einstellungen {
    @ObservationIgnored private let d = UserDefaults.standard
    /// Wird nach jeder Änderung aufgerufen (die App gibt die Werte an die Verbindung weiter)
    @ObservationIgnored var geaendert: () -> Void = {}

    var adresse: String { didSet { d.set(adresse, forKey: "adresse"); geaendert() } }
    var token: String { didSet { Schluesselbund.speichern(token); geaendert() } }
    var abfrageSekunden: Int { didSet { d.set(abfrageSekunden, forKey: "abfrageSekunden"); geaendert() } }
    var zeigeGruppen: Bool { didSet { d.set(zeigeGruppen, forKey: "zeigeGruppen") } }
    var zeigeRaeume: Bool { didSet { d.set(zeigeRaeume, forKey: "zeigeRaeume") } }
    var alteGruppen: Bool { didSet { d.set(alteGruppen, forKey: "alteGruppen"); geaendert() } }
    var nurSteckdosen: Bool { didSet { d.set(nurSteckdosen, forKey: "nurSteckdosen"); geaendert() } }
    var zeigeAnzahl: Bool { didSet { d.set(zeigeAnzahl, forKey: "zeigeAnzahl") } }
    var hauptzaehler: String { didSet { d.set(hauptzaehler, forKey: "hauptzaehler"); geaendert() } }
    var ausgeblendet: String { didSet { d.set(ausgeblendet, forKey: "ausgeblendet"); geaendert() } }
    var zeigeStromHeute: Bool { didSet { d.set(zeigeStromHeute, forKey: "zeigeStromHeute") } }
    var zeigeWasserHeute: Bool { didSet { d.set(zeigeWasserHeute, forKey: "zeigeWasserHeute") } }
    var zeigeGasHeute: Bool { didSet { d.set(zeigeGasHeute, forKey: "zeigeGasHeute") } }
    var zaehlerStrom: String { didSet { d.set(zaehlerStrom, forKey: "zaehlerStrom") } }
    var zaehlerWasser: String { didSet { d.set(zaehlerWasser, forKey: "zaehlerWasser") } }
    var zaehlerGas: String { didSet { d.set(zaehlerGas, forKey: "zaehlerGas") } }

    init(vorschau: Bool = false) {
        d.register(defaults: [
            "adresse": "http://homeassistant.local:8123", "abfrageSekunden": 10,
            "zeigeGruppen": true, "zeigeRaeume": true, "alteGruppen": true, "nurSteckdosen": false,
            "zeigeAnzahl": true, "zeigeStromHeute": true, "zeigeWasserHeute": true, "zeigeGasHeute": true,
        ])
        adresse = d.string(forKey: "adresse") ?? ""
        token = vorschau ? "" : (Schluesselbund.lesen() ?? "")
        abfrageSekunden = d.integer(forKey: "abfrageSekunden")
        zeigeGruppen = d.bool(forKey: "zeigeGruppen")
        zeigeRaeume = d.bool(forKey: "zeigeRaeume")
        alteGruppen = d.bool(forKey: "alteGruppen")
        nurSteckdosen = d.bool(forKey: "nurSteckdosen")
        zeigeAnzahl = d.bool(forKey: "zeigeAnzahl")
        hauptzaehler = d.string(forKey: "hauptzaehler") ?? ""
        ausgeblendet = d.string(forKey: "ausgeblendet") ?? ""
        zeigeStromHeute = d.bool(forKey: "zeigeStromHeute")
        zeigeWasserHeute = d.bool(forKey: "zeigeWasserHeute")
        zeigeGasHeute = d.bool(forKey: "zeigeGasHeute")
        zaehlerStrom = d.string(forKey: "zaehlerStrom") ?? ""
        zaehlerWasser = d.string(forKey: "zaehlerWasser") ?? ""
        zaehlerGas = d.string(forKey: "zaehlerGas") ?? ""
    }

    var optionen: Optionen {
        Optionen(alteGruppen: alteGruppen, nurSteckdosen: nurSteckdosen, hauptzaehler: hauptzaehler, ausgeblendet: ausgeblendet)
    }

    var verbrauchGewuenscht: Set<VerbrauchsArt> {
        var s = Set<VerbrauchsArt>()
        if zeigeStromHeute { s.insert(.strom) }
        if zeigeWasserHeute { s.insert(.wasser) }
        if zeigeGasHeute { s.insert(.gas) }
        return s
    }

    var eigeneZaehler: [VerbrauchsArt: String] { [.strom: zaehlerStrom, .wasser: zaehlerWasser, .gas: zaehlerGas] }

    /// Beim Anmelden automatisch starten
    var anmeldeStart: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Anmeldeobjekt: \(error)")
            }
        }
    }
}

/// Token im Schlüsselbund von macOS (nicht als Klartext in den Einstellungen).
enum Schluesselbund {
    static let dienst = "de.teyro.haleiste"
    static let konto = "token"

    static var basis: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: dienst, kSecAttrAccount as String: konto]
    }

    static func lesen() -> String? {
        var q = basis
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &ergebnis) == errSecSuccess, let d = ergebnis as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func speichern(_ token: String) {
        if token.isEmpty {
            SecItemDelete(basis as CFDictionary)
            return
        }
        let daten = Data(token.utf8)
        let status = SecItemUpdate(basis as CFDictionary, [kSecValueData as String: daten] as CFDictionary)
        if status == errSecItemNotFound {
            var neu = basis
            neu[kSecValueData as String] = daten
            neu[kSecAttrLabel as String] = "HA Leiste – Home Assistant Token"
            SecItemAdd(neu as CFDictionary, nil)
        }
    }
}
