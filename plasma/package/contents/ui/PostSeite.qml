/*
 * Reiter "Post": Briefe und Pakete aus der Integration „Briefankündigung“ (HACS) – mit Umschlagbild,
 * „Angekommen“ (gilt auf allen Geräten), Sendungsverfolgung und „Jetzt nachsehen“.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

ColumnLayout {
    id: seite
    objectName: "postSeite"

    required property var ha

    property double jetzt: Date.now()
    Timer { interval: 60000; running: seite.visible; repeat: true; onTriggered: seite.jetzt = Date.now() }

    readonly property var post: ha.post
    readonly property var gruppen: Logik.postGruppen(post ? post.briefe : [], jetzt)
    readonly property var konto: post && post.konten.length ? post.konten[0] : null
    property bool heuteOffen: true
    property bool unterwegsOffen: true
    property bool angekommenOffen: false
    // aufgeklappter Brief (großes Bild, Sendung)
    property string offen: ""

    spacing: 0

    // Kopf: Anzahl, Stand, „Nachsehen“
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PC3.Label {
                Layout.fillWidth: true
                readonly property var offene: seite.gruppen.heute.concat(seite.gruppen.unterwegs)
                text: offene.length ? i18n("%1 unterwegs", Logik.postAnzahl(offene)) : i18n("Nichts unterwegs")
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PC3.Label {
                Layout.fillWidth: true
                text: {
                    if (!seite.post) return "";
                    const teile = [];
                    if (seite.post.stand) teile.push(i18n("Postfach gelesen %1", Logik.formatVor(seite.post.stand, seite.jetzt)));
                    if (seite.konto && seite.konto.naechster_abruf)
                        teile.push(i18n("nächstes Mal %1", new Date(seite.konto.naechster_abruf).toLocaleTimeString(Qt.locale(), "hh:mm")));
                    return teile.join(" · ");
                }
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }
        }
        PC3.ToolButton {
            icon.name: "view-refresh"
            text: i18n("Nachsehen")
            enabled: !seite.ha.postNachsehen
            onClicked: seite.ha.postAbrufen()
            PC3.ToolTip.text: i18n("Home Assistant jetzt ins Postfach schauen lassen")
            PC3.ToolTip.visible: hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            PC3.BusyIndicator {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: width
                running: seite.ha.postNachsehen
                visible: running
            }
        }
    }

    // Fehler beim Lesen des Postfachs (z. B. Passwort geändert)
    PlasmaExtras.Highlight {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        visible: !!(seite.post && seite.post.fehler)
        implicitHeight: fehlerText.implicitHeight + Kirigami.Units.smallSpacing * 2
        PC3.Label {
            id: fehlerText
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            text: seite.post ? i18n("Postfach: %1", seite.post.fehler) : ""
            wrapMode: Text.Wrap
            color: Kirigami.Theme.negativeTextColor
        }
    }

    PC3.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 0

            KlappKopf {
                Layout.fillWidth: true
                visible: seite.gruppen.heute.length > 0
                text: i18n("Heute")
                anzahl: seite.gruppen.heute.length
                offen: seite.heuteOffen
                onUmschalten: seite.heuteOffen = !seite.heuteOffen
            }
            Repeater {
                model: seite.heuteOffen ? seite.gruppen.heute : []
                delegate: BriefZeile { required property var modelData; Layout.fillWidth: true; brief: modelData }
            }

            KlappKopf {
                Layout.fillWidth: true
                visible: seite.gruppen.unterwegs.length > 0
                text: i18n("Noch unterwegs")
                anzahl: seite.gruppen.unterwegs.length
                offen: seite.unterwegsOffen
                onUmschalten: seite.unterwegsOffen = !seite.unterwegsOffen
            }
            Repeater {
                model: seite.unterwegsOffen ? seite.gruppen.unterwegs : []
                delegate: BriefZeile { required property var modelData; Layout.fillWidth: true; brief: modelData }
            }

            KlappKopf {
                Layout.fillWidth: true
                visible: seite.gruppen.angekommen.length > 0
                text: i18n("Angekommen")
                anzahl: seite.gruppen.angekommen.length
                offen: seite.angekommenOffen
                onUmschalten: seite.angekommenOffen = !seite.angekommenOffen
            }
            Repeater {
                model: seite.angekommenOffen ? seite.gruppen.angekommen : []
                delegate: BriefZeile { required property var modelData; Layout.fillWidth: true; brief: modelData }
            }

            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.gridUnit * 2
                visible: !!seite.post && seite.post.briefe.length === 0
                iconName: "mail-mark-read"
                text: i18n("Keine Post angekündigt")
                explanation: i18n("Sobald die Deutsche Post einen Brief ankündigt, erscheint er hier mit Bild des Umschlags.")
            }
        }
    }

    // Eine Zeile: Umschlag (bzw. Symbol), Absender mit Etiketten, Datum/Stand, „Angekommen“
    component BriefZeile: Item {
        id: zeile
        property var brief
        readonly property bool erledigt: Logik.postErledigt(brief)
        readonly property bool paket: brief.art === "paket"
        readonly property bool aufgeklappt: seite.offen === brief.id
        readonly property string bild: seite.ha.postBilder[brief.id] || ""

        implicitHeight: spalte.implicitHeight + Kirigami.Units.smallSpacing * 2
        Accessible.role: Accessible.ListItem
        Accessible.name: (paket ? i18n("Paket von %1", absender.text) : i18n("Brief von %1", absender.text)) + ", " + unterzeile.text

        HoverHandler { id: zeiger; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: seite.offen = zeile.aufgeklappt ? "" : zeile.brief.id }
        PlasmaExtras.Highlight {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            hovered: true
            visible: zeiger.hovered || zeile.aufgeklappt
        }

        ColumnLayout {
            id: spalte
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
            opacity: zeile.erledigt ? 0.6 : 1

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                // Umschlag als kleines Bild (Papier-Rand), sonst Symbol in Plasma-Optik
                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3.2
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                    radius: Kirigami.Units.cornerRadius
                    color: zeile.bild ? "#fbf9f3" : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                    border.width: 1
                    border.color: zeile.brief.wichtig && !zeile.erledigt ? Kirigami.Theme.negativeTextColor
                                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: zeile.bild
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: zeile.bild !== ""
                        smooth: true
                        mipmap: true
                    }
                    Glyphe {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.smallMedium
                        height: width
                        visible: zeile.bild === ""
                        name: zeile.paket ? "paket" : zeile.brief.wichtig ? "brief-wichtig" : "brief"
                        farbe: zeile.brief.wichtig && !zeile.erledigt ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        Etikett {
                            visible: zeile.brief.wichtig === true
                            text: i18n("Wichtig")
                            farbe: Kirigami.Theme.negativeTextColor
                        }
                        Etikett {
                            visible: zeile.paket
                            text: i18n("Paket")
                            farbe: Kirigami.Theme.highlightColor
                        }
                        PC3.Label {
                            id: absender
                            Layout.fillWidth: true
                            text: zeile.brief.absender || (zeile.paket ? i18n("Paket") : i18n("Absender unbekannt"))
                            textFormat: Text.PlainText
                            font.weight: zeile.erledigt ? Font.Normal : Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        // Paket-Fortschritt: unterwegs · kommt heute · zugestellt
                        Row {
                            visible: zeile.paket
                            spacing: 2
                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    width: index === 0 ? 6 : 14
                                    height: 6
                                    radius: 3
                                    color: index < Logik.paketStufe(zeile.brief) ? Kirigami.Theme.positiveTextColor
                                         : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                                }
                            }
                        }
                        PC3.Label {
                            id: unterzeile
                            Layout.fillWidth: true
                            text: {
                                const b = zeile.brief, teile = [];
                                if (zeile.paket && b.stand === "zugestellt") teile.push(i18n("zugestellt"));
                                else if (zeile.paket && b.stand === "heute") teile.push(i18n("kommt heute"));
                                else teile.push(i18n("angekündigt %1", Logik.postDatum(b.datum, seite.jetzt)));
                                if (b.erledigt && !zeile.paket) teile.push(i18n("angekommen"));
                                if (seite.post && seite.post.konten.length > 1 && b.konto_name) teile.push(b.konto_name);
                                return teile.join(" · ");
                            }
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
                        }
                    }
                }

                PC3.ToolButton {
                    visible: !(zeile.paket && zeile.brief.stand === "zugestellt")
                    icon.name: zeile.erledigt ? "edit-undo" : "dialog-ok-apply"
                    text: zeile.erledigt ? i18n("Doch nicht angekommen") : i18n("Angekommen")
                    display: PC3.AbstractButton.IconOnly
                    onClicked: seite.ha.postAbhaken(zeile.brief.id, !zeile.erledigt)
                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            // Aufgeklappt: Umschlag groß, Sendungsverfolgung
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? width * 0.55 : 0
                visible: zeile.aufgeklappt && zeile.bild !== ""
                radius: Kirigami.Units.cornerRadius
                color: "#fbf9f3"
                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: parent.visible ? zeile.bild : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: zeile.aufgeklappt
                spacing: Kirigami.Units.smallSpacing
                PC3.Label {
                    Layout.fillWidth: true
                    text: i18n("angekündigt %1", new Date(zeile.brief.datum).toLocaleString(Qt.locale(), Locale.ShortFormat))
                          + (zeile.brief.sendung ? " · " + i18n("Sendung %1", zeile.brief.sendung) : "")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.Wrap
                }
                PC3.Button {
                    visible: !!zeile.brief.sendung
                    icon.name: "find-location"
                    text: i18n("Verfolgen")
                    onClicked: Qt.openUrlExternally(Logik.dhlAdresse(zeile.brief.sendung))
                }
            }
        }
    }

    // Kleines farbiges Etikett wie „Wichtig“
    component Etikett: Rectangle {
        property alias text: etikettText.text
        property color farbe
        implicitWidth: etikettText.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: etikettText.implicitHeight + 2
        radius: height / 2
        color: Qt.rgba(farbe.r, farbe.g, farbe.b, 0.18)
        PC3.Label {
            id: etikettText
            anchors.centerIn: parent
            font: Kirigami.Theme.smallFont
            color: parent.farbe
        }
    }
}
