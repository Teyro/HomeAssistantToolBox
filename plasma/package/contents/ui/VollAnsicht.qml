/*
 * Ausgeklappte Ansicht: Reiter Lampen · Steckdosen · Energie.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

PlasmaExtras.Representation {
    id: voll

    required property var ha    // HaVerbindung
    property bool zeigeGruppen: true
    property bool zeigeRaeume: true
    property string hauptzaehler: ""
    property var verbrauchAnzeige: ({ strom: true, wasser: true, gas: true })
    property var eigeneZaehler: ({})
    property bool offen: false

    signal einrichten()

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.preferredWidth: Kirigami.Units.gridUnit * 26
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredHeight: Kirigami.Units.gridUnit * 28

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        visible: voll.ha.eingerichtet && voll.ha.verbunden
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            PC3.TabBar {
                id: reiter
                objectName: "reiter"
                Layout.fillWidth: true
                position: PC3.TabBar.Header
                Reiter { text: i18n("Lampen"); symbol: "lampe"; zahl: voll.ha.lichterAn }
                Reiter { text: i18n("Steckdosen"); symbol: "steckdose"; zahl: voll.ha.schalterAn; visible: voll.ha.schalter.length > 0 }
                Reiter { text: i18n("Energie"); symbol: "energie"; visible: voll.ha.leistung.length > 0 || voll.ha.energie.length > 0 || voll.ha.hauptWatt !== null }
            }
            // Werkzeugknöpfe wie bei den Plasma-eigenen Widgets
            PC3.ToolButton {
                icon.name: "view-refresh"
                display: PC3.AbstractButton.IconOnly
                text: i18n("Neu laden")
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: { voll.ha.bereicheLaden(); voll.ha.erneutVersuchen(); }
            }
            PC3.ToolButton {
                icon.name: "internet-web-browser-symbolic"
                display: PC3.AbstractButton.IconOnly
                text: i18n("Home Assistant öffnen")
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: Qt.openUrlExternally(voll.ha.basis)
            }
            PC3.ToolButton {
                icon.name: "configure"
                display: PC3.AbstractButton.IconOnly
                text: i18n("Einrichten …")
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: voll.einrichten()
            }
        }
    }

    // Statuszeile: Live-Verbindung und Stand
    footer: PlasmaExtras.PlasmoidHeading {
        position: PC3.ToolBar.Footer
        visible: voll.ha.eingerichtet && voll.ha.verbunden
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Rectangle {
                Layout.preferredWidth: Kirigami.Units.smallSpacing * 2
                Layout.preferredHeight: width
                Layout.leftMargin: Kirigami.Units.smallSpacing
                radius: width / 2
                color: voll.ha.live ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
            }
            PC3.Label {
                Layout.fillWidth: true
                text: voll.ha.live ? i18n("Live verbunden mit %1", voll.ha.basis.replace(/^https?:\/\//, ""))
                                   : i18n("Verbunden mit %1 · Stand %2", voll.ha.basis.replace(/^https?:\/\//, ""), Qt.formatTime(voll.ha.stand, "hh:mm"))
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideMiddle
            }
        }
    }

    contentItem: Item {
        // Nicht eingerichtet / nicht erreichbar
        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: !voll.ha.eingerichtet
            iconName: "network-connect"
            text: i18n("Mit Home Assistant verbinden")
            explanation: i18n("Adresse deiner Home-Assistant-Installation und einen langlebigen Zugriffstoken eintragen.")
            helpfulAction: Kirigami.Action {
                text: i18n("Einrichten …")
                icon.name: "configure"
                onTriggered: voll.einrichten()
            }
        }
        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: voll.ha.eingerichtet && !voll.ha.verbunden
            iconName: voll.ha.laedt ? "view-refresh" : "network-disconnect"
            text: voll.ha.laedt ? i18n("Verbinde …") : i18n("Keine Verbindung")
            explanation: voll.ha.laedt ? "" : voll.ha.fehler
            helpfulAction: voll.ha.abgelehnt ? einrichtenAktion : erneutAktion
            property Kirigami.Action einrichtenAktion: Kirigami.Action {
                text: i18n("Token ändern …")
                icon.name: "configure"
                onTriggered: voll.einrichten()
            }
            property Kirigami.Action erneutAktion: Kirigami.Action {
                text: i18n("Erneut versuchen")
                icon.name: "view-refresh"
                enabled: !voll.ha.laedt
                onTriggered: voll.ha.erneutVersuchen()
            }
        }

        Kirigami.InlineMessage {
            id: hinweis
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            z: 1
            type: Kirigami.MessageType.Error
            text: voll.ha.meldung
            visible: voll.ha.meldung !== "" && voll.ha.verbunden
        }

        StackLayout {
            anchors.fill: parent
            visible: voll.ha.eingerichtet && voll.ha.verbunden
            currentIndex: reiter.currentIndex

            LampenSeite {
                ha: voll.ha
                zeigeGruppen: voll.zeigeGruppen
                zeigeRaeume: voll.zeigeRaeume
            }
            SteckdosenSeite {
                ha: voll.ha
            }
            EnergieSeite {
                ha: voll.ha
                hauptzaehler: voll.hauptzaehler
                verbrauchAnzeige: voll.verbrauchAnzeige
                eigeneZaehler: voll.eigeneZaehler
                aktiv: voll.offen && reiter.currentIndex === 2
            }
        }
    }

    // Ein Reiter mit eigenem Symbol (eingefärbt wie der Text) und optionaler Zahl
    component Reiter: PC3.TabButton {
        id: knopf
        property string symbol
        property int zahl: 0
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Item { Layout.fillWidth: true }
            Glyphe {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                name: knopf.symbol
                farbe: Kirigami.Theme.textColor
            }
            PC3.Label {
                text: knopf.text
                elide: Text.ElideRight
            }
            PC3.Label {
                visible: knopf.zahl > 0
                text: knopf.zahl
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.highlightedTextColor
                horizontalAlignment: Text.AlignHCenter
                leftPadding: Kirigami.Units.smallSpacing
                rightPadding: Kirigami.Units.smallSpacing
                background: Rectangle {
                    radius: height / 2
                    color: Kirigami.Theme.highlightColor
                }
            }
            Item { Layout.fillWidth: true }
        }
    }
}
