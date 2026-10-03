/*
 * Eine Lampengruppe oder ein Raum: zusammengefasster Zustand, gemeinsamer Schalter und
 * Regler. Ein Klick klappt die einzelnen Lampen darunter auf.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

ColumnLayout {
    id: eintrag

    required property var ha
    property string titel
    property string symbol
    property string steuerId: ""       // Gruppen-Entität; leer = Raum (Mitglieder direkt schalten)
    property var mitglieder: []
    property bool aufgeklappt: false

    signal klick()

    readonly property var status: Logik.gruppenStatus(mitglieder, ha.zustaende)
    readonly property bool an: status.an > 0
    readonly property string farbe: Logik.gruppenFarbe(mitglieder, ha.zustaende)

    spacing: 0

    function schalten(ein) {
        if (steuerId !== "") ha.schalte(steuerId, ein);
        else ha.schalteMehrere(mitglieder, ein);
    }
    function dimmen(p) {
        if (steuerId !== "") ha.dimme(steuerId, p);
        else ha.dimmeMehrere(mitglieder.filter(id => Logik.dimmbar(ha.zustaende[id])), p);
    }

    Item {
        id: kopf
        Layout.fillWidth: true
        implicitHeight: kopfInhalt.implicitHeight + Kirigami.Units.smallSpacing * 2

        HoverHandler { id: zeiger }
        // Klick auf freie Fläche klappt auf (Schalter/Regler liegen darüber und fangen ihre Klicks selbst)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: eintrag.klick()
        }
        PlasmaExtras.Highlight {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            hovered: !eintrag.aufgeklappt
            visible: eintrag.aufgeklappt || zeiger.hovered
        }

        ColumnLayout {
            id: kopfInhalt
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Symbol {
                    quelle: eintrag.symbol
                    farbe: eintrag.farbe
                    verfuegbar: eintrag.status.verfuegbar > 0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PC3.Label {
                        Layout.fillWidth: true
                        text: eintrag.titel
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: {
                            const s = eintrag.status;
                            if (s.verfuegbar === 0) return i18n("nicht erreichbar");
                            if (s.an === 0) return s.gesamt === 1 ? i18n("1 Lampe · aus") : i18n("%1 Lampen · alle aus", s.gesamt);
                            const teil = s.an === s.gesamt ? i18n("alle %1 an", s.gesamt) : i18n("%1 von %2 an", s.an, s.gesamt);
                            return s.dimmbar ? teil + " · " + (regler.pressed ? Math.round(regler.value) : s.helligkeit) + " %" : teil;
                        }
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: eintrag.aufgeklappt ? "arrow-up" : "arrow-down"
                    color: Kirigami.Theme.disabledTextColor
                }

                PC3.Switch {
                    checked: eintrag.an
                    enabled: eintrag.status.verfuegbar > 0
                    onToggled: eintrag.schalten(checked)
                    Accessible.name: i18n("%1 schalten", eintrag.titel)
                }
            }

            PC3.Slider {
                id: regler
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2 + Kirigami.Units.largeSpacing
                visible: eintrag.status.dimmbar
                enabled: eintrag.status.verfuegbar > 0
                from: 0
                to: 100
                stepSize: 1
                opacity: eintrag.an ? 1 : 0.55
                Accessible.name: i18n("Helligkeit %1", eintrag.titel)
                Binding on value {
                    when: !regler.pressed
                    value: eintrag.status.helligkeit
                    restoreMode: Binding.RestoreNone
                }
                onMoved: senden.restart()
                onPressedChanged: if (!pressed) { senden.stop(); eintrag.dimmen(value); }
                Timer {
                    id: senden
                    interval: 300
                    onTriggered: eintrag.dimmen(regler.value)
                }
            }
        }
    }

    // Die einzelnen Lampen, eingerückt und mit Linie links
    Item {
        Layout.fillWidth: true
        visible: eintrag.aufgeklappt
        implicitHeight: liste.implicitHeight
        Rectangle {
            x: Kirigami.Units.largeSpacing + Kirigami.Units.iconSizes.medium / 2 + Kirigami.Units.smallSpacing
            width: 2
            radius: 1
            y: Kirigami.Units.smallSpacing
            height: parent.height - Kirigami.Units.smallSpacing * 2
            color: eintrag.farbe !== "" ? Qt.alpha(eintrag.farbe, 0.6) : Qt.alpha(Kirigami.Theme.textColor, 0.15)
        }
        ColumnLayout {
            id: liste
            width: parent.width
            spacing: 0
            Repeater {
                model: eintrag.aufgeklappt ? eintrag.mitglieder : []
                delegate: LampenZeile {
                    required property var modelData
                    Layout.fillWidth: true
                    ha: eintrag.ha
                    entityId: modelData
                    einzug: Kirigami.Units.gridUnit * 1.5
                }
            }
        }
    }
}
