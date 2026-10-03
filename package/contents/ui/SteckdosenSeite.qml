/*
 * Reiter "Steckdosen": oben die Steckdosengruppen (Schaltergruppen und Geräte mit mehreren
 * Dosen), darunter – zunächst eingeklappt – die einzelnen Steckdosen nach Raum.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "logik.js" as Logik

ColumnLayout {
    id: seite
    objectName: "steckdosenSeite"

    required property var ha

    property var offen: ({})
    // Ohne Gruppen gibt es nichts zum Einklappen – dann gleich alles zeigen
    property bool einzelneOffen: false
    readonly property bool einzelneSichtbar: einzelneOffen || ha.schalterGruppen.length === 0

    function umschalten(schluessel) {
        const o = Object.assign({}, offen);
        o[schluessel] = !o[schluessel];
        offen = o;
    }

    // Einzelne nach Raum gruppiert, Räume alphabetisch, "Ohne Raum" zuletzt
    readonly property var einzelne: {
        const liste = ha.schalter.filter(s => ha.einzelneSchalter.indexOf(s.id) >= 0);
        liste.sort((a, b) => {
            if (a.raum === b.raum) return a.name.localeCompare(b.name, "de");
            if (!a.raum) return 1;
            if (!b.raum) return -1;
            return a.raum.localeCompare(b.raum, "de");
        });
        return liste;
    }
    readonly property bool mitRaeumen: einzelne.some(s => s.raum !== "")
    readonly property real summe: {
        let w = 0;
        const gesehen = {};
        for (const s of ha.schalter) {
            if (!s.leistung || gesehen[s.leistung]) continue;
            gesehen[s.leistung] = true;
            const p = Logik.wattVon(ha.zustaende[s.leistung]);
            if (!isNaN(p)) w += p;
        }
        return w;
    }

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        PC3.Label {
            Layout.fillWidth: true
            text: seite.ha.schalter.length === 0 ? i18n("Keine Steckdosen gefunden")
                : i18n("%1 von %2 an", seite.ha.schalterAn, seite.ha.schalter.length)
            color: Kirigami.Theme.disabledTextColor
        }
        PC3.Label {
            visible: seite.ha.schalter.some(s => s.leistung)
            text: i18n("zusammen %1", Logik.formatWatt(seite.summe))
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

            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: seite.ha.schalterGruppen.length > 0
                text: i18n("Gruppen & Steckdosenleisten")
            }
            Repeater {
                model: seite.ha.schalterGruppen
                delegate: SteckdosenGruppe {
                    required property var modelData
                    Layout.fillWidth: true
                    ha: seite.ha
                    daten: modelData
                    aufgeklappt: !!seite.offen[modelData.id]
                    onKlick: seite.umschalten(modelData.id)
                }
            }

            KlappKopf {
                Layout.fillWidth: true
                visible: seite.einzelne.length > 0 && seite.ha.schalterGruppen.length > 0
                text: i18n("Einzelne Steckdosen")
                anzahl: seite.einzelne.length
                offen: seite.einzelneOffen
                onUmschalten: seite.einzelneOffen = !seite.einzelneOffen
            }
            Repeater {
                model: seite.einzelneSichtbar ? seite.einzelne : []
                delegate: ColumnLayout {
                    id: einzelEintrag
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    PC3.Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        visible: seite.mitRaeumen && (einzelEintrag.index === 0 || seite.einzelne[einzelEintrag.index - 1].raum !== einzelEintrag.modelData.raum)
                        text: einzelEintrag.modelData.raum || i18n("Ohne Raum")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                    SteckdosenZeile {
                        Layout.fillWidth: true
                        ha: seite.ha
                        eintrag: einzelEintrag.modelData
                    }
                }
            }
            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }
}
