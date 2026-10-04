import Foundation
import AppKit
import Observation
import HALogik

/// Verbindung zu Home Assistant: lädt alle Zustände (REST), hält sie live aktuell (WebSocket,
/// sonst regelmäßiges Abfragen) und schaltet Geräte.
@MainActor
@Observable
final class HaVerbindung {
    // --- Einstellungen ---
    private(set) var basis = ""
    private(set) var token = ""
    private(set) var optionen = Optionen()
    var abfrageSekunden = 10 { didSet { if abfrageSekunden != oldValue { abfrageStarten() } } }
    /// Panel offen -> häufiger abfragen
    var sichtbar = false {
        didSet {
            guard sichtbar != oldValue else { return }
            // Beim Öffnen gleich frisch laden – mit Live-Verbindung ist ohnehin alles aktuell
            abfrageStarten(sofort: sichtbar && !live)
        }
    }
    /// Einstellungen: nur Verbindungstest, keine Live-Verbindung
    let liveErlaubt: Bool

    // --- Zustand ---
    private(set) var zustaende: [String: Entitaet] = [:]
    private(set) var bereiche: Bereiche?
    private(set) var register: [String: RegisterEintrag] = [:]
    // Anzeigemodell – jede Liste einzeln und nur neu gesetzt, wenn sie sich wirklich ändert
    private(set) var gruppen: [LichtGruppe] = []
    private(set) var raeume: [Raum] = []
    private(set) var ohneRaum: [String] = []
    private(set) var lichter: [String] = []
    private(set) var schalter: [Schalter] = []
    private(set) var schalterGruppen: [SchalterGruppe] = []
    private(set) var einzelneSchalter: [String] = []
    private(set) var leistung: [Messung] = []
    private(set) var energie: [Zaehlerstand] = []
    private(set) var lichterAn = 0
    private(set) var schalterAn = 0
    private(set) var hauptWatt: Double?
    private(set) var summeWatt: Double = 0

    private(set) var verbunden = false
    private(set) var laedt = false
    /// Token abgelehnt: nicht weiter abfragen – Home Assistant sperrt sonst nach einigen
    /// Fehlversuchen die IP-Adresse (ip_ban).
    private(set) var abgelehnt = false
    private(set) var fehler = ""
    /// Kurzer Hinweis, wenn ein Schaltbefehl fehlschlägt
    private(set) var meldung = ""
    private(set) var live = false
    private(set) var stand = Date(timeIntervalSince1970: 0)

    /// Verbrauch heute/gestern je Art
    private(set) var verbrauchHeute: [VerbrauchsArt: Tageswert] = [:]
    private var energiePrefs: JSON?
    /// Verlauf des Hauptzählers (24 h)
    private(set) var verlauf: [Punkt] = []

    var eingerichtet: Bool { !basis.isEmpty && !token.isEmpty }

    @ObservationIgnored private let liveVerbindung = LiveVerbindung()
    @ObservationIgnored private var puffer: [String: Entitaet?] = [:]
    @ObservationIgnored private var sammelTask: Task<Void, Never>?
    @ObservationIgnored private var abfrageTask: Task<Void, Never>?
    @ObservationIgnored private var meldungTask: Task<Void, Never>?
    @ObservationIgnored private var nachladenTask: Task<Void, Never>?
    @ObservationIgnored private var bereicheStand = Date.distantPast
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let sitzung: URLSession = {
        let k = URLSessionConfiguration.default
        k.timeoutIntervalForRequest = 15
        k.waitsForConnectivity = false
        return URLSession(configuration: k)
    }()

    init(liveErlaubt: Bool = true) {
        self.liveErlaubt = liveErlaubt
        liveVerbindung.zustandGeaendert = { [weak self] id, neu in self?.setzeZustand(id, neu) }
        liveVerbindung.registerGeladen = { [weak self] r in
            self?.register = r
            self?.neuBerechnen()
        }
        liveVerbindung.verbundenGeaendert = { [weak self] an in
            guard let self else { return }
            self.live = an
            // Nach (Wieder-)Verbindung einmal alles laden, dann seltener bzw. wieder regelmäßig
            self.abfrageStarten()
        }
        liveVerbindung.tokenAbgelehnt = { [weak self] in self?.live = false }
        if liveErlaubt {
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.liveVerbindung.neuVerbinden()
                    await self?.aktualisieren()
                }
            }
        }
    }

    // MARK: Einstellungen

    /// Neue Adresse/Token: alles zurücksetzen und neu verbinden.
    func verbinde(adresse: String, token neuerToken: String) {
        let b = adresse.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let t = neuerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        // Gleiche Werte: nichts tun – auch nicht nach abgelehntem Token (sonst würde jede
        // Einstellungsänderung einen neuen Fehlversuch auslösen → ip_ban)
        guard b != basis || t != token else { return }
        basis = b
        token = t
        neustart()
    }

    func setzeOptionen(_ o: Optionen) {
        guard o != optionen else { return }
        let hauptNeu = o.hauptzaehler != optionen.hauptzaehler
        optionen = o
        neuBerechnen()
        if hauptNeu {
            verlauf = []
            Task { await aktualisieren() }
        }
    }

    private func neustart() {
        generation += 1
        abgelehnt = false
        zustaende = [:]
        bereiche = nil
        register = [:]
        energiePrefs = nil
        verbrauchHeute = [:]
        verlauf = []
        fehler = ""
        verbunden = false
        laedt = false
        neuBerechnen()
        liveVerbindung.stop()
        live = false
        if eingerichtet && liveErlaubt { liveVerbindung.start(basis: basis, token: token) }
        abfrageStarten()
    }

    /// Manuell neu versuchen (auch nach abgelehntem Token).
    func erneutVersuchen() {
        abgelehnt = false
        if liveErlaubt && !live && eingerichtet { liveVerbindung.start(basis: basis, token: token) }
        abfrageStarten()
    }

    // MARK: HTTP

    enum Antwort { case ok(JSON?), fehler(String), abgebrochen }

    func anfrage(_ methode: String, _ pfad: String, _ daten: JSON? = nil) async -> Antwort {
        guard eingerichtet, let url = URL(string: basis + pfad) else { return .fehler("Nicht eingerichtet") }
        var r = URLRequest(url: url)
        r.httpMethod = methode
        r.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let daten { r.httpBody = daten.daten }
        do {
            let (d, antwort) = try await sitzung.data(for: r)
            let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) {
                return .ok(d.isEmpty ? nil : (JSON.lesen(d) ?? .text(String(decoding: d, as: UTF8.self))))
            }
            if status == 401 || status == 403 {
                abgelehnt = true
                liveVerbindung.stop()
                return .fehler("Zugriff verweigert – bitte den Token prüfen.")
            }
            return .fehler("Fehler \(status) von Home Assistant.")
        } catch {
            // Abgebrochen (neue Einstellungen, Neustart der Abfrage) ist kein Verbindungsfehler
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { return .abgebrochen }
            return .fehler("Home Assistant ist nicht erreichbar (\(basis)).")
        }
    }

    func aktualisieren() async {
        guard !abgelehnt else { return }
        guard eingerichtet else {
            fehler = ""
            verbunden = false
            return
        }
        // Läuft schon eine Abfrage, nicht noch eine hinterherschicken
        guard !laedt else { return }
        let gen = generation
        laedt = true
        let antwort = await anfrage("GET", "/api/states")
        guard gen == generation else { return }
        laedt = false
        switch antwort {
        case .abgebrochen:
            return
        case .fehler(let text):
            fehler = text
            verbunden = false
        case .ok(let liste):
            // Nur behalten, was die App braucht (Lampen, Schalter, Gruppen, Leistung/Energie)
            var neu: [String: Entitaet] = [:]
            for j in liste?.liste ?? [] {
                if let e = Entitaet(json: j), Logik.relevant(e.id, e, optionen.hauptzaehler) { neu[e.id] = e }
            }
            puffer = [:]
            zustaende = neu
            fehler = ""
            verbunden = true
            stand = Date()
            neuBerechnen()
            // Räume ändern sich selten: alle 10 Minuten neu laden
            if bereiche == nil || Date().timeIntervalSince(bereicheStand) > 600 { await bereicheLaden() }
        }
    }

    /// Räume und Leistungssensoren der Steckdosen über die Template-API.
    private func bereicheLaden() async {
        bereicheStand = Date()
        let gen = generation
        let antwort = await anfrage("POST", "/api/template", ["template": .text(Logik.bereicheTemplate)])
        guard gen == generation else { return }
        switch antwort {
        case .abgebrochen:
            bereicheStand = .distantPast
        case .fehler:
            bereiche = Bereiche() // ältere Versionen ohne Bereiche-Funktionen
        case .ok(let j):
            if case .text(let s)? = j { bereiche = Bereiche(json: JSON.lesen(s)) } else { bereiche = Bereiche(json: j) }
        }
        neuBerechnen()
    }

    private func neuBerechnen() {
        let m = Logik.baueModell(zustaende, bereiche, optionen, register: register)
        if gruppen != m.gruppen { gruppen = m.gruppen }
        if raeume != m.raeume { raeume = m.raeume }
        if ohneRaum != m.ohneRaum { ohneRaum = m.ohneRaum }
        if lichter != m.lichter { lichter = m.lichter }
        if schalter != m.schalter { schalter = m.schalter }
        if schalterGruppen != m.schalterGruppen { schalterGruppen = m.schalterGruppen }
        if einzelneSchalter != m.einzelneSchalter { einzelneSchalter = m.einzelneSchalter }
        if leistung != m.leistung { leistung = m.leistung }
        if energie != m.energie { energie = m.energie }
        if lichterAn != m.lichterAn { lichterAn = m.lichterAn }
        if schalterAn != m.schalterAn { schalterAn = m.schalterAn }
        if hauptWatt != m.hauptWatt { hauptWatt = m.hauptWatt }
        if summeWatt != m.summeWatt { summeWatt = m.summeWatt }
    }

    // MARK: Änderungen sammeln

    /// Einen Zustand ersetzen (WebSocket oder sofortige Rückmeldung). Home Assistant meldet oft
    /// viele Werte pro Sekunde – sie werden 120 ms gesammelt und gemeinsam übernommen.
    func setzeZustand(_ id: String, _ neu: Entitaet?, sofort: Bool = false) {
        guard Logik.relevant(id, neu ?? zustaende[id], optionen.hauptzaehler) else { return }
        puffer[id] = .some(neu)
        if sofort {
            uebernehmen()
        } else if sammelTask == nil {
            sammelTask = Task {
                try? await Task.sleep(for: .milliseconds(120))
                self.uebernehmen()
            }
        }
    }

    private func uebernehmen() {
        sammelTask?.cancel()
        sammelTask = nil
        guard !puffer.isEmpty else { return }
        var z = zustaende
        var struktur = false
        for (id, neu) in puffer {
            let alt = z[id]
            if let neu { z[id] = neu } else { z.removeValue(forKey: id) }
            // Neu aufbauen nur, wenn sich die Struktur ändern kann: neue/entfernte Entität,
            // geänderte Gruppenmitglieder oder Namen, Messwerte (Energie-Reiter)
            if alt == nil || neu == nil || id.hasPrefix("sensor.") || alt?.mitglieder != neu?.mitglieder || alt?.name != neu?.name {
                struktur = true
            }
        }
        puffer = [:]
        zustaende = z
        if struktur {
            neuBerechnen()
        } else {
            let la = lichter.filter { Logik.istAn(z[$0]) }.count
            if la != lichterAn { lichterAn = la }
            let sa = schalter.filter { Logik.istAn(z[$0.id]) }.count
            if sa != schalterAn { schalterAn = sa }
        }
    }

    // MARK: Zeitgeber

    private func abfrageStarten(sofort: Bool = true) {
        abfrageTask?.cancel()
        // Der Verbindungstest in den Einstellungen fragt nur einmal ab
        guard eingerichtet, !abgelehnt, liveErlaubt else { return }
        abfrageTask = Task {
            var erstes = sofort
            while !Task.isCancelled {
                if erstes || !self.verbunden || self.zustaende.isEmpty {
                    // eigene Aufgabe: ein Neustart der Schleife bricht die laufende Abfrage nicht ab
                    await Task { await self.aktualisieren() }.value
                }
                erstes = true
                if self.abgelehnt { return }
                // Mit Live-Verbindung nur selten zur Sicherheit, sonst regelmäßig
                let s = self.live ? 300 : (self.sichtbar ? max(3, self.abfrageSekunden) : max(30, self.abfrageSekunden * 6))
                try? await Task.sleep(for: .seconds(s))
            }
        }
    }

    private func zeigeMeldung(_ text: String) {
        meldung = text
        meldungTask?.cancel()
        meldungTask = Task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { self.meldung = "" }
        }
    }

    // MARK: Schalten

    private func dienst(_ domain: String, _ name: String, _ daten: JSON) {
        Task {
            switch await anfrage("POST", "/api/services/\(domain)/\(name)", daten) {
            case .abgebrochen:
                break
            case .fehler(let text):
                zeigeMeldung("Schalten fehlgeschlagen: " + text)
                // Vorab angezeigten Zustand wieder richtigstellen
                nachladen()
            case .ok(let antwort):
                // Antwort enthält die geänderten Zustände
                for j in antwort?.liste ?? [] {
                    if let e = Entitaet(json: j) { setzeZustand(e.id, e) }
                }
                if !live { nachladen() }
            }
        }
    }

    private func nachladen() {
        nachladenTask?.cancel()
        nachladenTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            if !Task.isCancelled { await self.aktualisieren() }
        }
    }

    /// Sofort sichtbar umschalten, bevor Home Assistant antwortet.
    private func vorab(_ id: String, _ an: Bool, _ prozent: Int? = nil) {
        guard var e = zustaende[id] else { return }
        e.state = an ? "on" : "off"
        if let prozent { e.attribute["brightness"] = .zahl((Double(prozent) * 2.55).rounded()) }
        setzeZustand(id, e, sofort: true)
    }

    func schalte(_ id: String, _ an: Bool) {
        let d = Logik.domain(id)
        let mitglieder = zustaende[id]?.mitglieder ?? []
        vorab(id, an)
        // Gruppen: Mitglieder gleich mit umschalten (die echte Rückmeldung kommt danach)
        mitglieder.forEach { vorab($0, an) }
        dienst(d == "group" ? "homeassistant" : d, an ? "turn_on" : "turn_off", ["entity_id": .text(id)])
    }

    func dimme(_ id: String, _ prozent: Double) {
        let p = Int(prozent.rounded())
        if p <= 0 { schalte(id, false); return }
        vorab(id, true, p)
        if Logik.domain(id) == "group" {
            // alte Gruppen können nicht dimmen – die Lampen einzeln
            dienst("light", "turn_on", ["entity_id": .texte(zustaende[id]?.mitglieder ?? []), "brightness_pct": .zahl(Double(p))])
        } else {
            dienst("light", "turn_on", ["entity_id": .text(id), "brightness_pct": .zahl(Double(p))])
        }
    }

    /// Mehrere Schalter/Steckdosen gemeinsam (Steckdosenleiste ohne eigene Gruppen-Entität).
    func schalteSchalter(_ ids: [String], _ an: Bool) {
        guard !ids.isEmpty else { return }
        ids.forEach { vorab($0, an) }
        dienst("switch", an ? "turn_on" : "turn_off", ["entity_id": .texte(ids)])
    }

    /// Mehrere Lampen gemeinsam (Räume): ein Aufruf für alle.
    func schalteMehrere(_ ids: [String], _ an: Bool) {
        guard !ids.isEmpty else { return }
        ids.forEach { vorab($0, an) }
        dienst("light", an ? "turn_on" : "turn_off", ["entity_id": .texte(ids)])
    }

    func dimmeMehrere(_ ids: [String], _ prozent: Double) {
        let p = Int(prozent.rounded())
        guard !ids.isEmpty else { return }
        if p <= 0 { schalteMehrere(ids, false); return }
        ids.forEach { vorab($0, true, p) }
        dienst("light", "turn_on", ["entity_id": .texte(ids), "brightness_pct": .zahl(Double(p))])
    }

    func alleLichterAus() {
        let an = lichter.filter { Logik.istAn(zustaende[$0]) }
        an.forEach { vorab($0, false) }
        if !an.isEmpty { dienst("light", "turn_off", ["entity_id": .texte(an)]) }
    }

    // MARK: Energie

    func verlaufLaden(stunden: Double = 24) async {
        let id = optionen.hauptzaehler
        guard !id.isEmpty else { verlauf = []; return }
        let start = Logik.isoText(Date().addingTimeInterval(-stunden * 3600))
        let pfad = "/api/history/period/" + kodiert(start) + "?filter_entity_id=" + kodiert(id) + "&minimal_response&no_attributes"
        guard case .ok(let antwort) = await anfrage("GET", pfad), id == optionen.hauptzaehler else { return }
        verlauf = Logik.verlaufPunkte(antwort, kw: zustaende[id]?.einheit == "kW")
    }

    private func kodiert(_ s: String) -> String {
        var erlaubt = CharacterSet.urlQueryAllowed
        erlaubt.remove(charactersIn: "+&=:,/")
        return s.addingPercentEncoding(withAllowedCharacters: erlaubt) ?? s
    }

    private func einheitVon(_ id: String) -> String { zustaende[id]?.einheit ?? "" }

    /// Verbrauch heute und gestern für Strom, Wasser und Gas. Zähler: eigene Auswahl aus den
    /// Einstellungen, sonst die Zähler aus dem Energie-Dashboard von Home Assistant.
    /// Mit Live-Verbindung über die Langzeitstatistik (genau wie das Energie-Dashboard),
    /// ohne über den Verlauf der Zählerstände.
    func verbrauchHeuteLaden(eigene: [VerbrauchsArt: String], gewuenscht: Set<VerbrauchsArt>) async {
        let gen = generation
        if live && energiePrefs == nil {
            energiePrefs = await liveVerbindung.anfrage(["type": "energy/get_prefs"]) ?? .objekt([:])
        }
        let ausDashboard = energiePrefs.map { Logik.zaehlerAusEnergieDashboard($0) }
        var plan: [VerbrauchsArt: [String]] = [:]
        for art in VerbrauchsArt.allCases where gewuenscht.contains(art) {
            let eigen = eigene[art] ?? ""
            let ids = !eigen.isEmpty ? [eigen] : (ausDashboard?[art] ?? [])
            if !ids.isEmpty { plan[art] = ids }
        }
        guard !plan.isEmpty else { verbrauchHeute = [:]; return }
        let ergebnis = live ? await statistikLaden(plan) : await historieTageLaden(plan)
        if gen == generation, let ergebnis { verbrauchHeute = ergebnis }
    }

    private func statistikLaden(_ plan: [VerbrauchsArt: [String]]) async -> [VerbrauchsArt: Tageswert]? {
        let alle = plan.values.flatMap { $0 }
        let meta = await liveVerbindung.anfrage(["type": "recorder/get_statistics_metadata", "statistic_ids": .texte(alle)])
        var einheit: [String: String] = [:]
        for m in meta?.liste ?? [] {
            if let id = m["statistic_id"]?.text {
                einheit[id] = m["statistics_unit_of_measurement"]?.text ?? m["display_unit_of_measurement"]?.text ?? ""
            }
        }
        var ergebnis: [VerbrauchsArt: Tageswert] = [:]
        for (art, ids) in plan {
            var w = Tageswert(heute: 0, gestern: 0, einheit: einheit[ids[0]] ?? einheitVon(ids[0]), zaehler: ids, gueltig: false)
            for id in ids {
                for versatz in [0, -1] {
                    let r = await liveVerbindung.anfrage(["type": "recorder/statistic_during_period", "statistic_id": .text(id),
                                                          "calendar": ["period": "day", "offset": .zahl(Double(versatz))],
                                                          "types": ["change"]])
                    if let c = r?["change"]?.zahl {
                        if versatz == 0 { w.heute += c } else { w.gestern = (w.gestern ?? 0) + c }
                        w.gueltig = true
                    }
                }
            }
            ergebnis[art] = w
        }
        return ergebnis
    }

    private func historieTageLaden(_ plan: [VerbrauchsArt: [String]]) async -> [VerbrauchsArt: Tageswert]? {
        // Ohne WebSocket gehen nur Entitäten (keine externen Statistiken)
        let ids = plan.values.flatMap { $0 }.filter { $0.contains(".") && !$0.contains(":") }
        guard !ids.isEmpty else { return [:] }
        let mitternacht = Calendar.current.startOfDay(for: Date())
        let start = Logik.isoText(mitternacht.addingTimeInterval(-86400))
        let pfad = "/api/history/period/" + kodiert(start) + "?filter_entity_id=" + kodiert(ids.joined(separator: ","))
            + "&minimal_response&no_attributes"
        guard case .ok(let antwort) = await anfrage("GET", pfad) else { return nil }
        var jeEntitaet: [String: [JSON]] = [:]
        for liste in antwort?.liste ?? [] {
            if let l = liste.liste, let id = l.first?["entity_id"]?.text { jeEntitaet[id] = l }
        }
        var ergebnis: [VerbrauchsArt: Tageswert] = [:]
        for (art, zaehler) in plan {
            var w = Tageswert(heute: 0, gestern: 0, einheit: einheitVon(zaehler[0]), zaehler: zaehler, gueltig: false)
            for id in zaehler {
                guard let v = Logik.tagesVerbrauch(jeEntitaet[id], heuteStart: mitternacht) else { continue }
                w.heute += v.heute
                if let g = v.gestern { w.gestern = (w.gestern ?? 0) + g }
                w.gueltig = true
            }
            ergebnis[art] = w
        }
        return ergebnis
    }

    /// Sensoren einer Geräteklasse für die Zählerauswahl in den Einstellungen
    func sensoren(klasse: String) -> [Entitaet] {
        zustaende.values.filter { $0.id.hasPrefix("sensor.") && $0.klasse == klasse }.sorted { Logik.vorher($0.name, $1.name) }
    }
}
