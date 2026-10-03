/*
 * Reiter "Energie": aktueller Verbrauch mit 24-Stunden-Verlauf, größte Verbraucher als
 * Balken und Zählerstände.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "logik.js" as Logik

PC3.ScrollView {
    id: seite

    required property var ha
    property string hauptzaehler: ""
    property bool aktiv: false

    property var verlauf: []
    readonly property real aktuell: ha.hauptWatt !== null ? ha.hauptWatt : ha.summeWatt
    readonly property var verbraucher: ha.leistung.filter(p => p.watt > 0).slice(0, 12)
    readonly property real maxWatt: verbraucher.length ? verbraucher[0].watt : 1

    contentWidth: availableWidth
    PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

    function verlaufHolen() {
        if (aktiv && hauptzaehler !== "") ha.verlaufLaden(hauptzaehler, 24);
    }
    onAktivChanged: verlaufHolen()
    onHauptzaehlerChanged: { verlauf = []; verlaufHolen(); }
    Connections {
        target: seite.ha
        function onVerlaufGeladen(entityId, punkte) {
            if (entityId === seite.hauptzaehler) seite.verlauf = punkte;
        }
    }
    Timer {
        interval: 5 * 60 * 1000
        running: seite.aktiv && seite.hauptzaehler !== ""
        repeat: true
        onTriggered: seite.verlaufHolen()
    }

    ColumnLayout {
        width: seite.availableWidth
        spacing: Kirigami.Units.smallSpacing

        // ---- Aktueller Verbrauch ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: 0
            PC3.Label {
                text: seite.ha.hauptWatt !== null ? i18n("Aktueller Verbrauch") : i18n("Verbrauch der Messsteckdosen")
                color: Kirigami.Theme.disabledTextColor
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Glyphe {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    name: "energie"
                    farbe: Kirigami.Theme.highlightColor
                }
                PC3.Label {
                    text: Logik.formatWatt(seite.aktuell)
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 2.4
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }

        // ---- Verlauf 24 h ----
        VerlaufDiagramm {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6
            visible: seite.hauptzaehler !== ""
            punkte: seite.verlauf
        }
        PC3.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            visible: seite.hauptzaehler === ""
            text: i18n("Tipp: In den Einstellungen einen Hauptzähler wählen, dann erscheint hier der Verlauf der letzten 24 Stunden.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        // ---- Größte Verbraucher ----
        Kirigami.ListSectionHeader {
            Layout.fillWidth: true
            visible: seite.verbraucher.length > 0
            text: i18n("Größte Verbraucher gerade")
        }
        Repeater {
            model: seite.verbraucher
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PC3.Label {
                        text: Logik.formatWatt(modelData.watt)
                        font.features: { "tnum": 1 }
                    }
                }
                // Balken: dünn, rechts abgerundet, Spur in Hintergrundton
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                    Rectangle {
                        width: Math.max(6, parent.width * modelData.watt / seite.maxWatt)
                        height: parent.height
                        radius: 3
                        color: Kirigami.Theme.highlightColor
                    }
                }
                Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
            }
        }

        // ---- Zählerstände ----
        Kirigami.ListSectionHeader {
            Layout.fillWidth: true
            visible: seite.ha.energie.length > 0
            text: i18n("Zählerstände")
        }
        Repeater {
            model: seite.ha.energie
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                PC3.Label {
                    Layout.fillWidth: true
                    text: modelData.name
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                PC3.Label {
                    text: Logik.formatKwh(modelData.kwh)
                    color: Kirigami.Theme.disabledTextColor
                    font.features: { "tnum": 1 }
                }
            }
        }
        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
    }
}
