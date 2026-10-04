/*
 * Eine Steckdose bzw. ein Schalter: Symbol, Name, Zustand mit Verbrauch, Schalter.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

Item {
    id: zeile

    required property var ha
    required property var eintrag          // { id, name, raum, leistung }
    property int einzug: 0
    property bool zeigeRaum: false

    readonly property var e: ha.zustaende[eintrag.id]
    readonly property bool an: Logik.istAn(e)
    readonly property bool verfuegbar: Logik.istVerfuegbar(e)
    readonly property real watt: eintrag.leistung ? Logik.wattVon(ha.zustaende[eintrag.leistung]) : NaN

    implicitHeight: reihe.implicitHeight + Kirigami.Units.smallSpacing * 2

    HoverHandler { id: zeiger }
    PlasmaExtras.Highlight {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing + zeile.einzug
        anchors.rightMargin: Kirigami.Units.smallSpacing
        hovered: true
        visible: zeiger.hovered
    }

    RowLayout {
        id: reihe
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Kirigami.Units.largeSpacing + zeile.einzug
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Symbol {
            quelle: "steckdose"
            farbe: zeile.an ? Kirigami.Theme.highlightColor.toString() : ""
            verfuegbar: zeile.verfuegbar
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
                text: {
                    const teile = [];
                    if (!zeile.verfuegbar) teile.push(i18n("nicht erreichbar"));
                    else teile.push(zeile.an ? i18n("an") : i18n("aus"));
                    if (!isNaN(zeile.watt)) teile.push(Logik.formatWatt(zeile.watt));
                    if (zeile.zeigeRaum && zeile.eintrag.raum) teile.push(zeile.eintrag.raum);
                    return teile.join(" · ");
                }
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }
        }
        PC3.Switch {
            checked: zeile.an
            enabled: zeile.verfuegbar
            onToggled: zeile.ha.schalte(zeile.eintrag.id, checked)
            Accessible.name: i18n("%1 schalten", zeile.eintrag.name)
        }
    }
}
