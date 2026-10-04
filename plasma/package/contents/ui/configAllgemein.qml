/*
 * Einstellungen: Home-Assistant-Instanzen (mehrere, eine als Favorit) und Anzeige.
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

    // alte Einzel-Verbindung (wird beim ersten Öffnen als Instanz übernommen)
    property string cfg_adresse
    property string cfg_token
    property string cfg_instanzen
    property alias cfg_zeigeHeizung: zeigeHeizung.checked
    property alias cfg_zeigePersonen: zeigePersonen.checked
    property alias cfg_updatesSuchen: updatesSuchen.checked
    property alias cfg_abfrageSekunden: abfrage.value
    property alias cfg_zeigeGruppen: zeigeGruppen.checked
    property alias cfg_zeigeRaeume: zeigeRaeume.checked
    property alias cfg_alteGruppen: alteGruppen.checked
    property alias cfg_nurSteckdosen: nurSteckdosen.checked
    property alias cfg_zeigeAnzahl: zeigeAnzahl.checked
    property alias cfg_symbolPanelhoehe: symbolPanelhoehe.checked
    property string cfg_hauptzaehler
    property alias cfg_ausgeblendet: ausgeblendet.text
    property alias cfg_zeigeStromHeute: zeigeStrom.checked
    property alias cfg_zeigeWasserHeute: zeigeWasser.checked
    property alias cfg_zeigeGasHeute: zeigeGas.checked
    property string cfg_zaehlerStrom
    property string cfg_zaehlerWasser
    property string cfg_zaehlerGas

    // ---- Instanzen: Arbeitskopie, jede Änderung landet sofort in cfg_instanzen ----
    property var liste: []
    property int gewaehlt: 0
    readonly property var aktuell: liste[gewaehlt] || ({})
    Component.onCompleted: {
        liste = Logik.instanzenLesen(cfg_instanzen, cfg_adresse, cfg_token);
        felderLaden();
    }
    function speichern(neu) {
        liste = neu;
        cfg_instanzen = JSON.stringify(neu);
    }
    function aendern(feld, wert) {
        const neu = liste.map(i => Object.assign({}, i));
        if (!neu[gewaehlt]) return;
        neu[gewaehlt][feld] = wert;
        speichern(neu);
    }
    function waehlen(i) {
        gewaehlt = i;
        getestet = false;
        felderLaden();
    }
    function felderLaden() {
        name.text = aktuell.name || "";
        adresse.text = aktuell.adresse || "";
        token.text = aktuell.token || "";
    }
    function hinzufuegen() {
        const neu = liste.map(i => Object.assign({}, i));
        neu.push({ id: Logik.neueInstanzId(neu), name: "", adresse: "", token: "", favorit: neu.length === 0 });
        speichern(neu);
        waehlen(neu.length - 1);
        adresse.forceActiveFocus();
    }
    function entfernen(i) {
        let neu = liste.filter((_, n) => n !== i).map(x => Object.assign({}, x));
        if (neu.length && !neu.some(x => x.favorit)) neu[0].favorit = true;
        speichern(neu);
        waehlen(Math.max(0, Math.min(gewaehlt, neu.length - 1)));
    }
    function alsFavorit(i) {
        speichern(liste.map((x, n) => Object.assign({}, x, { favorit: n === i })));
    }
    // Einstellungen, die je Instanz gelten; ohne eigenen Wert die bisherige gemeinsame Einstellung
    function instanzWert(feld, alt) { return aktuell[feld] !== undefined ? aktuell[feld] : alt; }

    // Zählerstände (total_increasing) einer Art aus dem Verbindungstest
    function zaehlerListe(klasse, gespeichert) {
        const liste = [{ id: "", name: i18n("Automatisch (Energie-Dashboard)") }];
        if (gespeichert && !probe.zustaende[gespeichert]) liste.push({ id: gespeichert, name: gespeichert });
        for (const id in probe.zustaende) {
            const e = probe.zustaende[id];
            if (!id.startsWith("sensor.") || !e.attributes || e.attributes.device_class !== klasse) continue;
            const einheit = e.attributes.unit_of_measurement || "";
            liste.push({ id: id, name: Logik.name(e) + " (" + e.state + (einheit ? " " + einheit : "") + ")" });
        }
        return liste;
    }

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
    // Ohne Namen den Namen der Installation aus Home Assistant übernehmen
    Connections {
        target: probe
        function onStandortNameChanged() {
            if (probe.standortName && !name.text.trim()) {
                name.text = probe.standortName;
                seite.aendern("name", probe.standortName);
            }
        }
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Home Assistant")
        }
        // Liste der Instanzen: Stern = Favorit (wird beim Start zuerst gezeigt)
        QQC2.Frame {
            Kirigami.FormData.label: i18n("Instanzen:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 22
            implicitHeight: Math.min(6, Math.max(1, seite.liste.length)) * Kirigami.Units.gridUnit * 2.6 + topPadding + bottomPadding
            padding: 1
            ListView {
                id: instanzListe
                objectName: "instanzListe"
                anchors.fill: parent
                clip: true
                model: seite.liste
                currentIndex: seite.gewaehlt
                delegate: QQC2.ItemDelegate {
                    id: instanzZeile
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    highlighted: index === seite.gewaehlt
                    onClicked: seite.waehlen(index)
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        QQC2.ToolButton {
                            icon.name: instanzZeile.modelData.favorit ? "starred-symbolic" : "non-starred-symbolic"
                            display: QQC2.AbstractButton.IconOnly
                            text: instanzZeile.modelData.favorit ? i18n("Favorit") : i18n("Als Favorit")
                            onClicked: seite.alsFavorit(instanzZeile.index)
                            QQC2.ToolTip.text: instanzZeile.modelData.favorit ? i18n("Favorit: wird beim Start zuerst gezeigt") : i18n("Als Favorit festlegen")
                            QQC2.ToolTip.visible: hovered
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: instanzZeile.modelData.name || i18n("Neue Instanz")
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: instanzZeile.modelData.adresse || i18n("noch keine Adresse")
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideMiddle
                            }
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-delete"
                            display: QQC2.AbstractButton.IconOnly
                            text: i18n("Entfernen")
                            onClicked: seite.entfernen(instanzZeile.index)
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                }
            }
        }
        QQC2.Button {
            text: i18n("Instanz hinzufügen")
            icon.name: "list-add"
            onClicked: seite.hinzufuegen()
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: seite.aktuell.name ? i18n("Instanz „%1“", seite.aktuell.name) : i18n("Instanz")
            visible: seite.liste.length > 0
        }
        QQC2.TextField {
            id: name
            visible: seite.liste.length > 0
            Kirigami.FormData.label: i18n("Name:")
            placeholderText: i18n("z. B. Zuhause, Ferienhaus (leer = aus Home Assistant)")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            onTextEdited: seite.aendern("name", text)
        }
        QQC2.TextField {
            id: adresse
            visible: seite.liste.length > 0
            Kirigami.FormData.label: i18n("Adresse:")
            placeholderText: "http://homeassistant.local:8123"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
            onTextEdited: seite.aendern("adresse", text.trim())
        }
        RowLayout {
            visible: seite.liste.length > 0
            Kirigami.FormData.label: i18n("Zugriffstoken:")
            Kirigami.PasswordField {
                id: token
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                placeholderText: i18n("Langlebiger Zugriffstoken")
                onTextEdited: seite.aendern("token", text.trim())
            }
        }
        QQC2.Label {
            visible: seite.liste.length > 0
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("In Home Assistant: unten links auf deinen Namen → Sicherheit → „Langlebige Zugriffstoken“ → Token erstellen.")
        }
        RowLayout {
            visible: seite.liste.length > 0
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
                ? i18n("Verbunden: %1 Lampen, %2 Steckdosen, %3 Räume mit Heizung, %4 Personen.",
                       probe.lichter.length, probe.schalter.length, probe.heizungen.length, probe.personen.length)
                : probe.fehler
        }
        QQC2.ComboBox {
            id: zaehlerAuswahl
            visible: seite.liste.length > 0
            Kirigami.FormData.label: i18n("Hauptzähler:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            readonly property string wert: seite.instanzWert("hauptzaehler", seite.cfg_hauptzaehler)
            // Liste erst nach einem erfolgreichen Verbindungstest; vorher nur der gespeicherte Wert
            model: {
                const liste = [{ id: "", name: i18n("Keiner (Summe der Messsteckdosen)") }];
                if (wert && !probe.leistung.some(p => p.id === wert))
                    liste.push({ id: wert, name: wert });
                for (const p of probe.leistung) liste.push({ id: p.id, name: p.name + " (" + Logik.formatWatt(p.watt) + ")" });
                return liste;
            }
            textRole: "name"
            valueRole: "id"
            currentIndex: Math.max(0, model.findIndex(e => e.id === wert))
            onActivated: seite.aendern("hauptzaehler", currentValue)
        }
        QQC2.Label {
            visible: seite.liste.length > 0
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Leistungssensor des Stromzählers dieser Instanz (z. B. Shelly 3EM, Tibber Pulse). Nach „Verbindung testen“ erscheinen alle Leistungssensoren.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Reiter")
        }
        QQC2.CheckBox {
            id: zeigeHeizung
            Kirigami.FormData.label: i18n("Anzeigen:")
            text: i18n("Heizung (Thermostate und Raumtemperaturen)")
        }
        QQC2.CheckBox {
            id: zeigePersonen
            text: i18n("Personen mit Karte")
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
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Verbrauch heute")
        }
        QQC2.CheckBox {
            id: zeigeStrom
            Kirigami.FormData.label: i18n("Anzeigen:")
            text: i18n("Strom")
        }
        QQC2.CheckBox {
            id: zeigeWasser
            text: i18n("Wasser")
        }
        QQC2.CheckBox {
            id: zeigeGas
            text: i18n("Gas")
        }
        ZaehlerWahl {
            Kirigami.FormData.label: i18n("Stromzähler:")
            enabled: zeigeStrom.checked
            klasse: "energy"
            wert: seite.instanzWert("zaehlerStrom", seite.cfg_zaehlerStrom)
            onGewaehlt: id => seite.aendern("zaehlerStrom", id)
        }
        ZaehlerWahl {
            Kirigami.FormData.label: i18n("Wasserzähler:")
            enabled: zeigeWasser.checked
            klasse: "water"
            wert: seite.instanzWert("zaehlerWasser", seite.cfg_zaehlerWasser)
            onGewaehlt: id => seite.aendern("zaehlerWasser", id)
        }
        ZaehlerWahl {
            Kirigami.FormData.label: i18n("Gaszähler:")
            enabled: zeigeGas.checked
            klasse: "gas"
            wert: seite.instanzWert("zaehlerGas", seite.cfg_zaehlerGas)
            onGewaehlt: id => seite.aendern("zaehlerGas", id)
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("„Automatisch“ nimmt die Zähler aus dem Energie-Dashboard von Home Assistant und rechnet genau wie dort. Eigene Zähler erscheinen nach „Verbindung testen“.")
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
        QQC2.CheckBox {
            id: updatesSuchen
            Kirigami.FormData.label: i18n("Updates:")
            text: i18n("Automatisch nach neuen Versionen suchen (GitHub)")
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

    component ZaehlerWahl: QQC2.ComboBox {
        id: wahl
        property string klasse
        property string wert
        signal gewaehlt(string id)
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        model: seite.zaehlerListe(klasse, wert)
        textRole: "name"
        valueRole: "id"
        currentIndex: Math.max(0, model.findIndex(e => e.id === wahl.wert))
        onActivated: wahl.gewaehlt(currentValue)
    }
}
