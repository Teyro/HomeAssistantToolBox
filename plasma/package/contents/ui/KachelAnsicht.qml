/*
 * Kachel auf dem Schreibtisch. Je Widget wählbar (Einstellungen → Schreibtisch):
 * Übersicht, eine Lampe, eine Steckdose, ein Raum, eine Heizung, Energie, Personen oder
 * eine beliebige Entität. Mehrere Kacheln = das Widget mehrmals auf den Schreibtisch ziehen.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

Item {
    id: kachel
    objectName: "kachel"

    required property var ha
    property var steuerung: null
    property string art: "uebersicht"   // uebersicht | lampe | steckdose | raum | heizung | energie | personen | entitaet
    property string ziel: ""             // Entität bzw. "raum:<id>"
    signal einrichten()

    readonly property bool klein: art === "lampe" || art === "steckdose" || art === "entitaet"
    readonly property bool gross: art === "energie" || art === "personen"

    Layout.minimumWidth: Kirigami.Units.gridUnit * (klein ? 9 : 14)
    Layout.minimumHeight: Kirigami.Units.gridUnit * (klein ? 4 : 8)
    Layout.preferredWidth: Kirigami.Units.gridUnit * (klein ? 13 : gross ? 22 : art === "heizung" ? 21 : 17)
    Layout.preferredHeight: Kirigami.Units.gridUnit * (klein ? 6 : gross ? 24 : art === "uebersicht" ? 10 : 13)

    readonly property bool bereit: ha.eingerichtet && ha.verbunden
    // für die Restzeit beim Extra heizen
    property double jetzt: Date.now()
    Timer { interval: 30000; running: kachel.art === "heizung" || kachel.art === "raum"; repeat: true; onTriggered: kachel.jetzt = Date.now() }
    readonly property bool zielFehlt: ["lampe", "steckdose", "raum", "heizung", "entitaet"].indexOf(art) >= 0 && ziel === ""

    // ---- Nicht eingerichtet / keine Verbindung / nichts gewählt ----
    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.largeSpacing * 2
        visible: !kachel.bereit || kachel.zielFehlt
        iconName: !kachel.ha.eingerichtet || kachel.zielFehlt ? "configure" : (kachel.ha.laedt ? "view-refresh" : "network-disconnect")
        text: !kachel.ha.eingerichtet ? i18n("Home Assistant einrichten")
            : !kachel.ha.verbunden ? (kachel.ha.laedt ? i18n("Verbinde …") : i18n("Keine Verbindung"))
            : i18n("Was soll die Kachel zeigen?")
        explanation: kachel.bereit ? i18n("In den Einstellungen unter „Schreibtisch“ auswählen.") : (kachel.ha.laedt ? "" : kachel.ha.fehler)
        helpfulAction: Kirigami.Action {
            text: i18n("Einrichten …")
            icon.name: "configure"
            onTriggered: kachel.einrichten()
        }
    }

    Loader {
        anchors.fill: parent
        active: kachel.bereit && !kachel.zielFehlt
        sourceComponent: ({ uebersicht: uebersicht, lampe: lampe, steckdose: steckdose, raum: raum, heizung: heizung,
                            energie: energie, personen: personen, entitaet: entitaet })[kachel.art] || uebersicht
    }

    // Kopfzeile in Kacheln: Symbol + Titel
    component Titel: RowLayout {
        property string symbol
        property string text
        property string farbe: ""
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        Glyphe {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            name: parent.symbol
            farbe: parent.farbe !== "" ? parent.farbe : Kirigami.Theme.textColor
        }
        Kirigami.Heading {
            Layout.fillWidth: true
            level: 4
            text: parent.text
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }

    // ---- Übersicht: alles Wichtige kompakt ----
    Component {
        id: uebersicht
        ColumnLayout {
            id: uebersichtSpalte
            spacing: Kirigami.Units.smallSpacing
            readonly property var heizung: {
                let heizen = 0, summe = 0, n = 0;
                for (const r of kachel.ha.heizungen) {
                    const k = Logik.raumKlima(r, kachel.ha.zustaende);
                    if (k.heizt) heizen++;
                    if (k.ist !== null) { summe += k.ist; n++; }
                }
                return { heizen: heizen, schnitt: n ? summe / n : null };
            }
            Titel { symbol: "ha-licht-an"; text: kachel.steuerung && kachel.steuerung.instanzen.length > 1 ? (kachel.steuerung.aktiv.name || i18n("Home Assistant")) : i18n("Home Assistant") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                Glyphe { Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth; name: "lampe-an"; farbe: kachel.ha.lichterAn ? "#fdbc4b" : Kirigami.Theme.disabledTextColor }
                PC3.Label { Layout.fillWidth: true; text: i18n("%1 von %2 Lampen an", kachel.ha.lichterAn, kachel.ha.lichter.length); elide: Text.ElideRight }
                PC3.ToolButton { icon.name: "system-shutdown"; text: i18n("Alle aus"); display: PC3.AbstractButton.IconOnly; enabled: kachel.ha.lichterAn > 0; onClicked: kachel.ha.alleLichterAus()
                                 PC3.ToolTip.text: text; PC3.ToolTip.visible: hovered }

                Glyphe { visible: kachel.ha.schalter.length > 0; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth; name: "steckdose"; farbe: Kirigami.Theme.textColor }
                PC3.Label { visible: kachel.ha.schalter.length > 0; Layout.fillWidth: true; Layout.columnSpan: 2; text: i18n("%1 von %2 Steckdosen an", kachel.ha.schalterAn, kachel.ha.schalter.length); elide: Text.ElideRight }

                Glyphe { visible: kachel.ha.heizungen.length > 0; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth; name: "heizung"; farbe: uebersichtSpalte.heizung.heizen ? "#f67400" : Kirigami.Theme.textColor }
                PC3.Label { visible: kachel.ha.heizungen.length > 0; Layout.fillWidth: true; Layout.columnSpan: 2; elide: Text.ElideRight
                            text: (uebersichtSpalte.heizung.heizen ? i18n("Heizung an (%1)", uebersichtSpalte.heizung.heizen) : i18n("Heizung ruht")) + (uebersichtSpalte.heizung.schnitt !== null ? " · Ø " + Logik.formatTemp(uebersichtSpalte.heizung.schnitt) : "") }

                Glyphe { visible: kachel.ha.leistung.length > 0 || kachel.ha.hauptWatt !== null; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth; name: "energie"; farbe: Kirigami.Theme.textColor }
                PC3.Label { visible: kachel.ha.leistung.length > 0 || kachel.ha.hauptWatt !== null; Layout.fillWidth: true; Layout.columnSpan: 2
                            text: i18n("Verbrauch %1", Logik.formatWatt(kachel.ha.hauptWatt !== null ? kachel.ha.hauptWatt : kachel.ha.summeWatt)) }

                Glyphe { visible: kachel.ha.personen.length > 0; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth; name: "person"; farbe: Kirigami.Theme.textColor }
                PC3.Label { visible: kachel.ha.personen.length > 0; Layout.fillWidth: true; Layout.columnSpan: 2; elide: Text.ElideRight
                            text: i18n("Zu Hause: %1", kachel.ha.personen.filter(p => p.zustand === "home").map(p => p.name).join(", ") || i18n("niemand")) }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ---- Eine Lampe oder Lichtgruppe ----
    Component {
        id: lampe
        ColumnLayout {
            spacing: 0
            LampenZeile {
                Layout.fillWidth: true
                ha: kachel.ha
                entityId: kachel.ziel
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ---- Eine Steckdose ----
    Component {
        id: steckdose
        ColumnLayout {
            spacing: 0
            SteckdosenZeile {
                Layout.fillWidth: true
                ha: kachel.ha
                eintrag: kachel.ha.schalter.find(s => s.id === kachel.ziel) || { id: kachel.ziel, name: Logik.name(kachel.ha.zustaende[kachel.ziel]), raum: "", leistung: "" }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ---- Eine Heizung (Raum oder Thermostat) ----
    Component {
        id: heizung
        ColumnLayout {
            spacing: 0
            readonly property var raumDaten: kachel.ha.heizungen.find(r => r.id === kachel.ziel || r.klima.indexOf(kachel.ziel) >= 0) || null
            HeizungRaum {
                visible: parent.raumDaten !== null
                Layout.fillWidth: true
                ha: kachel.ha
                raum: parent.raumDaten || { id: "", name: "", klima: [], temperatur: "", feuchte: "" }
                steuerung: kachel.steuerung
                jetzt: kachel.jetzt
                aufgeklappt: true
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ---- Ein Raum: Temperatur, Lampen, Steckdosen ----
    Component {
        id: raum
        ColumnLayout {
            id: raumKachel
            spacing: 0
            readonly property string raumId: kachel.ziel.replace(/^raum:/, "")
            readonly property var lampenRaum: kachel.ha.raeume.find(r => r.id === raumId) || null
            readonly property var klimaRaum: kachel.ha.heizungen.find(r => r.id === "raum:" + raumId) || null
            readonly property var klima: klimaRaum ? Logik.raumKlima(klimaRaum, kachel.ha.zustaende) : null
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                Titel {
                    symbol: "raum"
                    text: raumKachel.lampenRaum ? raumKachel.lampenRaum.name : (raumKachel.klimaRaum ? raumKachel.klimaRaum.name : raumKachel.raumId)
                }
                PC3.Label {
                    visible: raumKachel.klima !== null
                    text: raumKachel.klima ? Logik.formatTemp(raumKachel.klima.ist) + (raumKachel.klima.feuchte !== null ? " · " + Math.round(raumKachel.klima.feuchte) + " %" : "") : ""
                    color: raumKachel.klima && raumKachel.klima.heizt ? "#f67400" : Kirigami.Theme.textColor
                }
            }
            PC3.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width
                    spacing: 0
                    HeizungRaum {
                        visible: raumKachel.klimaRaum !== null && raumKachel.klimaRaum.klima.length > 0
                        Layout.fillWidth: true
                        ha: kachel.ha
                        raum: raumKachel.klimaRaum || { id: "", name: "", klima: [], temperatur: "", feuchte: "" }
                        steuerung: kachel.steuerung
                        jetzt: kachel.jetzt
                    }
                    Repeater {
                        model: raumKachel.lampenRaum ? raumKachel.lampenRaum.lichter : []
                        delegate: LampenZeile {
                            required property string modelData
                            Layout.fillWidth: true
                            ha: kachel.ha
                            entityId: modelData
                        }
                    }
                    Repeater {
                        model: raumKachel.lampenRaum ? raumKachel.lampenRaum.schalter : []
                        delegate: SteckdosenZeile {
                            required property string modelData
                            Layout.fillWidth: true
                            ha: kachel.ha
                            eintrag: kachel.ha.schalter.find(s => s.id === modelData) || { id: modelData, name: modelData, raum: "", leistung: "" }
                        }
                    }
                }
            }
        }
    }

    // ---- Energie (wie der Reiter) ----
    Component {
        id: energie
        EnergieSeite {
            ha: kachel.ha
            hauptzaehler: kachel.ha.optionen.hauptzaehler || ""
            verbrauchAnzeige: ({ strom: true, wasser: true, gas: true })
            eigeneZaehler: kachel.steuerung && kachel.steuerung.aktiv ? { strom: kachel.steuerung.aktiv.zaehlerStrom || "", wasser: kachel.steuerung.aktiv.zaehlerWasser || "", gas: kachel.steuerung.aktiv.zaehlerGas || "" } : ({})
            aktiv: true
        }
    }

    // ---- Personen mit Karte ----
    Component {
        id: personen
        PersonenSeite { ha: kachel.ha }
    }

    // ---- Beliebige Entität: großer Wert ----
    Component {
        id: entitaet
        ColumnLayout {
            id: ent
            spacing: Kirigami.Units.smallSpacing
            readonly property var e: kachel.ha.zustaende[kachel.ziel] || null
            readonly property string domain: Logik.domain(kachel.ziel)
            readonly property bool schaltbar: ["light", "switch", "group"].indexOf(domain) >= 0
            Titel {
                Layout.margins: Kirigami.Units.largeSpacing
                Layout.bottomMargin: 0
                symbol: ({ light: "lampe", switch: "steckdose", climate: "heizung", person: "person" })[ent.domain]
                        || (ent.e && ent.e.attributes.device_class === "temperature" ? "thermometer" : "energie")
                text: ent.e ? Logik.name(ent.e) : kachel.ziel
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 1
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                    text: {
                        const e = ent.e;
                        if (!e) return i18n("nicht gefunden");
                        if (ent.domain === "climate") return Logik.formatTemp(Logik.klimaStatus(e).ist);
                        if (ent.domain === "person") return Logik.ortText(e.state);
                        if (ent.schaltbar) return e.state === "on" ? i18n("an") : e.state === "off" ? i18n("aus") : e.state;
                        const z = parseFloat(e.state);
                        const einheit = e.attributes.unit_of_measurement || "";
                        if (isNaN(z)) return e.state;
                        if (einheit === "W" || einheit === "kW") return Logik.formatWatt(einheit === "kW" ? z * 1000 : z);
                        return (Math.abs(z) >= 100 ? Math.round(z) : z.toFixed(1)).toString().replace(".", ",") + (einheit ? " " + einheit : "");
                    }
                    elide: Text.ElideRight
                    font.features: { "tnum": 1 }
                }
                PC3.Switch {
                    visible: ent.schaltbar
                    checked: Logik.istAn(ent.e)
                    enabled: Logik.istVerfuegbar(ent.e)
                    onToggled: kachel.ha.schalte(kachel.ziel, checked)
                }
            }
            PC3.Label {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                text: ent.e && ent.e.last_changed ? i18n("geändert %1", Qt.formatTime(new Date(ent.e.last_changed), "hh:mm")) : ""
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
            Item { Layout.fillHeight: true }
        }
    }
}
