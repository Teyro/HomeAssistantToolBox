/*
 * Eine Lampe: Symbol in Lampenfarbe, Name, Zustand, Schalter und darunter der Helligkeitsregler.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "logik.js" as Logik

Item {
    id: zeile

    required property var ha
    required property string entityId
    property int einzug: 0

    readonly property var e: ha.zustaende[entityId]
    readonly property bool an: Logik.istAn(e)
    readonly property bool verfuegbar: Logik.istVerfuegbar(e)
    readonly property bool dimmbar: Logik.dimmbar(e)
    readonly property int prozent: Logik.helligkeit(e)

    implicitHeight: inhalt.implicitHeight + Kirigami.Units.smallSpacing * 2

    HoverHandler { id: zeiger }
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing + zeile.einzug
        anchors.rightMargin: Kirigami.Units.smallSpacing
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.highlightColor
        opacity: zeiger.hovered ? 0.1 : 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }

    ColumnLayout {
        id: inhalt
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Kirigami.Units.largeSpacing + zeile.einzug
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Symbol {
                quelle: zeile.an ? "lampe-an" : "lampe"
                farbe: Logik.lampenFarbe(zeile.e)
                verfuegbar: zeile.verfuegbar
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    text: Logik.name(zeile.e)
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                PC3.Label {
                    Layout.fillWidth: true
                    text: !zeile.verfuegbar ? i18n("nicht erreichbar")
                        : !zeile.an ? i18n("aus")
                        : zeile.dimmbar ? i18n("%1 %", regler.pressed ? Math.round(regler.value) : zeile.prozent)
                        : i18n("an")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }

            PC3.Switch {
                checked: zeile.an
                enabled: zeile.verfuegbar
                onToggled: zeile.ha.schalte(zeile.entityId, checked)
                Accessible.name: i18n("%1 schalten", Logik.name(zeile.e))
            }
        }

        PC3.Slider {
            id: regler
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2 + Kirigami.Units.largeSpacing
            visible: zeile.dimmbar
            enabled: zeile.verfuegbar
            from: 0
            to: 100
            stepSize: 1
            opacity: zeile.an ? 1 : 0.55
            Accessible.name: i18n("Helligkeit %1", Logik.name(zeile.e))

            // Während des Ziehens nicht von eintreffenden Werten überschreiben lassen
            Binding on value {
                when: !regler.pressed
                value: zeile.prozent
                restoreMode: Binding.RestoreNone
            }
            // Beim Ziehen gebremst senden, beim Loslassen sofort den Endwert
            onMoved: senden.restart()
            onPressedChanged: if (!pressed) { senden.stop(); zeile.ha.dimme(zeile.entityId, value); }
            Timer {
                id: senden
                interval: 250
                onTriggered: zeile.ha.dimme(zeile.entityId, regler.value)
            }
        }
    }
}
