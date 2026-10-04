import XCTest
@testable import HALogik

final class LogikTests: XCTestCase {

    func e(_ id: String, _ state: String, _ a: [String: JSON] = [:]) -> Entitaet {
        Entitaet(id: id, state: state, attribute: a)
    }

    func beispiel() -> [String: Entitaet] {
        let liste = [
            e("light.decke", "on", ["friendly_name": "Decke", "brightness": 128, "supported_color_modes": ["brightness"]]),
            e("light.stehlampe", "off", ["friendly_name": "Stehlampe", "supported_color_modes": ["color_temp"]]),
            e("light.flur", "on", ["friendly_name": "Flur", "supported_color_modes": ["onoff"]]),
            e("light.wohnzimmer", "on", ["friendly_name": "Wohnzimmer", "entity_id": ["light.decke", "light.stehlampe"]]),
            e("switch.tv", "on", ["friendly_name": "Fernseher", "device_class": "outlet"]),
            e("switch.leiste_1", "on", ["friendly_name": "Leiste 1"]),
            e("switch.leiste_2", "off", ["friendly_name": "Leiste 2"]),
            e("switch.steckdose_led", "on", ["friendly_name": "Steckdose LED"]),
            e("sensor.tv_leistung", "86.3", ["friendly_name": "Fernseher Leistung", "device_class": "power", "unit_of_measurement": "W"]),
            e("sensor.haupt", "1.24", ["friendly_name": "Hauptzähler", "device_class": "power", "unit_of_measurement": "kW"]),
            e("sensor.bezug", "12456.31", ["friendly_name": "Bezug", "device_class": "energy", "unit_of_measurement": "kWh"]),
            e("sensor.temperatur", "21.4", ["friendly_name": "Temperatur", "device_class": "temperature"]),
        ]
        return Dictionary(uniqueKeysWithValues: liste.map { ($0.id, $0) })
    }

    func testModell() {
        var b = Bereiche()
        b.bereiche = [.init(id: "wz", name: "Wohnzimmer", entitaeten: ["light.decke", "light.stehlampe", "switch.tv"])]
        b.leistung = [("switch.tv", "sensor.tv_leistung")]
        b.geraete = [.init(schalter: "switch.leiste_1", geraet: "d1", name: "Steckdosenleiste"),
                     .init(schalter: "switch.leiste_2", geraet: "d1", name: "Steckdosenleiste")]
        let m = Logik.baueModell(beispiel(), b, Optionen(hauptzaehler: "sensor.haupt"))
        XCTAssertEqual(m.gruppen.map(\.name), ["Wohnzimmer"])
        XCTAssertEqual(m.lichter, ["light.decke", "light.flur", "light.stehlampe"])
        XCTAssertEqual(m.lichterAn, 2)
        XCTAssertEqual(m.raeume.first?.lichter, ["light.decke", "light.stehlampe"])
        XCTAssertEqual(m.ohneRaum, ["light.flur"])
        // "Steckdose LED" ist eine Geräte-Einstellung und erscheint ohne Register nicht
        XCTAssertEqual(m.schalter.map(\.id), ["switch.tv", "switch.leiste_1", "switch.leiste_2"])
        XCTAssertEqual(m.schalter.first?.raum, "Wohnzimmer")
        XCTAssertEqual(m.schalter.first?.leistung, "sensor.tv_leistung")
        XCTAssertEqual(m.schalterGruppen.map(\.name), ["Steckdosenleiste"])
        XCTAssertEqual(m.einzelneSchalter, ["switch.tv"])
        XCTAssertEqual(m.hauptWatt, 1240)
        XCTAssertEqual(m.leistung.map(\.name), ["Fernseher"])
        XCTAssertEqual(m.energie.first?.kwh, 12456.31)
    }

    func testRegisterUndAusblenden() {
        let reg = ["switch.leiste_2": RegisterEintrag(ec: true, hb: false), "light.flur": RegisterEintrag(ec: false, hb: true)]
        let m = Logik.baueModell(beispiel(), nil, Optionen(ausgeblendet: "switch.tv, light.steh*"), register: reg)
        XCTAssertEqual(m.lichter, ["light.decke"])
        // Mit Register zählt der Name nicht mehr – "Steckdose LED" bleibt
        XCTAssertEqual(m.schalter.map(\.id), ["switch.leiste_1", "switch.steckdose_led"])
        let nur = Logik.baueModell(beispiel(), nil, Optionen(nurSteckdosen: true))
        XCTAssertEqual(nur.schalter.map(\.id), ["switch.tv"])
    }

    func testLampen() {
        let z = beispiel()
        XCTAssertEqual(Logik.helligkeit(z["light.decke"]), 50)
        XCTAssertEqual(Logik.helligkeit(z["light.flur"]), 100)
        XCTAssertTrue(Logik.dimmbar(z["light.decke"]))
        XCTAssertFalse(Logik.dimmbar(z["light.flur"]))
        XCTAssertEqual(Logik.lampenFarbe(z["light.flur"])?.hex, "#ffc65c")
        XCTAssertNil(Logik.lampenFarbe(z["light.stehlampe"]))
        let s = Logik.gruppenStatus(["light.decke", "light.stehlampe"], z)
        XCTAssertEqual(s, GruppenStatus(an: 1, gesamt: 2, verfuegbar: 2, helligkeit: 50, dimmbar: true))
        let warm = e("light.x", "on", ["color_mode": "color_temp", "color_temp_kelvin": 2000])
        XCTAssertEqual(Logik.lampenFarbe(warm)?.hex, "#ffbe6e")
    }

    func testFormat() {
        XCTAssertEqual([0, 4.21, 86.3, 1240, 23456].map { Logik.formatWatt($0) }, ["0 W", "4,2 W", "86 W", "1,24 kW", "23,5 kW"])
        XCTAssertEqual(Logik.formatKwh(12456.31), "12.456 kWh")
        XCTAssertEqual(Logik.formatKwh(6.17), "6,17 kWh")
        XCTAssertEqual(Logik.formatMenge(0.1057, "m³", .wasser), "106 L")
        XCTAssertEqual(Logik.formatMenge(1.41, "m³", .gas), "1,41 m³")
        XCTAssertEqual(Logik.formatMenge(12.3, "kWh", .gas), "12,3 kWh")
        XCTAssertEqual(Logik.formatMenge(nil, "", .gas), "–")
    }

    func testDatum() {
        XCTAssertNotNil(Logik.datum("2026-10-03T12:00:00.123456+00:00"))
        XCTAssertNotNil(Logik.datum("2026-10-03T12:00:00.000Z"))
        XCTAssertNotNil(Logik.datum("2026-10-03T12:00:00+00:00"))
        let a = Logik.datum("2026-10-03T12:00:00.5+00:00")!, b = Logik.datum("2026-10-03T12:00:00+00:00")!
        XCTAssertEqual(a.timeIntervalSince(b), 0.5, accuracy: 0.001)
    }

    func testEnergieDashboardUndTag() {
        let prefs: JSON = ["energy_sources": [
            ["type": "grid", "flow_from": [["stat_energy_from": "sensor.a"], ["stat_energy_from": "sensor.b"]]],
            ["type": "gas", "stat_energy_from": "sensor.g"], ["type": "water", "stat_energy_from": "sensor.w"]]]
        let z = Logik.zaehlerAusEnergieDashboard(prefs)
        XCTAssertEqual(z[.strom], ["sensor.a", "sensor.b"])
        XCTAssertEqual(z[.gas], ["sensor.g"])

        let mitternacht = Calendar.current.startOfDay(for: Date())
        func p(_ w: String, _ h: Double) -> JSON { ["state": .text(w), "last_changed": .text(Logik.isoText(mitternacht.addingTimeInterval(h * 3600)))] }
        let t = Logik.tagesVerbrauch([p("100", -24), p("103", -2), p("104", 3), p("1", 5), p("2.5", 8)], heuteStart: mitternacht)
        XCTAssertEqual(t?.heute, 3.5)
        XCTAssertEqual(t?.gestern, 3)
    }

    func testKennzahlen() {
        let start = Date(timeIntervalSince1970: 0)
        let k = Logik.verlaufKennzahlen([Punkt(t: start, w: 1000), Punkt(t: start.addingTimeInterval(3600), w: 500)],
                                        ende: start.addingTimeInterval(7200))
        XCTAssertEqual(k?.kwh, 1.5)
        XCTAssertEqual(k?.schnitt, 750)
        XCTAssertEqual(k?.spitze.w, 1000)
    }

    func testJSON() {
        let j = JSON.lesen(#"{"a":[1,"x",true,null],"b":{"c":2.5}}"#)
        XCTAssertEqual(j?["a"]?[1]?.text, "x")
        XCTAssertEqual(j?["b"]?["c"]?.zahl, 2.5)
        XCTAssertEqual(j?["a"]?[2]?.bool, true)
        let n: JSON = ["id": 3, "type": "auth"]
        XCTAssertEqual(JSON.lesen(n.zeichenkette), n)
        XCTAssertTrue(n.zeichenkette.contains("\"id\":3"))
    }
}

final class HeizungPersonenTests: XCTestCase {
    func testHeizung() {
        let z: [String: Entitaet] = [
            "climate.wz": Entitaet(id: "climate.wz", state: "heat", attribute: ["friendly_name": "Heizung Wohnzimmer", "current_temperature": 20.5, "temperature": 21.5,
                                                                         "hvac_action": "heating", "hvac_modes": ["off", "heat"], "preset_modes": ["none", "eco"], "preset_mode": "eco"]),
            "climate.buero": Entitaet(id: "climate.buero", state: "off", attribute: ["friendly_name": "Thermostat Büro", "current_temperature": 17]),
            "sensor.wz_t": Entitaet(id: "sensor.wz_t", state: "20.9", attribute: ["device_class": "temperature"]),
        ]
        var b = Bereiche()
        b.bereiche = [.init(id: "wz", name: "Wohnzimmer", entitaeten: ["climate.wz"], temperatur: ["sensor.wz_t"])]
        let h = Logik.heizungen(z, b)
        XCTAssertEqual(h.map(\.name), ["Büro", "Wohnzimmer"])
        let k = Logik.raumKlima(h[1], z)
        XCTAssertEqual(k.ist, 20.9)           // Raumsensor vor Thermostat
        XCTAssertEqual(k.ziel, 21.5)
        XCTAssertTrue(k.heizt)
        XCTAssertEqual(k.thermostat?.presets, ["eco"])
        XCTAssertTrue(Logik.raumKlima(h[0], z).aus)
        XCTAssertEqual(Logik.rundeZiel(21.37, k.thermostat), 21.5)
        XCTAssertEqual(Logik.formatTemp(21.5), "21,5 °C")
        XCTAssertEqual(Logik.formatDauer(5400), "1 h 30 min")
    }

    func testPersonen() {
        let z: [String: Entitaet] = [
            "person.b": Entitaet(id: "person.b", state: "not_home", attribute: ["friendly_name": "Ben", "latitude": 53.55, "longitude": 9.99]),
            "person.a": Entitaet(id: "person.a", state: "home", attribute: ["friendly_name": "Anna Maria", "latitude": 53.5656, "longitude": 10.1172]),
            "zone.home": Entitaet(id: "zone.home", state: "1", attribute: ["friendly_name": "Zuhause", "latitude": 53.5656, "longitude": 10.1172, "radius": 100]),
        ]
        let p = Logik.personen(z)
        XCTAssertEqual(p.map(\.name), ["Anna Maria", "Ben"])
        XCTAssertNotEqual(p[0].farbe, p[1].farbe)
        XCTAssertEqual(Logik.initialen("Anna Maria"), "AM")
        XCTAssertEqual(Logik.ortText("not_home"), "Unterwegs")
        let km = Logik.entfernung(p[1].lat, p[1].lon, 53.5656, 10.1172)
        XCTAssertEqual(km ?? 0, 8.5, accuracy: 0.3)
        XCTAssertEqual(Logik.zonen(z).first?.heim, true)
    }

    func testSchnappschuss() {
        var a = Anzeige()
        a.lichter = ["light.x"]
        a.lichterAn = 1
        let z = ["light.x": Entitaet(id: "light.x", state: "on", attribute: ["friendly_name": "X", "brightness": 255, "supported_color_modes": ["brightness"]])]
        let s = Logik.schnappschuss(instanz: "Zuhause", verbunden: true, z: z, anzeige: a, heizungen: [], personen: [], zonen: [], verlauf: [], tage: [:])
        XCTAssertEqual(s.lampen.first?.helligkeit, 100)
        XCTAssertEqual(s.lichterAn, 1)
        XCTAssertEqual(s.werte.first?.text, "an")
    }
}
