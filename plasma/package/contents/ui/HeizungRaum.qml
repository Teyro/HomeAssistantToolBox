/*
 * Ein Raum im Reiter "Heizung": Ist-Temperatur groß, Zustand, Zieltemperatur-Regler.
 * Aufgeklappt: Modus, Profil und "Extra heizen" (Temperatur für 30 min … 4 h, danach zurück).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

ColumnLayout {
    id: raumEintrag

    required property var ha
    required property var raum              // { id, name, klima: [], temperatur, feuchte }
    property var steuerung: null
    property double jetzt: Date.now()
    property bool aufgeklappt: false
    signal klick()

    readonly property var klima: Logik.raumKlima(raum, ha.zustaende)
    readonly property var k: klima.thermostat           // erstes Thermostat (oder null)
    readonly property bool hatThermostat: k !== null
    readonly property var boost: {
        if (!steuerung || !hatThermostat) return null;
        for (const b of steuerung.boosts) if (raum.klima.indexOf(b.id) >= 0 && b.instanz === steuerung.aktiveInstanzId) return b;
        return null;
    }
    readonly property color heizFarbe: "#f67400"

    function zielSetzen(t) {
        const ziel = Logik.rundeZiel(t, k);
        for (const id of raum.klima) ha.setzeTemperatur(id, ziel);
    }

    spacing: 0

    Item {
        Layout.fillWidth: true
        implicitHeight: kopf.implicitHeight + Kirigami.Units.smallSpacing * 2

        HoverHandler { id: zeiger }
        MouseArea {
            anchors.fill: parent
            enabled: raumEintrag.hatThermostat
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: raumEintrag.klick()
        }
        PlasmaExtras.Highlight {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            hovered: !raumEintrag.aufgeklappt
            visible: raumEintrag.aufgeklappt || (zeiger.hovered && raumEintrag.hatThermostat)
        }

        ColumnLayout {
            id: kopf
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Symbol {
                    quelle: raumEintrag.hatThermostat ? "heizung" : "thermometer"
                    farbe: raumEintrag.klima.heizt ? raumEintrag.heizFarbe.toString() : ""
                    verfuegbar: !raumEintrag.hatThermostat || raumEintrag.k.verfuegbar
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PC3.Label {
                        Layout.fillWidth: true
                        text: raumEintrag.raum.name
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: {
                            const k = raumEintrag.klima, teile = [];
                            if (!raumEintrag.hatThermostat) teile.push(i18n("Temperatur"));
                            else if (!raumEintrag.k.verfuegbar) teile.push(i18n("nicht erreichbar"));
                            else if (k.aus) teile.push(i18n("Heizung aus"));
                            else if (k.heizt) teile.push(i18n("heizt auf %1", Logik.formatTemp(k.ziel)));
                            else if (k.ziel !== null) teile.push(i18n("Ziel %1", Logik.formatTemp(k.ziel)));
                            if (raumEintrag.hatThermostat && raumEintrag.k.preset) teile.push(Logik.modusName(raumEintrag.k.preset));
                            if (k.feuchte !== null) teile.push(i18n("%1 % Luftfeuchte", Math.round(k.feuchte)));
                            return teile.join(" · ");
                        }
                        font: Kirigami.Theme.smallFont
                        color: raumEintrag.klima.heizt ? raumEintrag.heizFarbe : Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }
                // Ist-Temperatur groß wie im Wetter-Applet
                PC3.Label {
                    text: Logik.formatTemp(raumEintrag.klima.ist)
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.45
                    font.features: { "tnum": 1 }
                }
                PC3.ToolButton {
                    visible: raumEintrag.hatThermostat
                    icon.name: raumEintrag.aufgeklappt ? "collapse" : "expand"
                    display: PC3.AbstractButton.IconOnly
                    text: raumEintrag.aufgeklappt ? i18n("Weniger") : i18n("Modus, Profil, Extra heizen")
                    onClicked: raumEintrag.klick()
                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            // Zieltemperatur: − Regler + und der Wert daneben
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing - Kirigami.Units.smallSpacing
                visible: raumEintrag.hatThermostat && raumEintrag.k.verfuegbar && raumEintrag.k.ziel !== null
                spacing: 0
                PC3.ToolButton {
                    icon.name: "value-decrease"
                    display: PC3.AbstractButton.IconOnly
                    text: i18n("Kälter")
                    onClicked: raumEintrag.zielSetzen((raumEintrag.k.ziel || 20) - raumEintrag.k.schritt)
                }
                PC3.Slider {
                    id: regler
                    Layout.fillWidth: true
                    from: raumEintrag.hatThermostat ? raumEintrag.k.min : 5
                    to: raumEintrag.hatThermostat ? raumEintrag.k.max : 30
                    stepSize: raumEintrag.hatThermostat ? raumEintrag.k.schritt : 0.5
                    snapMode: PC3.Slider.SnapAlways
                    opacity: raumEintrag.klima.aus ? 0.55 : 1
                    Accessible.name: i18n("Zieltemperatur %1", raumEintrag.raum.name)
                    Binding on value {
                        when: !regler.pressed
                        value: raumEintrag.hatThermostat && raumEintrag.k.ziel !== null ? raumEintrag.k.ziel : 20
                        restoreMode: Binding.RestoreNone
                    }
                    // Erst beim Loslassen senden – Thermostate mögen keine Befehlsflut
                    onPressedChanged: if (!pressed) raumEintrag.zielSetzen(value)
                }
                PC3.ToolButton {
                    icon.name: "value-increase"
                    display: PC3.AbstractButton.IconOnly
                    text: i18n("Wärmer")
                    onClicked: raumEintrag.zielSetzen((raumEintrag.k.ziel || 20) + raumEintrag.k.schritt)
                }
                PC3.Label {
                    Layout.minimumWidth: zielMass.width
                    horizontalAlignment: Text.AlignRight
                    text: Logik.formatTemp(regler.value)
                    font.weight: Font.DemiBold
                    TextMetrics { id: zielMass; text: Logik.formatTemp(28.5) }
                }
            }

            // Läuft "Extra heizen"?
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
                visible: raumEintrag.boost !== null
                Kirigami.Icon {
                    source: "chronometer-lap"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PC3.Label {
                    Layout.fillWidth: true
                    text: raumEintrag.boost ? i18n("Extra heizen · noch %1, danach %2",
                                                   Logik.formatDauer(Logik.boostRest(raumEintrag.boost, raumEintrag.jetzt)),
                                                   raumEintrag.boost.modus === "off" ? i18n("aus") : Logik.formatTemp(raumEintrag.boost.vorher)) : ""
                    font: Kirigami.Theme.smallFont
                    color: raumEintrag.heizFarbe
                    elide: Text.ElideRight
                }
                PC3.ToolButton {
                    text: i18n("Beenden")
                    icon.name: "media-playback-stop"
                    onClicked: raumEintrag.steuerung.boostBeenden(raumEintrag.boost)
                }
            }
        }
    }

    // ---- Aufgeklappt: Modus, Profil, Extra heizen ----
    GridLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing * 2 + Kirigami.Units.iconSizes.medium
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        visible: raumEintrag.aufgeklappt && raumEintrag.hatThermostat
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        PC3.Label { text: i18n("Modus:"); Layout.alignment: Qt.AlignRight; color: Kirigami.Theme.disabledTextColor }
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: raumEintrag.hatThermostat ? raumEintrag.k.modi : []
                delegate: PC3.ToolButton {
                    required property string modelData
                    text: Logik.modusName(modelData)
                    checkable: true
                    checked: raumEintrag.k && raumEintrag.k.modus === modelData
                    onClicked: { for (const id of raumEintrag.raum.klima) raumEintrag.ha.setzeModus(id, modelData); }
                }
            }
        }

        PC3.Label {
            visible: profil.visible
            text: i18n("Profil:")
            Layout.alignment: Qt.AlignRight
            color: Kirigami.Theme.disabledTextColor
        }
        PC3.ComboBox {
            id: profil
            visible: raumEintrag.hatThermostat && raumEintrag.k.presets.length > 0
            Layout.fillWidth: true
            model: raumEintrag.hatThermostat ? [{ wert: "none", text: i18n("Kein Profil") }].concat(raumEintrag.k.presets.map(p => ({ wert: p, text: Logik.modusName(p) }))) : []
            textRole: "text"
            valueRole: "wert"
            currentIndex: raumEintrag.hatThermostat ? Math.max(0, raumEintrag.k.presets.indexOf(raumEintrag.k.preset) + 1) : 0
            onActivated: { for (const id of raumEintrag.raum.klima) raumEintrag.ha.setzePreset(id, currentValue); }
        }

        PC3.Label { text: i18n("Extra heizen:"); Layout.alignment: Qt.AlignRight; color: Kirigami.Theme.disabledTextColor }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            PC3.SpinBox {
                id: boostTemp
                // in Zehntelgrad, damit auch 0,5er-Schritte gehen
                from: raumEintrag.hatThermostat ? Math.round(raumEintrag.k.min * 10) : 50
                to: raumEintrag.hatThermostat ? Math.round(raumEintrag.k.max * 10) : 300
                stepSize: raumEintrag.hatThermostat ? Math.round(raumEintrag.k.schritt * 10) : 5
                value: raumEintrag.hatThermostat ? Math.round(Math.min(raumEintrag.k.max, (raumEintrag.k.ziel || 20) + 2) * 10) : 220
                editable: true
                textFromValue: (v) => Logik.formatTemp(v / 10)
                valueFromText: (t) => Math.round(parseFloat(t.replace(",", ".")) * 10)
                Accessible.name: i18n("Temperatur beim Extra heizen")
            }
            PC3.ComboBox {
                id: dauer
                model: [
                    { text: i18n("30 min"), minuten: 30 }, { text: i18n("1 h"), minuten: 60 },
                    { text: i18n("2 h"), minuten: 120 }, { text: i18n("3 h"), minuten: 180 }, { text: i18n("4 h"), minuten: 240 }
                ]
                textRole: "text"
                valueRole: "minuten"
                currentIndex: 1
            }
            PC3.ToolButton {
                icon.name: "media-playback-start"
                text: i18n("Starten")
                enabled: raumEintrag.steuerung !== null
                onClicked: raumEintrag.steuerung.boostStarten(raumEintrag.raum.klima, boostTemp.value / 10, dauer.currentValue)
            }
        }
    }
}
