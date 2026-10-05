/*
 * Verbrauch der letzten 24 Stunden: Linie mit leichter Fläche in der Akzentfarbe,
 * feine Hilfslinien, Achsen in Textfarbe. Beim Überfahren mit der Maus zeigt eine
 * Markierung Uhrzeit und Wert.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "logik.js" as Logik

Item {
    id: diagramm

    property var punkte: []
    property var aktuell: null          // aktueller Wert (Endpunkt), optional
    onAktuellChanged: leinwand.requestPaint()
    property real stunden: 24

    property real ende: Date.now()
    readonly property real anfang: ende - stunden * 3600 * 1000
    readonly property real maxWert: {
        let m = 0;
        for (const p of punkte) m = Math.max(m, p.w);
        if (aktuell !== null && aktuell !== undefined && !isNaN(aktuell)) m = Math.max(m, aktuell);
        return m;
    }
    readonly property real schritt: Logik.achsenSchritt(maxWert, 3)
    readonly property real yMax: Math.max(schritt, Math.ceil(maxWert / schritt) * schritt)
    readonly property int links: Kirigami.Units.gridUnit * 3.2
    readonly property int unten: Kirigami.Units.gridUnit
    property int zeigeIndex: -1

    readonly property int rechts: 8
    function xVon(t) { return links + (width - links - rechts) * (t - anfang) / (ende - anfang); }
    readonly property int oben: Kirigami.Units.smallSpacing * 2
    function yVon(w) { return oben + (height - unten - oben) * (1 - w / yMax); }
    // Achsenbeschriftung einheitlich: alles in W oder alles in kW, ohne unnötige Nachkommastellen
    function achse(v) {
        if (yMax >= 1000) {
            const kw = v / 1000;
            return (Math.round(kw * 100) / 100).toString().replace(".", Logik._dezimal) + "\u202fkW";
        }
        return Math.round(v) + "\u202fW";
    }

    onPunkteChanged: { ende = Date.now(); leinwand.requestPaint(); }
    onWidthChanged: leinwand.requestPaint()
    onHeightChanged: leinwand.requestPaint()

    PC3.Label {
        anchors.centerIn: parent
        visible: diagramm.punkte.length === 0
        text: i18n("Verlauf wird geladen …")
        color: Kirigami.Theme.disabledTextColor
        font: Kirigami.Theme.smallFont
    }

    Canvas {
        id: leinwand
        anchors.fill: parent
        visible: diagramm.punkte.length > 0
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const akzent = Kirigami.Theme.highlightColor;
            const text = Kirigami.Theme.textColor;
            const d = diagramm;
            const pt = Kirigami.Theme.smallFont.pointSize;
            ctx.font = Math.round(pt > 0 ? pt * 96 / 72 : 10) + "px sans-serif";

            // Hilfslinien und y-Beschriftung
            for (let v = 0; v <= d.yMax + 1e-9; v += d.schritt) {
                const y = Math.round(d.yVon(v)) + 0.5;
                ctx.strokeStyle = Qt.alpha(text, v === 0 ? 0.3 : 0.1);
                ctx.lineWidth = 1;
                if (v !== 0) ctx.setLineDash([2, 3]); else ctx.setLineDash([]);
                ctx.beginPath(); ctx.moveTo(d.links, y); ctx.lineTo(d.width, y); ctx.stroke();
                ctx.setLineDash([]);
                ctx.fillStyle = Qt.alpha(text, 0.6);
                ctx.textAlign = "right";
                ctx.fillText(d.achse(v), d.links - 4, y + 4);
            }
            // x-Beschriftung alle 6 Stunden
            ctx.textAlign = "center";
            const start = new Date(d.anfang);
            start.setMinutes(0, 0, 0);
            for (let t = start.getTime() + 3600000; t < d.ende; t += 3600000) {
                const h = new Date(t).getHours();
                if (h % 6 !== 0) continue;
                ctx.fillStyle = Qt.alpha(text, 0.6);
                ctx.fillText(("0" + h).slice(-2) + ":00", d.xVon(t), d.height - 2);
            }
            if (!d.punkte.length) return;

            // Linie als Treppe (Messwerte gelten bis zur nächsten Änderung)
            const pfad = [];
            let vorher = null;
            for (const p of d.punkte) {
                const t = Math.max(p.t, d.anfang);
                if (vorher !== null) pfad.push([d.xVon(t), d.yVon(vorher)]);
                pfad.push([d.xVon(t), d.yVon(p.w)]);
                vorher = p.w;
            }
            const endwert = d.aktuell !== null && d.aktuell !== undefined && !isNaN(d.aktuell) ? Math.min(d.aktuell, d.yMax) : vorher;
            pfad.push([d.xVon(d.ende), d.yVon(vorher)]);
            if (endwert !== vorher) pfad.push([d.xVon(d.ende), d.yVon(endwert)]);

            // Fläche
            ctx.beginPath();
            ctx.moveTo(pfad[0][0], d.yVon(0));
            for (const q of pfad) ctx.lineTo(q[0], q[1]);
            ctx.lineTo(pfad[pfad.length - 1][0], d.yVon(0));
            ctx.closePath();
            // weicher Verlauf von oben nach unten
            const verlauf = ctx.createLinearGradient(0, d.oben, 0, d.yVon(0));
            verlauf.addColorStop(0, Qt.alpha(akzent, 0.32));
            verlauf.addColorStop(1, Qt.alpha(akzent, 0.02));
            ctx.fillStyle = verlauf;
            ctx.fill();
            // Linie
            ctx.beginPath();
            ctx.moveTo(pfad[0][0], pfad[0][1]);
            for (const q of pfad) ctx.lineTo(q[0], q[1]);
            ctx.strokeStyle = akzent;
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.stroke();

            // "Jetzt"-Punkt am Ende mit Hof
            const letzter = pfad[pfad.length - 1];
            ctx.beginPath();
            ctx.arc(letzter[0] - 1, letzter[1], 7, 0, Math.PI * 2);
            ctx.fillStyle = Qt.alpha(akzent, 0.22);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(letzter[0] - 1, letzter[1], 3.5, 0, Math.PI * 2);
            ctx.fillStyle = akzent;
            ctx.fill();
        }
    }

    // Markierung beim Überfahren
    MouseArea {
        id: maus
        anchors.fill: parent
        hoverEnabled: true
        visible: diagramm.punkte.length > 0
        onPositionChanged: (ereignis) => {
            const t = diagramm.anfang + (ereignis.x - diagramm.links) / (diagramm.width - diagramm.links - diagramm.rechts) * (diagramm.ende - diagramm.anfang);
            let i = -1;
            for (let k = 0; k < diagramm.punkte.length; k++) if (diagramm.punkte[k].t <= t) i = k;
            diagramm.zeigeIndex = ereignis.x >= diagramm.links ? i : -1;
            linie.x = Math.max(diagramm.links, ereignis.x);
        }
        onExited: diagramm.zeigeIndex = -1
    }
    Rectangle {
        id: linie
        visible: diagramm.zeigeIndex >= 0
        width: 1
        y: diagramm.oben
        height: diagramm.height - diagramm.unten - diagramm.oben
        color: Qt.alpha(Kirigami.Theme.textColor, 0.5)
    }
    Rectangle {
        visible: diagramm.zeigeIndex >= 0
        x: Math.min(diagramm.width - width, Math.max(0, linie.x - width / 2))
        y: 0
        width: hinweis.implicitWidth + Kirigami.Units.smallSpacing * 2
        height: hinweis.implicitHeight + Kirigami.Units.smallSpacing
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.backgroundColor
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
        PC3.Label {
            id: hinweis
            anchors.centerIn: parent
            font: Kirigami.Theme.smallFont
            text: {
                const p = diagramm.punkte[diagramm.zeigeIndex];
                if (!p) return "";
                const zeit = linie.x >= diagramm.links
                    ? new Date(diagramm.anfang + (linie.x - diagramm.links) / (diagramm.width - diagramm.links - diagramm.rechts) * (diagramm.ende - diagramm.anfang))
                    : new Date(p.t);
                return Qt.formatTime(zeit, "hh:mm") + " · " + Logik.formatWatt(p.w);
            }
        }
    }
}
