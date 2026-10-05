/*
 * Updates: fragt die Releases auf GitHub ab, merkt sich die Änderungen ("Was ist neu?") und
 * installiert auf Wunsch die neue Version mit kpackagetool6. Danach Plasma neu starten.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.plasma.plasma5support as P5Support

import "logik.js" as Logik

Item {
    id: akt

    property string aktuelleVersion: "0"
    property string quelle: "https://api.github.com/repos/Teyro/HomeAssistantToolBox/releases?per_page=20"
    property bool automatisch: true

    // Neuere Version: { version, url, seite, notizen: [{ version, titel, text }] } oder null
    property var update: null
    // Änderungen der letzten Versionen (auch ohne Update – für "Was ist neu?")
    property var alleNotizen: []
    // "", "suche", "aktuell", "laedt", "installiert", "fehler"
    property string status: ""
    property string meldung: ""

    function pruefen() {
        status = "suche";
        const xhr = new XMLHttpRequest();
        xhr.open("GET", quelle);
        xhr.setRequestHeader("Accept", "application/vnd.github+json");
        xhr.timeout = 20000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) {
                status = "fehler";
                meldung = i18n("Updates konnten nicht abgefragt werden (%1).", xhr.status || i18n("keine Verbindung"));
                return;
            }
            let liste = [];
            try { liste = JSON.parse(xhr.responseText); } catch (e) { liste = []; }
            update = Logik.updateAusReleases(liste, aktuelleVersion, "homeassistant-toolbox.plasmoid");
            alleNotizen = (Array.isArray(liste) ? liste : []).filter(r => r && typeof r.tag_name === "string" && !r.draft && !r.prerelease).slice(0, 6)
                               .map(r => ({ version: r.tag_name.replace(/^v/, ""), titel: r.name || r.tag_name, text: r.body || "" }));
            status = update ? "" : "aktuell";
        };
        xhr.send();
    }

    function installieren() {
        // nur einfache Adressen von GitHub (keine Zeichen, die in der Shell etwas bedeuten)
        if (!update || !update.url || !/^https:\/\/github\.com\/[A-Za-z0-9._\/-]+$/.test(update.url) || update.url.indexOf("..") >= 0) return;
        status = "laedt";
        meldung = "";
        // Adresse ist geprüft (nur Downloads aus diesem Projekt), enthält keine Anführungszeichen
        shell.connectSource("sh -c 'set -e; d=$(mktemp -d); curl -fsSL --max-time 180 -o \"$d/ha.plasmoid\" \"" + update.url
                            + "\"; kpackagetool6 -t Plasma/Applet -u \"$d/ha.plasmoid\" 2>&1; rm -rf \"$d\"; echo UPDATE_OK' 2>&1");
    }

    /** Plasma neu starten, damit die neue Version läuft */
    function plasmaNeuStarten() {
        shell.connectSource("sh -c 'systemctl --user restart plasma-plasmashell.service || (kquitapp6 plasmashell; sleep 1; setsid kstart plasmashell)' >/dev/null 2>&1 &");
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: (quelle, daten) => {
            disconnectSource(quelle);
            if (quelle.indexOf("kpackagetool6") < 0) return;
            const ausgabe = (daten.stdout || "") + (daten.stderr || "");
            if (ausgabe.indexOf("UPDATE_OK") >= 0) {
                akt.status = "installiert";
            } else {
                akt.status = "fehler";
                akt.meldung = i18n("Installation fehlgeschlagen: %1", ausgabe.trim().split("\n").slice(-2).join(" ") || i18n("unbekannter Fehler"));
            }
        }
    }

    // Beim Start (kurz verzögert) und dann alle 12 Stunden
    Timer {
        interval: 15000
        running: akt.automatisch
        onTriggered: akt.pruefen()
    }
    Timer {
        interval: 12 * 3600 * 1000
        running: akt.automatisch
        repeat: true
        onTriggered: akt.pruefen()
    }
}
