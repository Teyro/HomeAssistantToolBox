/*
 * Eigenes Symbol in beliebiger Farbe (scharf in jeder Größe und Bildschirmskalierung).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Window

import "symbole.js" as Symbole

Image {
    id: glyphe
    property string name
    property color farbe

    source: Symbole.uri(name, farbe)
    sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: false
}
