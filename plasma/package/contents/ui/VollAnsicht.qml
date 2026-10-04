/*
 * Ausgeklappte Ansicht: Reiter Lampen · Steckdosen · Heizung · Energie · Personen,
 * rechts das Menü (Instanz wechseln, neu laden, Home Assistant öffnen, Einstellungen).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

PlasmaExtras.Representation {
    id: voll

    required property var ha    // HaVerbindung
    property var steuerung: null    // PlasmoidItem: Instanzen, Extra heizen
    property bool zeigeHeizung: true
    property bool zeigePersonen: true
    property bool zeigeGruppen: true
    property bool zeigeRaeume: true
    property string hauptzaehler: ""
    property var verbrauchAnzeige: ({ strom: true, wasser: true, gas: true })
    property var eigeneZaehler: ({})
    property bool offen: false

    signal einrichten()

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredWidth: Kirigami.Units.gridUnit * 30
    Layout.minimumHeight: Kirigami.Units.gridUnit * 18
    Layout.preferredHeight: Kirigami.Units.gridUnit * 32

    readonly property var instanzen: steuerung ? steuerung.instanzen : []
    readonly property var aktualisierer: steuerung ? steuerung.aktualisierer : null
    property bool zeigeNeuigkeiten: false
    readonly property string instanzName: steuerung && steuerung.aktiv ? (steuerung.aktiv.name || "") : ""

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        visible: voll.ha.eingerichtet && (voll.ha.verbunden || voll.instanzen.length > 1)
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            PC3.TabBar {
                id: reiter
                objectName: "reiter"
                Layout.fillWidth: true
                position: PC3.TabBar.Header
                Reiter { text: i18n("Lampen"); symbol: "lampe"; zahl: voll.ha.lichterAn }
                Reiter { text: i18n("Steckdosen"); symbol: "steckdose"; zahl: voll.ha.schalterAn; visible: voll.ha.schalter.length > 0 }
                Reiter { text: i18n("Heizung"); symbol: "heizung"; visible: voll.zeigeHeizung && voll.ha.heizungen.length > 0
                         zahl: voll.ha.heizungen.filter(r => Logik.raumKlima(r, voll.ha.zustaende).heizt).length }
                Reiter { text: i18n("Energie"); symbol: "energie"; visible: voll.ha.leistung.length > 0 || voll.ha.energie.length > 0 || voll.ha.hauptWatt !== null }
                Reiter { text: i18n("Personen"); symbol: "person"; visible: voll.zeigePersonen && voll.ha.personen.length > 0
                         zahl: voll.ha.personen.filter(p => p.zustand === "home").length }
            }
            // Ein Menü wie bei den Plasma-eigenen Widgets: Instanz wechseln, neu laden, …
            PC3.ToolButton {
                id: menueKnopf
                objectName: "menueKnopf"
                icon.name: "overflow-menu"
                display: PC3.AbstractButton.IconOnly
                text: i18n("Mehr")
                down: menue.opened
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered && !menue.opened
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: menue.opened ? menue.close() : menue.popup(menueKnopf, 0, menueKnopf.height)
            }
            PC3.Menu {
                id: menue
                objectName: "menue"
                PC3.Menu {
                    id: instanzMenue
                    title: i18n("Instanz wechseln")
                    enabled: voll.instanzen.length > 1
                    Instantiator {
                        model: voll.instanzen
                        delegate: PC3.MenuItem {
                            required property var modelData
                            text: modelData.name + (modelData.favorit ? " ★" : "")
                            checkable: true
                            checked: voll.steuerung && voll.steuerung.aktiveInstanzId === modelData.id
                            onTriggered: voll.steuerung.wechseln(modelData.id)
                        }
                        onObjectAdded: (index, objekt) => instanzMenue.insertItem(index, objekt)
                        onObjectRemoved: (index, objekt) => instanzMenue.removeItem(objekt)
                    }
                }
                PC3.MenuSeparator {}
                PC3.MenuItem {
                    text: i18n("Neu laden")
                    icon.name: "view-refresh"
                    onTriggered: { voll.ha.bereicheLaden(); voll.ha.erneutVersuchen(); }
                }
                PC3.MenuItem {
                    text: i18n("Home Assistant öffnen")
                    icon.name: "internet-web-browser-symbolic"
                    onTriggered: Qt.openUrlExternally(voll.ha.basis)
                }
                PC3.MenuItem {
                    text: i18n("Alle Lampen aus")
                    icon.name: "system-shutdown"
                    enabled: voll.ha.lichterAn > 0
                    onTriggered: voll.ha.alleLichterAus()
                }
                PC3.MenuSeparator {}
                PC3.MenuItem {
                    text: voll.aktualisierer && voll.aktualisierer.update ? i18n("Update auf %1 …", voll.aktualisierer.update.version) : i18n("Was ist neu?")
                    icon.name: voll.aktualisierer && voll.aktualisierer.update ? "update-none" : "documentinfo"
                    enabled: voll.aktualisierer !== null
                    onTriggered: { if (voll.aktualisierer.alleNotizen.length === 0) voll.aktualisierer.pruefen(); voll.zeigeNeuigkeiten = true; }
                }
                PC3.MenuItem {
                    text: i18n("Nach Updates suchen")
                    icon.name: "system-software-update"
                    enabled: voll.aktualisierer !== null && voll.aktualisierer.status !== "suche"
                    onTriggered: { voll.aktualisierer.pruefen(); voll.zeigeNeuigkeiten = true; }
                }
                PC3.MenuItem {
                    text: i18n("Einrichten …")
                    icon.name: "configure"
                    onTriggered: voll.einrichten()
                }
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
                readonly property string ziel: voll.instanzen.length > 1 && voll.instanzName ? voll.instanzName : voll.ha.basis.replace(/^https?:\/\//, "")
                text: voll.ha.live ? i18n("Live verbunden mit %1", ziel)
                                   : i18n("Verbunden mit %1 · Stand %2", ziel, Qt.formatTime(voll.ha.stand, "hh:mm"))
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
            visible: !voll.ha.eingerichtet && !voll.zeigeNeuigkeiten
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
            visible: voll.ha.eingerichtet && !voll.ha.verbunden && !voll.zeigeNeuigkeiten
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

        // Update verfügbar
        Kirigami.InlineMessage {
            id: updateHinweis
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Kirigami.Units.smallSpacing
            z: 1
            type: Kirigami.MessageType.Information
            showCloseButton: true
            visible: !!voll.aktualisierer && !!voll.aktualisierer.update && !voll.zeigeNeuigkeiten
            text: visible ? i18n("Version %1 ist verfügbar.", voll.aktualisierer.update.version) : ""
            actions: [
                Kirigami.Action {
                    text: i18n("Was ist neu?")
                    icon.name: "documentinfo"
                    onTriggered: voll.zeigeNeuigkeiten = true
                }
            ]
        }

        Neuigkeiten {
            anchors.fill: parent
            visible: voll.zeigeNeuigkeiten && voll.aktualisierer !== null
            aktualisierer: voll.aktualisierer
            onSchliessen: voll.zeigeNeuigkeiten = false
        }

        StackLayout {
            anchors.fill: parent
            visible: voll.ha.eingerichtet && voll.ha.verbunden && !voll.zeigeNeuigkeiten
            currentIndex: reiter.currentIndex

            LampenSeite {
                ha: voll.ha
                zeigeGruppen: voll.zeigeGruppen
                zeigeRaeume: voll.zeigeRaeume
            }
            SteckdosenSeite {
                ha: voll.ha
            }
            HeizungSeite {
                ha: voll.ha
                steuerung: voll.steuerung
            }
            EnergieSeite {
                ha: voll.ha
                hauptzaehler: voll.hauptzaehler
                verbrauchAnzeige: voll.verbrauchAnzeige
                eigeneZaehler: voll.eigeneZaehler
                aktiv: voll.offen && reiter.currentIndex === 3
            }
            PersonenSeite {
                ha: voll.ha
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
