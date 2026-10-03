/*
 * Reiter "Lampen": oben die Gruppen, darunter die Räume, zuletzt Lampen ohne Raum.
 * Ein Klick auf eine Gruppe/einen Raum klappt die einzelnen Lampen darunter auf.
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
    objectName: "lampenSeite"

    required property var ha
    property bool zeigeGruppen: true
    property bool zeigeRaeume: true

    // Welche Gruppen/Räume aufgeklappt sind (bleibt beim Aktualisieren erhalten)
    property var offen: ({})
    property bool einzelneOffen: true
    function umschalten(schluessel) {
        const o = Object.assign({}, offen);
        o[schluessel] = !o[schluessel];
        offen = o;
    }

    spacing: 0

    // Kopfzeile: Zusammenfassung + "Alle aus"
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        PC3.Label {
            Layout.fillWidth: true
            text: seite.ha.lichter.length === 0 ? i18n("Keine Lampen gefunden")
                : seite.ha.lichterAn === 0 ? i18n("Alle %1 Lampen sind aus", seite.ha.lichter.length)
                : i18n("%1 von %2 Lampen an", seite.ha.lichterAn, seite.ha.lichter.length)
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
        PC3.ToolButton {
            text: i18n("Alle aus")
            icon.name: "system-shutdown"
            enabled: seite.ha.lichterAn > 0
            onClicked: seite.ha.alleLichterAus()
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

            // ---- Gruppen ----
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: seite.zeigeGruppen && seite.ha.gruppen.length > 0
                text: i18n("Gruppen")
            }
            Repeater {
                model: seite.zeigeGruppen ? seite.ha.gruppen : []
                delegate: GruppenEintrag {
                    required property var modelData
                    Layout.fillWidth: true
                    ha: seite.ha
                    titel: modelData.name
                    symbol: "lampen-gruppe"
                    steuerId: modelData.id
                    mitglieder: modelData.mitglieder
                    aufgeklappt: !!seite.offen["g:" + modelData.id]
                    onKlick: seite.umschalten("g:" + modelData.id)
                }
            }

            // ---- Räume ----
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: seite.zeigeRaeume && raumListe.count > 0
                text: i18n("Räume")
            }
            Repeater {
                id: raumListe
                model: seite.zeigeRaeume ? seite.ha.raeume.filter(r => r.lichter.length > 0) : []
                delegate: GruppenEintrag {
                    required property var modelData
                    Layout.fillWidth: true
                    ha: seite.ha
                    titel: modelData.name
                    symbol: "raum"
                    steuerId: ""
                    mitglieder: modelData.lichter
                    aufgeklappt: !!seite.offen["r:" + modelData.id]
                    onKlick: seite.umschalten("r:" + modelData.id)
                }
            }

            // ---- Lampen ohne Raum (bzw. alle, wenn Räume ausgeblendet sind) ----
            KlappKopf {
                Layout.fillWidth: true
                visible: einzelListe.anzahl > 0
                text: seite.zeigeRaeume && seite.ha.raeume.length > 0 ? i18n("Ohne Raum") : i18n("Alle Lampen")
                anzahl: einzelListe.anzahl
                offen: seite.einzelneOffen
                onUmschalten: seite.einzelneOffen = !seite.einzelneOffen
            }
            Repeater {
                id: einzelListe
                readonly property var liste: seite.zeigeRaeume && seite.ha.raeume.length > 0 ? seite.ha.ohneRaum : seite.ha.lichter
                readonly property int anzahl: liste.length
                model: seite.einzelneOffen ? liste : []
                delegate: LampenZeile {
                    required property var modelData
                    Layout.fillWidth: true
                    ha: seite.ha
                    entityId: modelData
                }
            }
            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }
}
