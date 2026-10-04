/*
 * Einstellungen für das Widget auf dem Schreibtisch: was die Kachel zeigt.
 * Für mehrere Kacheln das Widget einfach mehrmals auf den Schreibtisch ziehen.
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

    property string cfg_darstellung
    property string cfg_kachelEntitaet
    property string cfg_kachelInstanz
    property string cfg_instanzen
    property string cfg_adresse
    property string cfg_token

    readonly property var instanzen: Logik.instanzenLesen(cfg_instanzen, cfg_adresse, cfg_token)
    readonly property var instanz: instanzen.find(i => i.id === cfg_kachelInstanz) || Logik.favorit(instanzen) || ({})

    readonly property var arten: [
        { wert: "uebersicht", text: i18n("Übersicht (alles kurz)"), ziel: false },
        { wert: "lampe", text: i18n("Eine Lampe oder Lichtgruppe"), ziel: true },
        { wert: "steckdose", text: i18n("Eine Steckdose"), ziel: true },
        { wert: "raum", text: i18n("Ein Raum (Temperatur, Lampen, Steckdosen)"), ziel: true },
        { wert: "heizung", text: i18n("Eine Heizung"), ziel: true },
        { wert: "energie", text: i18n("Energie (Verlauf, Verbrauch heute)"), ziel: false },
        { wert: "personen", text: i18n("Personen mit Karte"), ziel: false },
        { wert: "entitaet", text: i18n("Beliebige Entität (großer Wert)"), ziel: true },
        { wert: "komplett", text: i18n("Komplett (alle Reiter)"), ziel: false }
    ]
    readonly property var art: arten.find(a => a.wert === cfg_darstellung) || arten[0]

    // Verbindung nur, um die Auswahl zu füllen
    HaVerbindung {
        id: probe
        adresse: seite.instanz.adresse || ""
        token: seite.instanz.token || ""
        abfrageSekunden: 600
    }

    readonly property var ziele: {
        const z = probe.zustaende, liste = [];
        const name = (id) => Logik.name(z[id]) || id;
        switch (cfg_darstellung) {
        case "lampe":
            for (const g of probe.gruppen) liste.push({ id: g.id, name: g.name + " " + i18n("(Gruppe)") });
            for (const id of probe.lichter) liste.push({ id: id, name: name(id) });
            break;
        case "steckdose":
            for (const s of probe.schalter) liste.push({ id: s.id, name: s.name + (s.raum ? " · " + s.raum : "") });
            break;
        case "raum": {
            const gesehen = {};
            for (const r of probe.raeume) { gesehen[r.id] = true; liste.push({ id: "raum:" + r.id, name: r.name }); }
            for (const h of probe.heizungen) {
                const id = h.id.replace(/^raum:/, "");
                if (h.id.startsWith("raum:") && !gesehen[id]) liste.push({ id: h.id, name: h.name });
            }
            liste.sort((a, b) => a.name.localeCompare(b.name, "de"));
            break;
        }
        case "heizung":
            for (const h of probe.heizungen) if (h.klima.length) liste.push({ id: h.id, name: h.name });
            break;
        case "entitaet":
            for (const id of Object.keys(z).filter(id => !id.startsWith("zone.")).sort((a, b) => name(a).localeCompare(name(b), "de")))
                liste.push({ id: id, name: name(id) + " (" + id + ")" });
            break;
        }
        if (cfg_kachelEntitaet && !liste.some(e => e.id === cfg_kachelEntitaet)) liste.unshift({ id: cfg_kachelEntitaet, name: cfg_kachelEntitaet });
        return liste;
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            text: i18n("Diese Einstellungen gelten, wenn das Widget auf dem Schreibtisch liegt. Für mehrere Kacheln (z. B. eine Lampe, eine Heizung und Energie) das Widget mehrmals auf den Schreibtisch ziehen und jede Kachel einzeln einstellen.")
            color: Kirigami.Theme.disabledTextColor
        }
        QQC2.ComboBox {
            id: artWahl
            Kirigami.FormData.label: i18n("Kachel zeigt:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            model: seite.arten
            textRole: "text"
            valueRole: "wert"
            currentIndex: Math.max(0, seite.arten.findIndex(a => a.wert === seite.cfg_darstellung))
            onActivated: { seite.cfg_darstellung = currentValue; seite.cfg_kachelEntitaet = ""; }
        }
        QQC2.ComboBox {
            visible: seite.instanzen.length > 1
            Kirigami.FormData.label: i18n("Instanz:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            model: [{ id: "", name: i18n("Favorit") }].concat(seite.instanzen.map(i => ({ id: i.id, name: i.name || i.adresse })))
            textRole: "name"
            valueRole: "id"
            currentIndex: Math.max(0, model.findIndex(e => e.id === seite.cfg_kachelInstanz))
            onActivated: { seite.cfg_kachelInstanz = currentValue; seite.cfg_kachelEntitaet = ""; }
        }
        RowLayout {
            visible: seite.art.ziel
            Kirigami.FormData.label: ({ lampe: i18n("Lampe:"), steckdose: i18n("Steckdose:"), raum: i18n("Raum:"), heizung: i18n("Heizung:"), entitaet: i18n("Entität:") })[seite.cfg_darstellung] || i18n("Auswahl:")
            QQC2.ComboBox {
                id: zielWahl
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                model: seite.ziele
                textRole: "name"
                valueRole: "id"
                currentIndex: seite.ziele.findIndex(e => e.id === seite.cfg_kachelEntitaet)
                displayText: currentIndex < 0 ? (probe.laedt ? i18n("Lade …") : i18n("Bitte wählen")) : currentText
                onActivated: seite.cfg_kachelEntitaet = currentValue
            }
            QQC2.BusyIndicator {
                visible: probe.laedt
                running: visible
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !probe.laedt && probe.fehler !== ""
            type: Kirigami.MessageType.Error
            text: probe.fehler
        }
    }
}
