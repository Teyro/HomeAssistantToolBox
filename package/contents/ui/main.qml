/*
 * Home Assistant für Plasma 6: Lampen, Steckdosen und Energie direkt im Panel.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "logik.js" as Logik

PlasmoidItem {
    id: root

    // Eindeutiger Name: in der Popup-Komponente würde "ha: ha" auf die eigene Eigenschaft zeigen
    HaVerbindung {
        id: verbindung
        adresse: Plasmoid.configuration.adresse
        token: Plasmoid.configuration.token
        abfrageSekunden: Plasmoid.configuration.abfrageSekunden
        sichtbar: root.expanded
        optionen: ({
            alteGruppen: Plasmoid.configuration.alteGruppen,
            nurSteckdosen: Plasmoid.configuration.nurSteckdosen,
            hauptzaehler: Plasmoid.configuration.hauptzaehler,
            ausgeblendet: Plasmoid.configuration.ausgeblendet
        })
    }

    readonly property int lichterAn: verbindung.lichterAn
    readonly property real watt: verbindung.hauptWatt !== null ? verbindung.hauptWatt : verbindung.summeWatt

    Plasmoid.icon: Qt.resolvedUrl("../icons/" + (lichterAn > 0 ? "ha-licht-an.svg" : "ha-licht-aus.svg"))
    Plasmoid.status: verbindung.eingerichtet ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    toolTipMainText: i18n("Home Assistant")
    toolTipSubText: {
        if (!verbindung.eingerichtet) return i18n("Noch nicht eingerichtet – Rechtsklick → Einrichten");
        if (verbindung.fehler) return verbindung.fehler;
        const teile = [];
        teile.push(lichterAn === 1 ? i18n("1 Lampe an") : i18n("%1 Lampen an", lichterAn));
        if (verbindung.schalter.length) teile.push(i18n("%1 von %2 Steckdosen an", verbindung.schalterAn, verbindung.schalter.length));
        if (verbindung.leistung.length || verbindung.hauptWatt !== null) teile.push(i18n("Verbrauch %1", Logik.formatWatt(watt)));
        return teile.join("\n");
    }

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 12

    compactRepresentation: KompaktAnsicht {
        lichterAn: root.lichterAn
        zeigeAnzahl: Plasmoid.configuration.zeigeAnzahl
        verbunden: verbindung.verbunden
        eingerichtet: verbindung.eingerichtet
        panelhoehe: Plasmoid.configuration.symbolPanelhoehe
        horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
        onGeklickt: root.expanded = !root.expanded
    }

    fullRepresentation: VollAnsicht {
        ha: verbindung
        zeigeGruppen: Plasmoid.configuration.zeigeGruppen
        zeigeRaeume: Plasmoid.configuration.zeigeRaeume
        hauptzaehler: Plasmoid.configuration.hauptzaehler
        offen: root.expanded
        onEinrichten: Plasmoid.internalAction("configure").trigger()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Alle Lampen aus")
            icon.name: "system-shutdown"
            enabled: root.lichterAn > 0
            onTriggered: verbindung.alleLichterAus()
        },
        PlasmaCore.Action {
            text: i18n("Home Assistant öffnen")
            icon.name: "internet-web-browser"
            enabled: verbindung.basis !== ""
            onTriggered: Qt.openUrlExternally(verbindung.basis)
        },
        PlasmaCore.Action {
            text: i18n("Neu laden")
            icon.name: "view-refresh"
            enabled: verbindung.eingerichtet
            onTriggered: { verbindung.bereicheLaden(); verbindung.aktualisieren(); }
        }
    ]
}
