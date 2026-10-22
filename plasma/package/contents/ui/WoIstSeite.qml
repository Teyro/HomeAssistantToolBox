/*
 * Reiter "Wo ist?" (optional, ersetzt "Personen"): Personen, Geräte und Objekte mit Standort – auch aus
 * weiteren Home-Assistant-Installationen – auf einer Karte, mit Akku, Entfernung, Route und dem Weg der
 * letzten 30 Minuten bis 6 Stunden. Weitere Installationen werden nur abgefragt, solange der Reiter offen ist.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

ColumnLayout {
    id: seite
    objectName: "woIstSeite"

    required property var ha
    property var instanzen: []
    property string aktiveId: ""
    property string ausgeblendet: ""
    property bool aktiv: false

    property string art: "personen"
    property string auswahl: ""
    property int stufe: 0                 // Index in Logik.VERLAUF_STUFEN
    property double jetzt: Date.now()
    property var fremde: ({})             // Instanz-ID -> [Orter]
    property var fremdeFehler: ({})       // Instanz-ID -> Meldung
    property var verlaeufe: ({})          // Schlüssel -> [{ t, lat, lon }] der letzten 6 Stunden
    property double verlaufStand: 0

    readonly property var versteckt: ausgeblendet.split(/[\s,;]+/).filter(x => x)
    readonly property var weitere: instanzen.filter(i => i.id !== aktiveId && i.adresse && i.token)
    readonly property var alle: {
        let l = ha.orter.slice();
        for (const i of weitere) l = l.concat(fremde[i.id] || []);
        return l;
    }
    readonly property var gezeigt: alle.filter(o => o.art === art)
    readonly property var heim: ha.zonen.find(z => z.heim) || null
    readonly property int minuten: Logik.VERLAUF_STUFEN[stufe]
    readonly property var spuren: {
        if (!minuten) return [];
        const wen = auswahl ? alle.filter(o => o.id === auswahl) : gezeigt;
        const liste = [];
        for (const o of wen) {
            const p = Logik.spurSeit(verlaeufe[o.id] || [], minuten, jetzt, o);
            if (p.length) liste.push({ id: o.id, farbe: wen.length === 1 ? String(Kirigami.Theme.highlightColor) : o.farbe, punkte: p });
        }
        return liste;
    }
    readonly property string fehlerText: weitere.filter(i => fremdeFehler[i.id]).map(i => fremdeFehler[i.id]).join(" · ")

    function name(i) { return i.name || String(i.adresse).replace(/^https?:\/\//, ""); }
    function anzahl(a) { return alle.filter(o => o.art === a).length; }
    function waehle(id) {
        auswahl = auswahl === id ? "" : id;
        const o = alle.find(x => x.id === id);
        if (o && o.art !== art) art = o.art;
        if (auswahl && !spuren.length) karte.zeigePerson(o);
    }

    // ---- Weitere Installationen (nur lesen: Zustände und Verlauf) ----
    function holen(instanz, pfad, fertig) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", String(instanz.adresse).trim().replace(/\/+$/, "") + pfad);
        xhr.setRequestHeader("Authorization", "Bearer " + String(instanz.token).trim());
        xhr.timeout = 15000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            let antwort = null;
            if (xhr.status >= 200 && xhr.status < 300) { try { antwort = JSON.parse(xhr.responseText); } catch (e) { antwort = null; } }
            fertig(antwort, xhr.status);
        };
        xhr.send();
    }
    function fremdeLaden() {
        for (const i of weitere) {
            const inst = i;
            holen(inst, "/api/states", function (liste, status) {
                const fehler = Object.assign({}, seite.fremdeFehler);
                if (!liste) {
                    fehler[inst.id] = status === 401 || status === 403 ? i18n("„%1“: Zugriff verweigert", seite.name(inst)) : i18n("„%1“ nicht erreichbar", seite.name(inst));
                    seite.fremdeFehler = fehler;
                    return;
                }
                delete fehler[inst.id];
                seite.fremdeFehler = fehler;
                const z = {};
                for (const e of liste) if (Logik.relevant(e.entity_id, e, "")) z[e.entity_id] = e;
                const f = Object.assign({}, seite.fremde);
                f[inst.id] = Logik.orter(z, seite.versteckt, { id: inst.id, name: seite.name(inst) }, true);
                seite.fremde = f;
            });
        }
    }
    function verlaufLaden() {
        if (!Logik.VERLAUF_STUFEN[stufe] || !aktiv || Date.now() - verlaufStand < 3 * 60000) return;
        verlaufStand = Date.now();
        const eigene = ha.orter.map(o => o.entitaet);
        ha.ortVerlaufLaden(eigene, function (antwort, ab) {
            const v = Object.assign({}, seite.verlaeufe);
            for (const id of eigene) v[id] = Logik.ortSpur(antwort, id, ab);
            seite.verlaeufe = v;
        });
        for (const i of weitere) {
            const inst = i, liste = fremde[i.id] || [];
            if (!liste.length) continue;
            const ab = Date.now() - 6 * 3600000;
            holen(inst, "/api/history/period/" + encodeURIComponent(new Date(ab).toISOString()) + "?filter_entity_id="
                  + encodeURIComponent(liste.map(o => o.entitaet).join(",")) + "&significant_changes_only=0", function (antwort) {
                if (!antwort) return;
                const v = Object.assign({}, seite.verlaeufe);
                for (const o of liste) v[o.id] = Logik.ortSpur(antwort, o.entitaet, ab);
                seite.verlaeufe = v;
            });
        }
    }
    // erst nach dem Aktualisieren der abhängigen Bindungen (minuten) laden
    onStufeChanged: Qt.callLater(verlaufLaden)
    onAktivChanged: if (aktiv) { jetzt = Date.now(); Qt.callLater(verlaufLaden); }
    onAktiveIdChanged: { fremde = ({}); verlaeufe = ({}); verlaufStand = 0; }

    Timer {
        interval: 60000
        running: seite.aktiv && seite.weitere.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: seite.fremdeLaden()
    }
    Timer {
        interval: 60000
        running: seite.aktiv
        repeat: true
        onTriggered: { seite.jetzt = Date.now(); seite.verlaufLaden(); }
    }

    spacing: 0

    Karte {
        id: karte
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 11, seite.height * 0.5)
        personen: seite.gezeigt
        zonen: seite.ha.zonen
        spuren: seite.spuren
        satellitMoeglich: true
        auswahl: seite.auswahl
        onPersonGewaehlt: (id) => seite.waehle(id)
    }

    // Gruppen wie in Apples „Wo ist?“ und der Verlauf
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: 0
        Repeater {
            model: [{ art: "personen", text: i18n("Personen"), symbol: "group" },
                    { art: "geraete", text: i18n("Geräte"), symbol: "smartphone" },
                    { art: "objekte", text: i18n("Objekte"), symbol: "mark-location" }]
            delegate: PC3.ToolButton {
                required property var modelData
                readonly property int zahl: seite.anzahl(modelData.art)
                icon.name: modelData.symbol
                text: zahl ? modelData.text + " " + zahl : modelData.text
                checkable: true
                checked: seite.art === modelData.art
                onClicked: { seite.art = modelData.art; seite.auswahl = ""; karte.selbstBewegt = false; karte.einpassen(); }
            }
        }
        Item { Layout.fillWidth: true }
        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: "view-history"
        }
        PC3.ComboBox {
            id: stufenWahl
            Layout.leftMargin: Kirigami.Units.smallSpacing
            model: Logik.VERLAUF_STUFEN.map(m => m ? i18n("Weg: %1", Logik.verlaufStufeText(m)) : i18n("Kein Weg"))
            currentIndex: seite.stufe
            onActivated: (index) => seite.stufe = index
            PC3.ToolTip.text: i18n("Wo war jemand in den letzten 30 Minuten, 3 oder 6 Stunden?")
            PC3.ToolTip.visible: hovered
        }
    }

    PC3.Label {
        visible: seite.fehlerText !== ""
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        text: seite.fehlerText
        color: Kirigami.Theme.neutralTextColor
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    Kirigami.Separator { Layout.fillWidth: true }

    PC3.ScrollView {
        id: rollen
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

        ColumnLayout {
            width: rollen.availableWidth
            spacing: 0

            PlasmaExtras.PlaceholderMessage {
                visible: seite.gezeigt.length === 0
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                iconName: seite.art === "personen" ? "group" : seite.art === "geraete" ? "smartphone" : "mark-location"
                text: i18n("Nichts mit Standort in dieser Gruppe")
                explanation: seite.art === "personen" ? "" : i18n("Ortungsgeräte (device_tracker) mit GPS, z. B. aus der Companion-App oder von Trackern, erscheinen hier.")
            }

            Repeater {
                model: seite.gezeigt
                delegate: Item {
                    id: zeile
                    required property var modelData
                    readonly property bool gewaehlt: seite.auswahl === modelData.id
                    readonly property real km: seite.heim ? Logik.entfernung(modelData.lat, modelData.lon, seite.heim.lat, seite.heim.lon) : null
                    readonly property var spur: seite.spuren.find(s => s.id === modelData.id) || null
                    Layout.fillWidth: true
                    implicitHeight: spalte.implicitHeight + Kirigami.Units.smallSpacing * 2

                    HoverHandler { id: zeiger }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seite.waehle(zeile.modelData.id)
                    }
                    PlasmaExtras.Highlight {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        hovered: !zeile.gewaehlt
                        visible: zeiger.hovered || zeile.gewaehlt
                    }
                    ColumnLayout {
                        id: spalte
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing
                            Rectangle {
                                implicitWidth: Kirigami.Units.iconSizes.medium
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: zeile.modelData.farbe
                                opacity: zeile.modelData.zustand === "unknown" || zeile.modelData.zustand === "unavailable" ? 0.5 : 1
                                PC3.Label {
                                    anchors.centerIn: parent
                                    visible: zeile.modelData.art === "personen"
                                    text: Logik.initialen(zeile.modelData.name)
                                    color: "white"
                                    font.weight: Font.Bold
                                }
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    visible: zeile.modelData.art !== "personen"
                                    width: parent.width * 0.6
                                    height: width
                                    source: zeile.modelData.art === "geraete" ? "smartphone" : "mark-location"
                                    color: "white"
                                    isMask: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                PC3.Label {
                                    Layout.fillWidth: true
                                    text: zeile.modelData.name
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                PC3.Label {
                                    Layout.fillWidth: true
                                    text: [zeile.modelData.ort, Logik.formatSeit(zeile.modelData.seit, seite.jetzt)].filter(x => x).join(" · ")
                                    font: Kirigami.Theme.smallFont
                                    color: zeile.modelData.zustand === "home" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                PC3.Label {
                                    visible: zeile.gewaehlt && zeile.spur !== null
                                    Layout.fillWidth: true
                                    text: zeile.spur ? i18n("%1 unterwegs seit %2", Logik.formatEntfernung(Logik.streckeKm(zeile.spur.punkte)),
                                                            new Date(zeile.spur.punkte[0].t).toLocaleTimeString(Qt.locale(), Locale.ShortFormat)) : ""
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.highlightColor
                                    elide: Text.ElideRight
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                PC3.Label {
                                    Layout.alignment: Qt.AlignRight
                                    visible: zeile.km !== null && zeile.modelData.zustand !== "home"
                                    text: Logik.formatEntfernung(zeile.km)
                                    color: Kirigami.Theme.disabledTextColor
                                    font.features: { "tnum": 1 }
                                }
                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    visible: zeile.modelData.akku !== null
                                    spacing: 2
                                    Kirigami.Icon {
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                        source: Logik.akkuSymbol(zeile.modelData.akku)
                                    }
                                    PC3.Label {
                                        text: zeile.modelData.akku + " %"
                                        font: Kirigami.Theme.smallFont
                                        color: zeile.modelData.akku <= 20 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                                    }
                                }
                            }
                        }
                        // Ausgewählt: Route und Weg wie in der App
                        RowLayout {
                            visible: zeile.gewaehlt
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
                            spacing: Kirigami.Units.smallSpacing
                            PC3.Button {
                                icon.name: "map-flat"
                                text: i18n("Route")
                                onClicked: Qt.openUrlExternally("https://www.openstreetmap.org/directions?to=" + zeile.modelData.lat + "%2C" + zeile.modelData.lon)
                                PC3.ToolTip.text: i18n("Route im Browser planen (OpenStreetMap)")
                                PC3.ToolTip.visible: hovered
                            }
                            PC3.Button {
                                icon.name: "view-history"
                                text: seite.minuten ? i18n("Weg: %1", Logik.verlaufStufeText(seite.minuten)) : i18n("Weg zeigen")
                                onClicked: seite.stufe = (seite.stufe + 1) % Logik.VERLAUF_STUFEN.length
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }
}
