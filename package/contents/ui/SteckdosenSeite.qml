/*
 * Reiter "Steckdosen": alle Schalter/Steckdosen nach Raum sortiert, mit aktuellem Verbrauch,
 * wenn die Steckdose ihn misst.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "logik.js" as Logik

ColumnLayout {
    id: seite

    required property var ha

    // Nach Raum gruppiert, Räume alphabetisch, "Ohne Raum" zuletzt
    readonly property var sortiert: {
        const liste = ha.schalter.slice();
        liste.sort((a, b) => {
            if (a.raum === b.raum) return a.name.localeCompare(b.name, "de");
            if (!a.raum) return 1;
            if (!b.raum) return -1;
            return a.raum.localeCompare(b.raum, "de");
        });
        return liste;
    }
    readonly property bool mitRaeumen: ha.schalter.some(s => s.raum !== "")

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        PC3.Label {
            Layout.fillWidth: true
            text: i18n("%1 von %2 an", seite.ha.schalterAn, seite.ha.schalter.length)
            color: Kirigami.Theme.disabledTextColor
        }
        PC3.Label {
            readonly property real summe: {
                let w = 0;
                for (const s of seite.ha.schalter) {
                    const p = s.leistung ? parseFloat((seite.ha.zustaende[s.leistung] || {}).state) : NaN;
                    if (!isNaN(p)) w += (seite.ha.zustaende[s.leistung].attributes.unit_of_measurement === "kW" ? p * 1000 : p);
                }
                return w;
            }
            visible: seite.ha.schalter.some(s => s.leistung)
            text: i18n("zusammen %1", Logik.formatWatt(summe))
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
                model: seite.sortiert
                delegate: ColumnLayout {
                    id: eintrag
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0

                    readonly property var e: seite.ha.zustaende[modelData.id]
                    readonly property bool an: Logik.istAn(e)
                    readonly property bool verfuegbar: Logik.istVerfuegbar(e)
                    readonly property var messung: modelData.leistung ? seite.ha.zustaende[modelData.leistung] : null
                    readonly property real watt: {
                        if (!messung) return NaN;
                        const w = parseFloat(messung.state);
                        return messung.attributes && messung.attributes.unit_of_measurement === "kW" ? w * 1000 : w;
                    }

                    Kirigami.ListSectionHeader {
                        Layout.fillWidth: true
                        visible: seite.mitRaeumen && (eintrag.index === 0 || seite.sortiert[eintrag.index - 1].raum !== eintrag.modelData.raum)
                        text: eintrag.modelData.raum || i18n("Ohne Raum")
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: reihe.implicitHeight + Kirigami.Units.smallSpacing * 2
                        HoverHandler { id: zeiger }
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            radius: Kirigami.Units.cornerRadius
                            color: Kirigami.Theme.highlightColor
                            opacity: zeiger.hovered ? 0.1 : 0
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
                                quelle: "steckdose"
                                farbe: eintrag.an ? Kirigami.Theme.highlightColor.toString() : ""
                                verfuegbar: eintrag.verfuegbar
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                PC3.Label {
                                    Layout.fillWidth: true
                                    text: eintrag.modelData.name
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                PC3.Label {
                                    Layout.fillWidth: true
                                    text: !eintrag.verfuegbar ? i18n("nicht erreichbar")
                                        : !isNaN(eintrag.watt) ? (eintrag.an ? i18n("an · %1", Logik.formatWatt(eintrag.watt)) : i18n("aus · %1", Logik.formatWatt(eintrag.watt)))
                                        : eintrag.an ? i18n("an") : i18n("aus")
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.disabledTextColor
                                    elide: Text.ElideRight
                                }
                            }
                            PC3.Switch {
                                checked: eintrag.an
                                enabled: eintrag.verfuegbar
                                onToggled: seite.ha.schalte(eintrag.modelData.id, checked)
                                Accessible.name: i18n("%1 schalten", eintrag.modelData.name)
                            }
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }
}
