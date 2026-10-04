/*
 * Kleine Karte für den Reiter "Personen": Kartenkacheln von OpenStreetMap Deutschland (tile.openstreetmap.de, im dunklen
 * Farbschema abgedunkelt), Zonen als Kreise, Personen als runde Marker.
 * Verschieben mit der Maus, Zoomen mit dem Mausrad oder den Knöpfen.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "logik.js" as Logik

Item {
    id: karte

    property var personen: []          // [{ id, name, lat, lon, zustand }]
    property var zonen: []             // [{ id, name, lat, lon, radius, heim }]
    property string auswahl: ""
    signal personGewaehlt(string id)

    // Ansicht: Mitte (Grad) und Zoom; folgt den Personen, bis man selbst verschiebt/zoomt
    property int zoom: 13
    property real mitteLat: 53.55
    property real mitteLon: 10.0
    property bool selbstBewegt: false

    readonly property bool dunkel: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    readonly property var sichtbarePersonen: personen.filter(p => p.lat !== null && p.lon !== null)
    readonly property real mitteX: Logik.kachelX(mitteLon, zoom) * 256
    readonly property real mitteY: Logik.kachelY(mitteLat, zoom) * 256

    clip: true

    function einpassen() {
        const punkte = sichtbarePersonen.slice();
        const heim = zonen.find(z => z.heim);
        if (heim) punkte.push(heim);
        if (!punkte.length || width <= 0) return;
        zoom = Logik.passenderZoom(punkte, width, height);
        const xs = punkte.map(p => Logik.kachelX(p.lon, zoom)), ys = punkte.map(p => Logik.kachelY(p.lat, zoom));
        mitteLon = Logik.lonAusX((Math.min(...xs) + Math.max(...xs)) / 2, zoom);
        mitteLat = Logik.latAusY((Math.min(...ys) + Math.max(...ys)) / 2, zoom);
    }
    function zeigePerson(p) {
        if (!p || p.lat === null) return;
        selbstBewegt = true;
        mitteLat = p.lat;
        mitteLon = p.lon;
        zoom = Math.max(zoom, 15);
    }
    function zoomen(schritt) {
        selbstBewegt = true;
        zoom = Math.max(3, Math.min(19, zoom + schritt));
    }
    function bildschirm(lat, lon) {
        return Qt.point(Logik.kachelX(lon, zoom) * 256 - mitteX + width / 2, Logik.kachelY(lat, zoom) * 256 - mitteY + height / 2);
    }

    onPersonenChanged: if (!selbstBewegt) einpassen()
    onWidthChanged: if (!selbstBewegt) einpassen()
    onHeightChanged: if (!selbstBewegt) einpassen()

    Rectangle { anchors.fill: parent; color: karte.dunkel ? "#262626" : "#f2efe9" }

    // Kacheln
    Item {
        anchors.fill: parent
    Repeater {
        model: {
            const n = Math.pow(2, karte.zoom);
            const x0 = Math.floor((karte.mitteX - karte.width / 2) / 256), x1 = Math.floor((karte.mitteX + karte.width / 2) / 256);
            const y0 = Math.max(0, Math.floor((karte.mitteY - karte.height / 2) / 256)), y1 = Math.min(n - 1, Math.floor((karte.mitteY + karte.height / 2) / 256));
            const liste = [];
            for (let y = y0; y <= y1; y++)
                for (let x = x0; x <= x1; x++)
                    liste.push({ px: x * 256 - karte.mitteX + karte.width / 2, py: y * 256 - karte.mitteY + karte.height / 2,
                                 url: "https://tile.openstreetmap.de/" + karte.zoom + "/" + (((x % n) + n) % n) + "/" + y + ".png" });
            return liste;
        }
        delegate: Image {
            required property var modelData
            x: Math.round(modelData.px)
            y: Math.round(modelData.py)
            width: 256
            height: 256
            source: modelData.url
            asynchronous: true
            cache: true
            fillMode: Image.Stretch
        }
    }
    }
    // Im dunklen Farbschema abdunkeln (ohne Shader – geht auch bei Software-Darstellung)
    Rectangle { anchors.fill: parent; visible: karte.dunkel; color: "#000000"; opacity: 0.5 }

    // Zonen (Zuhause, Arbeit …)
    Repeater {
        model: karte.zonen
        delegate: Item {
            required property var modelData
            readonly property point p: karte.bildschirm(modelData.lat, modelData.lon)
            // Meter je Pixel bei diesem Zoom und Breitengrad
            readonly property real r: Math.max(6, modelData.radius / (156543.03 * Math.cos(modelData.lat * Math.PI / 180) / Math.pow(2, karte.zoom)))
            x: p.x - r
            y: p.y - r
            width: r * 2
            height: r * 2
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(modelData.heim ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor, 0.18)
                border.color: Qt.alpha(modelData.heim ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor, 0.7)
                border.width: 1
            }
            PC3.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                text: modelData.name
                font: Kirigami.Theme.smallFont
                color: karte.dunkel ? "#dddddd" : "#333333"
                visible: karte.zoom >= 11
            }
        }
    }

    // Personen
    Repeater {
        model: karte.sichtbarePersonen
        delegate: Item {
            id: marker
            required property var modelData
            required property int index
            readonly property point p: karte.bildschirm(modelData.lat, modelData.lon)
            readonly property int d: Kirigami.Units.iconSizes.medium + 4
            // Personen am (fast) gleichen Ort nebeneinander statt übereinander
            readonly property int versatz: {
                let n = 0;
                for (let i = 0; i < index; i++) {
                    const q = karte.sichtbarePersonen[i];
                    const pq = karte.bildschirm(q.lat, q.lon);
                    if (Math.abs(pq.x - p.x) < d && Math.abs(pq.y - p.y) < d) n++;
                }
                return n;
            }
            x: p.x - d / 2 + versatz * d * 0.7
            y: p.y - d / 2
            width: d
            height: d
            z: karte.auswahl === modelData.id ? 2 : 1
            Behavior on x { NumberAnimation { duration: Kirigami.Units.longDuration } }
            Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration } }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: marker.modelData.farbe || Logik.personFarbe(marker.modelData.name)
                border.color: karte.auswahl === marker.modelData.id ? Kirigami.Theme.highlightColor : "white"
                border.width: karte.auswahl === marker.modelData.id ? 3 : 2
                PC3.Label {
                    anchors.centerIn: parent
                    text: Logik.initialen(marker.modelData.name)
                    color: "white"
                    font.weight: Font.Bold
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: karte.personGewaehlt(marker.modelData.id)
            }
            PC3.ToolTip.text: marker.modelData.name + " · " + Logik.ortText(marker.modelData.zustand)
            PC3.ToolTip.visible: maus.containsMouse
            MouseArea { id: maus; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        }
    }

    // Verschieben und Zoomen
    DragHandler {
        id: ziehen
        target: null
        property real startX: 0
        property real startY: 0
        onActiveChanged: if (active) { startX = karte.mitteX; startY = karte.mitteY; karte.selbstBewegt = true; }
        onTranslationChanged: if (active) {
            karte.mitteLon = Logik.lonAusX((startX - translation.x) / 256, karte.zoom);
            karte.mitteLat = Logik.latAusY((startY - translation.y) / 256, karte.zoom);
        }
    }
    WheelHandler {
        onWheel: (ereignis) => karte.zoomen(ereignis.angleDelta.y > 0 ? 1 : -1)
    }

    Column {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: 2
        Repeater {
            model: [{ symbol: "zoom-in", text: i18n("Vergrößern"), schritt: 1 }, { symbol: "zoom-out", text: i18n("Verkleinern"), schritt: -1 },
                    { symbol: "zoom-fit-best", text: i18n("Alle zeigen"), schritt: 0 }]
            delegate: PC3.Button {
                required property var modelData
                icon.name: modelData.symbol
                display: PC3.AbstractButton.IconOnly
                text: modelData.text
                implicitWidth: implicitHeight
                onClicked: {
                    if (modelData.schritt) karte.zoomen(modelData.schritt);
                    else { karte.selbstBewegt = false; karte.einpassen(); }
                }
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
            }
        }
    }

    // Quellenangabe (Pflicht bei OpenStreetMap)
    PC3.Label {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        text: "© <a href=\"https://www.openstreetmap.org/copyright\">OpenStreetMap-Mitwirkende</a>"
        textFormat: Text.StyledText
        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
        color: karte.dunkel ? "#cccccc" : "#444444"
        linkColor: color
        onLinkActivated: (link) => Qt.openUrlExternally(link)
        leftPadding: 4
        rightPadding: 4
        background: Rectangle { color: Qt.alpha(karte.dunkel ? "black" : "white", 0.6); radius: 2 }
    }
}
