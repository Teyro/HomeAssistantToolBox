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
    // Anzeigemodell – jede Liste einzeln und nur neu gesetzt, wenn sie sich wirklich ändert.
    // So bauen die Listen ihre Zeilen nicht bei jedem Sensorwert neu auf (z. B. mitten im Schieben).
    property var gruppen: []
    property var raeume: []
    property var ohneRaum: []
    property var lichter: []
    property var schalter: []
    property var leistung: []
    property var energie: []
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
    property bool live: liveLader.item !== null && liveLader.item.verbunden
    property date stand: new Date(0)

    readonly property bool eingerichtet: basis !== "" && token !== ""
    readonly property string basis: adresse.trim().replace(/\/+$/, "")

    signal verlaufGeladen(string entityId, var punkte)

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
            const neu = {};
            for (let i = 0; i < liste.length; i++) neu[liste[i].entity_id] = liste[i];
            zustaende = neu;
            fehler = "";
            verbunden = true;
            stand = new Date();
            neuBerechnen();
            if (bereiche === null) bereicheLaden();
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
        const m = Logik.baueModell(zustaende, bereiche, optionen);
        for (const schluessel of ["gruppen", "raeume", "ohneRaum", "lichter", "schalter", "leistung", "energie"]) {
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

    /** Einen einzelnen Zustand ersetzen (WebSocket oder sofortige Rückmeldung). */
    function setzeZustand(entityId, neu) {
        const z = Object.assign({}, zustaende);
        const alt = z[entityId];
        if (neu) z[entityId] = neu; else delete z[entityId];
        zustaende = z;
        // Nur neu aufbauen, wenn sich die Struktur ändern kann (neue/entfernte Entität, Gruppenmitglieder)
        if (!alt || !neu || (alt.attributes && neu.attributes && String(alt.attributes.entity_id) !== String(neu.attributes.entity_id))
                || entityId.startsWith("sensor.") || alt.attributes.friendly_name !== neu.attributes.friendly_name) {
            neuBerechnen();
        } else {
            // Zähler (Lampen an …) trotzdem aktuell halten
            lichterAn = lichter.filter(id => Logik.istAn(z[id])).length;
            schalterAn = schalter.filter(s => Logik.istAn(z[s.id])).length;
        }
    }

    // ------------------------------------------------------------------ Schalten
    function dienst(domain, dienstName, daten) {
        anfrage("POST", "/api/services/" + domain + "/" + dienstName, daten, function (antwort, meldung) {
            if (meldung) {
                fehler = meldung;
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
        setzeZustand(entityId, neu);
    }

    function schalte(entityId, an) {
        const d = Logik.domain(entityId);
        vorab(entityId, an);
        if (d === "group") {
            const e = zustaende[entityId];
            // alte Gruppen: Mitglieder vorab mitschalten
            if (e && e.attributes && e.attributes.entity_id) e.attributes.entity_id.forEach(m => vorab(m, an));
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

    function alleLichterAus() {
        const an = lichter.filter(id => Logik.istAn(zustaende[id]));
        an.forEach(id => vorab(id, false));
        if (an.length) dienst("light", "turn_off", { entity_id: an });
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
    }
}
