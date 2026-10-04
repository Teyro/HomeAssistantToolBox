/*
 * "Was ist neu?": Änderungen der neuen (bzw. der letzten) Versionen, dazu Installieren und
 * nach der Installation Plasma neu starten.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

ColumnLayout {
    id: neu
    objectName: "neuigkeiten"

    required property var aktualisierer
    signal schliessen()

    readonly property var notizen: aktualisierer.update ? aktualisierer.update.notizen : aktualisierer.alleNotizen

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        PC3.ToolButton {
            icon.name: "go-previous"
            text: i18n("Zurück")
            onClicked: neu.schliessen()
        }
        Kirigami.Heading {
            Layout.fillWidth: true
            level: 3
            text: neu.aktualisierer.update ? i18n("Version %1 ist da", neu.aktualisierer.update.version) : i18n("Was ist neu?")
            elide: Text.ElideRight
        }
        PC3.Label {
            text: i18n("installiert: %1", neu.aktualisierer.aktuelleVersion)
            color: Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
        }
    }
    Kirigami.Separator { Layout.fillWidth: true }

    PC3.ScrollView {
        id: rollen
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff
        ColumnLayout {
            width: rollen.availableWidth
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: neu.notizen.length === 0
                text: neu.aktualisierer.status === "suche" ? i18n("Suche nach Updates …") : i18n("Keine Änderungen gefunden.")
                color: Kirigami.Theme.disabledTextColor
            }
            Repeater {
                model: neu.notizen
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.ListSectionHeader {
                        Layout.fillWidth: true
                        text: modelData.titel && modelData.titel !== "v" + modelData.version ? modelData.titel : i18n("Version %1", modelData.version)
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: modelData.text || i18n("(keine Beschreibung)")
                        textFormat: Text.MarkdownText
                        wrapMode: Text.Wrap
                        onLinkActivated: (link) => Qt.openUrlExternally(link)
                    }
                }
            }
        }
    }

    Kirigami.Separator { Layout.fillWidth: true; visible: knoepfe.visible }
    RowLayout {
        id: knoepfe
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        visible: neu.aktualisierer.update !== null
        PC3.BusyIndicator {
            visible: neu.aktualisierer.status === "laedt"
            running: visible
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            Layout.preferredWidth: Layout.preferredHeight
        }
        PC3.Label {
            Layout.fillWidth: true
            text: neu.aktualisierer.status === "laedt" ? i18n("Wird geladen und installiert …")
                : neu.aktualisierer.status === "installiert" ? i18n("Installiert – nach dem Neustart von Plasma ist die neue Version aktiv.")
                : neu.aktualisierer.status === "fehler" ? neu.aktualisierer.meldung : ""
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: neu.aktualisierer.status === "fehler" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
        }
        PC3.Button {
            visible: neu.aktualisierer.status !== "installiert"
            enabled: neu.aktualisierer.status !== "laedt" && !!neu.aktualisierer.update && neu.aktualisierer.update.url !== ""
            icon.name: "download"
            text: i18n("Installieren")
            onClicked: neu.aktualisierer.installieren()
        }
        PC3.Button {
            visible: neu.aktualisierer.status === "installiert"
            icon.name: "view-refresh"
            text: i18n("Plasma neu starten")
            onClicked: neu.aktualisierer.plasmaNeuStarten()
        }
        PC3.ToolButton {
            icon.name: "internet-web-browser-symbolic"
            display: PC3.AbstractButton.IconOnly
            text: i18n("Auf GitHub ansehen")
            onClicked: Qt.openUrlExternally(neu.aktualisierer.update.seite)
            PC3.ToolTip.text: text
            PC3.ToolTip.visible: hovered
        }
    }
}
