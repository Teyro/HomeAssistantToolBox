/*
 * Rundes Symbol links in jeder Zeile: eingeschaltet in der Farbe der Lampe hinterlegt
 * (wie die Kacheln in Home Assistant), ausgeschaltet zurückhaltend grau.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami

Rectangle {
    id: symbol

    property string quelle            // Name aus symbole.js
    property string farbe: ""         // "" = aus
    property bool verfuegbar: true

    implicitWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
    implicitHeight: implicitWidth
    radius: width / 2
    color: farbe !== "" ? Qt.alpha(farbe, 0.22) : Qt.alpha(Kirigami.Theme.textColor, 0.07)
    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

    Glyphe {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.smallMedium
        height: width
        name: symbol.quelle
        farbe: !symbol.verfuegbar ? Kirigami.Theme.disabledTextColor
             : symbol.farbe !== "" ? symbol.farbe
             : Kirigami.Theme.textColor
        opacity: symbol.verfuegbar ? 1 : 0.6
    }
}
