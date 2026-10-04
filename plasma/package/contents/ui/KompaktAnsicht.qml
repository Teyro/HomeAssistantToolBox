/*
 * Symbol im Panel: Haus mit Glühbirne (passt sich der Panel-Farbe an), dazu die Zahl
 * der eingeschalteten Lampen.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

MouseArea {
    id: kompakt

    property int lichterAn: 0
    property bool zeigeAnzahl: true
    property bool verbunden: false
    property bool eingerichtet: false
    // Größe wie die Symbole im Systemabschnitt (Standard) oder so hoch wie das Panel
    property bool panelhoehe: false
    property bool horizontal: true
    readonly property int symbolGroesse: panelhoehe
        ? Kirigami.Units.iconSizes.roundedIconSize(Math.min(width, height))
        : Math.min(Kirigami.Units.iconSizes.smallMedium, Math.min(width, height))

    // Im Panel nur so breit wie nötig (wie die Einträge im Systemabschnitt)
    Layout.minimumWidth: horizontal ? symbolGroesse + Kirigami.Units.smallSpacing * 2 : -1
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: horizontal ? -1 : symbolGroesse + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: Layout.minimumHeight

    signal geklickt()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: geklickt()

    Glyphe {
        id: symbol
        anchors.centerIn: parent
        // Wie Plasma-Symbole: auf die nächste Standardgröße, damit es nicht verschwimmt
        width: kompakt.symbolGroesse
        height: width
        name: kompakt.lichterAn > 0 ? "ha-licht-an" : "ha-licht-aus"
        farbe: kompakt.containsMouse ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: kompakt.eingerichtet && !kompakt.verbunden ? 0.5 : 1
    }

    // Anzahl der eingeschalteten Lampen als kleines Abzeichen (wie bei Benachrichtigungen)
    Rectangle {
        visible: kompakt.zeigeAnzahl && kompakt.lichterAn > 0
        // Unten rechts am Symbol, leicht überstehend – wie bei den Benachrichtigungen
        anchors.right: symbol.right
        anchors.bottom: symbol.bottom
        anchors.rightMargin: -Math.round(width / 4)
        anchors.bottomMargin: -Math.round(height / 5)
        width: Math.max(height, zahl.implicitWidth + Kirigami.Units.smallSpacing)
        height: Math.max(10, Math.round(kompakt.symbolGroesse * 0.55))
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
