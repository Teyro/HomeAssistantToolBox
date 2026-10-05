/*
 * Home Assistant für Plasma 6: Lampen, Steckdosen, Heizung, Energie und Personen –
 * im Panel oder als Kachel auf dem Schreibtisch. Mehrere Home-Assistant-Instanzen.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import "logik.js" as Logik

PlasmoidItem {
    id: root

    // ---- Instanzen ----
    readonly property var instanzen: Logik.instanzenLesen(Plasmoid.configuration.instanzen, Plasmoid.configuration.adresse, Plasmoid.configuration.token)
    // Gewählte Instanz (nur bis zum Neustart; danach wieder der Favorit bzw. die Kachel-Instanz)
    property string gewaehlteId: ""
    readonly property var aktiv: instanzen.find(i => i.id === gewaehlteId)
        || (Plasmoid.configuration.kachelInstanz !== "" ? instanzen.find(i => i.id === Plasmoid.configuration.kachelInstanz) : null)
        || Logik.favorit(instanzen) || ({})
    readonly property string aktiveInstanzId: aktiv.id || ""
    readonly property bool aufDemSchreibtisch: Plasmoid.formFactor === PlasmaCore.Types.Planar || Plasmoid.formFactor === PlasmaCore.Types.MediaCenter

    function wechseln(id) { gewaehlteId = id; }

    // Eindeutiger Name: in der Popup-Komponente würde "ha: ha" auf die eigene Eigenschaft zeigen
    HaVerbindung {
        id: verbindung
        adresse: root.aktiv.adresse || ""
        token: root.aktiv.token || ""
        abfrageSekunden: Plasmoid.configuration.abfrageSekunden
        sichtbar: root.expanded || root.aufDemSchreibtisch
        optionen: ({
            alteGruppen: Plasmoid.configuration.alteGruppen,
            nurSteckdosen: Plasmoid.configuration.nurSteckdosen,
            hauptzaehler: root.aktiv.hauptzaehler !== undefined ? root.aktiv.hauptzaehler : Plasmoid.configuration.hauptzaehler,
            ausgeblendet: Plasmoid.configuration.ausgeblendet
        })
    }

    // ---- Instanzen mit anderen Widgets teilen (~/.config/homeassistanttoolbox/instanzen.json) ----
    // Ein neu hinzugefügtes Widget (z. B. eine Kachel auf dem Schreibtisch) übernimmt so die
    // schon eingerichteten Instanzen, ohne dass man Adresse und Token erneut eintippen muss.
    readonly property string teilDatei: "\"$HOME/.config/homeassistanttoolbox/instanzen.json\""
    // Übernahme aus der Vorgängerversion ("Home Assistant Leiste"), falls es noch keine eigene Datei gibt
    readonly property string leseBefehl: "cat " + teilDatei + " 2>/dev/null || cat \"$HOME/.config/homeassistant-leiste/instanzen.json\" 2>/dev/null"
    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: (quelle, daten) => {
            disconnectSource(quelle);
            if (quelle !== root.leseBefehl) return;
            const text = (daten.stdout || "").trim();
            if (text && root.instanzen.length === 0 && Logik.instanzenLesen(text).length) Plasmoid.configuration.instanzen = text;
        }
    }
    function teilen() {
        if (!instanzen.length) return;
        const b64 = Qt.btoa(JSON.stringify(instanzen));
        shell.connectSource("sh -c 'umask 077; mkdir -p \"$HOME/.config/homeassistanttoolbox\" && printf %s " + b64
                            + " | base64 -d > " + teilDatei.replace(/'/g, "") + "' # " + Date.now());
    }
    Connections {
        target: Plasmoid.configuration
        function onValueChanged(schluessel, wert) { if (schluessel === "instanzen") root.teilen(); }
    }
    // Gemeinsame Logik übersetzen (Platzhalter %1 … bleiben stehen, die Logik setzt sie ein)
    function uebersetze(text) {
        const n = (text.match(/%\d/g) || []).length;
        return n === 0 ? i18n(text) : n === 1 ? i18n(text, "%1") : n === 2 ? i18n(text, "%1", "%2") : i18n(text, "%1", "%2", "%3");
    }
    Component.onCompleted: {
        Logik.sprache(uebersetze, Qt.locale().decimalPoint, Qt.locale().textDirection === Qt.RightToLeft);
        if (instanzen.length === 0) shell.connectSource(leseBefehl);
        else if (!Plasmoid.configuration.instanzen) {
            // alte Einzel-Einstellung (Adresse/Token) als erste Instanz übernehmen
            Plasmoid.configuration.instanzen = JSON.stringify(instanzen);
        }
    }

    // ---- Extra heizen: Temperatur für eine Zeit, danach zurück (übersteht Neustarts) ----
    readonly property var boosts: { try { return JSON.parse(Plasmoid.configuration.boosts || "[]"); } catch (e) { return []; } }
    function boostsSpeichern(liste) { Plasmoid.configuration.boosts = JSON.stringify(liste); }
    function boostStarten(ids, grad, minuten) {
        let liste = boosts.filter(b => !(b.instanz === aktiveInstanzId && ids.indexOf(b.id) >= 0));
        for (const id of ids) {
            const k = Logik.klimaStatus(verbindung.zustaende[id]);
            if (!k) continue;
            liste.push({ instanz: aktiveInstanzId, id: id, bis: Date.now() + minuten * 60000, vorher: k.ziel !== null ? k.ziel : grad, modus: k.modus });
            verbindung.setzeTemperatur(id, grad);
        }
        boostsSpeichern(liste);
    }
    function boostBeenden(b) {
        if (!b) return;
        // alle Thermostate dieses Raums gemeinsam zurück
        const betroffen = boosts.filter(x => x.instanz === b.instanz && Math.abs(x.bis - b.bis) < 1000);
        if (b.instanz === aktiveInstanzId) {
            for (const x of betroffen) {
                if (x.modus === "off") verbindung.setzeModus(x.id, "off");
                else verbindung.setzeTemperatur(x.id, x.vorher);
            }
        }
        boostsSpeichern(boosts.filter(x => betroffen.indexOf(x) < 0));
    }
    Timer {
        interval: 15000
        running: root.boosts.length > 0 && verbindung.verbunden
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const abgelaufen = root.boosts.filter(b => b.instanz === root.aktiveInstanzId && b.bis <= Date.now());
            if (abgelaufen.length) root.boostBeenden(abgelaufen[0]);
        }
    }

    // ---- Updates (nur im Panel-Widget, nicht in jeder Kachel) ----
    Aktualisierer {
        id: updater
        aktuelleVersion: Plasmoid.metaData.version
        automatisch: Plasmoid.configuration.updatesSuchen && !root.aufDemSchreibtisch
    }
    readonly property alias aktualisierer: updater

    readonly property int lichterAn: verbindung.lichterAn
    readonly property real watt: verbindung.hauptWatt !== null ? verbindung.hauptWatt : verbindung.summeWatt

    Plasmoid.icon: Qt.resolvedUrl("../icons/" + (lichterAn > 0 ? "ha-licht-an.svg" : "ha-licht-aus.svg"))
    Plasmoid.status: verbindung.eingerichtet ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.StandardBackground

    toolTipMainText: instanzen.length > 1 ? i18n("Home Assistant · %1", aktiv.name || "") : i18n("Home Assistant")
    toolTipSubText: {
        if (!verbindung.eingerichtet) return i18n("Noch nicht eingerichtet – Rechtsklick → Einrichten");
        if (verbindung.fehler) return verbindung.fehler;
        const teile = [];
        teile.push(lichterAn === 1 ? i18n("1 Lampe an") : i18n("%1 Lampen an", lichterAn));
        if (verbindung.schalter.length) teile.push(i18n("%1 von %2 Steckdosen an", verbindung.schalterAn, verbindung.schalter.length));
        const heizen = verbindung.heizungen.filter(r => Logik.raumKlima(r, verbindung.zustaende).heizt).length;
        if (verbindung.heizungen.length) teile.push(heizen ? i18n("Heizung an in %1 Räumen", heizen) : i18n("Heizung ruht"));
        if (verbindung.leistung.length || verbindung.hauptWatt !== null) teile.push(i18n("Verbrauch %1", Logik.formatWatt(watt)));
        return teile.join("\n");
    }

    switchWidth: Kirigami.Units.gridUnit * 8
    switchHeight: Kirigami.Units.gridUnit * 5
    // Auf dem Schreibtisch gleich den Inhalt zeigen, im Panel das Symbol
    preferredRepresentation: aufDemSchreibtisch ? fullRepresentation : compactRepresentation

    compactRepresentation: KompaktAnsicht {
        lichterAn: root.lichterAn
        zeigeAnzahl: Plasmoid.configuration.zeigeAnzahl
        verbunden: verbindung.verbunden
        eingerichtet: verbindung.eingerichtet
        panelhoehe: Plasmoid.configuration.symbolPanelhoehe
        horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
        onGeklickt: root.expanded = !root.expanded
    }

    fullRepresentation: aufDemSchreibtisch && Plasmoid.configuration.darstellung !== "komplett" ? kachel : voll

    Component {
        id: voll
        VollAnsicht {
            ha: verbindung
            steuerung: root
            zeigeGruppen: Plasmoid.configuration.zeigeGruppen
            zeigeRaeume: Plasmoid.configuration.zeigeRaeume
            zeigeHeizung: Plasmoid.configuration.zeigeHeizung
            zeigePersonen: Plasmoid.configuration.zeigePersonen
            hauptzaehler: verbindung.optionen.hauptzaehler || ""
            verbrauchAnzeige: ({ strom: Plasmoid.configuration.zeigeStromHeute,
                                 wasser: Plasmoid.configuration.zeigeWasserHeute,
                                 gas: Plasmoid.configuration.zeigeGasHeute })
            eigeneZaehler: ({ strom: root.aktiv.zaehlerStrom || Plasmoid.configuration.zaehlerStrom,
                              wasser: root.aktiv.zaehlerWasser || Plasmoid.configuration.zaehlerWasser,
                              gas: root.aktiv.zaehlerGas || Plasmoid.configuration.zaehlerGas })
            offen: root.expanded || root.aufDemSchreibtisch
            onEinrichten: Plasmoid.internalAction("configure").trigger()
        }
    }
    Component {
        id: kachel
        KachelAnsicht {
            ha: verbindung
            steuerung: root
            art: Plasmoid.configuration.darstellung
            ziel: Plasmoid.configuration.kachelEntitaet
            onEinrichten: Plasmoid.internalAction("configure").trigger()
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Alle Lampen aus")
            icon.name: "system-shutdown"
            enabled: root.lichterAn > 0
            onTriggered: verbindung.alleLichterAus()
        },
        PlasmaCore.Action {
            text: i18n("Home Assistant öffnen")
            icon.name: "internet-web-browser"
            enabled: verbindung.basis !== ""
            onTriggered: Qt.openUrlExternally(verbindung.basis)
        },
        PlasmaCore.Action {
            text: i18n("Neu laden")
            icon.name: "view-refresh"
            enabled: verbindung.eingerichtet
            onTriggered: { verbindung.bereicheLaden(); verbindung.erneutVersuchen(); }
        }
    ]
}
