/*
 * Symbol links in jeder Zeile, schlicht wie in den Plasma-Applets (Lautstärke, Bluetooth):
 * eingeschaltet in der Farbe der Lampe, ausgeschaltet in Textfarbe.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami

Item {
    id: symbol

    property string quelle            // Name aus symbole.js
    property string farbe: ""         // "" = aus
    property bool verfuegbar: true

    // Sehr helle Lampenfarben (Warmweiß) wären auf hellem Hintergrund kaum zu sehen – dann abdunkeln
    readonly property color sichtbareFarbe: farbe === "" ? Kirigami.Theme.textColor
        : (Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Light
           && Kirigami.ColorUtils.grayForColor(farbe) > 0.7)
          // gleicher Farbton, aber kräftiger und dunkler (Warmweiß → Bernstein statt Braun)
          ? Qt.hsla(basis.hslHue < 0 ? 0.11 : basis.hslHue, Math.max(basis.hslSaturation, 0.8), 0.52, 1) : farbe
    readonly property color basis: farbe !== "" ? farbe : "transparent"

    implicitWidth: Kirigami.Units.iconSizes.medium
    implicitHeight: implicitWidth

    Glyphe {
        anchors.fill: parent
        name: symbol.quelle
        farbe: !symbol.verfuegbar ? Kirigami.Theme.disabledTextColor
             : symbol.farbe !== "" ? symbol.sichtbareFarbe
             : Kirigami.Theme.textColor
        opacity: symbol.verfuegbar ? 1 : 0.6
    }
}
