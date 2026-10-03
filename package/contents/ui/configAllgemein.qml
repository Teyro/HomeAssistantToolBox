/*
 * Einstellungen: Verbindung (Adresse, Token, Verbindungstest) und Anzeige.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "logik.js" as Logik

KCM.SimpleKCM {
    id: seite

    property alias cfg_adresse: adresse.text
    property alias cfg_token: token.text
    property alias cfg_abfrageSekunden: abfrage.value
    property alias cfg_zeigeGruppen: zeigeGruppen.checked
    property alias cfg_zeigeRaeume: zeigeRaeume.checked
    property alias cfg_alteGruppen: alteGruppen.checked
    property alias cfg_nurSteckdosen: nurSteckdosen.checked
    property alias cfg_zeigeAnzahl: zeigeAnzahl.checked
    property alias cfg_symbolPanelhoehe: symbolPanelhoehe.checked
    property string cfg_hauptzaehler
    property alias cfg_ausgeblendet: ausgeblendet.text

    // Eigene Verbindung nur für den Test und die Auswahl des Hauptzählers
    HaVerbindung {
        id: probe
        adresse: ""
        token: ""
        abfrageSekunden: 600
    }
    property bool getestet: false
    function testen() {
        getestet = true;
        probe.adresse = adresse.text;
        probe.token = token.text;
        probe.erneutVersuchen();
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Verbindung")
        }
        QQC2.TextField {
            id: adresse
            Kirigami.FormData.label: i18n("Adresse:")
            placeholderText: "http://homeassistant.local:8123"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Zugriffstoken:")
            Kirigami.PasswordField {
                id: token
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                placeholderText: i18n("Langlebiger Zugriffstoken")
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("In Home Assistant: unten links auf deinen Namen → Sicherheit → „Langlebige Zugriffstoken“ → Token erstellen.")
        }
        RowLayout {
            QQC2.Button {
                text: i18n("Verbindung testen")
                icon.name: "network-connect"
                enabled: adresse.text !== "" && token.text !== ""
                onClicked: seite.testen()
            }
            QQC2.BusyIndicator {
                visible: probe.laedt
                running: visible
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: seite.getestet && !probe.laedt
            type: probe.verbunden ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
            text: probe.verbunden
                ? i18n("Verbunden: %1 Lampen, %2 Gruppen, %3 Steckdosen, %4 Leistungssensoren.",
                       probe.lichter.length, probe.gruppen.length, probe.schalter.length, probe.leistung.length)
                : probe.fehler
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Lampen")
        }
        QQC2.CheckBox {
            id: zeigeGruppen
            Kirigami.FormData.label: i18n("Anzeigen:")
            text: i18n("Lampengruppen")
        }
        QQC2.CheckBox {
            id: alteGruppen
            text: i18n("Auch klassische Gruppen (group.*) mit Lampen")
            enabled: zeigeGruppen.checked
        }
        QQC2.CheckBox {
            id: zeigeRaeume
            text: i18n("Räume (Bereiche aus Home Assistant)")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Steckdosen & Energie")
        }
        QQC2.CheckBox {
            id: nurSteckdosen
            Kirigami.FormData.label: i18n("Steckdosen:")
            text: i18n("Nur Schalter vom Typ „Steckdose“ zeigen")
        }
        QQC2.ComboBox {
            id: zaehlerAuswahl
            Kirigami.FormData.label: i18n("Hauptzähler:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            // Liste erst nach einem erfolgreichen Verbindungstest; vorher nur der gespeicherte Wert
            model: {
                const liste = [{ id: "", name: i18n("Keiner (Summe der Messsteckdosen)") }];
                if (seite.cfg_hauptzaehler && !probe.leistung.some(p => p.id === seite.cfg_hauptzaehler))
                    liste.push({ id: seite.cfg_hauptzaehler, name: seite.cfg_hauptzaehler });
                for (const p of probe.leistung) liste.push({ id: p.id, name: p.name + " (" + Logik.formatWatt(p.watt) + ")" });
                return liste;
            }
            textRole: "name"
            valueRole: "id"
            currentIndex: Math.max(0, model.findIndex(e => e.id === seite.cfg_hauptzaehler))
            onActivated: seite.cfg_hauptzaehler = currentValue
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Leistungssensor deines Stromzählers (z. B. Shelly 3EM, Tibber Pulse). Nach „Verbindung testen“ erscheinen alle Leistungssensoren zur Auswahl.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Sonstiges")
        }
        QQC2.CheckBox {
            id: zeigeAnzahl
            Kirigami.FormData.label: i18n("Panel:")
            text: i18n("Zahl der eingeschalteten Lampen am Symbol")
        }
        QQC2.CheckBox {
            id: symbolPanelhoehe
            text: i18n("Symbol so groß wie das Panel (statt wie im Systemabschnitt)")
        }
        QQC2.TextField {
            id: ausgeblendet
            Kirigami.FormData.label: i18n("Ausblenden:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            placeholderText: "light.flur_nachtlicht, switch.*_kindersicherung"
        }
        QQC2.SpinBox {
            id: abfrage
            Kirigami.FormData.label: i18n("Abfrage alle (Sek.):")
            from: 3
            to: 600
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Normalerweise aktualisiert sich das Widget sofort über die Live-Verbindung. Das Intervall gilt nur, falls die nicht möglich ist.")
        }
    }
}
