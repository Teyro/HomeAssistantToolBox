import Foundation

/// Reine Hilfsfunktionen ohne Oberfläche – Gegenstück zu logik.js im Plasma-Widget.
public enum Logik {

    /// Template für Home Assistant: Räume (Bereiche) mit Lampen/Schaltern, Leistungssensoren
    /// und Gerät je Schalter.
    public static let bereicheTemplate = #"{%- set ns = namespace(a=[], p=[], g=[]) -%}"#
        + #"{%- for ar in areas() -%}"#
        + #"{%- set ns.a = ns.a + [{'id': ar, 'name': area_name(ar), 'e': area_entities(ar) | select('match', '(light|switch)\\.') | list}] -%}"#
        + #"{%- endfor -%}"#
        + #"{%- for s in states.switch -%}"#
        + #"{%- set d = device_id(s.entity_id) -%}"#
        + #"{%- if d -%}{%- set ns.g = ns.g + [[s.entity_id, d, device_attr(d, 'name_by_user') or device_attr(d, 'name') or '']] -%}"#
        + #"{%- for e in device_entities(d) -%}"#
        + #"{%- if e.startswith('sensor.') and state_attr(e, 'device_class') == 'power' -%}{%- set ns.p = ns.p + [[s.entity_id, e]] -%}{%- endif -%}"#
        + #"{%- endfor -%}{%- endif -%}"#
        + #"{%- endfor -%}"#
        + #"{{ {'bereiche': ns.a, 'leistung': ns.p, 'geraete': ns.g} | tojson }}"#

    /// Typische Geräte-Einstellungen, die Home Assistant als Schalter führt (nur ohne Register).
    static let einstellungsSchalter = try! NSRegularExpression(
        pattern: #"(^|[\s_.-])(led|leds|indikator|indicator|kindersicherung|child[\s_]?lock|tastensperre|button[\s_]?lock|nachtmodus|night[\s_]?mode|do[\s_]?not[\s_]?disturb|auto[\s_-]?update|firmware|beta|ota|neustart|restart|reboot|identify|identifizieren|power[\s_]?on[\s_]?behavio(u)?r|einschaltverhalten|überlastschutz|overload|benachrichtigung|notification|signalton|beep|buzzer|statuslicht|status[\s_]?light|ecomodus|eco[\s_]?mode)($|[\s_.-])"#,
        options: [.caseInsensitive])

    static let messEndung = try! NSRegularExpression(
        pattern: #"[\s_-]+(aktuelle?\s+)?(leistung|power|verbrauch|consumption|watt)$"#, options: [.caseInsensitive])

    static func passt(_ re: NSRegularExpression, _ s: String) -> Bool {
        re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    public static func domain(_ id: String) -> String {
        String(id.split(separator: ".", maxSplits: 1).first ?? "")
    }

    public static func name(_ e: Entitaet?) -> String { e?.name ?? "" }

    /// Kürzerer Name für Messwerte: "Fernseher Leistung" -> "Fernseher".
    public static func messName(_ e: Entitaet) -> String {
        let n = e.name
        let r = messEndung.stringByReplacingMatches(in: n, range: NSRange(n.startIndex..., in: n), withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
        return r.isEmpty ? n : r
    }

    public static func istAn(_ e: Entitaet?) -> Bool { e?.istAn ?? false }
    public static func istVerfuegbar(_ e: Entitaet?) -> Bool { e?.istVerfuegbar ?? false }

    /// Helligkeit in Prozent (0–100); aus = 0.
    public static func helligkeit(_ e: Entitaet?) -> Int {
        guard let e, e.istAn else { return 0 }
        guard let b = e.attribute["brightness"]?.zahl else { return 100 }
        return max(1, Int((b / 255 * 100).rounded()))
    }

    /// Kann die Lampe gedimmt werden?
    public static func dimmbar(_ e: Entitaet?) -> Bool {
        guard let e else { return false }
        if let modi = e.attribute["supported_color_modes"]?.liste, !modi.isEmpty {
            return !(modi.count == 1 && modi[0].text == "onoff")
        }
        let f = Int(e.attribute["supported_features"]?.zahl ?? 0)
        return f & 1 == 1 || e.attribute["brightness"] != nil
    }

    /// Farbe für das Lampensymbol: echte Farbe, Weißton aus der Farbtemperatur oder warmes Gelb.
    public static func lampenFarbe(_ e: Entitaet?) -> RGB? {
        guard let e, e.istAn else { return nil }
        let a = e.attribute
        let modus = a["color_mode"]?.text
        if let rgb = a["rgb_color"]?.liste, rgb.count >= 3, modus != "color_temp", modus != "brightness", modus != "onoff" {
            let r = rgb[0].zahl ?? 0, g = rgb[1].zahl ?? 0, b = rgb[2].zahl ?? 0
            // sehr helle, fast weiße Farben etwas wärmer darstellen
            if r > 235 && g > 235 && b > 235 { return RGB(255, 244, 214) }
            return RGB(r, g, b)
        }
        let kelvin = a["color_temp_kelvin"]?.zahl ?? a["color_temp"]?.zahl.map { (1_000_000 / $0).rounded() }
        if let kelvin, kelvin > 0 {
            // 2000 K (warm) … 6500 K (kalt)
            let t = max(0, min(1, (kelvin - 2000) / 4500))
            return RGB(255, 190 + 55 * t, 110 + 145 * t)
        }
        return RGB(255, 198, 92)
    }

    public static func ausgeblendet(_ id: String, _ liste: [String]) -> Bool {
        for m in liste where !m.isEmpty {
            if m == id { return true }
            if m.contains("*") {
                let muster = "^" + NSRegularExpression.escapedPattern(for: m).replacingOccurrences(of: "\\*", with: ".*") + "$"
                if let re = try? NSRegularExpression(pattern: muster), passt(re, id) { return true }
            }
        }
        return false
    }

    static let deutsch = Locale(identifier: "de_DE")
    public static func vorher(_ a: String, _ b: String) -> Bool {
        a.compare(b, locale: deutsch) == .orderedAscending
    }

    /// Baut aus allen Zuständen und den Bereichen das Anzeigemodell.
    public static func baueModell(_ zustaende: [String: Entitaet], _ bereiche: Bereiche?, _ opt: Optionen,
                                  register: [String: RegisterEintrag] = [:]) -> Anzeige {
        let versteckt = opt.ausgeblendet.split(whereSeparator: { " \t\n,;".contains($0) }).map(String.init)
        var lichter: [(id: String, name: String)] = []
        var gruppen: [LichtGruppe] = []
        var schalter: [(id: String, name: String)] = []
        var schalterGruppen: [SchalterGruppe] = []
        var leistung: [Messung] = []
        var energie: [Zaehlerstand] = []

        for id in zustaende.keys.sorted() {
            guard let e = zustaende[id] else { continue }
            if ausgeblendet(id, versteckt) { continue }
            let d = domain(id)
            let reg = register[id]
            // In Home Assistant versteckt: nirgends zeigen. Einstellungs-/Diagnose-Entitäten
            // (z. B. "LED an der Steckdose", "Kindersicherung"): keine Lampen/Steckdosen.
            if reg?.hb == true { continue }
            if reg?.ec == true && (d == "light" || d == "switch") { continue }
            switch d {
            case "light":
                // Lichtgruppe: hat eine Liste von Mitgliedern
                if let m = e.mitglieder {
                    gruppen.append(LichtGruppe(id: id, name: e.name,
                                               mitglieder: m.filter { zustaende[$0] != nil && !ausgeblendet($0, versteckt) }, alt: false))
                } else {
                    lichter.append((id, e.name))
                }
            case "group":
                guard opt.alteGruppen, let m = e.mitglieder else { continue }
                let nurLicht = m.filter { domain($0) == "light" && zustaende[$0] != nil }
                let nurSchalter = m.filter { domain($0) == "switch" && zustaende[$0] != nil }
                if !nurLicht.isEmpty && nurLicht.count == m.count {
                    gruppen.append(LichtGruppe(id: id, name: e.name, mitglieder: nurLicht, alt: true))
                } else if !nurSchalter.isEmpty && nurSchalter.count == m.count {
                    schalterGruppen.append(SchalterGruppe(id: id, name: e.name, steuerId: id, mitglieder: nurSchalter, art: "gruppe"))
                }
            case "switch":
                if opt.nurSteckdosen && e.klasse != "outlet" { continue }
                // Ohne Entitäten-Register (keine WebSocket-Verbindung): typische Geräte-Einstellungen
                // am Namen erkennen, damit nicht jede "LED"- oder "Kindersicherung"-Option erscheint.
                if register.isEmpty && (passt(einstellungsSchalter, e.name) || passt(einstellungsSchalter, id)) { continue }
                // Schaltergruppe (Helfer "Gruppe → Schalter")
                if let m = e.mitglieder {
                    schalterGruppen.append(SchalterGruppe(id: id, name: e.name, steuerId: id, mitglieder: m, art: "gruppe"))
                    continue
                }
                schalter.append((id, e.name))
            case "sensor":
                guard e.istVerfuegbar, let wert = e.wert else { continue }
                let einheit = e.einheit
                if e.klasse == "power" && (einheit == "W" || einheit == "kW") {
                    leistung.append(Messung(id: id, name: messName(e), watt: einheit == "kW" ? wert * 1000 : wert))
                } else if e.klasse == "energy" && ["kWh", "Wh", "MWh"].contains(einheit) {
                    energie.append(Zaehlerstand(id: id, name: e.name, kwh: einheit == "Wh" ? wert / 1000 : einheit == "MWh" ? wert * 1000 : wert))
                }
            default:
                continue
            }
        }

        gruppen.sort { vorher($0.name, $1.name) }
        lichter.sort { vorher($0.name, $1.name) }
        schalter.sort { vorher($0.name, $1.name) }
        leistung.sort { $0.watt > $1.watt }
        energie.sort { vorher($0.name, $1.name) }

        let lichtIds = Set(lichter.map { $0.id })
        let schalterIds = Set(schalter.map { $0.id })

        // Räume aus Home Assistant
        var raeume: [Raum] = []
        var imRaum = Set<String>()
        for b in bereiche?.bereiche ?? [] {
            var l = b.entitaeten.filter { lichtIds.contains($0) }
            let s = b.entitaeten.filter { schalterIds.contains($0) }
            l.forEach { imRaum.insert($0) }
            s.forEach { imRaum.insert($0) }
            if !l.isEmpty || !s.isEmpty {
                l.sort { vorher(name(zustaende[$0]), name(zustaende[$1])) }
                raeume.append(Raum(id: b.id, name: b.name.isEmpty ? b.id : b.name, lichter: l, schalter: s))
            }
        }
        raeume.sort { vorher($0.name, $1.name) }
        let ohneRaum = lichter.filter { !imRaum.contains($0.id) }.map { $0.id }

        // Leistung je Steckdose
        var schalterLeistung: [String: String] = [:]
        for (s, p) in bereiche?.leistung ?? [] where schalterLeistung[s] == nil { schalterLeistung[s] = p }
        // Ersatz ohne Template: Sensor mit gleichem Namensanfang ("switch.kaffee" -> "sensor.kaffee_power")
        for s in schalter where schalterLeistung[s.id] == nil {
            let basis = s.id.split(separator: ".", maxSplits: 1).last.map(String.init) ?? ""
            if let t = leistung.first(where: { $0.id.hasPrefix("sensor." + basis) }) { schalterLeistung[s.id] = t.id }
        }
        // Räume für Steckdosen
        var schalterRaum: [String: String] = [:]
        for r in raeume { for id in r.schalter { schalterRaum[id] = r.name } }

        // Geräte mit mehreren Schaltern (z. B. Steckdosenleisten) als eigene Gruppe
        var jeGeraet: [String: (name: String, ids: [String])] = [:]
        var geraeteReihenfolge: [String] = []
        for g in bereiche?.geraete ?? [] where schalterIds.contains(g.schalter) {
            if jeGeraet[g.geraet] == nil { jeGeraet[g.geraet] = (g.name, []); geraeteReihenfolge.append(g.geraet) }
            jeGeraet[g.geraet]!.ids.append(g.schalter)
        }
        for d in geraeteReihenfolge {
            guard var g = jeGeraet[d], g.ids.count >= 2 else { continue }
            g.ids.sort { vorher(name(zustaende[$0]), name(zustaende[$1])) }
            schalterGruppen.append(SchalterGruppe(id: "geraet:" + d, name: g.name.isEmpty ? name(zustaende[g.ids[0]]) : g.name,
                                                  steuerId: "", mitglieder: g.ids, art: "geraet"))
        }
        // Mitglieder auf vorhandene, sichtbare Schalter beschränken; leere Gruppen weglassen
        schalterGruppen = schalterGruppen.map { g in
            var n = g
            n.mitglieder = g.mitglieder.filter { schalterIds.contains($0) }
            return n
        }.filter { !$0.mitglieder.isEmpty }
        var inSchalterGruppe = Set<String>()
        for i in schalterGruppen.indices {
            let m = schalterGruppen[i].mitglieder
            m.forEach { inSchalterGruppe.insert($0) }
            // Gesamtverbrauch: jeden Sensor nur einmal (eine Leiste hat oft einen Sensor für alle Dosen)
            var sensoren: [String] = []
            for id in m { if let p = schalterLeistung[id], !sensoren.contains(p) { sensoren.append(p) } }
            schalterGruppen[i].leistung = sensoren
            let raeumeG = Set(m.map { schalterRaum[$0] ?? "" })
            schalterGruppen[i].raum = raeumeG.count == 1 ? raeumeG.first! : ""
        }
        schalterGruppen.sort { vorher($0.name, $1.name) }

        var a = Anzeige()
        if !opt.hauptzaehler.isEmpty, let h = zustaende[opt.hauptzaehler], let hw = h.wert {
            a.hauptWatt = h.einheit == "kW" ? hw * 1000 : hw
        }
        a.summeWatt = leistung.filter { $0.id != opt.hauptzaehler && $0.watt > 0 }.reduce(0) { $0 + $1.watt }
        a.gruppen = gruppen
        a.raeume = raeume
        a.ohneRaum = ohneRaum
        a.lichter = lichter.map { $0.id }
        a.lichterAn = a.lichter.filter { istAn(zustaende[$0]) }.count
        a.schalter = schalter.map { Schalter(id: $0.id, name: $0.name, raum: schalterRaum[$0.id] ?? "", leistung: schalterLeistung[$0.id] ?? "") }
        a.schalterAn = schalter.filter { istAn(zustaende[$0.id]) }.count
        a.schalterGruppen = schalterGruppen
        a.einzelneSchalter = schalter.filter { !inSchalterGruppe.contains($0.id) }.map { $0.id }
        a.leistung = leistung.filter { $0.id != opt.hauptzaehler }
        a.energie = energie
        return a
    }

    /// Zustand einer Gruppe: wie viele Mitglieder an, mittlere Helligkeit der eingeschalteten.
    public static func gruppenStatus(_ mitglieder: [String], _ z: [String: Entitaet]) -> GruppenStatus {
        var an = 0, summe = 0, dimmbarAnz = 0, verfuegbar = 0
        for id in mitglieder {
            let e = z[id]
            if istVerfuegbar(e) { verfuegbar += 1 }
            if istAn(e) { an += 1; summe += helligkeit(e) }
            if dimmbar(e) { dimmbarAnz += 1 }
        }
        return GruppenStatus(an: an, gesamt: mitglieder.count, verfuegbar: verfuegbar,
                             helligkeit: an > 0 ? Int((Double(summe) / Double(an)).rounded()) : 0, dimmbar: dimmbarAnz > 0)
    }

    /// Farbe der Gruppe: Mischfarbe der eingeschalteten Mitglieder.
    public static func gruppenFarbe(_ mitglieder: [String], _ z: [String: Entitaet]) -> RGB? {
        let farben = mitglieder.compactMap { lampenFarbe(z[$0]) }
        guard !farben.isEmpty else { return nil }
        let n = Double(farben.count)
        return RGB((farben.reduce(0) { $0 + $1.r } / n).rounded(),
                   (farben.reduce(0) { $0 + $1.g } / n).rounded(),
                   (farben.reduce(0) { $0 + $1.b } / n).rounded())
    }

    /// Zustand einer Steckdosengruppe: an/gesamt und Summe der (eindeutigen) Leistungssensoren.
    public static func schalterGruppenStatus(_ g: SchalterGruppe, _ z: [String: Entitaet]) -> SchalterGruppenStatus {
        var an = 0, verfuegbar = 0
        for id in g.mitglieder {
            if istVerfuegbar(z[id]) { verfuegbar += 1 }
            if istAn(z[id]) { an += 1 }
        }
        let werte = g.leistung.compactMap { wattVon(z[$0]) }
        return SchalterGruppenStatus(an: an, gesamt: g.mitglieder.count, verfuegbar: verfuegbar,
                                     watt: werte.isEmpty ? nil : werte.reduce(0, +))
    }

    /// Leistung eines Sensors in Watt (nil, wenn unbekannt).
    public static func wattVon(_ e: Entitaet?) -> Double? {
        guard let e, e.istVerfuegbar, let w = e.wert else { return nil }
        return e.einheit == "kW" ? w * 1000 : w
    }

    /// Ist diese Entität für die App überhaupt interessant? (alles andere wird ignoriert)
    public static func relevant(_ id: String, _ e: Entitaet?, _ hauptzaehler: String) -> Bool {
        let d = domain(id)
        if d == "light" || d == "switch" || d == "group" { return true }
        if d != "sensor" { return false }
        if id == hauptzaehler { return true }
        let k = e?.klasse
        return k == "power" || k == "energy" || k == "water" || k == "gas"
    }

    // MARK: Zahlen

    static func komma(_ x: Double, _ stellen: Int) -> String {
        String(format: "%.\(stellen)f", x).replacingOccurrences(of: ".", with: ",")
    }

    public static func formatWatt(_ w: Double?) -> String {
        guard let w, !w.isNaN else { return "–" }
        if w == 0 { return "0 W" }
        if abs(w) >= 10000 { return komma(w / 1000, 1) + " kW" }
        if abs(w) >= 1000 { return komma(w / 1000, 2) + " kW" }
        if abs(w) >= 10 { return "\(Int(w.rounded())) W" }
        return komma(w, 1) + " W"
    }

    public static func formatKwh(_ k: Double?) -> String {
        guard let k, !k.isNaN else { return "–" }
        // Zählerstände wie auf dem Zähler: 12.456 kWh
        if k >= 1000 { return tausender(Int(k.rounded())) + " kWh" }
        if k >= 100 { return "\(Int(k.rounded())) kWh" }
        return komma(k, k >= 10 ? 1 : 2) + " kWh"
    }

    static func tausender(_ n: Int) -> String {
        var s = String(n), ergebnis = ""
        while s.count > 3 {
            ergebnis = "." + s.suffix(3) + ergebnis
            s = String(s.dropLast(3))
        }
        return s + ergebnis
    }

    /// Menge mit passender Einheit: Strom in kWh, Wasser in Litern bzw. m³, Gas in m³ oder kWh.
    public static func formatMenge(_ wert: Double?, _ einheit: String, _ art: VerbrauchsArt) -> String {
        guard let wert, !wert.isNaN else { return "–" }
        switch art {
        case .strom:
            return formatKwh(einheit == "Wh" ? wert / 1000 : einheit == "MWh" ? wert * 1000 : wert)
        case .wasser:
            let liter = einheit == "m³" || einheit == "m3" ? wert * 1000 : einheit == "gal" ? wert * 3.785 : einheit == "ft³" ? wert * 28.317 : wert
            if liter >= 1000 { return komma(liter / 1000, 2) + " m³" }
            return "\(Int(liter.rounded())) L"
        case .gas:
            if ["kWh", "Wh", "MWh"].contains(einheit) {
                return formatKwh(einheit == "Wh" ? wert / 1000 : einheit == "MWh" ? wert * 1000 : wert)
            }
            return komma(wert, wert >= 10 ? 1 : 2) + " " + (einheit.isEmpty ? "m³" : einheit)
        }
    }

    // MARK: Zeit und Verlauf

    nonisolated(unsafe) static let isoMitBruch: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let isoOhneBruch = ISO8601DateFormatter()
    static let bruchteil = try! NSRegularExpression(pattern: #"\.(\d+)"#)

    /// Zeitangabe von Home Assistant ("2026-10-03T12:00:00.123456+00:00") lesen.
    public static func datum(_ s: String) -> Date? {
        if let d = isoMitBruch.date(from: s) { return d }
        // Mikrosekunden kann der Formatierer nicht immer – Bruchteil getrennt lesen
        let bereich = NSRange(s.startIndex..., in: s)
        guard let m = bruchteil.firstMatch(in: s, range: bereich), let r = Range(m.range, in: s) else {
            return isoOhneBruch.date(from: s)
        }
        let ohne = s.replacingCharacters(in: r, with: "")
        guard let d = isoOhneBruch.date(from: ohne) else { return nil }
        return d.addingTimeInterval(Double("0" + s[r]) ?? 0)
    }

    public static func isoText(_ d: Date) -> String { isoOhneBruch.string(from: d) }

    static func zeitVon(_ p: JSON) -> Date? {
        if let s = p["last_changed"]?.text { return datum(s) }
        if let lu = p["lu"]?.zahl { return Date(timeIntervalSince1970: lu) }
        return nil
    }

    /// Verlauf (History-API, minimal_response) in Punkte umwandeln.
    public static func verlaufPunkte(_ antwort: JSON?, kw: Bool) -> [Punkt] {
        guard let liste = antwort?[0]?.liste else { return [] }
        return liste.compactMap { p in
            guard let s = p["state"]?.text, let w = Double(s), let t = zeitVon(p) else { return nil }
            return Punkt(t: t, w: kw ? w * 1000 : w)
        }
    }

    /// Kennzahlen aus dem Verlauf: Energie (Fläche unter der Kurve), Spitze, Durchschnitt.
    public static func verlaufKennzahlen(_ punkte: [Punkt], ende: Date) -> Kennzahlen? {
        guard punkte.count >= 2 else { return nil }
        var wh = 0.0, spitze = punkte[0], minimum = punkte[0]
        for (i, p) in punkte.enumerated() {
            let bis = i + 1 < punkte.count ? punkte[i + 1].t : ende
            wh += p.w * max(0, bis.timeIntervalSince(p.t)) / 3600
            if p.w > spitze.w { spitze = p }
            if p.w < minimum.w { minimum = p }
        }
        let dauer = ende.timeIntervalSince(punkte[0].t) / 3600
        return Kennzahlen(kwh: wh / 1000, spitze: spitze, minimum: minimum, schnitt: dauer > 0 ? wh / dauer : 0)
    }

    /// Zähler aus den Einstellungen des Energie-Dashboards von Home Assistant (energy/get_prefs).
    public static func zaehlerAusEnergieDashboard(_ prefs: JSON?) -> [VerbrauchsArt: [String]] {
        var z: [VerbrauchsArt: [String]] = [.strom: [], .wasser: [], .gas: []]
        for q in prefs?["energy_sources"]?.liste ?? [] {
            switch q["type"]?.text {
            case "grid":
                for f in q["flow_from"]?.liste ?? [] { if let s = f["stat_energy_from"]?.text { z[.strom]!.append(s) } }
            case "gas":
                if let s = q["stat_energy_from"]?.text { z[.gas]!.append(s) }
            case "water":
                if let s = q["stat_energy_from"]?.text { z[.wasser]!.append(s) }
            default: break
            }
        }
        return z
    }

    /// Verbrauch eines Zählerstands aus dem Verlauf (REST-History, ohne WebSocket):
    /// Summe der Zunahmen ab heuteStart bzw. im Tag davor. Ein Zurückspringen auf (fast) 0 gilt
    /// als Neustart des Zählers, kleines Zittern nach unten wird ignoriert.
    public static func tagesVerbrauch(_ liste: [JSON]?, heuteStart: Date) -> (heute: Double, gestern: Double?)? {
        guard let liste, !liste.isEmpty else { return nil }
        let gesternStart = heuteStart.addingTimeInterval(-86400)
        var heute = 0.0, gestern = 0.0, vorher: Double?, hatHeute = false, hatGestern = false
        for p in liste {
            guard let s = p["state"]?.text, let w = Double(s), let t = zeitVon(p) else { continue }
            if let v = vorher {
                var d = w - v
                if d < 0 { d = w < v * 0.5 ? w : 0 }
                if t >= heuteStart { heute += d; hatHeute = true }
                else if t >= gesternStart { gestern += d; hatGestern = true }
            }
            if t >= heuteStart { hatHeute = true }
            vorher = w
        }
        guard vorher != nil else { return nil }
        return (heute, hatGestern || hatHeute ? gestern : nil)
    }
}
