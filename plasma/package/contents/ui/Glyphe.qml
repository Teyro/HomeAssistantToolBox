/*
 * Eigenes Symbol in beliebiger Farbe (scharf in jeder Größe und Bildschirmskalierung).
 * Das Bild liegt in einem Item: so hängt die Größe nicht vom Bild ab (keine Bindungsschleifen
 * in Layouts).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Window

import org.kde.kirigami as Kirigami

import "symbole.js" as Symbole

Item {
    id: glyphe
    property string name
    property color farbe

    implicitWidth: Kirigami.Units.iconSizes.small
    implicitHeight: implicitWidth

    Image {
        anchors.fill: parent
        source: Symbole.uri(glyphe.name, glyphe.farbe)
        sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)), Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: false
    }
}
