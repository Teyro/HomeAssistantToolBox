/*
 * Eine Steckdosengruppe (Schaltergruppe aus Home Assistant oder ein Gerät mit mehreren
 * Dosen, z. B. eine Steckdosenleiste): gemeinsamer Schalter, Gesamtverbrauch, aufklappbar.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

ColumnLayout {
    id: gruppe

    required property var ha
    required property var daten            // { id, name, steuerId, mitglieder, leistung, raum, art }
    property bool aufgeklappt: false
    signal klick()

    readonly property var status: Logik.schalterGruppenStatus(daten, ha.zustaende)
    readonly property bool an: status.an > 0

    spacing: 0

    // Teilen sich mehrere Dosen einen Messsensor (typisch bei Leisten), gehört der Wert zur
    // ganzen Leiste – dann nicht bei jeder einzelnen Dose anzeigen.
    function mitglied(id) {
        const s = ha.schalter.find(x => x.id === id);
        if (!s) return { id: id, name: id, raum: "", leistung: "" };
        const geteilt = s.leistung && daten.mitglieder.filter(m => (ha.schalter.find(x => x.id === m) || {}).leistung === s.leistung).length > 1;
        return geteilt ? Object.assign({}, s, { leistung: "" }) : s;
    }

    function schalten(ein) {
        if (daten.steuerId) ha.schalte(daten.steuerId, ein);
        else ha.schalteSchalter(daten.mitglieder, ein);
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: reihe.implicitHeight + Kirigami.Units.smallSpacing * 2

        HoverHandler { id: zeiger }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: gruppe.klick()
        }
        PlasmaExtras.Highlight {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            hovered: !gruppe.aufgeklappt
            visible: gruppe.aufgeklappt || zeiger.hovered
        }

        RowLayout {
            id: reihe
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Symbol {
                quelle: "steckdosenleiste"
                farbe: gruppe.an ? Kirigami.Theme.highlightColor.toString() : ""
                verfuegbar: gruppe.status.verfuegbar > 0
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    text: gruppe.daten.name
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                PC3.Label {
                    Layout.fillWidth: true
                    text: {
                        const s = gruppe.status;
                        const teile = [];
                        if (s.verfuegbar === 0) teile.push(i18n("nicht erreichbar"));
                        else if (s.an === 0) teile.push(i18n("%1 Dosen · alle aus", s.gesamt));
                        else if (s.an === s.gesamt) teile.push(i18n("alle %1 an", s.gesamt));
                        else teile.push(i18n("%1 von %2 an", s.an, s.gesamt));
                        if (!isNaN(s.watt)) teile.push(Logik.formatWatt(s.watt));
                        if (gruppe.daten.raum) teile.push(gruppe.daten.raum);
                        return teile.join(" · ");
                    }
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: gruppe.aufgeklappt ? "arrow-up" : "arrow-down"
                color: Kirigami.Theme.disabledTextColor
            }
            PC3.Switch {
                checked: gruppe.an
                enabled: gruppe.status.verfuegbar > 0
                onToggled: gruppe.schalten(checked)
                Accessible.name: i18n("%1 schalten", gruppe.daten.name)
            }
        }
    }

    // Die einzelnen Dosen, eingerückt mit Linie links
    Item {
        Layout.fillWidth: true
        visible: gruppe.aufgeklappt
        implicitHeight: liste.implicitHeight
        Rectangle {
            x: Kirigami.Units.largeSpacing + Kirigami.Units.iconSizes.medium / 2 + Kirigami.Units.smallSpacing
            width: 2
            radius: 1
            y: Kirigami.Units.smallSpacing
            height: parent.height - Kirigami.Units.smallSpacing * 2
            color: gruppe.an ? Qt.alpha(Kirigami.Theme.highlightColor, 0.6) : Qt.alpha(Kirigami.Theme.textColor, 0.15)
        }
        ColumnLayout {
            id: liste
            width: parent.width
            spacing: 0
            Repeater {
                model: gruppe.aufgeklappt ? gruppe.daten.mitglieder : []
                delegate: SteckdosenZeile {
                    required property var modelData
                    Layout.fillWidth: true
                    ha: gruppe.ha
                    eintrag: gruppe.mitglied(modelData)
                    einzug: Kirigami.Units.gridUnit * 1.5
                }
            }
        }
    }
}
