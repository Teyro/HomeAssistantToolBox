/*
 * Reiter "Rollläden": Rollläden, Markisen, Tore (cover.*) nach Raum – auf, stopp, zu und
 * (wenn das Gerät es kann) die Position per Schieberegler.
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
    objectName: "rolllaedenSeite"

    required property var ha

    // Für „Alle auf/zu“: keine Tore und Türen
    readonly property var ohneTore: ha.rolllaeden.filter(r => !Logik.istTor(ha.zustaende[r.id]) && Logik.istVerfuegbar(ha.zustaende[r.id]))
    readonly property int offenAnzahl: ha.rolllaeden.filter(r => { const s = Logik.rollladenStatus(ha.zustaende[r.id]); return s.verfuegbar && s.position !== 0; }).length

    function alle(aktion) { for (const r of ohneTore) ha.rollladen(r.id, aktion); }

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        PC3.Label {
            Layout.fillWidth: true
            text: i18n("%1 von %2 offen", seite.offenAnzahl, seite.ha.rolllaeden.length)
            color: Kirigami.Theme.disabledTextColor
        }
        PC3.ToolButton {
            visible: seite.ohneTore.length > 1
            icon.name: "go-up"
            text: i18n("Alle auf")
            onClicked: seite.alle("auf")
        }
        PC3.ToolButton {
            visible: seite.ohneTore.length > 1
            icon.name: "go-down"
            text: i18n("Alle zu")
            onClicked: seite.alle("zu")
        }
    }

    PC3.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 0
            Repeater {
                model: seite.ha.rolllaeden
                delegate: ColumnLayout {
                    id: eintragsBlock
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    // Raum als Zwischenüberschrift, sobald er wechselt
                    PC3.Label {
                        readonly property string vorher: eintragsBlock.index > 0 ? seite.ha.rolllaeden[eintragsBlock.index - 1].raum : null
                        visible: eintragsBlock.index === 0 || vorher !== eintragsBlock.modelData.raum
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.topMargin: eintragsBlock.index === 0 ? 0 : Kirigami.Units.smallSpacing
                        text: eintragsBlock.modelData.raum || i18n("Ohne Raum")
                        font.weight: Font.DemiBold
                        color: Kirigami.Theme.disabledTextColor
                        textFormat: Text.PlainText
                    }
                    RollladenZeile {
                        Layout.fillWidth: true
                        eintrag: eintragsBlock.modelData
                    }
                }
            }
        }
    }

    component RollladenZeile: Item {
        id: zeile
        property var eintrag
        readonly property var e: seite.ha.zustaende[eintrag.id]
        readonly property var s: Logik.rollladenStatus(e)

        implicitHeight: spalte.implicitHeight + Kirigami.Units.smallSpacing * 2

        HoverHandler { id: zeiger }
        PlasmaExtras.Highlight {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            hovered: true
            visible: zeiger.hovered
        }

        ColumnLayout {
            id: spalte
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
                    quelle: zeile.s.position === 0 ? "rollladen-zu" : "rollladen"
                    farbe: zeile.s.bewegt ? Kirigami.Theme.highlightColor.toString() : ""
                    verfuegbar: zeile.s.verfuegbar
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PC3.Label {
                        Layout.fillWidth: true
                        text: zeile.eintrag.name
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: Logik.rollladenText(zeile.e)
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }
                PC3.ToolButton {
                    icon.name: "go-up"
                    text: i18n("Öffnen")
                    display: PC3.AbstractButton.IconOnly
                    enabled: zeile.s.verfuegbar && zeile.s.kannAuf
                    onClicked: seite.ha.rollladen(zeile.eintrag.id, "auf")
                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                PC3.ToolButton {
                    visible: zeile.s.kannStopp
                    icon.name: "media-playback-stop"
                    text: i18n("Anhalten")
                    display: PC3.AbstractButton.IconOnly
                    enabled: zeile.s.verfuegbar
                    onClicked: seite.ha.rollladen(zeile.eintrag.id, "stopp")
                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                PC3.ToolButton {
                    icon.name: "go-down"
                    text: i18n("Schließen")
                    display: PC3.AbstractButton.IconOnly
                    enabled: zeile.s.verfuegbar && zeile.s.kannZu
                    onClicked: seite.ha.rollladen(zeile.eintrag.id, "zu")
                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
            // Position: links zu, rechts offen (wie in Home Assistant)
            PC3.Slider {
                id: regler
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
                visible: zeile.s.kannPosition
                enabled: zeile.s.verfuegbar
                from: 0
                to: 100
                value: zeile.s.position === null ? 0 : zeile.s.position
                // erst beim Loslassen senden, auf 5 % gerundet (Teilstriche würden die Zeile unruhig machen)
                onPressedChanged: if (!pressed) seite.ha.rollladen(zeile.eintrag.id, Math.round(value / 5) * 5)
                Accessible.name: i18n("%1: Position", zeile.eintrag.name)
            }
        }
    }
}
