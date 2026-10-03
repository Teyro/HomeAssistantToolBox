/*
 * Symbol im Panel: Haus mit Glühbirne (passt sich der Panel-Farbe an), dazu die Zahl
 * der eingeschalteten Lampen.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

MouseArea {
    id: kompakt

    property int lichterAn: 0
    property bool zeigeAnzahl: true
    property bool verbunden: false
    property bool eingerichtet: false

    signal geklickt()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: geklickt()

    Glyphe {
        id: symbol
        anchors.centerIn: parent
        // Wie Plasma-Symbole: auf die nächste Standardgröße, damit es nicht verschwimmt
        width: Math.round(Math.min(parent.width, parent.height) * 0.86)
        height: width
        name: kompakt.lichterAn > 0 ? "ha-licht-an" : "ha-licht-aus"
        farbe: kompakt.containsMouse ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: kompakt.eingerichtet && !kompakt.verbunden ? 0.5 : 1
    }

    // Anzahl der eingeschalteten Lampen als kleines Abzeichen (wie bei Benachrichtigungen)
    Rectangle {
        visible: kompakt.zeigeAnzahl && kompakt.lichterAn > 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.max(height, zahl.implicitWidth + Kirigami.Units.smallSpacing)
        height: Math.max(9, Math.round(Math.min(parent.width, parent.height) * 0.4))
        radius: height / 2
        color: Kirigami.Theme.highlightColor
        border.color: Kirigami.Theme.backgroundColor
        border.width: 1

        PC3.Label {
            id: zahl
            anchors.centerIn: parent
            text: kompakt.lichterAn > 99 ? "99+" : kompakt.lichterAn
            font.pixelSize: Math.max(7, parent.height * 0.72)
            font.weight: Font.Bold
            color: Kirigami.Theme.highlightedTextColor
        }
    }
}
