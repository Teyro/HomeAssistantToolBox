/*
 * Abschnittsüberschrift im Plasma-Stil, die sich auf- und zuklappen lässt
 * (z. B. "Einzelne Steckdosen · 12").
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: kopf

    property string text
    property int anzahl: -1
    property bool offen: true
    signal umschalten()

    implicitHeight: zeile.implicitHeight + Kirigami.Units.smallSpacing * 2
    Accessible.role: Accessible.Button
    Accessible.name: text

    HoverHandler { id: zeiger; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: kopf.umschalten() }
    PlasmaExtras.Highlight {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        hovered: true
        visible: zeiger.hovered
    }

    RowLayout {
        id: zeile
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: kopf.offen ? "arrow-down" : (kopf.LayoutMirroring.enabled ? "arrow-left" : "arrow-right")
            color: Kirigami.Theme.disabledTextColor
        }
        PC3.Label {
            text: kopf.text
            font.weight: Font.DemiBold
            color: Kirigami.Theme.disabledTextColor
            textFormat: Text.PlainText
        }
        PC3.Label {
            visible: kopf.anzahl >= 0
            text: kopf.anzahl
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            leftPadding: Kirigami.Units.smallSpacing
            rightPadding: Kirigami.Units.smallSpacing
            background: Rectangle {
                radius: height / 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
            }
        }
        // Trennlinie wie bei Kirigami.ListSectionHeader
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        }
    }
}
