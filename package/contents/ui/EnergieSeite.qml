/*
 * Reiter "Energie": aktueller Verbrauch mit Kennzahlen der letzten 24 Stunden und Verlauf,
 * Verbrauch heute (Strom, Wasser, Gas), größte Verbraucher mit Anteil am Gesamtverbrauch,
 * Zählerstände.
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
    property var verbrauchAnzeige: ({ strom: true, wasser: true, gas: true })
    property var eigeneZaehler: ({})

    property var verlauf: []
    readonly property real aktuell: ha.hauptWatt !== null ? ha.hauptWatt : ha.summeWatt
    readonly property var verbraucher: ha.leistung.filter(p => p.watt > 0).slice(0, 10)
    readonly property real maxWatt: verbraucher.length ? verbraucher[0].watt : 1
    readonly property var kennzahlen: Logik.verlaufKennzahlen(verlauf, Date.now())

    readonly property var verbrauchArten: [
        { art: "strom", titel: i18n("Strom"), symbol: "energie", farbe: "#fdbc4b" },
        { art: "wasser", titel: i18n("Wasser"), symbol: "wasser", farbe: "#3daee9" },
        { art: "gas", titel: i18n("Gas"), symbol: "gas", farbe: "#f67400" }
    ]
    readonly property bool verbrauchGewuenscht: Logik.VERBRAUCH_ARTEN.some(a => verbrauchAnzeige[a])
    readonly property var verbrauchKacheln: verbrauchArten.filter(k => verbrauchAnzeige[k.art] && ha.verbrauchHeute[k.art])

    contentWidth: availableWidth
    PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

    function verlaufHolen() {
        if (aktiv && hauptzaehler !== "" && ha) ha.verlaufLaden(hauptzaehler, 24);
    }
    function verbrauchHolen() {
        if (aktiv && verbrauchGewuenscht && ha) ha.verbrauchHeuteLaden(eigeneZaehler, verbrauchAnzeige);
    }
    onAktivChanged: { verlaufHolen(); verbrauchHolen(); }
    onVerbrauchAnzeigeChanged: verbrauchHolen()
    onEigeneZaehlerChanged: verbrauchHolen()
    Connections {
        // Nach dem Aufbau der Live-Verbindung genauer über die Langzeitstatistik nachladen
        target: seite.ha
        function onLiveChanged() { if (seite.ha.live) seite.verbrauchHolen(); }
    }
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
    Timer {
        interval: 5 * 60 * 1000
        running: seite.aktiv && seite.verbrauchGewuenscht
        repeat: true
        onTriggered: seite.verbrauchHolen()
    }

    ColumnLayout {
        width: seite.availableWidth
        spacing: Kirigami.Units.smallSpacing

        // ---- Jetzt (wie der Kopf im Akku-Applet: großes Symbol, Wert, Details) ----
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Glyphe {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                name: "energie"
                farbe: Kirigami.Theme.textColor
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Kirigami.Heading {
                    level: 1
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.9
                    text: Logik.formatWatt(seite.aktuell)
                    font.features: { "tnum": 1 }
                }
                PC3.Label {
                    text: seite.ha.hauptWatt !== null ? i18n("Verbrauch gerade") : i18n("Verbrauch der Messsteckdosen")
                    color: Kirigami.Theme.disabledTextColor
                    font: Kirigami.Theme.smallFont
                }
            }
            // Kennzahlen der letzten 24 Stunden
            GridLayout {
                visible: seite.kennzahlen !== null
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: 0
                PC3.Label { text: i18n("24 h:"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; Layout.alignment: Qt.AlignRight }
                PC3.Label {
                    text: seite.kennzahlen ? "≈ " + Logik.formatKwh(seite.kennzahlen.kwh) : ""
                    font: Kirigami.Theme.smallFont
                }
                PC3.Label { text: i18n("Durchschnitt:"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; Layout.alignment: Qt.AlignRight }
                PC3.Label {
                    text: seite.kennzahlen ? Logik.formatWatt(seite.kennzahlen.schnitt) : ""
                    font: Kirigami.Theme.smallFont
                }
                PC3.Label { text: i18n("Spitze:"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; Layout.alignment: Qt.AlignRight }
                PC3.Label {
                    text: seite.kennzahlen ? Logik.formatWatt(seite.kennzahlen.spitze.w) + " · " + Qt.formatTime(new Date(seite.kennzahlen.spitze.t), "hh:mm") : ""
                    font: Kirigami.Theme.smallFont
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


        // ---- Verbrauch heute ----
        Kirigami.ListSectionHeader {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: seite.verbrauchGewuenscht
            text: i18n("Verbrauch heute")
        }
        PC3.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            visible: seite.verbrauchGewuenscht && seite.verbrauchKacheln.length === 0
            text: i18n("Keine Zähler gefunden. In Home Assistant das Energie-Dashboard einrichten oder in den Einstellungen Zähler wählen.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
        Repeater {
            model: seite.verbrauchGewuenscht ? seite.verbrauchKacheln.length : 0
            delegate: RowLayout {
                id: tag
                required property int index
                readonly property var art: seite.verbrauchKacheln[index] || seite.verbrauchArten[0]
                readonly property var wert: seite.ha.verbrauchHeute[art.art] || null
                objectName: "verbrauch-" + art.art
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing
                Glyphe {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    name: tag.art.symbol
                    farbe: tag.art.farbe
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        PC3.Label { Layout.fillWidth: true; text: tag.art.titel; elide: Text.ElideRight }
                        PC3.Label {
                            text: tag.wert && tag.wert.gueltig ? Logik.formatMenge(tag.wert.heute, tag.wert.einheit, tag.art.art) : "–"
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        visible: !!tag.wert && tag.wert.gueltig
                        text: tag.wert ? i18n("gestern %1", Logik.formatMenge(tag.wert.gestern, tag.wert.einheit, tag.art.art)) : ""
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }
            }
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
                spacing: 0
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
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PC3.Label {
                        text: Logik.formatWatt(verbraucher.modelData.watt)
                        font.features: { "tnum": 1 }
                        horizontalAlignment: Text.AlignRight
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 3.5
                    }
                }
                // Standard-Fortschrittsbalken von Plasma
                PC3.ProgressBar {
                    id: balken
                    objectName: "balken" + verbraucher.index
                    Layout.fillWidth: true
                    from: 0
                    to: seite.maxWatt
                    value: verbraucher.modelData.watt
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
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            Repeater {
                model: seite.ha.energie.length
                delegate: PC3.Label {
                    required property int index
                    readonly property var modelData: seite.ha.energie[index] || { name: "", kwh: NaN }
                    // abwechselnd Name (links) und Wert (rechts) – je Zähler zwei Zellen
                    Layout.fillWidth: true
                    text: modelData.name
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    Layout.row: index
                    Layout.column: 0
                }
            }
            Repeater {
                model: seite.ha.energie.length
                delegate: PC3.Label {
                    required property int index
                    readonly property var modelData: seite.ha.energie[index] || { name: "", kwh: NaN }
                    text: Logik.formatKwh(modelData.kwh)
                    font.features: { "tnum": 1 }
                    Layout.alignment: Qt.AlignRight
                    Layout.row: index
                    Layout.column: 1
                }
            }
        }
        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
    }
}
