/*
 * Heizungsverlauf der letzten 24 Stunden: Ist-Temperatur als Linie (Akzentfarbe),
 * Zieltemperatur gestrichelt (orange), Zeiten, in denen geheizt wurde, als orange Flächen.
 * Beim Überfahren mit der Maus Uhrzeit, Ist und Ziel.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "logik.js" as Logik

Item {
    id: diagramm

    property var daten: null             // { ist: [{t,w}], ziel: [{t,w}], heizen: [{von,bis}] }
    property real ende: Date.now()
    readonly property real anfang: ende - 24 * 3600 * 1000
    readonly property color heizFarbe: "#f67400"
    readonly property bool leer: !daten || (!daten.ist.length && !daten.ziel.length)

    // Wertebereich in ganzen Grad mit etwas Luft
    readonly property var bereich: {
        let lo = Infinity, hi = -Infinity;
        for (const p of (daten ? daten.ist.concat(daten.ziel) : [])) { lo = Math.min(lo, p.w); hi = Math.max(hi, p.w); }
        if (lo === Infinity) return { lo: 15, hi: 25 };
        lo = Math.floor(lo - 0.5); hi = Math.ceil(hi + 0.5);
        if (hi - lo < 4) { const m = (hi + lo) / 2; lo = Math.floor(m - 2); hi = Math.ceil(m + 2); }
        return { lo: lo, hi: hi };
    }
    readonly property real schritt: (bereich.hi - bereich.lo) > 8 ? 4 : 2
    readonly property int links: Kirigami.Units.gridUnit * 2.6
    readonly property int unten: Kirigami.Units.gridUnit
    readonly property int oben: Kirigami.Units.smallSpacing * 2
    readonly property int rechts: 8
    function xVon(t) { return links + (width - links - rechts) * (t - anfang) / (ende - anfang); }
    function yVon(w) { return oben + (height - unten - oben) * (1 - (w - bereich.lo) / (bereich.hi - bereich.lo)); }
    function wertBei(liste, t) {
        let w = null;
        for (const p of liste) { if (p.t <= t) w = p.w; else break; }
        return w;
    }
    property real zeigeZeit: -1

    onDatenChanged: { ende = Date.now(); leinwand.requestPaint(); }
    onWidthChanged: leinwand.requestPaint()
    onHeightChanged: leinwand.requestPaint()

    PC3.Label {
        anchors.centerIn: parent
        visible: diagramm.leer
        text: diagramm.daten ? i18n("Kein Verlauf vorhanden") : i18n("Verlauf wird geladen …")
        color: Kirigami.Theme.disabledTextColor
        font: Kirigami.Theme.smallFont
    }

    Canvas {
        id: leinwand
        anchors.fill: parent
        visible: !diagramm.leer
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const d = diagramm;
            if (d.leer) return;
            const akzent = Kirigami.Theme.highlightColor;
            const text = Kirigami.Theme.textColor;
            const pt = Kirigami.Theme.smallFont.pointSize;
            ctx.font = Math.round(pt > 0 ? pt * 96 / 72 : 10) + "px sans-serif";

            // Heizphasen als Flächen
            ctx.fillStyle = Qt.alpha(d.heizFarbe, 0.16);
            for (const h of d.daten.heizen) {
                const x0 = d.xVon(Math.max(h.von, d.anfang)), x1 = d.xVon(Math.min(h.bis, d.ende));
                if (x1 > x0) ctx.fillRect(x0, d.oben, x1 - x0, d.height - d.unten - d.oben);
            }
            // Hilfslinien und y-Beschriftung
            for (let v = Math.ceil(d.bereich.lo / d.schritt) * d.schritt; v <= d.bereich.hi + 1e-9; v += d.schritt) {
                const y = Math.round(d.yVon(v)) + 0.5;
                ctx.strokeStyle = Qt.alpha(text, 0.1);
                ctx.lineWidth = 1;
                ctx.setLineDash([2, 3]);
                ctx.beginPath(); ctx.moveTo(d.links, y); ctx.lineTo(d.width, y); ctx.stroke();
                ctx.setLineDash([]);
                ctx.fillStyle = Qt.alpha(text, 0.6);
                ctx.textAlign = "right";
                ctx.fillText(v + " °", d.links - 4, y + 4);
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
            // Treppe (Werte gelten bis zur nächsten Änderung)
            function treppe(liste) {
                const pfad = [];
                let vorher = null;
                for (const p of liste) {
                    if (p.t < d.anfang - 3600000) { vorher = p.w; continue; }
                    const t = Math.max(p.t, d.anfang);
                    if (vorher !== null) pfad.push([d.xVon(t), d.yVon(vorher)]);
                    pfad.push([d.xVon(t), d.yVon(p.w)]);
                    vorher = p.w;
                }
                if (vorher !== null) pfad.push([d.xVon(d.ende), d.yVon(vorher)]);
                return pfad;
            }
            // Ziel gestrichelt
            const ziel = treppe(d.daten.ziel);
            if (ziel.length) {
                ctx.beginPath();
                ctx.moveTo(ziel[0][0], ziel[0][1]);
                for (const q of ziel) ctx.lineTo(q[0], q[1]);
                ctx.strokeStyle = d.heizFarbe;
                ctx.lineWidth = 1.5;
                ctx.setLineDash([5, 4]);
                ctx.stroke();
                ctx.setLineDash([]);
            }
            // Ist als glatte Linie
            const ist = d.daten.ist.filter(p => p.t >= d.anfang - 3600000);
            if (ist.length) {
                ctx.beginPath();
                ist.forEach((p, i) => { const x = d.xVon(Math.max(p.t, d.anfang)), y = d.yVon(p.w); if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y); });
                ctx.lineTo(d.xVon(d.ende), d.yVon(ist[ist.length - 1].w));
                ctx.strokeStyle = akzent;
                ctx.lineWidth = 2;
                ctx.lineJoin = "round";
                ctx.stroke();
                const ly = d.yVon(ist[ist.length - 1].w), lx = d.xVon(d.ende) - 1;
                ctx.beginPath(); ctx.arc(lx, ly, 6, 0, Math.PI * 2); ctx.fillStyle = Qt.alpha(akzent, 0.22); ctx.fill();
                ctx.beginPath(); ctx.arc(lx, ly, 3, 0, Math.PI * 2); ctx.fillStyle = akzent; ctx.fill();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        visible: !diagramm.leer
        onPositionChanged: (ereignis) => {
            diagramm.zeigeZeit = ereignis.x < diagramm.links ? -1
                : diagramm.anfang + (ereignis.x - diagramm.links) / (diagramm.width - diagramm.links - diagramm.rechts) * (diagramm.ende - diagramm.anfang);
        }
        onExited: diagramm.zeigeZeit = -1
    }
    Rectangle {
        id: linie
        visible: diagramm.zeigeZeit >= 0
        x: diagramm.zeigeZeit >= 0 ? diagramm.xVon(diagramm.zeigeZeit) : 0
        width: 1
        y: diagramm.oben
        height: diagramm.height - diagramm.unten - diagramm.oben
        color: Qt.alpha(Kirigami.Theme.textColor, 0.5)
    }
    Rectangle {
        visible: diagramm.zeigeZeit >= 0
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
                if (diagramm.zeigeZeit < 0 || !diagramm.daten) return "";
                const ist = diagramm.wertBei(diagramm.daten.ist, diagramm.zeigeZeit);
                const ziel = diagramm.wertBei(diagramm.daten.ziel, diagramm.zeigeZeit);
                const heizt = diagramm.daten.heizen.some(h => h.von <= diagramm.zeigeZeit && h.bis >= diagramm.zeigeZeit);
                return Qt.formatTime(new Date(diagramm.zeigeZeit), "hh:mm") + " · " + Logik.formatTemp(ist)
                    + (ziel !== null ? " · " + i18n("Ziel %1", Logik.formatTemp(ziel)) : "") + (heizt ? " · " + i18n("heizt") : "");
            }
        }
    }

    // Legende
    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: diagramm.rechts
        spacing: Kirigami.Units.smallSpacing * 2
        visible: !diagramm.leer && diagramm.zeigeZeit < 0
        Repeater {
            model: [{ farbe: Kirigami.Theme.highlightColor, text: i18n("Ist") }, { farbe: diagramm.heizFarbe, text: i18n("Ziel") },
                    { farbe: Qt.alpha(diagramm.heizFarbe, 0.35), text: i18n("heizt") }]
            delegate: Row {
                required property var modelData
                spacing: 3
                Rectangle { width: 10; height: 3; radius: 1; color: modelData.farbe; anchors.verticalCenter: parent.verticalCenter }
                PC3.Label { text: modelData.text; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
            }
        }
    }
}
