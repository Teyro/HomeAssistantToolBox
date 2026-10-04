/*
 * Reiter "Personen": wer ist wo – Karte wie bei "Wo ist?", darunter die Liste mit Ort,
 * seit wann und Entfernung von zu Hause. Dazu, ob gerade geheizt wird.
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
    objectName: "personenSeite"

    required property var ha
    property string auswahl: ""
    property double jetzt: Date.now()

    readonly property var heim: ha.zonen.find(z => z.heim) || null
    readonly property int zuhause: ha.personen.filter(p => p.zustand === "home").length
    readonly property var heizung: {
        let heizen = 0;
        for (const r of ha.heizungen) if (Logik.raumKlima(r, ha.zustaende).heizt) heizen++;
        return { heizen: heizen, raeume: ha.heizungen.filter(r => r.klima.length).length };
    }

    Timer { interval: 60000; running: seite.visible; repeat: true; onTriggered: seite.jetzt = Date.now() }

    spacing: 0

    Karte {
        id: karte
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 11, seite.height * 0.5)
        personen: seite.ha.personen
        zonen: seite.ha.zonen
        auswahl: seite.auswahl
        onPersonGewaehlt: (id) => seite.auswahl = (seite.auswahl === id ? "" : id)
    }

    // Kurzüberblick: wer ist da, heizt es?
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        PC3.Label {
            Layout.fillWidth: true
            text: seite.ha.personen.length === 0 ? i18n("Keine Personen in Home Assistant")
                : seite.zuhause === 0 ? i18n("Niemand zu Hause")
                : seite.zuhause === seite.ha.personen.length ? i18n("Alle zu Hause")
                : i18n("%1 von %2 zu Hause", seite.zuhause, seite.ha.personen.length)
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
        Glyphe {
            visible: seite.heizung.raeume > 0
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            name: "heizung"
            farbe: seite.heizung.heizen > 0 ? "#f67400" : Kirigami.Theme.disabledTextColor
        }
        PC3.Label {
            visible: seite.heizung.raeume > 0
            text: seite.heizung.heizen === 0 ? i18n("Heizung ruht") : i18n("Heizung an (%1 von %2)", seite.heizung.heizen, seite.heizung.raeume)
            color: seite.heizung.heizen > 0 ? "#f67400" : Kirigami.Theme.disabledTextColor
        }
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
            Repeater {
                model: seite.ha.personen
                delegate: Item {
                    id: zeile
                    required property var modelData
                    readonly property real km: seite.heim ? Logik.entfernung(modelData.lat, modelData.lon, seite.heim.lat, seite.heim.lon) : null
                    Layout.fillWidth: true
                    implicitHeight: reihe.implicitHeight + Kirigami.Units.smallSpacing * 2

                    HoverHandler { id: zeiger }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { seite.auswahl = zeile.modelData.id; karte.zeigePerson(zeile.modelData); }
                    }
                    PlasmaExtras.Highlight {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        hovered: seite.auswahl !== zeile.modelData.id
                        visible: zeiger.hovered || seite.auswahl === zeile.modelData.id
                    }
                    RowLayout {
                        id: reihe
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.largeSpacing
                        Rectangle {
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: zeile.modelData.farbe || Logik.personFarbe(zeile.modelData.name)
                            opacity: zeile.modelData.zustand === "unknown" ? 0.5 : 1
                            PC3.Label {
                                anchors.centerIn: parent
                                text: Logik.initialen(zeile.modelData.name)
                                color: "white"
                                font.weight: Font.Bold
                            }
                            // grüner Punkt: zu Hause
                            Rectangle {
                                visible: zeile.modelData.zustand === "home"
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: parent.width * 0.36
                                height: width
                                radius: width / 2
                                color: Kirigami.Theme.positiveTextColor
                                border.color: Kirigami.Theme.backgroundColor
                                border.width: 2
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
                                text: [Logik.ortText(zeile.modelData.zustand), Logik.formatSeit(zeile.modelData.seit, seite.jetzt)].filter(x => x).join(" · ")
                                font: Kirigami.Theme.smallFont
                                color: zeile.modelData.zustand === "home" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                            }
                        }
                        PC3.Label {
                            visible: zeile.km !== null && zeile.modelData.zustand !== "home"
                            text: Logik.formatEntfernung(zeile.km)
                            color: Kirigami.Theme.disabledTextColor
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }
}
