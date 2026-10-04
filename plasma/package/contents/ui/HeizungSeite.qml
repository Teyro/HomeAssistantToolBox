/*
 * Reiter "Heizung": alle Räume mit Ist-Temperatur (live), Luftfeuchte und Thermostat.
 * Zieltemperatur per Regler, Modus, Profil und "Extra heizen" für eine bestimmte Zeit.
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
    objectName: "heizungSeite"

    required property var ha
    property var steuerung: null          // PlasmoidItem: Extra heizen (boosts, boostStarten, boostBeenden)
    property var offen: ({})
    property double jetzt: Date.now()

    function umschalten(schluessel) {
        const o = Object.assign({}, offen);
        o[schluessel] = !o[schluessel];
        offen = o;
    }

    readonly property var zusammenfassung: {
        let heizen = 0, summe = 0, n = 0;
        for (const r of ha.heizungen) {
            const k = Logik.raumKlima(r, ha.zustaende);
            if (k.heizt) heizen++;
            if (k.ist !== null) { summe += k.ist; n++; }
        }
        return { heizen: heizen, schnitt: n ? summe / n : null };
    }

    // Restzeit beim Extra-Heizen sekundengenau genug
    Timer { interval: 30000; running: seite.visible; repeat: true; onTriggered: seite.jetzt = Date.now() }

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        PC3.Label {
            Layout.fillWidth: true
            text: seite.ha.heizungen.length === 0 ? i18n("Keine Thermostate oder Temperatursensoren gefunden")
                : seite.zusammenfassung.heizen === 0 ? i18n("Gerade heizt kein Raum")
                : seite.zusammenfassung.heizen === 1 ? i18n("1 Raum heizt")
                : i18n("%1 Räume heizen", seite.zusammenfassung.heizen)
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
        PC3.Label {
            visible: seite.zusammenfassung.schnitt !== null
            text: i18n("Ø %1", Logik.formatTemp(seite.zusammenfassung.schnitt))
            color: Kirigami.Theme.disabledTextColor
        }
    }

    PC3.ScrollView {
        id: rollen
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

        ColumnLayout {
            width: rollen.availableWidth
            spacing: 0
            Repeater {
                model: seite.ha.heizungen
                delegate: HeizungRaum {
                    required property var modelData
                    Layout.fillWidth: true
                    ha: seite.ha
                    raum: modelData
                    steuerung: seite.steuerung
                    jetzt: seite.jetzt
                    aufgeklappt: !!seite.offen[modelData.id]
                    onKlick: seite.umschalten(modelData.id)
                }
            }
            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }
}
