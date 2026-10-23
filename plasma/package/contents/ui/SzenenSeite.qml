/*
 * Reiter "Szenen": Szenen und Skripte aus Home Assistant – ein Klick startet sie.
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
    objectName: "szenenSeite"

    required property var ha

    property bool szenenOffen: true
    property bool skripteOffen: true
    // zuletzt gestartet: kurz ein Häkchen zeigen
    property string gestartet: ""
    // Uhrzeit für „vor 3 h“ – jede Minute neu
    property double jetzt: Date.now()
    Timer { interval: 60000; running: seite.visible; repeat: true; onTriggered: seite.jetzt = Date.now() }
    Timer { id: haekchenTimer; interval: 1800; onTriggered: seite.gestartet = "" }

    function starte(id) {
        ha.starte(id);
        gestartet = id;
        haekchenTimer.restart();
    }

    spacing: 0

    PC3.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        text: i18n("%1 Szenen · %2 Skripte", seite.ha.szenen.length, seite.ha.skripte.length)
        color: Kirigami.Theme.disabledTextColor
    }

    PC3.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 0

            KlappKopf {
                Layout.fillWidth: true
                visible: seite.ha.szenen.length > 0
                text: i18n("Szenen")
                anzahl: seite.ha.szenen.length
                offen: seite.szenenOffen
                onUmschalten: seite.szenenOffen = !seite.szenenOffen
            }
            Repeater {
                model: seite.szenenOffen ? seite.ha.szenen : []
                delegate: StartZeile {
                    required property var modelData
                    Layout.fillWidth: true
                    eintrag: modelData
                    symbolName: "szene"
                    knopfText: i18n("Aktivieren")
                    // Der Zustand einer Szene ist der Zeitpunkt, zu dem sie zuletzt aktiviert wurde
                    untertitel: {
                        const e = seite.ha.zustaende[modelData.id];
                        if (!Logik.istVerfuegbar(e)) return i18n("nicht erreichbar");
                        const vor = Logik.formatVor(Date.parse(e.state), seite.jetzt);
                        return vor ? i18n("zuletzt %1", vor) : "";
                    }
                }
            }

            KlappKopf {
                Layout.fillWidth: true
                visible: seite.ha.skripte.length > 0
                text: i18n("Skripte")
                anzahl: seite.ha.skripte.length
                offen: seite.skripteOffen
                onUmschalten: seite.skripteOffen = !seite.skripteOffen
            }
            Repeater {
                model: seite.skripteOffen ? seite.ha.skripte : []
                delegate: StartZeile {
                    required property var modelData
                    Layout.fillWidth: true
                    eintrag: modelData
                    symbolName: "skript"
                    knopfText: i18n("Starten")
                    readonly property bool laeuft: Logik.istAn(seite.ha.zustaende[modelData.id])
                    untertitel: !Logik.istVerfuegbar(seite.ha.zustaende[modelData.id]) ? i18n("nicht erreichbar")
                              : laeuft ? i18n("läuft …") : ""
                    hervorheben: laeuft
                }
            }

            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.gridUnit * 2
                visible: seite.ha.szenen.length === 0 && seite.ha.skripte.length === 0
                iconName: "media-playback-start"
                text: i18n("Keine Szenen oder Skripte")
                explanation: i18n("In Home Assistant unter Einstellungen → Automationen & Szenen anlegen.")
            }
        }
    }

    // Eine Zeile: Symbol, Name, Untertitel, Knopf (die ganze Zeile ist anklickbar)
    component StartZeile: Item {
        id: zeile
        property var eintrag
        property string symbolName
        property string knopfText
        property string untertitel
        property bool hervorheben: false
        readonly property bool verfuegbar: Logik.istVerfuegbar(seite.ha.zustaende[eintrag.id])
        readonly property bool fertig: seite.gestartet === eintrag.id

        implicitHeight: reihe.implicitHeight + Kirigami.Units.smallSpacing * 2
        Accessible.role: Accessible.Button
        Accessible.name: knopfText + ": " + eintrag.name

        HoverHandler { id: zeiger; cursorShape: zeile.verfuegbar ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: zeile.verfuegbar; onTapped: seite.starte(zeile.eintrag.id) }
        PlasmaExtras.Highlight {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            hovered: true
            visible: zeiger.hovered && zeile.verfuegbar
        }
        RowLayout {
            id: reihe
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Symbol {
                quelle: zeile.symbolName
                farbe: zeile.hervorheben || zeile.fertig ? Kirigami.Theme.highlightColor.toString() : ""
                verfuegbar: zeile.verfuegbar
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    text: zeile.eintrag.name
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: zeile.untertitel
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }
            PC3.ToolButton {
                icon.name: zeile.fertig ? "dialog-ok-apply" : "media-playback-start"
                text: zeile.knopfText
                display: PC3.AbstractButton.IconOnly
                enabled: zeile.verfuegbar
                onClicked: seite.starte(zeile.eintrag.id)
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }
}
