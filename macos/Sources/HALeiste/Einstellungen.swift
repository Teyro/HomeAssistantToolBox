import Foundation
import Observation
import Security
import ServiceManagement
import HALogik

/// Einstellungen der App. Alles in den Benutzereinstellungen, die Token im Schlüsselbund.
@MainActor
@Observable
final class Einstellungen {
    @ObservationIgnored private let d = UserDefaults.standard
    /// Wird nach jeder Änderung aufgerufen (die App gibt die Werte an die Verbindung weiter)
    @ObservationIgnored var geaendert: () -> Void = {}
    @ObservationIgnored let vorschau: Bool
    /// Token im Testlauf (nicht im Schlüsselbund)
    @ObservationIgnored var vorschauToken: [String: String] = [:]

    /// Home-Assistant-Instanzen (ohne Token)
    var instanzen: [Instanz] { didSet { speichereInstanzen(); geaendert() } }
    var abfrageSekunden: Int { didSet { d.set(abfrageSekunden, forKey: "abfrageSekunden"); geaendert() } }
    var zeigeGruppen: Bool { didSet { d.set(zeigeGruppen, forKey: "zeigeGruppen") } }
    var zeigeRaeume: Bool { didSet { d.set(zeigeRaeume, forKey: "zeigeRaeume") } }
    var alteGruppen: Bool { didSet { d.set(alteGruppen, forKey: "alteGruppen"); geaendert() } }
    var nurSteckdosen: Bool { didSet { d.set(nurSteckdosen, forKey: "nurSteckdosen"); geaendert() } }
    var zeigeAnzahl: Bool { didSet { d.set(zeigeAnzahl, forKey: "zeigeAnzahl") } }
    var ausgeblendet: String { didSet { d.set(ausgeblendet, forKey: "ausgeblendet"); geaendert() } }
    var zeigeStromHeute: Bool { didSet { d.set(zeigeStromHeute, forKey: "zeigeStromHeute") } }
    var zeigeWasserHeute: Bool { didSet { d.set(zeigeWasserHeute, forKey: "zeigeWasserHeute") } }
    var zeigeGasHeute: Bool { didSet { d.set(zeigeGasHeute, forKey: "zeigeGasHeute") } }
    var zeigeHeizung: Bool { didSet { d.set(zeigeHeizung, forKey: "zeigeHeizung") } }
    var zeigePersonen: Bool { didSet { d.set(zeigePersonen, forKey: "zeigePersonen") } }
    /// Laufendes "Extra heizen"
    var boosts: [Boost] { didSet { if let j = try? JSONEncoder().encode(boosts) { d.set(j, forKey: "boosts") } } }

    init(vorschau: Bool = false) {
        self.vorschau = vorschau
        d.register(defaults: [
            "abfrageSekunden": 10, "zeigeGruppen": true, "zeigeRaeume": true, "alteGruppen": true, "nurSteckdosen": false,
            "zeigeAnzahl": true, "zeigeStromHeute": true, "zeigeWasserHeute": true, "zeigeGasHeute": true,
            "zeigeHeizung": true, "zeigePersonen": true,
        ])
        abfrageSekunden = d.integer(forKey: "abfrageSekunden")
        zeigeGruppen = d.bool(forKey: "zeigeGruppen")
        zeigeRaeume = d.bool(forKey: "zeigeRaeume")
        alteGruppen = d.bool(forKey: "alteGruppen")
        nurSteckdosen = d.bool(forKey: "nurSteckdosen")
        zeigeAnzahl = d.bool(forKey: "zeigeAnzahl")
        ausgeblendet = d.string(forKey: "ausgeblendet") ?? ""
        zeigeStromHeute = d.bool(forKey: "zeigeStromHeute")
        zeigeWasserHeute = d.bool(forKey: "zeigeWasserHeute")
        zeigeGasHeute = d.bool(forKey: "zeigeGasHeute")
        zeigeHeizung = d.bool(forKey: "zeigeHeizung")
        zeigePersonen = d.bool(forKey: "zeigePersonen")
        boosts = (d.data(forKey: "boosts")).flatMap { try? JSONDecoder().decode([Boost].self, from: $0) } ?? []
        if vorschau {
            instanzen = []
        } else if let j = d.data(forKey: "instanzen"), let liste = try? JSONDecoder().decode([Instanz].self, from: j) {
            instanzen = liste
        } else if let alteAdresse = d.string(forKey: "adresse"), !alteAdresse.isEmpty, let alterToken = Schluesselbund.lesen(konto: "token") {
            // Version 2.0: eine Verbindung → erste Instanz (Favorit)
            instanzen = [Instanz(id: "i1", adresse: alteAdresse, favorit: true, hauptzaehler: d.string(forKey: "hauptzaehler") ?? "",
                                 zaehlerStrom: d.string(forKey: "zaehlerStrom") ?? "", zaehlerWasser: d.string(forKey: "zaehlerWasser") ?? "",
                                 zaehlerGas: d.string(forKey: "zaehlerGas") ?? "")]
            Schluesselbund.speichern(alterToken, konto: "token-i1")
            speichereInstanzen()
        } else {
            instanzen = []
        }
    }

    private func speichereInstanzen() {
        guard !vorschau, let j = try? JSONEncoder().encode(instanzen) else { return }
        d.set(j, forKey: "instanzen")
    }

    // MARK: Token je Instanz

    func token(_ id: String) -> String {
        vorschau ? (vorschauToken[id] ?? "") : (Schluesselbund.lesen(konto: "token-" + id) ?? "")
    }

    func setzeToken(_ token: String, fuer id: String) {
        if vorschau { vorschauToken[id] = token } else { Schluesselbund.speichern(token, konto: "token-" + id) }
        geaendert()
    }

    func entfernen(_ id: String) {
        if !vorschau { Schluesselbund.speichern("", konto: "token-" + id) }
        var neu = instanzen.filter { $0.id != id }
        if !neu.isEmpty && !neu.contains(where: { $0.favorit }) { neu[0].favorit = true }
        instanzen = neu
        boosts.removeAll { $0.instanz == id }
    }

    func alsFavorit(_ id: String) {
        instanzen = instanzen.map { var i = $0; i.favorit = i.id == id; return i }
    }

    func aendern(_ id: String, _ aenderung: (inout Instanz) -> Void) {
        guard let n = instanzen.firstIndex(where: { $0.id == id }) else { return }
        var i = instanzen[n]
        aenderung(&i)
        if i != instanzen[n] { instanzen[n] = i }
    }

    var optionenBasis: Optionen {
        Optionen(alteGruppen: alteGruppen, nurSteckdosen: nurSteckdosen, hauptzaehler: "", ausgeblendet: ausgeblendet)
    }

    var verbrauchGewuenscht: Set<VerbrauchsArt> {
        var s = Set<VerbrauchsArt>()
        if zeigeStromHeute { s.insert(.strom) }
        if zeigeWasserHeute { s.insert(.wasser) }
        if zeigeGasHeute { s.insert(.gas) }
        return s
    }

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

    static func basis(_ konto: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: dienst, kSecAttrAccount as String: konto]
    }

    static func lesen(konto: String) -> String? {
        var q = basis(konto)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &ergebnis) == errSecSuccess, let d = ergebnis as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func speichern(_ token: String, konto: String) {
        if token.isEmpty {
            SecItemDelete(basis(konto) as CFDictionary)
            return
        }
        let daten = Data(token.utf8)
        let status = SecItemUpdate(basis(konto) as CFDictionary, [kSecValueData as String: daten] as CFDictionary)
        if status == errSecItemNotFound {
            var neu = basis(konto)
            neu[kSecValueData as String] = daten
            neu[kSecAttrLabel as String] = "HA Leiste – Home Assistant Token"
            SecItemAdd(neu as CFDictionary, nil)
        }
    }
}
