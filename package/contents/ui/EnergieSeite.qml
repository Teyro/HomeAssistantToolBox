/*
 * Reiter "Energie": aktueller Verbrauch mit Kennzahlen der letzten 24 Stunden und Verlauf,
 * größte Verbraucher mit Anteil am Gesamtverbrauch, Zählerstände als Kacheln.
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
    readonly property var verbraucher: ha.leistung.filter(p => p.watt > 0).slice(0, 10)
    readonly property real maxWatt: verbraucher.length ? verbraucher[0].watt : 1
    readonly property var kennzahlen: Logik.verlaufKennzahlen(verlauf, Date.now())

    contentWidth: availableWidth
    PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

    function verlaufHolen() {
        if (aktiv && hauptzaehler !== "" && ha) ha.verlaufLaden(hauptzaehler, 24);
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

        // ---- Jetzt ----
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // Symbol im Kreis wie bei den Lampen
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Kirigami.Units.iconSizes.large
                implicitHeight: implicitWidth
                radius: width / 2
                color: Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                Glyphe {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.medium
                    height: width
                    name: "energie"
                    farbe: Kirigami.Theme.highlightColor
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    text: seite.ha.hauptWatt !== null ? i18n("Verbrauch gerade") : i18n("Verbrauch der Messsteckdosen")
                    color: Kirigami.Theme.disabledTextColor
                    font: Kirigami.Theme.smallFont
                }
                PC3.Label {
                    text: Logik.formatWatt(seite.aktuell)
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
            // Kennzahlen der letzten 24 Stunden
            GridLayout {
                visible: seite.kennzahlen !== null
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: 0
                PC3.Label { text: i18n("24 h"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                PC3.Label {
                    text: seite.kennzahlen ? "≈ " + Logik.formatKwh(seite.kennzahlen.kwh) : ""
                    font: Kirigami.Theme.smallFont
                    Layout.alignment: Qt.AlignRight
                }
                PC3.Label { text: i18n("Ø"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                PC3.Label {
                    text: seite.kennzahlen ? Logik.formatWatt(seite.kennzahlen.schnitt) : ""
                    font: Kirigami.Theme.smallFont
                    Layout.alignment: Qt.AlignRight
                }
                PC3.Label { text: i18n("Spitze"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                PC3.Label {
                    text: seite.kennzahlen ? Logik.formatWatt(seite.kennzahlen.spitze.w) + " · " + Qt.formatTime(new Date(seite.kennzahlen.spitze.t), "hh:mm") : ""
                    font: Kirigami.Theme.smallFont
                    Layout.alignment: Qt.AlignRight
                }
            }
        }

        // ---- Verlauf 24 h ----
        VerlaufDiagramm {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6.5
            visible: seite.hauptzaehler !== ""
            punkte: seite.verlauf
            aktuell: seite.ha.hauptWatt
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
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: seite.verbraucher.length > 0
            text: i18n("Größte Verbraucher gerade")
        }
        Repeater {
            // Modell ist nur die Anzahl: die Zeilen bleiben bestehen und ändern nur ihre Werte.
            // (Mit der Liste als Modell würde bei jedem neuen Messwert alles neu aufgebaut.)
            model: seite.verbraucher.length
            delegate: ColumnLayout {
                id: verbraucher
                required property int index
                readonly property var modelData: seite.verbraucher[index] || { name: "", watt: 0 }
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    PC3.Label {
                        Layout.fillWidth: true
                        text: verbraucher.modelData.name
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PC3.Label {
                        // Anteil am Hauptzähler (über 100 % z. B. bei eigener PV-Erzeugung nicht sinnvoll)
                        visible: seite.aktuell > 0 && seite.ha.hauptWatt !== null && verbraucher.modelData.watt <= seite.aktuell
                        text: Math.round(verbraucher.modelData.watt / seite.aktuell * 100) + " %"
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PC3.Label {
                        text: Logik.formatWatt(verbraucher.modelData.watt)
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        horizontalAlignment: Text.AlignRight
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 3.5
                    }
                }
                // Balken: dünn, abgerundet, Spur im Hintergrundton
                Rectangle {
                    id: spur
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                    Rectangle {
                        id: balken
                        objectName: "balken" + verbraucher.index
                        width: Math.max(6, spur.width * verbraucher.modelData.watt / seite.maxWatt)
                        height: parent.height
                        radius: 3
                        color: Kirigami.Theme.highlightColor
                        // Erst nach dem Aufbau animieren, sonst wächst der Balken beim Öffnen von 0 an
                        property bool bereit: false
                        Component.onCompleted: Qt.callLater(() => bereit = true)
                        Behavior on width {
                            enabled: spur.width > 0 && balken.bereit
                            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                        }
                    }
                }
                Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
            }
        }

        // ---- Zählerstände als Kacheln ----
        Kirigami.ListSectionHeader {
            Layout.fillWidth: true
            visible: seite.ha.energie.length > 0
            text: i18n("Zählerstände")
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            Repeater {
                model: seite.ha.energie.length
                delegate: Rectangle {
                    id: kachel
                    required property int index
                    readonly property var modelData: seite.ha.energie[index] || { name: "", kwh: NaN }
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: kachelInhalt.implicitHeight + Kirigami.Units.largeSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                    ColumnLayout {
                        id: kachelInhalt
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: 0
                        PC3.Label {
                            Layout.fillWidth: true
                            text: kachel.modelData.name
                            elide: Text.ElideRight
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                            textFormat: Text.PlainText
                        }
                        PC3.Label {
                            Layout.fillWidth: true
                            text: Logik.formatKwh(kachel.modelData.kwh)
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
    }
}
