/*
 * Verbindung zu Home Assistant: lädt alle Zustände (REST), hält sie live aktuell
 * (WebSocket, falls verfügbar – sonst regelmäßiges Abfragen) und schaltet Geräte.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import "logik.js" as Logik

Item {
    id: ha

    // --- Einstellungen (werden von main.qml gesetzt) ---
    property string adresse: ""
    property string token: ""
    property int abfrageSekunden: 10
    property bool sichtbar: false          // Popup offen -> häufiger abfragen
    property var optionen: ({})
    property bool liveErlaubt: true        // Einstellungsseite: nur Verbindungstest, keine Live-Verbindung

    // --- Zustand ---
    property var zustaende: ({})
    property var bereiche: null
    // Aus dem Entitäten-Register: Einstellungs-/Diagnose-Entitäten und versteckte (nur per WebSocket)
    property var register: ({})
    // Anzeigemodell – jede Liste einzeln und nur neu gesetzt, wenn sie sich wirklich ändert.
    // So bauen die Listen ihre Zeilen nicht bei jedem Sensorwert neu auf (z. B. mitten im Schieben).
    property var gruppen: []
    property var raeume: []
    property var ohneRaum: []
    property var lichter: []
    property var schalter: []
    property var schalterGruppen: []
    property var einzelneSchalter: []
    property var leistung: []
    property var energie: []
    property var heizungen: []
    property var personen: []
    property var zonen: []
    // Name der Installation aus Home Assistant (Einstellungen → Allgemein), z. B. "Zuhause"
    property string standortName: ""
    property int lichterAn: 0
    property int schalterAn: 0
    property var hauptWatt: null
    property real summeWatt: 0
    property var _json: ({})
    property bool verbunden: false
    property bool laedt: false
    // Token abgelehnt: nicht weiter abfragen – Home Assistant sperrt sonst nach einigen
    // Fehlversuchen die IP-Adresse (ip_ban). Erst nach geänderten Einstellungen oder
    // "Erneut versuchen" wieder.
    property bool abgelehnt: false
    property string fehler: ""
    // Kurzer Hinweis, wenn ein Schaltbefehl fehlschlägt (verschwindet nach einigen Sekunden)
    property string meldung: ""
    Timer {
        id: meldungTimer
        interval: 6000
        onTriggered: ha.meldung = ""
    }
    property bool live: liveLader.item !== null && liveLader.item.verbunden
    property date stand: new Date(0)

    readonly property bool eingerichtet: basis !== "" && token !== ""
    readonly property string basis: adresse.trim().replace(/\/+$/, "")

    signal verlaufGeladen(string entityId, var punkte)

    // "Verbrauch heute": { strom|wasser|gas: { heute, gestern, einheit, zaehler } }
    property var verbrauchHeute: ({})
    property var energiePrefs: null

    // ------------------------------------------------------------------ HTTP
    function anfrage(methode, pfad, daten, fertig) {
        if (!eingerichtet) return;
        const xhr = new XMLHttpRequest();
        xhr.open(methode, basis + pfad);
        xhr.setRequestHeader("Authorization", "Bearer " + token.trim());
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 15000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status >= 200 && xhr.status < 300) {
                let antwort = null;
                try { antwort = xhr.responseText ? JSON.parse(xhr.responseText) : null; }
                catch (e) { antwort = xhr.responseText; }
                if (fertig) fertig(antwort, null);
            } else {
                let meldung;
                if (xhr.status === 401 || xhr.status === 403) {
                    meldung = i18n("Zugriff verweigert – bitte den Token prüfen.");
                    abgelehnt = true;
                }
                else if (xhr.status === 0) meldung = i18n("Home Assistant ist nicht erreichbar (%1).", basis);
                else meldung = i18n("Fehler %1 von Home Assistant.", xhr.status);
                if (fertig) fertig(null, meldung);
            }
        };
        xhr.send(daten === undefined || daten === null ? null : JSON.stringify(daten));
    }

    /** Manuell neu versuchen (auch nach abgelehntem Token). */
    function erneutVersuchen() {
        abgelehnt = false;
        aktualisieren();
    }

    function aktualisieren() {
        if (abgelehnt) return;
        if (!eingerichtet) {
            fehler = "";
            verbunden = false;
            return;
        }
        laedt = true;
        anfrage("GET", "/api/states", null, function (liste, meldung) {
            laedt = false;
            if (meldung) {
                fehler = meldung;
                verbunden = false;
                return;
            }
            // Nur behalten, was das Widget braucht (Lampen, Schalter, Gruppen, Leistung/Energie)
            const neu = {};
            const haupt = optionen.hauptzaehler || "";
            for (let i = 0; i < liste.length; i++) {
                const e = liste[i];
                if (Logik.relevant(e.entity_id, e, haupt)) neu[e.entity_id] = e;
            }
            puffer = {};
            zustaende = neu;
            fehler = "";
            verbunden = true;
            stand = new Date();
            neuBerechnen();
            if (bereiche === null) { bereicheLaden(); standortLaden(); }
        });
    }

    /** Räume und Leistungssensoren der Steckdosen über die Template-API (einmal, dann selten). */
    function bereicheLaden() {
        anfrage("POST", "/api/template", { template: Logik.BEREICHE_TEMPLATE }, function (antwort, meldung) {
            if (meldung) {
                bereiche = { bereiche: [], leistung: [] }; // ältere Versionen ohne Bereiche-Funktionen
                return;
            }
            try {
                bereiche = typeof antwort === "string" ? JSON.parse(antwort) : antwort;
            } catch (e) {
                bereiche = { bereiche: [], leistung: [] };
            }
            neuBerechnen();
        });
    }

    function neuBerechnen() {
        const m = Logik.baueModell(zustaende, bereiche, Object.assign({}, optionen, { register: register }));
        const versteckt = (optionen.ausgeblendet || "").split(/[\s,;]+/).filter(x => x);
        m.heizungen = Logik.heizungen(zustaende, bereiche, versteckt);
        m.personen = Logik.personen(zustaende, versteckt);
        m.zonen = Logik.zonen(zustaende);
        for (const schluessel of ["gruppen", "raeume", "ohneRaum", "lichter", "schalter", "schalterGruppen", "einzelneSchalter", "leistung", "energie", "heizungen", "personen", "zonen"]) {
            const j = JSON.stringify(m[schluessel]);
            if (_json[schluessel] !== j) {
                _json[schluessel] = j;
                ha[schluessel] = m[schluessel];
            }
        }
        lichterAn = m.lichterAn;
        schalterAn = m.schalterAn;
        hauptWatt = m.hauptWatt;
        summeWatt = m.summeWatt;
    }

    // Änderungen werden kurz gesammelt und gemeinsam übernommen: Home Assistant meldet oft
    // viele Werte pro Sekunde – einzeln würde jedes Mal die ganze Liste kopiert.
    property var puffer: ({})

    /** Einen einzelnen Zustand ersetzen (WebSocket oder sofortige Rückmeldung). */
    function setzeZustand(entityId, neu, sofort) {
        if (!Logik.relevant(entityId, neu || zustaende[entityId], optionen.hauptzaehler || "")) return;
        puffer[entityId] = neu || null;
        if (sofort) uebernehmen();
        else if (!sammelTimer.running) sammelTimer.start();
    }

    function uebernehmen() {
        sammelTimer.stop();
        const ids = Object.keys(puffer);
        if (!ids.length) return;
        const z = Object.assign({}, zustaende);
        let struktur = false;
        for (const id of ids) {
            const alt = z[id];
            const neu = puffer[id];
            if (neu) z[id] = neu; else delete z[id];
            // Neu aufbauen nur, wenn sich die Struktur ändern kann: neue/entfernte Entität,
            // geänderte Gruppenmitglieder oder Namen, Messwerte (Energie-Reiter)
            if (!alt || !neu || id.startsWith("sensor.") || id.startsWith("person.")
                    || String(alt.attributes && alt.attributes.entity_id) !== String(neu.attributes && neu.attributes.entity_id)
                    || (alt.attributes && alt.attributes.friendly_name) !== (neu.attributes && neu.attributes.friendly_name)) {
                struktur = true;
            }
        }
        puffer = {};
        zustaende = z;
        if (struktur) {
            neuBerechnen();
        } else {
            lichterAn = lichter.filter(id => Logik.istAn(z[id])).length;
            schalterAn = schalter.filter(s => Logik.istAn(z[s.id])).length;
        }
    }
    Timer {
        id: sammelTimer
        interval: 120
        onTriggered: ha.uebernehmen()
    }

    // ------------------------------------------------------------------ Schalten
    function dienst(domain, dienstName, daten) {
        anfrage("POST", "/api/services/" + domain + "/" + dienstName, daten, function (antwort, fehlertext) {
            if (fehlertext) {
                ha.meldung = i18n("Schalten fehlgeschlagen: %1", fehlertext);
                meldungTimer.restart();
                // Vorab angezeigten Zustand wieder richtigstellen
                nachladenTimer.restart();
                return;
            }
            // Antwort enthält die geänderten Zustände
            if (antwort && antwort.length !== undefined) {
                for (let i = 0; i < antwort.length; i++) setzeZustand(antwort[i].entity_id, antwort[i]);
            }
            if (!live) nachladenTimer.restart();
        });
    }

    /** Sofort sichtbar umschalten, bevor Home Assistant antwortet. */
    function vorab(entityId, an, prozent) {
        const e = zustaende[entityId];
        if (!e) return;
        const neu = Object.assign({}, e, { state: an ? "on" : "off", attributes: Object.assign({}, e.attributes) });
        if (prozent !== undefined) neu.attributes.brightness = Math.round(prozent * 2.55);
        setzeZustand(entityId, neu, true);
    }

    function schalte(entityId, an) {
        const d = Logik.domain(entityId);
        const e = zustaende[entityId];
        vorab(entityId, an);
        // Gruppen: Mitglieder gleich mit umschalten (die echte Rückmeldung kommt danach)
        if (e && e.attributes && e.attributes.entity_id) e.attributes.entity_id.forEach(m => vorab(m, an));
        if (d === "group") {
            dienst("homeassistant", an ? "turn_on" : "turn_off", { entity_id: entityId });
        } else {
            dienst(d, an ? "turn_on" : "turn_off", { entity_id: entityId });
        }
    }

    function dimme(entityId, prozent) {
        const p = Math.round(prozent);
        if (p <= 0) {
            schalte(entityId, false);
            return;
        }
        vorab(entityId, true, p);
        if (Logik.domain(entityId) === "group") {
            // alte Gruppen können nicht dimmen – die Lampen einzeln
            const e = zustaende[entityId];
            dienst("light", "turn_on", { entity_id: e.attributes.entity_id, brightness_pct: p });
        } else {
            dienst("light", "turn_on", { entity_id: entityId, brightness_pct: p });
        }
    }

    /** Mehrere Schalter/Steckdosen gemeinsam (Steckdosenleiste ohne eigene Gruppen-Entität). */
    function schalteSchalter(ids, an) {
        if (!ids.length) return;
        ids.forEach(id => vorab(id, an));
        dienst("switch", an ? "turn_on" : "turn_off", { entity_id: ids });
    }

    /** Mehrere Lampen gemeinsam (Räume): ein Aufruf für alle. */
    function schalteMehrere(ids, an) {
        if (!ids.length) return;
        ids.forEach(id => vorab(id, an));
        dienst("light", an ? "turn_on" : "turn_off", { entity_id: ids });
    }

    function dimmeMehrere(ids, prozent) {
        const p = Math.round(prozent);
        if (!ids.length) return;
        if (p <= 0) {
            schalteMehrere(ids, false);
            return;
        }
        ids.forEach(id => vorab(id, true, p));
        dienst("light", "turn_on", { entity_id: ids, brightness_pct: p });
    }

    // ------------------------------------------------------------------ Heizung
    /** Thermostat sofort sichtbar ändern, dann an Home Assistant schicken */
    function vorabKlima(entityId, attribute, zustand) {
        const e = zustaende[entityId];
        if (!e) return;
        const neu = Object.assign({}, e, { attributes: Object.assign({}, e.attributes, attribute) });
        if (zustand) neu.state = zustand;
        setzeZustand(entityId, neu, true);
    }

    function setzeTemperatur(entityId, grad) {
        const e = zustaende[entityId];
        // Ein ausgeschaltetes Thermostat mit neuer Zieltemperatur soll auch heizen
        const aus = e && e.state === "off";
        const modus = aus ? ((e.attributes.hvac_modes || []).indexOf("heat") >= 0 ? "heat" : (e.attributes.hvac_modes || [])[1]) : "";
        vorabKlima(entityId, { temperature: grad }, modus || undefined);
        const daten = { entity_id: entityId, temperature: grad };
        if (modus) daten.hvac_mode = modus;
        dienst("climate", "set_temperature", daten);
    }

    function setzeModus(entityId, modus) {
        vorabKlima(entityId, {}, modus);
        dienst("climate", "set_hvac_mode", { entity_id: entityId, hvac_mode: modus });
    }

    function setzePreset(entityId, preset) {
        vorabKlima(entityId, { preset_mode: preset });
        dienst("climate", "set_preset_mode", { entity_id: entityId, preset_mode: preset });
    }

    /** Name der Installation holen (für die Instanzliste) */
    function standortLaden() {
        anfrage("GET", "/api/config", null, function (antwort, meldung) {
            if (!meldung && antwort && antwort.location_name) standortName = antwort.location_name;
        });
    }

    function alleLichterAus() {
        const an = lichter.filter(id => Logik.istAn(zustaende[id]));
        an.forEach(id => vorab(id, false));
        if (an.length) dienst("light", "turn_off", { entity_id: an });
    }

    /**
     * Verbrauch heute und gestern für Strom, Wasser und Gas. Zähler: eigene Auswahl aus den
     * Einstellungen, sonst die Zähler aus dem Energie-Dashboard von Home Assistant.
     * Mit Live-Verbindung über die Langzeitstatistik (genau wie das Energie-Dashboard),
     * ohne über den Verlauf der Zählerstände.
     */
    function verbrauchHeuteLaden(eigene, gewuenscht) {
        const live = liveLader.item && liveLader.item.verbunden ? liveLader.item : null;
        const weiter = function (ausDashboard) {
            const plan = {};
            for (const art of Logik.VERBRAUCH_ARTEN) {
                if (!gewuenscht[art]) continue;
                const ids = eigene[art] ? [eigene[art]] : (ausDashboard ? ausDashboard[art] : []);
                if (ids.length) plan[art] = ids;
            }
            if (!Object.keys(plan).length) { verbrauchHeute = {}; return; }
            if (live) statistikLaden(live, plan);
            else historieTageLaden(plan);
        };
        if (live && energiePrefs === null) {
            live.anfrage({ type: "energy/get_prefs" }, function (ok, r) {
                energiePrefs = ok && r ? r : {};
                weiter(Logik.zaehlerAusEnergieDashboard(energiePrefs));
            });
        } else {
            weiter(energiePrefs ? Logik.zaehlerAusEnergieDashboard(energiePrefs) : null);
        }
    }

    function einheitVon(id) {
        const e = zustaende[id];
        return e && e.attributes ? (e.attributes.unit_of_measurement || "") : "";
    }

    function statistikLaden(live, plan) {
        const alle = [].concat(...Object.values(plan));
        live.anfrage({ type: "recorder/get_statistics_metadata", statistic_ids: alle }, function (ok, meta) {
            const einheit = {};
            if (ok && meta) for (const m of meta) einheit[m.statistic_id] = m.statistics_unit_of_measurement || m.display_unit_of_measurement || "";
            const ergebnis = {};
            let offen = 0;
            for (const art in plan) {
                ergebnis[art] = { heute: 0, gestern: 0, einheit: einheit[plan[art][0]] || einheitVon(plan[art][0]), zaehler: plan[art], gueltig: false };
                for (const id of plan[art]) {
                    for (const versatz of [0, -1]) {
                        offen++;
                        live.anfrage({ type: "recorder/statistic_during_period", statistic_id: id,
                                       calendar: { period: "day", offset: versatz }, types: ["change"] }, function (ok2, r) {
                            if (ok2 && r && r.change !== undefined && r.change !== null) {
                                if (versatz === 0) ergebnis[art].heute += r.change;
                                else ergebnis[art].gestern += r.change;
                                ergebnis[art].gueltig = true;
                            }
                            if (--offen === 0) verbrauchHeute = ergebnis;
                        });
                    }
                }
            }
        });
    }

    function historieTageLaden(plan) {
        // Ohne WebSocket gehen nur Entitäten (keine externen Statistiken)
        const ids = [].concat(...Object.values(plan)).filter(id => id.indexOf(".") > 0 && id.indexOf(":") < 0);
        if (!ids.length) { verbrauchHeute = {}; return; }
        const mitternacht = new Date();
        mitternacht.setHours(0, 0, 0, 0);
        const start = new Date(mitternacht.getTime() - 86400000).toISOString();
        anfrage("GET", "/api/history/period/" + encodeURIComponent(start) + "?filter_entity_id=" + encodeURIComponent(ids.join(","))
                + "&minimal_response&no_attributes", null, function (antwort, fehlertext) {
            if (fehlertext || !antwort) return;
            const jeEntitaet = {};
            for (const liste of antwort) if (liste && liste.length && liste[0].entity_id) jeEntitaet[liste[0].entity_id] = liste;
            const ergebnis = {};
            for (const art in plan) {
                let heute = 0, gestern = 0, gueltig = false;
                for (const id of plan[art]) {
                    const v = Logik.tagesVerbrauch(jeEntitaet[id], mitternacht.getTime());
                    if (!v) continue;
                    heute += v.heute;
                    if (v.gestern !== null) gestern += v.gestern;
                    gueltig = true;
                }
                ergebnis[art] = { heute: heute, gestern: gestern, einheit: einheitVon(plan[art][0]), zaehler: plan[art], gueltig: gueltig };
            }
            verbrauchHeute = ergebnis;
        });
    }

    function verlaufLaden(entityId, stunden) {
        if (!entityId) return;
        const start = new Date(Date.now() - stunden * 3600 * 1000).toISOString();
        anfrage("GET", "/api/history/period/" + encodeURIComponent(start) + "?filter_entity_id=" + encodeURIComponent(entityId)
                + "&minimal_response&no_attributes", null, function (antwort, meldung) {
            if (meldung) return;
            const e = zustaende[entityId];
            const kw = e && e.attributes && e.attributes.unit_of_measurement === "kW";
            verlaufGeladen(entityId, Logik.verlaufPunkte(antwort, kw));
        });
    }

    // ------------------------------------------------------------------ Zeitgeber
    Timer {
        // Ohne Live-Verbindung regelmäßig abfragen; mit Live-Verbindung nur selten zur Sicherheit.
        interval: ha.live ? 300000 : (ha.sichtbar ? Math.max(3, ha.abfrageSekunden) : Math.max(30, ha.abfrageSekunden * 6)) * 1000
        running: ha.eingerichtet && !ha.abgelehnt
        repeat: true
        triggeredOnStart: true
        onTriggered: ha.aktualisieren()
    }
    Timer {
        // Räume ändern sich selten
        interval: 15 * 60 * 1000
        running: ha.eingerichtet && ha.verbunden
        repeat: true
        onTriggered: ha.bereicheLaden()
    }
    Timer {
        id: nachladenTimer
        interval: 1200
        onTriggered: ha.aktualisieren()
    }

    onAdresseChanged: neustart.restart()
    onTokenChanged: neustart.restart()
    onOptionenChanged: neuBerechnen()
    onSichtbarChanged: if (sichtbar && !live) aktualisieren()
    Timer {
        id: neustart
        interval: 400
        onTriggered: {
            ha.abgelehnt = false;
            ha.zustaende = {};
            ha.bereiche = null;
            ha.energiePrefs = null;
            ha.verbrauchHeute = {};
            ha.standortName = "";
            ha._json = {};
            ha.neuBerechnen();
            ha.aktualisieren();
        }
    }

    // ------------------------------------------------------------------ Live (WebSocket)
    // In einer eigenen Datei: fehlt das Qt-Modul "QtWebSockets", lädt sie nicht – dann wird
    // einfach regelmäßig abgefragt.
    Loader {
        id: liveLader
        active: ha.eingerichtet && ha.liveErlaubt && !ha.abgelehnt
        source: "LiveVerbindung.qml"
        onLoaded: {
            item.adresse = Qt.binding(() => ha.basis);
            item.token = Qt.binding(() => ha.token.trim());
        }
    }
    Connections {
        target: liveLader.item
        ignoreUnknownSignals: true
        function onZustandGeaendert(entityId, neu) { ha.setzeZustand(entityId, neu); }
        function onWiederVerbunden() { ha.aktualisieren(); }
        function onRegisterGeladen(eintraege) { ha.register = eintraege; ha.neuBerechnen(); }
    }
}
