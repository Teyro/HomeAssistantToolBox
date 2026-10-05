// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: deep-blue; icon-glyph: home;

/*
 * HA Leiste für iOS (Scriptable) – Home Assistant auf dem Homebildschirm und Sperrbildschirm.
 * Lampen, Steckdosen, Heizung, Energie, Personen; mehrere Instanzen; akkuschonend:
 * eine Abfrage je Aktualisierung, alles andere aus dem Zwischenspeicher.
 * https://github.com/Teyro/homeassistant-leiste · GPL-3.0-or-later
 *
 * Diese Datei wird gebaut (ios/baue.mjs) – die Logik kommt aus dem Plasma-Widget (logik.js).
 */

const VERSION = "2.3.0";
const PROJEKT = "Teyro/homeassistant-leiste";
const SCHLUESSEL = "ha-leiste-instanzen";

// ---------------------------------------------------------------- Logik (aus logik.js)
const Logik = (() => {

// Reine Hilfsfunktionen ohne Qt-Abhängigkeiten – werden auch außerhalb von Plasma getestet.

/** Template für Home Assistant: Räume (Bereiche) mit Lampen/Schaltern und Leistungssensoren je Schalter. */
var BEREICHE_TEMPLATE =
    "{%- set ns = namespace(a=[], p=[], g=[]) -%}" +
    "{%- for ar in areas() -%}" +
    "{%- set se = area_entities(ar) | select('match', 'sensor\\\\.') | list -%}" +
    "{%- set be = area_entities(ar) | select('match', 'binary_sensor\\\\.') | list -%}" +
    "{%- set ns.a = ns.a + [{'id': ar, 'name': area_name(ar), 'e': area_entities(ar) | select('match', '(light|switch|climate)\\\\.') | list," +
    " 't': se | select('is_state_attr', 'device_class', 'temperature') | list, 'h': se | select('is_state_attr', 'device_class', 'humidity') | list," +
    " 'f': (be | select('is_state_attr', 'device_class', 'window') | list) + (be | select('is_state_attr', 'device_class', 'opening') | list)}] -%}" +
    "{%- endfor -%}" +
    "{%- for s in states.switch -%}" +
    "{%- set d = device_id(s.entity_id) -%}" +
    "{%- if d -%}{%- set ns.g = ns.g + [[s.entity_id, d, device_attr(d, 'name_by_user') or device_attr(d, 'name') or '']] -%}" +
    "{%- for e in device_entities(d) -%}" +
    "{%- if e.startswith('sensor.') and state_attr(e, 'device_class') == 'power' -%}{%- set ns.p = ns.p + [[s.entity_id, e]] -%}{%- endif -%}" +
    "{%- endfor -%}{%- endif -%}" +
    "{%- endfor -%}" +
    "{{ {'bereiche': ns.a, 'leistung': ns.p, 'geraete': ns.g} | tojson }}";

var EINSTELLUNGS_SCHALTER = /(^|[\s_.-])(led|leds|indikator|indicator|kindersicherung|child[\s_]?lock|tastensperre|button[\s_]?lock|nachtmodus|night[\s_]?mode|do[\s_]?not[\s_]?disturb|auto[\s_-]?update|firmware|beta|ota|neustart|restart|reboot|identify|identifizieren|power[\s_]?on[\s_]?behavio(u)?r|einschaltverhalten|überlastschutz|overload|benachrichtigung|notification|signalton|beep|buzzer|statuslicht|status[\s_]?light|ecomodus|eco[\s_]?mode)($|[\s_.-])/i;

function domain(id) { return id.split(".")[0]; }

function name(e) {
    if (!e) return "";
    return (e.attributes && e.attributes.friendly_name) || e.entity_id;
}

/** Kürzerer Name für Messwerte: "Fernseher Leistung" -> "Fernseher". */
function messName(e) {
    var n = name(e).replace(/[\s_-]+(aktuelle?\s+)?(leistung|power|verbrauch|consumption|watt)$/i, "").trim();
    return n || name(e);
}

function istAn(e) { return !!e && e.state === "on"; }
function istVerfuegbar(e) { return !!e && e.state !== "unavailable" && e.state !== "unknown"; }

/** Helligkeit in Prozent (0–100); aus = 0. */
function helligkeit(e) {
    if (!istAn(e)) return 0;
    var b = e.attributes ? e.attributes.brightness : null;
    if (b === null || b === undefined) return 100;
    return Math.max(1, Math.round(b / 255 * 100));
}

/** Kann die Lampe gedimmt werden? */
function dimmbar(e) {
    if (!e || !e.attributes) return false;
    var modi = e.attributes.supported_color_modes;
    if (modi && modi.length) return !(modi.length === 1 && modi[0] === "onoff");
    // ältere Integrationen: Bit 1 = Helligkeit
    return ((e.attributes.supported_features || 0) & 1) === 1 || e.attributes.brightness !== undefined;
}

function hex2(n) { var s = Math.max(0, Math.min(255, Math.round(n))).toString(16); return s.length < 2 ? "0" + s : s; }

/** Farbe für das Lampensymbol: echte Farbe, Weißton aus der Farbtemperatur oder warmes Gelb. */
function lampenFarbe(e) {
    if (!istAn(e)) return "";
    var a = e.attributes || {};
    var modus = a.color_mode;
    if (a.rgb_color && modus !== "color_temp" && modus !== "brightness" && modus !== "onoff") {
        var r = a.rgb_color[0], g = a.rgb_color[1], b = a.rgb_color[2];
        // sehr helle, fast weiße Farben etwas wärmer darstellen
        if (r > 235 && g > 235 && b > 235) return "#fff4d6";
        return "#" + hex2(r) + hex2(g) + hex2(b);
    }
    var kelvin = a.color_temp_kelvin || (a.color_temp ? Math.round(1000000 / a.color_temp) : null);
    if (kelvin) {
        // 2000 K (warm) … 6500 K (kalt)
        var t = Math.max(0, Math.min(1, (kelvin - 2000) / 4500));
        return "#" + hex2(255) + hex2(190 + 55 * t) + hex2(110 + 145 * t);
    }
    return "#ffc65c";
}

function ausgeblendet(id, liste) {
    if (!liste) return false;
    for (var i = 0; i < liste.length; i++) {
        var m = liste[i];
        if (!m) continue;
        if (m === id) return true;
        if (m.indexOf("*") >= 0) {
            var re = new RegExp("^" + m.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*") + "$");
            if (re.test(id)) return true;
        }
    }
    return false;
}

function vergleicheName(a, b) { return a.name.localeCompare(b.name, "de"); }

/**
 * Baut aus allen Zuständen und den Bereichen (Template-Ergebnis) das Anzeigemodell.
 * zustaende: { entity_id: state }, bereiche: Ergebnis von BEREICHE_TEMPLATE oder null.
 */
function baueModell(zustaende, bereiche, opt) {
    opt = opt || {};
    var versteckt = (opt.ausgeblendet || "").split(/[\s,;]+/).filter(function (x) { return x; });
    var ids = Object.keys(zustaende);
    var lichter = [], gruppen = [], schalter = [], schalterGruppen = [], leistung = [], energie = [];
    var inGruppe = {};

    var register = opt.register || {};
    ids.forEach(function (id) {
        if (ausgeblendet(id, versteckt)) return;
        var e = zustaende[id];
        var d = domain(id);
        var reg = register[id];
        // In Home Assistant versteckt: nirgends zeigen. Einstellungs-/Diagnose-Entitäten
        // (z. B. "LED an der Steckdose", "Kindersicherung"): keine Lampen/Steckdosen.
        if (reg && reg.hb) return;
        if (reg && reg.ec && (d === "light" || d === "switch")) return;
        var a = e.attributes || {};
        if (d === "light") {
            // Lichtgruppe: hat eine Liste von Mitgliedern
            if (a.entity_id && a.entity_id.length) {
                gruppen.push({ id: id, name: name(e), mitglieder: a.entity_id.filter(function (m) { return zustaende[m] && !ausgeblendet(m, versteckt); }) });
            } else {
                lichter.push({ id: id, name: name(e) });
            }
        } else if (d === "group" && opt.alteGruppen !== false && a.entity_id && a.entity_id.length) {
            var nurLicht = a.entity_id.filter(function (m) { return domain(m) === "light" && zustaende[m]; });
            var nurSchalter = a.entity_id.filter(function (m) { return domain(m) === "switch" && zustaende[m]; });
            if (nurLicht.length && nurLicht.length === a.entity_id.length) {
                gruppen.push({ id: id, name: name(e), mitglieder: nurLicht, alt: true });
            } else if (nurSchalter.length && nurSchalter.length === a.entity_id.length) {
                schalterGruppen.push({ id: id, name: name(e), steuerId: id, mitglieder: nurSchalter, art: "gruppe" });
            }
        } else if (d === "switch") {
            if (opt.nurSteckdosen && a.device_class !== "outlet") return;
            // Ohne Entitäten-Register (keine WebSocket-Verbindung): typische Geräte-Einstellungen
            // am Namen erkennen, damit nicht jede "LED"- oder "Kindersicherung"-Option erscheint.
            if (!opt.register || !Object.keys(opt.register).length) {
                if (EINSTELLUNGS_SCHALTER.test(name(e)) || EINSTELLUNGS_SCHALTER.test(id)) return;
            }
            // Schaltergruppe (Helfer "Gruppe → Schalter"): hat eine Liste von Mitgliedern
            if (a.entity_id && a.entity_id.length) {
                schalterGruppen.push({ id: id, name: name(e), steuerId: id, mitglieder: a.entity_id.slice(), art: "gruppe" });
                return;
            }
            schalter.push({ id: id, name: name(e) });
        } else if (d === "sensor" && istVerfuegbar(e)) {
            var wert = parseFloat(e.state);
            if (isNaN(wert)) return;
            var einheit = a.unit_of_measurement || "";
            if (a.device_class === "power" && (einheit === "W" || einheit === "kW")) {
                leistung.push({ id: id, name: messName(e), watt: einheit === "kW" ? wert * 1000 : wert });
            } else if (a.device_class === "energy" && (einheit === "kWh" || einheit === "Wh" || einheit === "MWh")) {
                energie.push({ id: id, name: name(e), kwh: einheit === "Wh" ? wert / 1000 : einheit === "MWh" ? wert * 1000 : wert });
            }
        }
    });

    gruppen.forEach(function (g) { g.mitglieder.forEach(function (m) { inGruppe[m] = true; }); });
    gruppen.sort(vergleicheName);
    lichter.sort(vergleicheName);
    schalter.sort(vergleicheName);
    leistung.sort(function (a, b) { return b.watt - a.watt; });
    energie.sort(vergleicheName);

    // Räume aus Home Assistant
    var raeume = [];
    var imRaum = {};
    if (bereiche && bereiche.bereiche) {
        bereiche.bereiche.forEach(function (b) {
            var l = (b.e || []).filter(function (id) {
                return domain(id) === "light" && zustaende[id] && !ausgeblendet(id, versteckt)
                    && !(zustaende[id].attributes && zustaende[id].attributes.entity_id && zustaende[id].attributes.entity_id.length);
            });
            var s = (b.e || []).filter(function (id) { return schalter.some(function (x) { return x.id === id; }); });
            l = l.filter(function (id) { return lichter.some(function (x) { return x.id === id; }); });
            l.forEach(function (id) { imRaum[id] = true; });
            s.forEach(function (id) { imRaum[id] = true; });
            if (l.length || s.length) {
                l.sort(function (x, y) { return name(zustaende[x]).localeCompare(name(zustaende[y]), "de"); });
                raeume.push({ id: b.id, name: b.name || b.id, lichter: l, schalter: s });
            }
        });
        raeume.sort(vergleicheName);
    }
    var ohneRaum = lichter.filter(function (l) { return !imRaum[l.id]; }).map(function (l) { return l.id; });

    // Leistung je Steckdose
    var schalterLeistung = {};
    if (bereiche && bereiche.leistung) {
        bereiche.leistung.forEach(function (p) { if (!schalterLeistung[p[0]]) schalterLeistung[p[0]] = p[1]; });
    }
    // Ersatz ohne Template: Sensor mit gleichem Namensanfang ("switch.kaffee" -> "sensor.kaffee_power")
    schalter.forEach(function (s) {
        if (schalterLeistung[s.id]) return;
        var basis = s.id.split(".")[1];
        var treffer = leistung.filter(function (p) { return p.id.indexOf("sensor." + basis) === 0; });
        if (treffer.length) schalterLeistung[s.id] = treffer[0].id;
    });
    // Räume für Steckdosen
    var schalterRaum = {};
    raeume.forEach(function (r) { r.schalter.forEach(function (id) { schalterRaum[id] = r.name; }); });

    // Geräte mit mehreren Schaltern (z. B. Steckdosenleisten) als eigene Gruppe
    var istSchalter = {};
    schalter.forEach(function (x) { istSchalter[x.id] = true; });
    if (bereiche && bereiche.geraete) {
        var jeGeraet = {};
        bereiche.geraete.forEach(function (g) {
            if (!istSchalter[g[0]]) return;
            (jeGeraet[g[1]] = jeGeraet[g[1]] || { name: g[2], ids: [] }).ids.push(g[0]);
        });
        Object.keys(jeGeraet).forEach(function (d) {
            var g = jeGeraet[d];
            if (g.ids.length < 2) return;
            g.ids.sort(function (x, y) { return name(zustaende[x]).localeCompare(name(zustaende[y]), "de"); });
            schalterGruppen.push({ id: "geraet:" + d, name: g.name || name(zustaende[g.ids[0]]), steuerId: "", mitglieder: g.ids, art: "geraet" });
        });
    }
    // Mitglieder auf vorhandene, sichtbare Schalter beschränken; leere Gruppen weglassen
    schalterGruppen = schalterGruppen.map(function (g) {
        return Object.assign({}, g, { mitglieder: g.mitglieder.filter(function (m) { return istSchalter[m]; }) });
    }).filter(function (g) { return g.mitglieder.length > 0; });
    var inSchalterGruppe = {};
    schalterGruppen.forEach(function (g) {
        g.mitglieder.forEach(function (m) { inSchalterGruppe[m] = true; });
        // Gesamtverbrauch: jeden Sensor nur einmal (eine Leiste hat oft einen Sensor für alle Dosen)
        var sensoren = {};
        g.mitglieder.forEach(function (m) { if (schalterLeistung[m]) sensoren[schalterLeistung[m]] = true; });
        g.leistung = Object.keys(sensoren);
        var raeumeG = {};
        g.mitglieder.forEach(function (m) { raeumeG[schalterRaum[m] || ""] = true; });
        var rk = Object.keys(raeumeG);
        g.raum = rk.length === 1 ? rk[0] : "";
    });
    schalterGruppen.sort(vergleicheName);

    var hauptWatt = null;
    if (opt.hauptzaehler && zustaende[opt.hauptzaehler]) {
        var h = zustaende[opt.hauptzaehler];
        var hw = parseFloat(h.state);
        if (!isNaN(hw)) hauptWatt = (h.attributes && h.attributes.unit_of_measurement === "kW") ? hw * 1000 : hw;
    }
    var summeWatt = 0;
    leistung.forEach(function (p) { if (p.id !== opt.hauptzaehler && p.watt > 0) summeWatt += p.watt; });

    var alleLichter = lichter.map(function (l) { return l.id; });
    var lichterAn = alleLichter.filter(function (id) { return istAn(zustaende[id]); }).length;

    return {
        gruppen: gruppen,
        raeume: raeume,
        ohneRaum: ohneRaum,
        lichter: alleLichter,
        lichterAn: lichterAn,
        schalter: schalter.map(function (s) { return { id: s.id, name: s.name, raum: schalterRaum[s.id] || "", leistung: schalterLeistung[s.id] || "" }; }),
        schalterAn: schalter.filter(function (s) { return istAn(zustaende[s.id]); }).length,
        schalterGruppen: schalterGruppen,
        einzelneSchalter: schalter.filter(function (s) { return !inSchalterGruppe[s.id]; }).map(function (s) { return s.id; }),
        leistung: leistung.filter(function (p) { return p.id !== opt.hauptzaehler; }),
        energie: energie,
        hauptWatt: hauptWatt,
        summeWatt: summeWatt,
        nichtImRaumGruppiert: inGruppe
    };
}

/** Zustand einer Gruppe: wie viele Mitglieder an, mittlere Helligkeit der eingeschalteten. */
function gruppenStatus(mitglieder, zustaende) {
    var an = 0, summe = 0, dimmbarAnz = 0, verfuegbar = 0;
    mitglieder.forEach(function (id) {
        var e = zustaende[id];
        if (istVerfuegbar(e)) verfuegbar++;
        if (istAn(e)) { an++; summe += helligkeit(e); }
        if (dimmbar(e)) dimmbarAnz++;
    });
    return { an: an, gesamt: mitglieder.length, verfuegbar: verfuegbar, helligkeit: an ? Math.round(summe / an) : 0, dimmbar: dimmbarAnz > 0 };
}

/** Farbe der Gruppe: Mischfarbe der eingeschalteten Mitglieder. */
function gruppenFarbe(mitglieder, zustaende) {
    var r = 0, g = 0, b = 0, n = 0;
    mitglieder.forEach(function (id) {
        var f = lampenFarbe(zustaende[id]);
        if (!f) return;
        r += parseInt(f.substr(1, 2), 16); g += parseInt(f.substr(3, 2), 16); b += parseInt(f.substr(5, 2), 16); n++;
    });
    if (!n) return "";
    return "#" + hex2(r / n) + hex2(g / n) + hex2(b / n);
}

function formatWatt(w) {
    if (w === null || w === undefined || isNaN(w)) return "–";
    if (w === 0) return "0 W";
    if (Math.abs(w) >= 10000) return (w / 1000).toFixed(1).replace(".", ",") + " kW";
    if (Math.abs(w) >= 1000) return (w / 1000).toFixed(2).replace(".", ",") + " kW";
    if (Math.abs(w) >= 10) return Math.round(w) + " W";
    return w.toFixed(1).replace(".", ",") + " W";
}

function formatKwh(k) {
    if (k === null || k === undefined || isNaN(k)) return "–";
    // Zählerstände wie auf dem Zähler: 12.456 kWh
    if (k >= 1000) return Math.round(k).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".") + " kWh";
    if (k >= 100) return Math.round(k) + " kWh";
    return k.toFixed(k >= 10 ? 1 : 2).replace(".", ",") + " kWh";
}

/** Verlauf (History-API, minimal_response) in Punkte [{t, w}] umwandeln. */
function verlaufPunkte(antwort, kw) {
    if (!antwort || !antwort.length || !antwort[0]) return [];
    var punkte = [];
    antwort[0].forEach(function (p) {
        var w = parseFloat(p.state);
        var t = Date.parse(p.last_changed || p.lu * 1000 || "");
        if (isNaN(w) || isNaN(t)) return;
        punkte.push({ t: t, w: kw ? w * 1000 : w });
    });
    return punkte;
}

/** "Schöne" Achsenschritte (1, 2, 2.5, 5 × 10^n). */
function achsenSchritt(max, ziel) {
    if (!(max > 0)) return 1;
    var roh = max / (ziel || 3);
    var p = Math.pow(10, Math.floor(Math.log(roh) / Math.LN10));
    var stufen = [1, 2, 2.5, 5, 10];
    for (var i = 0; i < stufen.length; i++) if (stufen[i] * p >= roh) return stufen[i] * p;
    return 10 * p;
}

/** Zustand einer Steckdosengruppe: an/gesamt und Summe der (eindeutigen) Leistungssensoren. */
function schalterGruppenStatus(gruppe, zustaende) {
    var an = 0, verfuegbar = 0, watt = 0, gemessen = false;
    gruppe.mitglieder.forEach(function (id) {
        var e = zustaende[id];
        if (istVerfuegbar(e)) verfuegbar++;
        if (istAn(e)) an++;
    });
    (gruppe.leistung || []).forEach(function (id) {
        var w = wattVon(zustaende[id]);
        if (!isNaN(w)) { watt += w; gemessen = true; }
    });
    return { an: an, gesamt: gruppe.mitglieder.length, verfuegbar: verfuegbar, watt: gemessen ? watt : NaN };
}

/** Leistung eines Sensors in Watt (NaN, wenn unbekannt). */
function wattVon(e) {
    if (!e || !istVerfuegbar(e)) return NaN;
    var w = parseFloat(e.state);
    if (isNaN(w)) return NaN;
    return e.attributes && e.attributes.unit_of_measurement === "kW" ? w * 1000 : w;
}

/** Ist diese Entität für das Widget überhaupt interessant? (alles andere wird ignoriert) */
function relevant(id, e, hauptzaehler) {
    var d = domain(id);
    if (d === "light" || d === "switch" || d === "group" || d === "climate" || d === "person" || d === "zone") return true;
    var k = e && e.attributes ? e.attributes.device_class : null;
    if (d === "binary_sensor") return k === "window" || k === "opening";
    if (d !== "sensor") return false;
    if (id === hauptzaehler) return true;
    return k === "power" || k === "energy" || k === "water" || k === "gas" || k === "temperature" || k === "humidity";
}

/** Kennzahlen aus dem Verlauf: Energie (Fläche unter der Kurve), Spitze, Durchschnitt. */
function verlaufKennzahlen(punkte, ende) {
    if (!punkte || punkte.length < 2) return null;
    var wh = 0, spitze = punkte[0], minimum = punkte[0];
    for (var i = 0; i < punkte.length; i++) {
        var p = punkte[i];
        var bis = i + 1 < punkte.length ? punkte[i + 1].t : ende;
        wh += p.w * Math.max(0, bis - p.t) / 3600000;
        if (p.w > spitze.w) spitze = p;
        if (p.w < minimum.w) minimum = p;
    }
    var dauer = (ende - punkte[0].t) / 3600000;
    return { kwh: wh / 1000, spitze: spitze, minimum: minimum, schnitt: dauer > 0 ? wh / dauer : 0 };
}

/** Zählerarten für "Verbrauch heute" */
var VERBRAUCH_ARTEN = ["strom", "wasser", "gas"];

/** Zähler aus den Einstellungen des Energie-Dashboards von Home Assistant (energy/get_prefs). */
function zaehlerAusEnergieDashboard(prefs) {
    var z = { strom: [], wasser: [], gas: [] };
    if (!prefs || !prefs.energy_sources) return z;
    prefs.energy_sources.forEach(function (q) {
        if (q.type === "grid") (q.flow_from || []).forEach(function (f) { if (f.stat_energy_from) z.strom.push(f.stat_energy_from); });
        else if (q.type === "gas" && q.stat_energy_from) z.gas.push(q.stat_energy_from);
        else if (q.type === "water" && q.stat_energy_from) z.wasser.push(q.stat_energy_from);
    });
    return z;
}

/**
 * Verbrauch eines Zählerstands aus dem Verlauf (REST-History, ohne WebSocket):
 * Summe der Zunahmen ab [heuteStart] bzw. im Tag davor. Ein Zurückspringen auf (fast) 0 gilt als
 * Neustart des Zählers, kleines Zittern nach unten wird ignoriert.
 */
function tagesVerbrauch(liste, heuteStart) {
    var gesternStart = heuteStart - 86400000;
    var heute = 0, gestern = 0, vorher = null, hatHeute = false, hatGestern = false;
    if (!liste || !liste.length) return null;
    liste.forEach(function (p) {
        var w = parseFloat(p.state);
        var t = Date.parse(p.last_changed || "");
        if (isNaN(w) || isNaN(t)) return;
        if (vorher !== null) {
            var d = w - vorher;
            if (d < 0) d = w < vorher * 0.5 ? w : 0;
            if (t >= heuteStart) { heute += d; hatHeute = true; }
            else if (t >= gesternStart) { gestern += d; hatGestern = true; }
        }
        if (t >= heuteStart) hatHeute = true;
        vorher = w;
    });
    if (vorher === null) return null;
    return { heute: heute, gestern: hatGestern || hatHeute ? gestern : null };
}

/** Menge mit passender Einheit: Strom in kWh, Wasser in Litern bzw. m³, Gas in m³ oder kWh. */
function formatMenge(wert, einheit, art) {
    if (wert === null || wert === undefined || isNaN(wert)) return "–";
    var e = einheit || "";
    if (art === "strom") {
        var kwh = e === "Wh" ? wert / 1000 : e === "MWh" ? wert * 1000 : wert;
        return formatKwh(kwh);
    }
    if (art === "wasser") {
        var liter = e === "m³" || e === "m3" ? wert * 1000 : e === "gal" ? wert * 3.785 : e === "ft³" ? wert * 28.317 : wert;
        if (liter >= 1000) return (liter / 1000).toFixed(2).replace(".", ",") + " m³";
        return Math.round(liter) + " L";
    }
    // Gas
    if (e === "kWh" || e === "Wh" || e === "MWh") return formatKwh(e === "Wh" ? wert / 1000 : e === "MWh" ? wert * 1000 : wert);
    return wert.toFixed(wert >= 10 ? 1 : 2).replace(".", ",") + " " + (e || "m³");
}


// ------------------------------------------------------------------ Heizung

/** Räume mit Thermostat oder Temperatursensor; Thermostate ohne Raum als eigene Einträge. */
function heizungen(zustaende, bereiche, versteckt) {
    versteckt = versteckt || [];
    var liste = [], vergeben = {};
    var sichtbar = function (id) { return zustaende[id] && !ausgeblendet(id, versteckt); };
    ((bereiche && bereiche.bereiche) || []).forEach(function (b) {
        var klima = (b.e || []).filter(function (id) { return domain(id) === "climate" && sichtbar(id); });
        var temp = (b.t || []).filter(sichtbar);
        var feuchte = (b.h || []).filter(sichtbar);
        var fenster = (b.f || []).filter(sichtbar);
        if (!klima.length && !temp.length) return;
        klima.forEach(function (id) { vergeben[id] = true; });
        liste.push({ id: "raum:" + b.id, name: b.name || b.id, klima: klima, temperatur: temp[0] || "", feuchte: feuchte[0] || "", fenster: fenster });
    });
    Object.keys(zustaende).forEach(function (id) {
        if (domain(id) !== "climate" || vergeben[id] || !sichtbar(id)) return;
        liste.push({ id: id, name: name(zustaende[id]).replace(/^(heizung|thermostat|heizkörper)\s+/i, ""), klima: [id], temperatur: "", feuchte: "", fenster: [] });
    });
    liste.sort(vergleicheName);
    return liste;
}

function zahl(x) { var n = parseFloat(x); return isNaN(n) ? null : n; }

/** Zustand eines Thermostats (climate.*) */
function klimaStatus(e) {
    if (!e) return null;
    var a = e.attributes || {};
    var modi = a.hvac_modes || [];
    return {
        modus: e.state,                                   // off / heat / auto / cool …
        aktion: a.hvac_action || (e.state === "off" ? "off" : ""),
        heizt: a.hvac_action === "heating" || a.hvac_action === "preheating",
        ist: zahl(a.current_temperature),
        ziel: zahl(a.temperature),
        min: zahl(a.min_temp) !== null ? zahl(a.min_temp) : 7,
        max: zahl(a.max_temp) !== null ? zahl(a.max_temp) : 30,
        schritt: zahl(a.target_temp_step) || 0.5,
        modi: modi,
        presets: (a.preset_modes || []).filter(function (p) { return p && p !== "none"; }),
        preset: a.preset_mode && a.preset_mode !== "none" ? a.preset_mode : "",
        verfuegbar: istVerfuegbar(e)
    };
}

/** Zusammenfassung eines Raums: Ist-Temperatur (Raumsensor vor Thermostat), Ziel, heizt? */
function raumKlima(raum, zustaende) {
    var thermostat = raum.klima.length ? klimaStatus(zustaende[raum.klima[0]]) : null;
    var sensor = raum.temperatur ? zahl(zustaende[raum.temperatur] && zustaende[raum.temperatur].state) : null;
    var feuchte = raum.feuchte ? zahl(zustaende[raum.feuchte] && zustaende[raum.feuchte].state) : null;
    var heizt = raum.klima.some(function (id) { var k = klimaStatus(zustaende[id]); return k && k.heizt; });
    // Fenster: Fensterkontakte im Raum oder das Thermostat selbst (Attribut window_open bzw. window_state)
    var fensterIds = (raum.fenster || []).filter(function (id) { return zustaende[id]; });
    var thermostatFenster = raum.klima.map(function (id) { var a = (zustaende[id] && zustaende[id].attributes) || {}; return a.window_open !== undefined ? !!a.window_open : (a.window_state !== undefined ? a.window_state === "open" : null); })
        .filter(function (x) { return x !== null; });
    var fensterBekannt = fensterIds.length > 0 || thermostatFenster.length > 0;
    var fensterOffen = fensterIds.some(function (id) { return zustaende[id].state === "on"; }) || thermostatFenster.some(function (x) { return x; });
    return {
        ist: sensor !== null ? sensor : (thermostat ? thermostat.ist : null),
        ziel: thermostat && thermostat.modus !== "off" ? thermostat.ziel : null,
        feuchte: feuchte,
        heizt: heizt,
        aus: !!thermostat && raum.klima.every(function (id) { return zustaende[id] && zustaende[id].state === "off"; }),
        fensterBekannt: fensterBekannt,
        fensterOffen: fensterOffen,
        thermostat: thermostat
    };
}

function formatTemp(t, stellen) {
    if (t === null || t === undefined || isNaN(t)) return "–";
    return t.toFixed(stellen === undefined ? 1 : stellen).replace(".", ",") + " °C";
}

/** Name eines Heizmodus bzw. Presets auf Deutsch */
function modusName(m) {
    return ({ off: "Aus", heat: "Heizen", auto: "Automatik", heat_cool: "Heizen/Kühlen", cool: "Kühlen", dry: "Entfeuchten", fan_only: "Lüfter",
              eco: "Eco", comfort: "Komfort", boost: "Boost", away: "Abwesend", home: "Zuhause", sleep: "Schlafen", activity: "Aktiv" })[m] || m;
}

/** Temperatur auf den Schritt des Thermostats runden und begrenzen */
function rundeZiel(t, k) {
    var s = (k && k.schritt) || 0.5;
    var r = Math.round(t / s) * s;
    return Math.max(k ? k.min : 5, Math.min(k ? k.max : 30, Math.round(r * 10) / 10));
}

/** Extra heizen: laufende Einträge { id, bis, vorher, modus } (bis = ms) */
function boostRest(b, jetzt) { return b ? Math.max(0, b.bis - jetzt) : 0; }
function formatDauer(ms) {
    var min = Math.ceil(ms / 60000);
    if (min < 60) return min + " min";
    var h = Math.floor(min / 60), m = min % 60;
    return m ? h + " h " + m + " min" : h + " h";
}

// ------------------------------------------------------------------ Personen

function personen(zustaende, versteckt) {
    var liste = [];
    Object.keys(zustaende).forEach(function (id) {
        if (domain(id) !== "person" || ausgeblendet(id, versteckt || [])) return;
        var e = zustaende[id], a = e.attributes || {};
        liste.push({ id: id, name: name(e), zustand: e.state, lat: zahl(a.latitude), lon: zahl(a.longitude),
                     bild: a.entity_picture || "", seit: Date.parse(e.last_changed || "") || 0 });
    });
    liste.sort(vergleicheName);
    // feste, unterschiedliche Farben in alphabetischer Reihenfolge
    liste.forEach(function (p, i) { p.farbe = PERSONEN_FARBEN[i % PERSONEN_FARBEN.length]; });
    return liste;
}
var PERSONEN_FARBEN = ["#3daee9", "#f67400", "#9b59b6", "#1cdc9a", "#da4453", "#fdbc4b", "#2980b9", "#27ae60"];

function zonen(zustaende) {
    return Object.keys(zustaende).filter(function (id) { return domain(id) === "zone"; }).map(function (id) {
        var e = zustaende[id], a = e.attributes || {};
        return { id: id, name: name(e), lat: zahl(a.latitude), lon: zahl(a.longitude), radius: zahl(a.radius) || 100, heim: id === "zone.home" };
    }).filter(function (z) { return z.lat !== null && z.lon !== null; });
}

function ortText(zustand) {
    if (zustand === "home") return "Zuhause";
    if (zustand === "not_home") return "Unterwegs";
    if (zustand === "unknown" || zustand === "unavailable") return "Unbekannt";
    return zustand;
}

/** Entfernung in km (Haversine) */
function entfernung(lat1, lon1, lat2, lon2) {
    if ([lat1, lon1, lat2, lon2].some(function (x) { return x === null || x === undefined; })) return null;
    var r = 6371, g = Math.PI / 180;
    var dLat = (lat2 - lat1) * g, dLon = (lon2 - lon1) * g;
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat1 * g) * Math.cos(lat2 * g) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return 2 * r * Math.asin(Math.sqrt(a));
}

function formatEntfernung(km) {
    if (km === null || km === undefined) return "";
    if (km < 1) return Math.round(km * 1000 / 10) * 10 + " m";
    return (km < 10 ? km.toFixed(1).replace(".", ",") : Math.round(km)) + " km";
}

/** "seit 2 h", "seit 15 min" */
function formatSeit(ms, jetzt) {
    if (!ms) return "";
    var min = Math.max(0, Math.round((jetzt - ms) / 60000));
    if (min < 1) return "gerade eben";
    if (min < 60) return "seit " + min + " min";
    var h = Math.floor(min / 60);
    if (h < 24) return "seit " + h + " h";
    return "seit " + Math.floor(h / 24) + " d";
}

/** Kartenkacheln (Web-Mercator): Längen-/Breitengrad → Kachelkoordinaten (Bruchteil) */
function kachelX(lon, zoom) { return (lon + 180) / 360 * Math.pow(2, zoom); }
function kachelY(lat, zoom) {
    var r = lat * Math.PI / 180;
    return (1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * Math.pow(2, zoom);
}

/** Zoomstufe, bei der alle Punkte in breite×hoehe Pixel (256er-Kacheln) passen */
function passenderZoom(punkte, breite, hoehe) {
    if (!punkte.length) return 13;
    for (var z = 17; z >= 2; z--) {
        var xs = punkte.map(function (p) { return kachelX(p.lon, z) * 256; });
        var ys = punkte.map(function (p) { return kachelY(p.lat, z) * 256; });
        if (Math.max.apply(null, xs) - Math.min.apply(null, xs) < breite * 0.75 && Math.max.apply(null, ys) - Math.min.apply(null, ys) < hoehe * 0.7) return Math.min(z, 16);
    }
    return 2;
}

// ------------------------------------------------------------------ Instanzen

/** Liste der Home-Assistant-Instanzen aus den Einstellungen (JSON); alte Einzel-Einstellung wird übernommen */
function instanzenLesen(json, alteAdresse, alterToken) {
    var liste = [];
    try { liste = JSON.parse(json || "[]") || []; } catch (e) { liste = []; }
    liste = liste.filter(function (i) { return i && i.adresse; });
    if (!liste.length && alteAdresse && alterToken)
        liste = [{ id: "i1", name: "Zuhause", adresse: alteAdresse, token: alterToken, favorit: true }];
    if (liste.length && !liste.some(function (i) { return i.favorit; })) liste[0].favorit = true;
    return liste;
}

function favorit(liste) {
    for (var i = 0; i < liste.length; i++) if (liste[i].favorit) return liste[i];
    return liste[0] || null;
}

function neueInstanzId(liste) {
    var n = 1;
    while (liste.some(function (i) { return i.id === "i" + n; })) n++;
    return "i" + n;
}

/** Umkehrung: Kachelkoordinaten → Längen-/Breitengrad */
function lonAusX(x, zoom) { return x / Math.pow(2, zoom) * 360 - 180; }
function latAusY(y, zoom) {
    var n = Math.PI * (1 - 2 * y / Math.pow(2, zoom));
    return Math.atan((Math.exp(n) - Math.exp(-n)) / 2) * 180 / Math.PI;
}

/** Gleichbleibende Farbe je Person (aus dem Namen) */
function personFarbe(name) {
    var farben = ["#3daee9", "#f67400", "#1cdc9a", "#da4453", "#9b59b6", "#fdbc4b", "#2980b9", "#27ae60"];
    var h = 0;
    for (var i = 0; i < (name || "").length; i++) h = (h * 31 + name.charCodeAt(i)) % 997;
    return farben[h % farben.length];
}

function initialen(name) {
    var teile = (name || "?").trim().split(/\s+/);
    return ((teile[0] || "?")[0] + (teile.length > 1 ? teile[teile.length - 1][0] : "")).toUpperCase();
}


/**
 * Heizungsverlauf aus der History-API: Ist-Temperatur (Raumsensor, sonst Thermostat),
 * Zieltemperatur und Zeiten, in denen geheizt wurde.
 * antwort: Liste von Listen (je Entität), ende: jetzt (ms)
 */
function klimaVerlauf(antwort, klimaId, sensorId, ende) {
    var jeEntitaet = {};
    (antwort || []).forEach(function (l) { if (l && l.length && l[0].entity_id) jeEntitaet[l[0].entity_id] = l; });
    var klima = jeEntitaet[klimaId] || [], sensor = sensorId ? (jeEntitaet[sensorId] || []) : [];
    var ist = [], ziel = [], heizen = [], von = null;
    klima.forEach(function (p) {
        var t = Date.parse(p.last_changed || p.last_updated || "");
        if (isNaN(t)) return;
        var a = p.attributes || {};
        var zt = p.state === "off" ? null : zahl(a.temperature);
        if (zt !== null) ziel.push({ t: t, w: zt });
        if (!sensor.length && zahl(a.current_temperature) !== null) ist.push({ t: t, w: zahl(a.current_temperature) });
        var h = a.hvac_action === "heating" || a.hvac_action === "preheating";
        if (h && von === null) von = t;
        if (!h && von !== null) { heizen.push({ von: von, bis: t }); von = null; }
    });
    if (von !== null) heizen.push({ von: von, bis: ende });
    sensor.forEach(function (p) {
        var t = Date.parse(p.last_changed || ""), w = zahl(p.state);
        if (!isNaN(t) && w !== null) ist.push({ t: t, w: w });
    });
    return { ist: ist, ziel: ziel, heizen: heizen };
}

// ------------------------------------------------------------------ Updates

/** Versionen vergleichen ("2.10.1" > "2.9") */
function versionNeuer(a, b) {
    var x = String(a).replace(/^v/, "").split(/[.-]/).map(function (n) { return parseInt(n, 10) || 0; });
    var y = String(b).replace(/^v/, "").split(/[.-]/).map(function (n) { return parseInt(n, 10) || 0; });
    for (var i = 0; i < Math.max(x.length, y.length); i++) {
        if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
    }
    return false;
}

/** Aus der Release-Liste von GitHub: alle neueren Versionen mit Änderungen und die Download-Adresse */
function updateAusReleases(releases, aktuell, dateiname) {
    var neuer = (releases || []).filter(function (r) { return r && !r.draft && !r.prerelease && versionNeuer(r.tag_name, aktuell); });
    neuer.sort(function (a, b) { return versionNeuer(a.tag_name, b.tag_name) ? -1 : 1; });
    if (!neuer.length) return null;
    var asset = (neuer[0].assets || []).filter(function (a) { return a.name === dateiname || (dateiname.indexOf("*") >= 0 && new RegExp("^" + dateiname.replace(/[.]/g, "\\.").replace("*", ".*") + "$").test(a.name)); })[0];
    var url = asset ? asset.browser_download_url : "";
    // nur Downloads aus diesem Projekt auf GitHub
    if (url && url.indexOf("https://github.com/Teyro/homeassistant-leiste/releases/download/") !== 0) url = "";
    return {
        version: neuer[0].tag_name.replace(/^v/, ""),
        url: url,
        seite: neuer[0].html_url || "https://github.com/Teyro/homeassistant-leiste/releases",
        notizen: neuer.map(function (r) { return { version: r.tag_name.replace(/^v/, ""), titel: r.name || r.tag_name, text: r.body || "" }; })
    };
}

return { BEREICHE_TEMPLATE, EINSTELLUNGS_SCHALTER, domain, name, messName, istAn, istVerfuegbar, helligkeit, dimmbar, hex2, lampenFarbe, ausgeblendet, vergleicheName, baueModell, gruppenStatus, gruppenFarbe, formatWatt, formatKwh, verlaufPunkte, achsenSchritt, schalterGruppenStatus, wattVon, relevant, verlaufKennzahlen, VERBRAUCH_ARTEN, zaehlerAusEnergieDashboard, tagesVerbrauch, formatMenge, heizungen, zahl, klimaStatus, raumKlima, formatTemp, modusName, rundeZiel, boostRest, formatDauer, personen, PERSONEN_FARBEN, zonen, ortText, entfernung, formatEntfernung, formatSeit, kachelX, kachelY, passenderZoom, instanzenLesen, favorit, neueInstanzId, lonAusX, latAusY, personFarbe, initialen, klimaVerlauf, versionNeuer, updateAusReleases };
})();

// ---------------------------------------------------------------- Farben und Schrift

// Nutzbare Breite in mittleren/großen Widgets (kleinstes iPhone 329 pt minus Rand)
const INNEN = 300;

const F = {
  text: Color.dynamic(new Color("#1c1c1e"), new Color("#ffffff")),
  leise: Color.dynamic(new Color("#6e6e73"), new Color("#a1a1a6")),
  karte: Color.dynamic(new Color("#ffffff", 0.62), new Color("#ffffff", 0.09)),
  akzent: new Color("#0a84ff"),
  gelb: new Color("#ffc65c"),
  orange: new Color("#ff9f0a"),
  blau: new Color("#64d2ff"),
  gruen: new Color("#30d158"),
  rot: new Color("#ff453a"),
  aus: Color.dynamic(new Color("#8e8e93", 0.35), new Color("#8e8e93", 0.45)),
};

function hintergrund(art) {
  // Ruhige Verläufe, je nach Inhalt leicht getönt (hell/dunkel automatisch)
  const toene = {
    lampen: ["#fff6e5", "#ffe9c7", "#2a2116", "#1a140d"],
    heizung: ["#fff1e6", "#ffe0cc", "#2b1a12", "#170e0a"],
    energie: ["#eef6ff", "#dceeff", "#10202f", "#0b1520"],
    personen: ["#ecfbf1", "#d7f5e2", "#0f241a", "#09160f"],
    standard: ["#f2f4fb", "#e3e8f6", "#1c1f2e", "#10121c"],
  };
  const t = toene[art] || toene.standard;
  const g = new LinearGradient();
  g.colors = [Color.dynamic(new Color(t[0]), new Color(t[2])), Color.dynamic(new Color(t[1]), new Color(t[3]))];
  g.locations = [0, 1];
  g.startPoint = new Point(0, 0);
  g.endPoint = new Point(1, 1);
  return g;
}

function symbol(name, groesse, farbe) {
  const s = SFSymbol.named(name) || SFSymbol.named("questionmark.circle");
  s.applyFont(Font.semiboldSystemFont(groesse));
  const bild = s.image;
  bild._symbol = name;
  return { bild, groesse, farbe };
}

function bildEinfuegen(stack, s) {
  const i = stack.addImage(s.bild);
  i.imageSize = new Size(s.groesse, s.groesse);
  if (s.farbe) i.tintColor = s.farbe;
  return i;
}

function text(stack, inhalt, font, farbe, opts = {}) {
  const t = stack.addText(String(inhalt));
  t.font = font;
  t.textColor = farbe || F.text;
  if (opts.zeilen !== undefined) t.lineLimit = opts.zeilen;
  if (opts.min) t.minimumScaleFactor = opts.min;
  if (opts.mitte) t.centerAlignText();
  if (opts.rechts) t.rightAlignText();
  return t;
}

function zeile(eltern, abstand = 4) {
  const s = eltern.addStack();
  s.layoutHorizontally();
  s.centerAlignContent();
  s.spacing = abstand;
  return s;
}

function spalte(eltern, abstand = 2) {
  const s = eltern.addStack();
  s.layoutVertically();
  s.spacing = abstand;
  return s;
}

/** Abgerundete Karte (leicht durchscheinend) */
function karte(eltern, pad = 8) {
  const k = eltern.addStack();
  k.layoutVertically();
  k.backgroundColor = F.karte;
  k.cornerRadius = 14;
  k.setPadding(pad, pad + 2, pad, pad + 2);
  return k;
}

/** Runder Kreis mit Symbol (wie im Kontrollzentrum) */
function symbolKreis(eltern, name, farbe, groesse = 26) {
  const k = eltern.addStack();
  k.size = new Size(groesse, groesse);
  k.cornerRadius = groesse / 2;
  k.backgroundColor = farbe ? farbe : F.aus;
  k.centerAlignContent();
  k.addSpacer();
  bildEinfuegen(k, symbol(name, groesse * 0.5, farbe ? new Color("#000000", 0.65) : F.text));
  k.addSpacer();
  return k;
}

function farbeAusHex(hex) { return hex ? new Color(hex) : null; }

// ---------------------------------------------------------------- Instanzen und Zwischenspeicher

function instanzenLaden() {
  try { return JSON.parse(Keychain.contains(SCHLUESSEL) ? Keychain.get(SCHLUESSEL) : "[]") || []; } catch (e) { return []; }
}
function instanzenSpeichern(liste) { Keychain.set(SCHLUESSEL, JSON.stringify(liste)); }

function instanzWaehlen(liste, name) {
  if (name) {
    const n = name.toLowerCase();
    const i = liste.find((x) => (x.name || "").toLowerCase() === n || x.id === name);
    if (i) return i;
  }
  return liste.find((x) => x.favorit) || liste[0] || null;
}

const fm = FileManager.local();
const cacheOrdner = fm.joinPath(fm.documentsDirectory(), "ha-leiste");
function cacheDatei(instanz) { return fm.joinPath(cacheOrdner, instanz.id + ".json"); }
function cacheLesen(instanz) {
  try {
    const d = cacheDatei(instanz);
    return fm.fileExists(d) ? JSON.parse(fm.readString(d)) : {};
  } catch (e) { return {}; }
}
function cacheSchreiben(instanz, c) {
  if (!fm.fileExists(cacheOrdner)) fm.createDirectory(cacheOrdner, true);
  fm.writeString(cacheDatei(instanz), JSON.stringify(c));
}

// ---------------------------------------------------------------- Home Assistant

async function ha(instanz, methode, pfad, daten, sekunden = 12) {
  const r = new Request(instanz.adresse.replace(/\/+$/, "") + pfad);
  r.method = methode;
  r.timeoutInterval = sekunden;
  r.headers = { Authorization: "Bearer " + instanz.token, "Content-Type": "application/json" };
  if (daten !== undefined) r.body = JSON.stringify(daten);
  const text = await r.loadString();
  const status = r.response ? r.response.statusCode : 0;
  if (status === 401 || status === 403) throw new Error("Zugriff verweigert – Token prüfen");
  if (status < 200 || status >= 300) throw new Error("Fehler " + status + " von Home Assistant");
  try { return text ? JSON.parse(text) : null; } catch (e) { return text; }
}

function zeitstempel(min) { return new Date(Date.now() - min * 60000).toISOString(); }

/**
 * Daten holen – akkuschonend: Zustände einmal je Aufruf, Räume 1× am Tag, Verläufe höchstens
 * alle 30 Minuten. Ohne Netz bleibt der letzte Stand (mit Uhrzeit) stehen.
 */
async function datenLaden(instanz, bedarf = {}) {
  const c = cacheLesen(instanz);
  const jetzt = Date.now();
  c.fehler = "";
  try {
    const liste = await ha(instanz, "GET", "/api/states");
    const z = {};
    for (const e of liste || []) if (Logik.relevant(e.entity_id, e, instanz.hauptzaehler || "")) z[e.entity_id] = e;
    c.zustaende = z;
    c.stand = jetzt;
    if (!c.bereiche || jetzt - (c.bereicheStand || 0) > 24 * 3600e3) {
      try {
        const t = await ha(instanz, "POST", "/api/template", { template: Logik.BEREICHE_TEMPLATE });
        c.bereiche = typeof t === "string" ? JSON.parse(t) : t;
      } catch (e) { c.bereiche = c.bereiche || { bereiche: [], leistung: [], geraete: [] }; }
      try {
        const cfg = await ha(instanz, "GET", "/api/config");
        c.standort = cfg && cfg.location_name;
      } catch (e) { /* egal */ }
      c.bereicheStand = jetzt;
    }
    if (bedarf.verlauf && instanz.hauptzaehler && jetzt - (c.verlaufStand || 0) > 30 * 60e3) {
      try {
        const v = await ha(instanz, "GET", "/api/history/period/" + encodeURIComponent(zeitstempel(24 * 60))
          + "?filter_entity_id=" + encodeURIComponent(instanz.hauptzaehler) + "&minimal_response&no_attributes");
        const e = z[instanz.hauptzaehler];
        c.verlauf = Logik.verlaufPunkte(v, e && e.attributes && e.attributes.unit_of_measurement === "kW");
        c.verlaufStand = jetzt;
      } catch (e) { /* alter Verlauf bleibt */ }
    }
    if (bedarf.tage && jetzt - (c.tageStand || 0) > 30 * 60e3) {
      c.tage = await tagesVerbrauchLaden(instanz, z) || c.tage;
      c.tageStand = jetzt;
    }
    if (bedarf.klima) {
      c.klima = c.klima || {};
      const alt = c.klima[bedarf.klima.id];
      if (!alt || jetzt - alt.stand > 30 * 60e3) {
        const ids = [bedarf.klima.klima[0], bedarf.klima.temperatur].filter((x) => x);
        try {
          const v = await ha(instanz, "GET", "/api/history/period/" + encodeURIComponent(zeitstempel(24 * 60))
            + "?filter_entity_id=" + encodeURIComponent(ids.join(",")) + "&significant_changes_only=0");
          c.klima[bedarf.klima.id] = { daten: Logik.klimaVerlauf(v, bedarf.klima.klima[0] || "", bedarf.klima.temperatur, jetzt), stand: jetzt };
        } catch (e) { /* alter Verlauf bleibt */ }
      }
    }
    if (c.standort && !instanz.name) {
      // Ohne eigenen Namen den Namen der Installation übernehmen
      const liste2 = instanzenLaden();
      const i = liste2.find((x) => x.id === instanz.id);
      if (i && !i.name) { i.name = c.standort; instanzenSpeichern(liste2); instanz.name = c.standort; }
    }
    cacheSchreiben(instanz, c);
  } catch (e) {
    c.fehler = String(e.message || e);
  }
  return c;
}

/** Zähler für Strom/Wasser/Gas: eigene Wahl, sonst der passendste Zählerstand */
function zaehlerFinden(instanz, z) {
  const ergebnis = {};
  for (const [art, klasse, einheiten] of [["strom", "energy", ["kWh", "Wh", "MWh"]], ["wasser", "water", null], ["gas", "gas", null]]) {
    const eigen = instanz.zaehler && instanz.zaehler[art];
    if (eigen && z[eigen]) { ergebnis[art] = eigen; continue; }
    const alle = Object.values(z).filter((e) => e.entity_id.startsWith("sensor.") && e.attributes.device_class === klasse
      && (!einheiten || einheiten.includes(e.attributes.unit_of_measurement)));
    // Zählerstände (total_increasing) bevorzugen, Tageswerte ("heute") meiden
    const zaehler = alle.filter((e) => /^total/.test(e.attributes.state_class || "") && !/(heute|today|daily|tag)/i.test(Logik.name(e)));
    const kandidaten = zaehler.length ? zaehler : alle;
    const bester = kandidaten.find((e) => /(bezug|import|netz|grid|zähler|meter|haus|gesamt|total)/i.test(Logik.name(e))) || kandidaten[0];
    if (bester) ergebnis[art] = bester.entity_id;
  }
  return ergebnis;
}

async function tagesVerbrauchLaden(instanz, z) {
  const zaehler = zaehlerFinden(instanz, z);
  const ids = Object.values(zaehler);
  if (!ids.length) return null;
  const mitternacht = new Date(); mitternacht.setHours(0, 0, 0, 0);
  const start = new Date(mitternacht.getTime() - 86400000).toISOString();
  try {
    const v = await ha(instanz, "GET", "/api/history/period/" + encodeURIComponent(start) + "?filter_entity_id="
      + encodeURIComponent(ids.join(",")) + "&minimal_response&no_attributes", undefined, 20);
    const je = {};
    for (const l of v || []) if (l && l.length && l[0].entity_id) je[l[0].entity_id] = l;
    const tage = {};
    for (const [art, id] of Object.entries(zaehler)) {
      const t = Logik.tagesVerbrauch(je[id], mitternacht.getTime());
      if (t) tage[art] = { heute: t.heute, gestern: t.gestern, einheit: z[id].attributes.unit_of_measurement || "" };
    }
    return tage;
  } catch (e) { return null; }
}

/** Anzeigemodell aus dem Zwischenspeicher */
function modell(instanz, c) {
  const z = c.zustaende || {};
  const m = Logik.baueModell(z, c.bereiche || null, { alteGruppen: true, hauptzaehler: instanz.hauptzaehler || "", ausgeblendet: instanz.ausgeblendet || "" });
  m.heizungen = Logik.heizungen(z, c.bereiche || null, []);
  m.personen = Logik.personen(z, []);
  m.zonen = Logik.zonen(z);
  m.watt = m.hauptWatt !== null ? m.hauptWatt : (m.leistung.length ? m.summeWatt : null);
  m.heizen = m.heizungen.filter((r) => Logik.raumKlima(r, z).heizt).length;
  const temps = m.heizungen.map((r) => Logik.raumKlima(r, z).ist).filter((t) => t !== null);
  m.schnitt = temps.length ? temps.reduce((a, b) => a + b, 0) / temps.length : null;
  m.zuhause = m.personen.filter((p) => p.zustand === "home");
  m.z = z;
  return m;
}

// ---------------------------------------------------------------- Widgets

function aktionsURL(aktion, werte) {
  let u = "scriptable:///run/" + encodeURIComponent(Script.name()) + "?aktion=" + aktion;
  for (const [k, v] of Object.entries(werte || {})) u += "&" + k + "=" + encodeURIComponent(v);
  return u;
}

function kopf(w, symbolName, titel, rechts, farbe) {
  const k = zeile(w, 5);
  bildEinfuegen(k, symbol(symbolName, 12, farbe || F.leise));
  text(k, titel, Font.semiboldSystemFont(12), F.leise, { zeilen: 1 });
  k.addSpacer();
  if (rechts) text(k, rechts, Font.mediumSystemFont(11), F.leise, { zeilen: 1 });
  return k;
}

function standZeile(w, c, nurBeiFehler) {
  if (nurBeiFehler && !c.fehler) return;
  const s = zeile(w, 3);
  if (c.fehler) {
    bildEinfuegen(s, symbol("exclamationmark.triangle.fill", 9, F.orange));
    text(s, c.stand ? "Stand " + uhrzeit(c.stand) : c.fehler, Font.mediumSystemFont(9), F.orange, { zeilen: 1 });
  } else {
    text(s, "Stand " + uhrzeit(c.stand || Date.now()), Font.mediumSystemFont(9), F.leise, { zeilen: 1 });
  }
}

function uhrzeit(ms) {
  const d = new Date(ms);
  return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
}

/** Kleine Linie (Verlauf) als Bild */
function sparkline(punkte, breite, hoehe, farbe, flaeche = true) {
  const d = new DrawContext();
  d.size = new Size(breite, hoehe);
  d.opaque = false;
  d.respectScreenScale = true;
  if (!punkte || punkte.length < 2) return d.getImage();
  const t0 = punkte[0].t, t1 = punkte[punkte.length - 1].t || t0 + 1;
  const max = Math.max(...punkte.map((p) => p.w)) || 1, min = Math.min(0, ...punkte.map((p) => p.w));
  const x = (t) => (t - t0) / Math.max(1, t1 - t0) * (breite - 2) + 1;
  const y = (w) => hoehe - 2 - (w - min) / Math.max(1e-9, max - min) * (hoehe - 4);
  const pfad = new Path();
  pfad.move(new Point(x(punkte[0].t), y(punkte[0].w)));
  for (let i = 1; i < punkte.length; i++) {
    pfad.addLine(new Point(x(punkte[i].t), y(punkte[i - 1].w)));
    pfad.addLine(new Point(x(punkte[i].t), y(punkte[i].w)));
  }
  if (flaeche) {
    const f = new Path();
    f.move(new Point(x(punkte[0].t), hoehe));
    f.addLine(new Point(x(punkte[0].t), y(punkte[0].w)));
    for (let i = 1; i < punkte.length; i++) {
      f.addLine(new Point(x(punkte[i].t), y(punkte[i - 1].w)));
      f.addLine(new Point(x(punkte[i].t), y(punkte[i].w)));
    }
    f.addLine(new Point(x(punkte[punkte.length - 1].t), hoehe));
    f.closeSubpath();
    d.addPath(f);
    d.setFillColor(new Color(farbe.hex, 0.22));
    d.fillPath();
  }
  d.addPath(pfad);
  d.setStrokeColor(farbe);
  d.setLineWidth(2);
  d.strokePath();
  return d.getImage();
}

/** Heizungsverlauf: Ist (blau), Ziel (orange), Heizphasen (orange hinterlegt) */
function klimaBild(daten, breite, hoehe) {
  const d = new DrawContext();
  d.size = new Size(breite, hoehe);
  d.opaque = false;
  d.respectScreenScale = true;
  if (!daten || (!daten.ist.length && !daten.ziel.length)) return d.getImage();
  const ende = Date.now(), anfang = ende - 86400000;
  const werte = daten.ist.concat(daten.ziel).map((p) => p.w);
  const lo = Math.floor(Math.min(...werte) - 0.5), hi = Math.ceil(Math.max(...werte) + 0.5);
  const x = (t) => (Math.max(t, anfang) - anfang) / (ende - anfang) * breite;
  const y = (w) => hoehe - 2 - (w - lo) / Math.max(1, hi - lo) * (hoehe - 4);
  d.setFillColor(new Color("#ff9f0a", 0.18));
  for (const h of daten.heizen) d.fillRect(new Rect(x(h.von), 0, Math.max(1, x(h.bis) - x(h.von)), hoehe));
  const linie = (liste, farbe, breiteL, treppe) => {
    const p = new Path();
    let vorher = null;
    liste.filter((q) => q.t >= anfang - 3600e3).forEach((q, i) => {
      if (i === 0) p.move(new Point(x(q.t), y(q.w)));
      else { if (treppe) p.addLine(new Point(x(q.t), y(vorher))); p.addLine(new Point(x(q.t), y(q.w))); }
      vorher = q.w;
    });
    if (vorher !== null) p.addLine(new Point(breite, y(vorher)));
    d.addPath(p);
    d.setStrokeColor(farbe);
    d.setLineWidth(breiteL);
    d.strokePath();
  };
  linie(daten.ziel, new Color("#ff9f0a"), 1.5, true);
  linie(daten.ist, new Color("#0a84ff"), 2, false);
  return d.getImage();
}

// ---- Übersicht ----
function widgetUebersicht(w, familie, instanz, c, m) {
  w.backgroundGradient = hintergrund("standard");
  w.url = aktionsURL("dashboard", { instanz: instanz.id });
  const name = instanz.name || "Zuhause";
  if (familie === "small") {
    kopf(w, "house.fill", name);
    w.addSpacer(6);
    const r = zeile(w, 6);
    symbolKreis(r, "lightbulb.fill", m.lichterAn ? F.gelb : null, 30);
    const s = spalte(r, 0);
    text(s, String(m.lichterAn), Font.boldRoundedSystemFont(26), F.text);
    text(s, m.lichterAn === 1 ? "Lampe an" : "Lampen an", Font.mediumSystemFont(11), F.leise);
    w.addSpacer();
    if (m.heizungen.length) infoZeile(w, m.heizen ? "flame.fill" : "heater.vertical", m.heizen ? F.orange : F.leise,
      (m.heizen ? m.heizen + " heizen" : "Heizung ruht") + (m.schnitt !== null ? " · " + Logik.formatTemp(m.schnitt) : ""));
    if (m.watt !== null) infoZeile(w, "bolt.fill", F.gelb, Logik.formatWatt(m.watt));
    if (m.personen.length) infoZeile(w, "person.2.fill", F.gruen, m.zuhause.length + " zu Hause");
    return;
  }
  kopf(w, "house.fill", name, c.fehler ? "offline" : "", F.leise);
  w.addSpacer(8);
  const raster = zeile(w, 8);
  raster.addSpacer();
  const anzahl = 1 + (m.heizungen.length ? 1 : 0) + (m.watt !== null ? 1 : 0) + (m.personen.length ? 1 : 0);
  const kachelBreite = Math.floor((INNEN - 8 * (anzahl - 1)) / anzahl);
  const kachel = (sym, farbe, wert, label, url) => {
    const k = karte(raster, 8);
    k.size = new Size(kachelBreite, 0);
    if (url) k.url = url;
    const o = zeile(k, 4);
    bildEinfuegen(o, symbol(sym, 13, farbe));
    o.addSpacer();
    k.addSpacer(4);
    text(k, wert, Font.boldRoundedSystemFont(familie === "large" ? 22 : 18), F.text, { zeilen: 1, min: 0.6 });
    text(k, label, Font.mediumSystemFont(10), F.leise, { zeilen: 1, min: 0.7 });
  };
  kachel("lightbulb.fill", m.lichterAn ? F.gelb : F.leise, String(m.lichterAn), "Lampen an", aktionsURL("dashboard", { reiter: "lampen", instanz: instanz.id }));
  if (m.heizungen.length) kachel(m.heizen ? "flame.fill" : "heater.vertical.fill", m.heizen ? F.orange : F.leise, Logik.formatTemp(m.schnitt), m.heizen ? m.heizen + " heizen" : "ruht", aktionsURL("dashboard", { reiter: "heizung", instanz: instanz.id }));
  if (m.watt !== null) kachel("bolt.fill", F.gelb, Logik.formatWatt(m.watt), "jetzt", aktionsURL("dashboard", { reiter: "energie", instanz: instanz.id }));
  if (m.personen.length) kachel("person.2.fill", F.gruen, m.zuhause.length + "/" + m.personen.length, "zu Hause", aktionsURL("dashboard", { reiter: "personen", instanz: instanz.id }));
  raster.addSpacer();

  if (familie === "large") {
    w.addSpacer(10);
    const unten = zeile(w, 8);
    unten.topAlignContent();
    unten.addSpacer();
    // Heizung je Raum
    const halbe = Math.floor((INNEN - 8) / 2);
    const links = karte(unten, 8);
    links.size = new Size(halbe, 0);
    text(links, "Räume", Font.semiboldSystemFont(11), F.leise);
    links.addSpacer(4);
    for (const r of m.heizungen.slice(0, 6)) {
      const k = Logik.raumKlima(r, m.z);
      const z2 = zeile(links, 6);
      text(z2, r.name, Font.mediumSystemFont(12), F.text, { zeilen: 1, min: 0.8 });
      if (k.fensterOffen) bildEinfuegen(z2, symbol("window.vertical.open", 10, F.blau));
      z2.addSpacer();
      if (k.heizt) bildEinfuegen(z2, symbol("flame.fill", 10, F.orange));
      text(z2, Logik.formatTemp(k.ist), Font.semiboldRoundedSystemFont(12), F.text, { zeilen: 1 });
      links.addSpacer(3);
    }
    // Lampen an + Personen
    const rechts = karte(unten, 8);
    rechts.size = new Size(halbe, 0);
    text(rechts, "An", Font.semiboldSystemFont(11), F.leise);
    rechts.addSpacer(4);
    const an = m.lichter.filter((id) => Logik.istAn(m.z[id])).slice(0, 5);
    if (!an.length) text(rechts, "Alle Lampen aus", Font.mediumSystemFont(12), F.leise);
    for (const id of an) {
      const z2 = zeile(rechts, 5);
      const punkt = z2.addStack();
      punkt.size = new Size(8, 8);
      punkt.cornerRadius = 4;
      punkt.backgroundColor = farbeAusHex(Logik.lampenFarbe(m.z[id])) || F.gelb;
      text(z2, Logik.name(m.z[id]), Font.mediumSystemFont(12), F.text, { zeilen: 1 });
      rechts.addSpacer(3);
    }
    if (m.personen.length) {
      rechts.addSpacer(4);
      const p = zeile(rechts, 3);
      for (const person of m.personen.slice(0, 5)) personPunkt(p, person, 20);
    }
    unten.addSpacer();
    w.addSpacer(8);
    if (c.verlauf && c.verlauf.length > 2) {
      const sp = w.addImage(sparkline(c.verlauf, 300, 36, F.akzent));
      sp.imageSize = new Size(300, 36);
    }
  }
  w.addSpacer();
  standZeile(w, c);
}

function infoZeile(w, sym, farbe, inhalt) {
  const z = zeile(w, 5);
  bildEinfuegen(z, symbol(sym, 11, farbe));
  text(z, inhalt, Font.mediumSystemFont(12), F.text, { zeilen: 1, min: 0.7 });
  w.addSpacer(2);
}

function personPunkt(eltern, p, groesse) {
  const k = eltern.addStack();
  k.size = new Size(groesse, groesse);
  k.cornerRadius = groesse / 2;
  k.backgroundColor = new Color(p.farbe);
  k.centerAlignContent();
  k.addSpacer();
  text(k, Logik.initialen(p.name), Font.boldSystemFont(groesse * 0.42), Color.white());
  k.addSpacer();
}

// ---- Lampen ----
function widgetLampen(w, familie, instanz, c, m) {
  w.backgroundGradient = hintergrund("lampen");
  w.url = aktionsURL("dashboard", { reiter: "lampen", instanz: instanz.id });
  const max = familie === "large" ? 9 : familie === "medium" ? 4 : 3;
  kopf(w, "lightbulb.fill", "Lampen", m.lichterAn + " von " + m.lichter.length + " an", F.gelb);
  w.addSpacer(6);
  // Gruppen zuerst, dann die eingeschalteten, dann der Rest
  const ids = m.gruppen.map((g) => g.id).concat(m.lichter.filter((id) => Logik.istAn(m.z[id])), m.lichter.filter((id) => !Logik.istAn(m.z[id])));
  if (familie === "small") {
    for (const id of ids.slice(0, max)) {
      const z2 = zeile(w, 6);
      z2.url = aktionsURL("schalte", { id, an: Logik.istAn(m.z[id]) ? "0" : "1", instanz: instanz.id });
      symbolKreis(z2, Logik.istAn(m.z[id]) ? "lightbulb.fill" : "lightbulb", farbeAusHex(Logik.lampenFarbe(m.z[id])), 20);
      text(z2, Logik.name(m.z[id]), Font.mediumSystemFont(12), F.text, { zeilen: 1 });
      w.addSpacer(4);
    }
    w.addSpacer();
    standZeile(w, c);
    return;
  }
  for (const id of ids.slice(0, max)) {
    const e = m.z[id];
    const an = Logik.istAn(e);
    const k = karte(w, familie === "medium" ? 4 : 6);
    k.url = aktionsURL("schalte", { id, an: an ? "0" : "1", instanz: instanz.id });
    const z2 = zeile(k, 8);
    symbolKreis(z2, (e.attributes || {}).entity_id ? "lightbulb.2.fill" : an ? "lightbulb.fill" : "lightbulb", farbeAusHex(Logik.lampenFarbe(e)), 24);
    const s = spalte(z2, 0);
    text(s, Logik.name(e), Font.semiboldSystemFont(13), F.text, { zeilen: 1 });
    text(s, !Logik.istVerfuegbar(e) ? "nicht erreichbar" : !an ? "aus" : Logik.dimmbar(e) ? "an · " + Logik.helligkeit(e) + " %" : "an",
      Font.mediumSystemFont(10), F.leise, { zeilen: 1 });
    z2.addSpacer();
    schalterBild(z2, an);
    w.addSpacer(familie === "medium" ? 4 : 5);
  }
  w.addSpacer();
  standZeile(w, c, familie === "medium");
}

/** Kleiner Schalter als Bild (Widgets können keine echten Schalter) */
function schalterBild(eltern, an) {
  const d = new DrawContext();
  d.size = new Size(36, 22);
  d.opaque = false;
  d.respectScreenScale = true;
  const p = new Path();
  p.addRoundedRect(new Rect(0, 0, 36, 22), 11, 11);
  d.addPath(p);
  d.setFillColor(an ? new Color("#30d158") : new Color("#8e8e93", 0.45));
  d.fillPath();
  d.setFillColor(Color.white());
  d.fillEllipse(new Rect(an ? 16 : 2, 2, 18, 18));
  const i = eltern.addImage(d.getImage());
  i.imageSize = new Size(30, 18);
}

// ---- Heizung ----
function widgetHeizung(w, familie, instanz, c, m, ziel) {
  w.backgroundGradient = hintergrund("heizung");
  const raeume = ziel ? m.heizungen.filter((r) => passt(r, ziel)) : m.heizungen;
  w.url = aktionsURL("dashboard", { reiter: "heizung", instanz: instanz.id });
  if (!raeume.length) return hinweis(w, "Keine Heizung gefunden", ziel ? "„" + ziel + "“ gibt es nicht." : "In Home Assistant fehlen Thermostate.");
  if (familie === "small" || (ziel && raeume.length === 1)) {
    const r = raeume[0];
    const k = Logik.raumKlima(r, m.z);
    kopf(w, k.heizt ? "flame.fill" : "heater.vertical.fill", r.name, k.feuchte !== null ? Math.round(k.feuchte) + " %" : "", k.heizt ? F.orange : F.leise);
    if (familie === "large") w.addSpacer(10); else w.addSpacer();
    text(w, Logik.formatTemp(k.ist), Font.boldRoundedSystemFont(familie === "small" ? 32 : 40), F.text, { zeilen: 1, min: 0.6 });
    const z2 = zeile(w, 4);
    if (k.fensterOffen) { bildEinfuegen(z2, symbol("window.vertical.open", 11, F.blau)); text(z2, "Fenster offen", Font.semiboldSystemFont(11), F.blau); }
    else text(z2, !r.klima.length ? "Temperatur" : k.aus ? "Heizung aus" : k.heizt ? "heizt auf " + Logik.formatTemp(k.ziel) : "Ziel " + Logik.formatTemp(k.ziel),
      Font.semiboldSystemFont(11), k.heizt ? F.orange : F.leise, { zeilen: 1 });
    if (familie === "large" && r.klima.length) {
      const t = k.thermostat;
      const z3 = zeile(w, 10);
      for (const [titel, wert] of [["Ziel", k.ziel !== null ? Logik.formatTemp(k.ziel) : "aus"], ["Luftfeuchte", k.feuchte !== null ? Math.round(k.feuchte) + " %" : "–"],
                                   ["Modus", t ? Logik.modusName(t.preset || t.modus) : "–"]]) {
        const kk = karte(z3, 6);
        kk.size = new Size(Math.floor((INNEN - 20) / 3), 0);
        text(kk, titel, Font.mediumSystemFont(10), F.leise);
        text(kk, wert, Font.semiboldRoundedSystemFont(14), F.text, { zeilen: 1, min: 0.7 });
      }
    }
    if (familie !== "small") {
      w.addSpacer(6);
      const v = c.klima && c.klima[r.id];
      if (v) { const b = w.addImage(klimaBild(v.daten, 300, familie === "large" ? 120 : 44)); b.imageSize = new Size(300, familie === "large" ? 120 : 44); }
    }
    w.addSpacer();
    standZeile(w, c);
    return;
  }
  kopf(w, "heater.vertical.fill", "Heizung", m.heizen ? m.heizen + " heizen" : "ruht", m.heizen ? F.orange : F.leise);
  w.addSpacer(6);
  const max = familie === "large" ? 8 : 3;
  for (const r of raeume.slice(0, max)) {
    const k = Logik.raumKlima(r, m.z);
    const kk = karte(w, familie === "medium" ? 4 : 6);
    const z2 = zeile(kk, 6);
    symbolKreis(z2, r.klima.length ? "heater.vertical.fill" : "thermometer.medium", k.heizt ? F.orange : null, 22);
    const s = spalte(z2, 0);
    const n = zeile(s, 4);
    text(n, r.name, Font.semiboldSystemFont(12), F.text, { zeilen: 1 });
    if (k.fensterBekannt) bildEinfuegen(n, symbol(k.fensterOffen ? "window.vertical.open" : "window.vertical.closed", 10, k.fensterOffen ? F.blau : F.leise));
    text(s, k.fensterOffen ? "Fenster offen" : !r.klima.length ? "Temperatur" : k.aus ? "aus" : k.heizt ? "heizt auf " + Logik.formatTemp(k.ziel) : "Ziel " + Logik.formatTemp(k.ziel),
      Font.mediumSystemFont(10), k.fensterOffen ? F.blau : k.heizt ? F.orange : F.leise, { zeilen: 1 });
    z2.addSpacer();
    text(z2, Logik.formatTemp(k.ist), Font.boldRoundedSystemFont(16), F.text);
    w.addSpacer(4);
  }
  w.addSpacer();
  standZeile(w, c, familie === "medium");
}

// ---- Energie ----
function widgetEnergie(w, familie, instanz, c, m) {
  w.backgroundGradient = hintergrund("energie");
  w.url = aktionsURL("dashboard", { reiter: "energie", instanz: instanz.id });
  kopf(w, "bolt.fill", "Verbrauch gerade", "", F.gelb);
  w.addSpacer(2);
  text(w, Logik.formatWatt(m.watt), Font.boldRoundedSystemFont(familie === "small" ? 28 : 32), F.text, { zeilen: 1, min: 0.6 });
  if (c.verlauf && c.verlauf.length > 2) {
    const b = w.addImage(sparkline(c.verlauf, familie === "small" ? 130 : 300, familie === "large" ? 70 : 30, F.akzent));
    b.imageSize = new Size(familie === "small" ? 130 : 300, familie === "large" ? 70 : 30);
  } else if (!instanz.hauptzaehler) {
    text(w, "Tipp: Hauptzähler in den Einstellungen wählen", Font.mediumSystemFont(9), F.leise, { zeilen: 2 });
  }
  if (familie !== "small" && c.tage && Object.keys(c.tage).length) {
    w.addSpacer(6);
    const r = zeile(w, 6);
    for (const [art, sym, farbe, titel] of [["strom", "bolt.fill", F.gelb, "Strom"], ["wasser", "drop.fill", F.blau, "Wasser"], ["gas", "flame.fill", F.orange, "Gas"]]) {
      const t = c.tage[art];
      if (!t) continue;
      const k = karte(r, 6);
      const o = zeile(k, 3);
      bildEinfuegen(o, symbol(sym, 9, farbe));
      text(o, titel, Font.semiboldSystemFont(9), F.leise);
      text(k, Logik.formatMenge(t.heute, t.einheit, art), Font.boldRoundedSystemFont(13), F.text, { zeilen: 1, min: 0.6 });
      if (familie === "large") text(k, "gestern " + Logik.formatMenge(t.gestern, t.einheit, art), Font.mediumSystemFont(9), F.leise, { zeilen: 1, min: 0.7 });
    }
  }
  if (familie === "large") {
    w.addSpacer(8);
    text(w, "Größte Verbraucher", Font.semiboldSystemFont(11), F.leise);
    w.addSpacer(3);
    const max = Math.max(1, ...m.leistung.map((p) => p.watt));
    for (const p of m.leistung.filter((x) => x.watt > 0).slice(0, 5)) {
      const z2 = zeile(w, 4);
      text(z2, p.name, Font.mediumSystemFont(12), F.text, { zeilen: 1 });
      z2.addSpacer();
      text(z2, Logik.formatWatt(p.watt), Font.semiboldRoundedSystemFont(12), F.text);
      const balken = w.addImage(balkenBild(p.watt / max, 300, 4));
      balken.imageSize = new Size(300, 4);
      w.addSpacer(3);
    }
  }
  w.addSpacer();
  standZeile(w, c);
}

function balkenBild(anteil, breite, hoehe) {
  const d = new DrawContext();
  d.size = new Size(breite, hoehe);
  d.opaque = false;
  d.respectScreenScale = true;
  const spur = new Path();
  spur.addRoundedRect(new Rect(0, 0, breite, hoehe), hoehe / 2, hoehe / 2);
  d.addPath(spur);
  d.setFillColor(new Color("#8e8e93", 0.25));
  d.fillPath();
  const f = new Path();
  f.addRoundedRect(new Rect(0, 0, Math.max(hoehe, breite * anteil), hoehe), hoehe / 2, hoehe / 2);
  d.addPath(f);
  d.setFillColor(new Color("#0a84ff"));
  d.fillPath();
  return d.getImage();
}

// ---- Personen ----
function widgetPersonen(w, familie, instanz, c, m) {
  w.backgroundGradient = hintergrund("personen");
  w.url = aktionsURL("dashboard", { reiter: "personen", instanz: instanz.id });
  if (!m.personen.length) return hinweis(w, "Keine Personen", "In Home Assistant sind keine Personen angelegt.");
  const heim = m.zonen.find((z) => z.heim);
  kopf(w, "person.2.fill", "Personen", m.zuhause.length + " von " + m.personen.length + " zu Hause", F.gruen);
  w.addSpacer(6);
  const max = familie === "large" ? 8 : familie === "medium" ? 3 : 3;
  for (const p of m.personen.slice(0, max)) {
    const z2 = zeile(w, 7);
    personPunkt(z2, p, familie === "small" ? 22 : 26);
    const s = spalte(z2, 0);
    text(s, p.name, Font.semiboldSystemFont(familie === "small" ? 12 : 13), F.text, { zeilen: 1 });
    if (familie !== "small" || true) text(s, Logik.ortText(p.zustand) + (familie !== "small" ? " · " + Logik.formatSeit(p.seit, Date.now()) : ""),
      Font.mediumSystemFont(10), p.zustand === "home" ? F.gruen : F.leise, { zeilen: 1 });
    z2.addSpacer();
    const km = heim ? Logik.entfernung(p.lat, p.lon, heim.lat, heim.lon) : null;
    if (km !== null && p.zustand !== "home" && familie !== "small") text(z2, Logik.formatEntfernung(km), Font.semiboldRoundedSystemFont(12), F.leise);
    w.addSpacer(familie === "small" ? 3 : 5);
  }
  if (m.heizungen.length && familie === "large") {
    w.addSpacer(4);
    infoZeile(w, m.heizen ? "flame.fill" : "heater.vertical", m.heizen ? F.orange : F.leise, m.heizen ? "Heizung an in " + m.heizen + " Räumen" : "Heizung ruht");
  }
  w.addSpacer();
  standZeile(w, c);
}

// ---- Raum ----
function widgetRaum(w, familie, instanz, c, m, ziel) {
  w.backgroundGradient = hintergrund("standard");
  const raum = m.raeume.find((r) => passt(r, ziel));
  const klima = m.heizungen.find((r) => passt(r, ziel));
  if (!raum && !klima) return hinweis(w, "Raum nicht gefunden", ziel ? "„" + ziel + "“ gibt es in Home Assistant nicht." : "Widget-Parameter z. B. raum:Küche");
  w.url = aktionsURL("dashboard", { reiter: "lampen", instanz: instanz.id });
  const k = klima ? Logik.raumKlima(klima, m.z) : null;
  const o = zeile(w, 5);
  bildEinfuegen(o, symbol("house.fill", 12, F.leise));
  text(o, (raum || klima).name, Font.semiboldSystemFont(13), F.text, { zeilen: 1 });
  o.addSpacer();
  if (k) {
    if (k.fensterOffen) bildEinfuegen(o, symbol("window.vertical.open", 11, F.blau));
    if (k.heizt) bildEinfuegen(o, symbol("flame.fill", 11, F.orange));
    text(o, Logik.formatTemp(k.ist), Font.boldRoundedSystemFont(15), F.text);
  }
  w.addSpacer(6);
  const ids = raum ? raum.lichter.concat(raum.schalter) : [];
  const max = familie === "large" ? 8 : familie === "medium" ? 3 : 3;
  for (const id of ids.slice(0, max)) {
    const e = m.z[id];
    const an = Logik.istAn(e);
    const z2 = zeile(w, 7);
    z2.url = aktionsURL("schalte", { id, an: an ? "0" : "1", instanz: instanz.id });
    const lampe = id.startsWith("light.");
    symbolKreis(z2, lampe ? (an ? "lightbulb.fill" : "lightbulb") : "poweroutlet.type.f.fill", an ? (lampe ? farbeAusHex(Logik.lampenFarbe(e)) || F.gelb : F.akzent) : null, 20);
    text(z2, Logik.name(e), Font.mediumSystemFont(12), F.text, { zeilen: 1 });
    z2.addSpacer();
    if (familie !== "small") schalterBild(z2, an);
    w.addSpacer(4);
  }
  if (familie === "large" && klima) {
    const v = c.klima && c.klima[klima.id];
    if (v) { const b = w.addImage(klimaBild(v.daten, 300, 70)); b.imageSize = new Size(300, 70); }
  }
  w.addSpacer();
  standZeile(w, c);
}

// ---- Eine Entität ----
function widgetEntitaet(w, familie, instanz, c, m, ziel) {
  w.backgroundGradient = hintergrund("standard");
  const id = Object.keys(m.z).find((x) => x === ziel) || Object.keys(m.z).find((x) => Logik.name(m.z[x]).toLowerCase() === String(ziel).toLowerCase());
  if (!id) return hinweis(w, "Nicht gefunden", ziel ? "„" + ziel + "“" : "Widget-Parameter z. B. lampe:light.flur");
  const e = m.z[id], d = Logik.domain(id), an = Logik.istAn(e);
  const schaltbar = d === "light" || d === "switch";
  if (schaltbar) w.url = aktionsURL("schalte", { id, an: an ? "0" : "1", instanz: instanz.id });
  else w.url = aktionsURL("dashboard", { instanz: instanz.id });
  const o = zeile(w, 6);
  if (d === "light") symbolKreis(o, an ? "lightbulb.fill" : "lightbulb", farbeAusHex(Logik.lampenFarbe(e)), 30);
  else if (d === "switch") symbolKreis(o, "poweroutlet.type.f.fill", an ? F.akzent : null, 30);
  else if (d === "climate") symbolKreis(o, "heater.vertical.fill", Logik.klimaStatus(e).heizt ? F.orange : null, 30);
  else symbolKreis(o, e.attributes.device_class === "temperature" ? "thermometer.medium" : "gauge.with.dots.needle.33percent", null, 30);
  o.addSpacer();
  if (schaltbar) schalterBild(o, an);
  w.addSpacer();
  text(w, Logik.name(e), Font.semiboldSystemFont(13), F.text, { zeilen: 2 });
  let wert;
  if (schaltbar) wert = !Logik.istVerfuegbar(e) ? "nicht erreichbar" : an ? (Logik.dimmbar(e) && d === "light" ? Logik.helligkeit(e) + " %" : "an") : "aus";
  else if (d === "climate") wert = Logik.formatTemp(Logik.klimaStatus(e).ist);
  else if (d === "person") wert = Logik.ortText(e.state);
  else {
    const z2 = parseFloat(e.state), einheit = e.attributes.unit_of_measurement || "";
    wert = isNaN(z2) ? e.state : einheit === "W" || einheit === "kW" ? Logik.formatWatt(einheit === "kW" ? z2 * 1000 : z2)
      : (Math.abs(z2) >= 100 ? Math.round(z2) : z2.toFixed(1)).toString().replace(".", ",") + (einheit ? " " + einheit : "");
  }
  text(w, wert, Font.boldRoundedSystemFont(familie === "small" ? 22 : 28), F.text, { zeilen: 1, min: 0.5 });
}

function passt(r, ziel) {
  if (!ziel) return true;
  const z = String(ziel).toLowerCase();
  return r.id.toLowerCase() === z || r.id.toLowerCase() === "raum:" + z || (r.name || "").toLowerCase() === z || (r.klima || []).indexOf(ziel) >= 0;
}

function hinweis(w, titel, unter) {
  w.addSpacer();
  text(w, titel, Font.semiboldSystemFont(14), F.text, { zeilen: 2 });
  w.addSpacer(2);
  text(w, unter, Font.mediumSystemFont(11), F.leise, { zeilen: 4 });
  w.addSpacer();
}

// ---- Sperrbildschirm ----
function widgetSperre(w, familie, instanz, c, m) {
  w.url = aktionsURL("dashboard", { instanz: instanz.id });
  if (familie === "accessoryCircular") {
    const s = w.addStack();
    s.layoutVertically();
    s.centerAlignContent();
    bildEinfuegen(s, symbol(m.lichterAn ? "lightbulb.fill" : "lightbulb", 14, Color.white()));
    text(s, String(m.lichterAn), Font.boldRoundedSystemFont(16), Color.white(), { mitte: true });
    return;
  }
  if (familie === "accessoryInline") {
    text(w, "💡 " + m.lichterAn + (m.heizungen.length ? "  🔥 " + m.heizen : "") + (m.watt !== null ? "  ⚡ " + Logik.formatWatt(m.watt) : ""), Font.mediumSystemFont(12), Color.white());
    return;
  }
  const z1 = zeile(w, 4);
  bildEinfuegen(z1, symbol("lightbulb.fill", 11, Color.white()));
  text(z1, m.lichterAn + " Lampen an", Font.semiboldSystemFont(13), Color.white(), { zeilen: 1 });
  if (m.heizungen.length) {
    const z2 = zeile(w, 4);
    bildEinfuegen(z2, symbol("flame.fill", 11, Color.white()));
    text(z2, (m.heizen ? m.heizen + " heizen" : "Heizung ruht") + (m.schnitt !== null ? " · " + Logik.formatTemp(m.schnitt) : ""), Font.mediumSystemFont(12), Color.white(), { zeilen: 1 });
  }
  const z3 = zeile(w, 4);
  bildEinfuegen(z3, symbol("bolt.fill", 11, Color.white()));
  text(z3, (m.watt !== null ? Logik.formatWatt(m.watt) : "–") + (m.personen.length ? " · " + m.zuhause.length + " zu Hause" : ""), Font.mediumSystemFont(12), Color.white(), { zeilen: 1 });
}

/**
 * Widget-Parameter: "art", "art:ziel" und optional "@Instanz", z. B.
 * "heizung", "heizung:Wohnzimmer", "raum:Küche", "lampe:light.flur", "energie@Ferienhaus"
 */
function parameterLesen(p) {
  let s = String(p || "").trim(), instanz = "";
  const at = s.lastIndexOf("@");
  if (at >= 0) { instanz = s.slice(at + 1).trim(); s = s.slice(0, at).trim(); }
  const doppel = s.indexOf(":");
  let art = (doppel >= 0 ? s.slice(0, doppel) : s).trim().toLowerCase() || "uebersicht";
  const ziel = doppel >= 0 ? s.slice(doppel + 1).trim() : "";
  art = { übersicht: "uebersicht", lampe: "entitaet", steckdose: "entitaet", sensor: "entitaet", entität: "entitaet", licht: "lampen" }[art] || art;
  return { art, ziel, instanz };
}

async function widgetBauen(familie, parameter) {
  const w = new ListWidget();
  const kompakt = familie && familie.startsWith("accessory");
  if (!kompakt) w.setPadding(14, 14, 12, 14);
  // iOS entscheidet selbst, wann neu geladen wird; 15 Minuten sind ein guter Wunsch
  w.refreshAfterDate = new Date(Date.now() + 15 * 60000);
  const instanzen = instanzenLaden();
  const p = parameterLesen(parameter);
  const instanz = instanzWaehlen(instanzen, p.instanz);
  if (!instanz) {
    w.backgroundGradient = hintergrund("standard");
    hinweis(w, "HA Leiste einrichten", "Skript in Scriptable einmal starten und Home Assistant hinzufügen.");
    w.url = aktionsURL("einstellungen");
    return w;
  }
  const bedarf = {
    verlauf: (p.art === "energie" || (p.art === "uebersicht" && familie === "large")) && !kompakt,
    tage: p.art === "energie" && familie !== "small" && !kompakt,
  };
  // Heizungsverlauf nur für einen einzelnen Raum in mittleren und großen Widgets
  let c = cacheLesen(instanz);
  if ((p.art === "heizung" || p.art === "raum") && p.ziel && familie !== "small" && c.zustaende) {
    const r = Logik.heizungen(c.zustaende, c.bereiche || null, []).find((x) => passt(x, p.ziel));
    if (r) bedarf.klima = r;
  }
  c = await datenLaden(instanz, bedarf);
  if (!c.zustaende) {
    w.backgroundGradient = hintergrund("standard");
    hinweis(w, "Keine Verbindung", c.fehler || "Home Assistant antwortet nicht.");
    return w;
  }
  const m = modell(instanz, c);
  if (kompakt) widgetSperre(w, familie, instanz, c, m);
  else if (p.art === "lampen") widgetLampen(w, familie, instanz, c, m);
  else if (p.art === "heizung") widgetHeizung(w, familie, instanz, c, m, p.ziel);
  else if (p.art === "energie") widgetEnergie(w, familie, instanz, c, m);
  else if (p.art === "personen") widgetPersonen(w, familie, instanz, c, m);
  else if (p.art === "raum") widgetRaum(w, familie, instanz, c, m, p.ziel);
  else if (p.art === "entitaet") widgetEntitaet(w, familie, instanz, c, m, p.ziel);
  else widgetUebersicht(w, familie, instanz, c, m);
  return w;
}

// ---------------------------------------------------------------- Schalten (Tippen im Widget)

async function dienst(instanz, domain, name, daten) {
  return ha(instanz, "POST", "/api/services/" + domain + "/" + name, daten);
}

async function schalte(instanz, id, an) {
  const d = Logik.domain(id);
  if (["light", "switch", "group"].indexOf(d) < 0) return;
  await dienst(instanz, d === "group" ? "homeassistant" : d, an ? "turn_on" : "turn_off", { entity_id: id });
}

// ---------------------------------------------------------------- Dashboard (in der App)

async function dashboard(instanz, reiter) {
  let c = await datenLaden(instanz, { verlauf: true, tage: true });
  const wv = new WebView();
  let offen = true;
  const senden = async () => {
    const m = modell(instanz, c);
    const daten = {
      instanz: instanz.name || "Zuhause", stand: c.stand, fehler: c.fehler || "",
      z: m.z, gruppen: m.gruppen, raeume: m.raeume, ohneRaum: m.ohneRaum, lichter: m.lichter, lichterAn: m.lichterAn,
      schalter: m.schalter, schalterAn: m.schalterAn, heizungen: m.heizungen.map((r) => Object.assign({}, r, { k: Logik.raumKlima(r, m.z) })),
      watt: m.watt, leistung: m.leistung.slice(0, 8), verlauf: c.verlauf || [], tage: c.tage || {},
      personen: m.personen, zonen: m.zonen, zuhause: m.zuhause.length, instanzen: instanzenLaden().map((i) => ({ id: i.id, name: i.name || i.adresse })),
    };
    await wv.evaluateJavaScript("zeigen(" + JSON.stringify(daten) + ")", false);
  };
  // Aktionen aus der Seite kommen als Adresse "haleiste://…" an
  wv.shouldAllowRequest = (anfrage) => {
    const u = anfrage.url || "";
    if (!u.startsWith("haleiste://")) return u.startsWith("about:") || u.startsWith("data:") || u.startsWith("https://unpkg.com") || u.includes("openstreetmap");
    const q = {};
    (u.split("?")[1] || "").split("&").forEach((t) => { const [k, v] = t.split("="); q[k] = decodeURIComponent(v || ""); });
    (async () => {
      try {
        const aktion = u.slice(11).split("?")[0];
        if (aktion === "schalte") await schalte(instanz, q.id, q.an === "1");
        else if (aktion === "dimme") await dienst(instanz, "light", "turn_on", { entity_id: q.id, brightness_pct: Number(q.p) });
        else if (aktion === "temperatur") await dienst(instanz, "climate", "set_temperature", { entity_id: q.id, temperature: Number(q.t) });
        else if (aktion === "alleaus") await dienst(instanz, "light", "turn_off", { entity_id: modell(instanz, c).lichter.filter((id) => Logik.istAn(c.zustaende[id])) });
        else if (aktion === "instanz") {
          const neu = instanzenLaden().find((i) => i.id === q.id);
          if (neu) { instanz = neu; c = await datenLaden(instanz, { verlauf: true, tage: true }); }
        }
        await new Promise((r) => Timer.schedule(400, false, r));
        c = await datenLaden(instanz, {});
        await senden();
      } catch (e) {
        await wv.evaluateJavaScript("meldung(" + JSON.stringify(String(e.message || e)) + ")", false);
      }
    })();
    return false;
  };
  await wv.loadHTML(dashboardHTML(reiter || "lampen"));
  await senden();
  // Solange das Dashboard offen ist alle 10 Sekunden aktualisieren (danach nicht mehr – Akku)
  const t = Timer.schedule(10000, true, async () => {
    if (!offen) return;
    c = await datenLaden(instanz, {});
    if (offen) await senden();
  });
  await wv.present(true);
  offen = false;
  t.invalidate();
}

function dashboardHTML(reiter) {
  return `<!doctype html><html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<style>
:root { color-scheme: light dark; --bg: #f2f2f7; --karte: rgba(255,255,255,.75); --text: #1c1c1e; --leise: #6e6e73; --linie: rgba(60,60,67,.12);
  --akzent: #0a84ff; --orange: #ff9f0a; --gruen: #30d158; --blau: #64d2ff; }
@media (prefers-color-scheme: dark) { :root { --bg: #000; --karte: rgba(44,44,46,.72); --text: #fff; --leise: #98989f; --linie: rgba(84,84,88,.4); } }
* { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
body { margin: 0; font: 15px -apple-system, system-ui; background: var(--bg); color: var(--text); padding: env(safe-area-inset-top) 0 90px; }
header { position: sticky; top: 0; z-index: 5; padding: 14px 16px 10px; backdrop-filter: saturate(180%) blur(20px); -webkit-backdrop-filter: saturate(180%) blur(20px); background: color-mix(in srgb, var(--bg) 70%, transparent); }
h1 { margin: 0; font-size: 28px; font-weight: 700; letter-spacing: -.5px; display: flex; align-items: center; gap: 8px; }
h1 select { font: inherit; font-size: 15px; color: var(--akzent); background: none; border: 0; }
.unter { color: var(--leise); font-size: 13px; margin-top: 2px; }
nav { position: fixed; bottom: 0; left: 0; right: 0; display: flex; justify-content: space-around; padding: 8px 6px calc(8px + env(safe-area-inset-bottom));
  backdrop-filter: saturate(180%) blur(20px); -webkit-backdrop-filter: saturate(180%) blur(20px); background: color-mix(in srgb, var(--bg) 75%, transparent); border-top: .5px solid var(--linie); z-index: 10; }
nav button { flex: 1; background: none; border: 0; color: var(--leise); font: 600 10px -apple-system; display: flex; flex-direction: column; align-items: center; gap: 3px; }
nav button.an { color: var(--akzent); }
nav svg { width: 24px; height: 24px; }
main { padding: 0 16px; }
.abschnitt { color: var(--leise); font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: .3px; margin: 18px 4px 8px; }
.karte { background: var(--karte); border-radius: 16px; padding: 12px 14px; margin-bottom: 10px; backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); }
.zeile { display: flex; align-items: center; gap: 12px; }
.zeile + .zeile { margin-top: 12px; padding-top: 12px; border-top: .5px solid var(--linie); }
.kreis { width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center; background: rgba(142,142,147,.25); flex: none; font-size: 18px; transition: background .2s; }
.name { font-weight: 600; } .info { color: var(--leise); font-size: 13px; }
.mitte { flex: 1; min-width: 0; } .mitte .name { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.schalter { position: relative; width: 51px; height: 31px; border-radius: 16px; background: rgba(120,120,128,.32); flex: none; transition: background .2s; }
.schalter::after { content: ""; position: absolute; top: 2px; left: 2px; width: 27px; height: 27px; border-radius: 50%; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,.25); transition: left .2s; }
.schalter.an { background: var(--gruen); } .schalter.an::after { left: 22px; }
input[type=range] { width: 100%; margin-top: 10px; accent-color: var(--gelb, #ffc65c); }
.gross { font-size: 34px; font-weight: 700; letter-spacing: -.5px; font-variant-numeric: tabular-nums; }
.temp { font-size: 24px; font-weight: 600; font-variant-numeric: tabular-nums; }
.knopf { border: 0; background: rgba(120,120,128,.2); color: var(--text); width: 36px; height: 36px; border-radius: 50%; font-size: 20px; }
.ziel { min-width: 64px; text-align: center; font-weight: 600; font-variant-numeric: tabular-nums; }
.raster { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.balken { height: 6px; border-radius: 3px; background: rgba(120,120,128,.2); margin-top: 6px; overflow: hidden; } .balken > div { height: 100%; background: var(--akzent); border-radius: 3px; }
#karte { height: 320px; border-radius: 16px; margin-bottom: 10px; }
.punkt { width: 34px; height: 34px; border-radius: 50%; color: #fff; display: grid; place-items: center; font-weight: 700; font-size: 13px; border: 2px solid #fff; box-shadow: 0 2px 6px rgba(0,0,0,.3); }
.meldung { position: fixed; left: 16px; right: 16px; bottom: 90px; background: #ff453a; color: #fff; padding: 12px 14px; border-radius: 14px; display: none; z-index: 20; }
.leiste { display: flex; justify-content: space-between; align-items: center; }
.pille { background: rgba(120,120,128,.2); border: 0; color: var(--text); border-radius: 14px; padding: 6px 12px; font: 600 13px -apple-system; }
svg.verlauf { width: 100%; height: 90px; display: block; margin-top: 8px; }
</style></head><body>
<header><h1><span id="titel">Lampen</span> <select id="instanz" onchange="los('instanz', {id: this.value})"></select></h1><div class="unter" id="unter"></div></header>
<main id="inhalt"></main>
<div class="meldung" id="meldung"></div>
<nav id="nav"></nav>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
let D = null, reiter = ${JSON.stringify(reiter)}, karte = null;
const REITER = [["lampen","Lampen","M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2zM9 19h6M10 22h4"],["steckdosen","Steckdosen","M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8z"],
  ["heizung","Heizung","M4 6h16v12H4zM8 6v12M12 6v12M16 6v12"],["energie","Energie","M13 2 4 14h7l-1 8 9-12h-7z"],["personen","Personen","M12 4a4 4 0 1 0 0 8a4 4 0 1 0 0-8zM4 21c1-4 4-6 8-6s7 2 8 6"]];
const ICON = { lampe: "M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2zM9 19.5h6M10 22h4", dose: "M6 3h12a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3zM9.5 12h.01M14.5 12h.01",
  heizung: "M5 5v14M9.5 5v14M14.5 5v14M19 5v14M3 8h18M3 16h18", thermo: "M10 14.5V5a2 2 0 0 1 4 0v9.5a4 4 0 1 1-4 0z", fenster: "M4 3h16v18H4zM12 3v18M4 12h16" };
function icon(name, farbe) { return '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="' + (farbe || "currentColor") + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="' + ICON[name] + '"/></svg>'; }
function entfernung(a, b, c, d) { if ([a, b, c, d].some(x => x == null)) return null; const g = Math.PI / 180, x = Math.sin((c - a) * g / 2) ** 2 + Math.cos(a * g) * Math.cos(c * g) * Math.sin((d - b) * g / 2) ** 2; return 12742 * Math.asin(Math.sqrt(x)); }
function seit(ms) { if (!ms) return ""; const m = Math.round((Date.now() - ms) / 60000); return m < 1 ? "gerade eben" : m < 60 ? "seit " + m + " min" : m < 1440 ? "seit " + Math.floor(m / 60) + " h" : "seit " + Math.floor(m / 1440) + " d"; }
const fmtW = w => w == null ? "–" : w >= 1000 ? (w/1000).toFixed(2).replace(".", ",") + " kW" : Math.round(w) + " W";
const fmtT = t => t == null ? "–" : t.toFixed(1).replace(".", ",") + " °C";
const esc = s => String(s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
function los(aktion, werte) { location.href = "haleiste://" + aktion + "?" + Object.entries(werte || {}).map(([k, v]) => k + "=" + encodeURIComponent(v)).join("&"); }
function meldung(t) { const m = document.getElementById("meldung"); m.textContent = t; m.style.display = "block"; setTimeout(() => m.style.display = "none", 4000); }
function name(id) { const e = D.z[id]; return e ? (e.attributes.friendly_name || id) : id; }
function an(id) { return D.z[id] && D.z[id].state === "on"; }
function farbe(id) { const a = (D.z[id] || {}).attributes || {}; if (!an(id)) return ""; if (a.rgb_color && a.color_mode !== "color_temp") return "rgb(" + a.rgb_color.join(",") + ")"; return "#ffc65c"; }
function hell(id) { const a = (D.z[id] || {}).attributes || {}; return a.brightness ? Math.max(1, Math.round(a.brightness / 2.55)) : 100; }
function dimmbar(id) { const m = ((D.z[id] || {}).attributes || {}).supported_color_modes || []; return m.length && !(m.length === 1 && m[0] === "onoff"); }
function schalter(id) { const a = an(id); D.z[id].state = a ? "off" : "on"; zeichnen(); los("schalte", { id, an: a ? "0" : "1" }); }
function lampe(id) {
  const a = an(id), f = farbe(id);
  return '<div class="zeile"><div class="kreis" style="background:' + (f || "") + '">' + icon("lampe", f ? "rgba(0,0,0,.65)" : "") + '</div><div class="mitte"><div class="name">' + esc(name(id)) + '</div><div class="info">' + (a ? (dimmbar(id) ? hell(id) + " %" : "an") : "aus") + '</div>'
    + (a && dimmbar(id) ? '<input type="range" min="1" max="100" value="' + hell(id) + '" onchange="los(\\'dimme\\', {id: \\'' + id + '\\', p: this.value})">' : "") + '</div><div class="schalter' + (a ? " an" : "") + '" onclick="schalter(\\'' + id + '\\')"></div></div>';
}
function seiteLampen() {
  let h = '<div class="leiste"><div class="info">' + D.lichterAn + " von " + D.lichter.length + ' Lampen an</div><button class="pille" onclick="los(\\'alleaus\\')">Alle aus</button></div>';
  if (D.gruppen.length) h += '<div class="abschnitt">Gruppen</div><div class="karte">' + D.gruppen.map(g => lampe(g.id)).join("") + "</div>";
  for (const r of D.raeume.filter(r => r.lichter.length)) h += '<div class="abschnitt">' + esc(r.name) + '</div><div class="karte">' + r.lichter.map(lampe).join("") + "</div>";
  if (D.ohneRaum.length) h += '<div class="abschnitt">Ohne Raum</div><div class="karte">' + D.ohneRaum.map(lampe).join("") + "</div>";
  return h;
}
function seiteSteckdosen() {
  if (!D.schalter.length) return '<div class="info">Keine Steckdosen gefunden.</div>';
  return '<div class="karte">' + D.schalter.map(s => { const a = an(s.id); const w = s.leistung && D.z[s.leistung] ? parseFloat(D.z[s.leistung].state) : null;
    return '<div class="zeile"><div class="kreis" style="background:' + (a ? "var(--akzent)" : "") + '">' + icon("dose", a ? "#fff" : "") + '</div><div class="mitte"><div class="name">' + esc(s.name) + '</div><div class="info">' + (a ? "an" : "aus") + (w != null && !isNaN(w) ? " · " + fmtW(w) : "") + (s.raum ? " · " + esc(s.raum) : "") + '</div></div><div class="schalter' + (a ? " an" : "") + '" onclick="schalter(\\'' + s.id + '\\')"></div></div>'; }).join("") + "</div>";
}
function verlaufSVG(v) {
  if (!v || (!v.ist.length && !v.ziel.length)) return "";
  const ende = Date.now(), anf = ende - 864e5, w = v.ist.concat(v.ziel).map(p => p.w), lo = Math.floor(Math.min(...w) - .5), hi = Math.ceil(Math.max(...w) + .5);
  const x = t => (Math.max(t, anf) - anf) / 864e5 * 300, y = t => 88 - (t - lo) / Math.max(1, hi - lo) * 84;
  let s = '<svg class="verlauf" viewBox="0 0 300 90" preserveAspectRatio="none">';
  for (const h of v.heizen) s += '<rect x="' + x(h.von) + '" y="0" width="' + Math.max(1, x(h.bis) - x(h.von)) + '" height="90" fill="rgba(255,159,10,.18)"/>';
  const linie = (l, f, d) => l.length ? '<polyline fill="none" stroke="' + f + '" stroke-width="' + (d ? 1.5 : 2) + '"' + (d ? ' stroke-dasharray="5 4"' : "") + ' points="' + l.map(p => x(p.t) + "," + y(p.w)).join(" ") + " 300," + y(l[l.length - 1].w) + '"/>' : "";
  return s + linie(v.ziel, "#ff9f0a", true) + linie(v.ist, "#0a84ff", false) + "</svg>";
}
function seiteHeizung() {
  if (!D.heizungen.length) return '<div class="info">Keine Thermostate gefunden.</div>';
  return D.heizungen.map(r => { const k = r.k, t = k.thermostat;
    let h = '<div class="karte"><div class="zeile"><div class="kreis" style="background:' + (k.heizt ? "var(--orange)" : "") + '">' + icon(t ? "heizung" : "thermo", k.heizt ? "rgba(0,0,0,.65)" : "") + '</div><div class="mitte"><div class="name">' + esc(r.name) + (k.fensterBekannt ? ' <span style="vertical-align:-3px;display:inline-block">' + icon("fenster", k.fensterOffen ? "var(--blau)" : "var(--leise)").replace(/20/g, "15") + "</span>" : "") + '</div><div class="info" style="color:' + (k.fensterOffen ? "var(--blau)" : k.heizt ? "var(--orange)" : "") + '">'
      + (k.fensterOffen ? "Fenster offen · " : "") + (!t ? "Temperatur" : k.aus ? "Heizung aus" : k.heizt ? "heizt auf " + fmtT(k.ziel) : "Ziel " + fmtT(k.ziel)) + (k.feuchte != null ? " · " + Math.round(k.feuchte) + " %" : "") + '</div></div><div class="temp">' + fmtT(k.ist) + "</div></div>";
    if (t && t.ziel != null) h += '<div class="zeile" style="justify-content:center"><button class="knopf" onclick="los(\\'temperatur\\', {id: \\'' + r.klima[0] + '\\', t: ' + Math.max(t.min, t.ziel - t.schritt) + '})">−</button><div class="ziel">' + fmtT(t.ziel) + '</div><button class="knopf" onclick="los(\\'temperatur\\', {id: \\'' + r.klima[0] + '\\', t: ' + Math.min(t.max, t.ziel + t.schritt) + '})">+</button></div>';
    return h + "</div>"; }).join("");
}
function seiteEnergie() {
  let h = '<div class="karte"><div class="info">Verbrauch gerade</div><div class="gross">' + fmtW(D.watt) + "</div>";
  if (D.verlauf.length > 1) { const t0 = D.verlauf[0].t, t1 = Date.now(), m = Math.max(...D.verlauf.map(p => p.w)) || 1;
    h += '<svg class="verlauf" viewBox="0 0 300 90" preserveAspectRatio="none"><polyline fill="none" stroke="var(--akzent)" stroke-width="2" points="' + D.verlauf.map(p => ((p.t - t0) / (t1 - t0) * 300) + "," + (88 - p.w / m * 84)).join(" ") + '"/></svg>'; }
  h += "</div>";
  const tage = Object.entries(D.tage);
  if (tage.length) h += '<div class="abschnitt">Verbrauch heute</div><div class="raster">' + tage.map(([art, t]) => '<div class="karte"><div class="info">' + ({strom:"Strom",wasser:"Wasser",gas:"Gas"})[art] + '</div><div class="name" style="font-size:18px">' + (Math.round(t.heute * 100) / 100).toString().replace(".", ",") + " " + esc(t.einheit) + "</div></div>").join("") + "</div>";
  if (D.leistung.length) { const m = Math.max(...D.leistung.map(p => p.watt)) || 1;
    h += '<div class="abschnitt">Größte Verbraucher</div><div class="karte">' + D.leistung.filter(p => p.watt > 0).map(p => '<div style="margin:6px 0"><div class="leiste"><span>' + esc(p.name) + '</span><b>' + fmtW(p.watt) + '</b></div><div class="balken"><div style="width:' + (p.watt / m * 100) + '%"></div></div></div>').join("") + "</div>"; }
  return h;
}
function seitePersonen() {
  const heim = D.zonen.find(z => z.heim);
  return '<div id="karte"></div><div class="karte">' + D.personen.map(p => '<div class="zeile"><div class="punkt" style="background:' + p.farbe + '">' + esc(p.name.split(" ").map(x => x[0]).join("").slice(0, 2).toUpperCase()) + '</div><div class="mitte"><div class="name">' + esc(p.name) + '</div><div class="info" style="color:' + (p.zustand === "home" ? "var(--gruen)" : "") + '">' + esc(p.zustand === "home" ? "Zuhause" : p.zustand === "not_home" ? "Unterwegs" : p.zustand) + (seit(p.seit) ? " · " + seit(p.seit) : "") + "</div></div>"
    + (p.zustand !== "home" && heim && entfernung(p.lat, p.lon, heim.lat, heim.lon) != null ? '<div class="info" style="font-weight:600">' + (e => e < 1 ? Math.round(e * 100) * 10 + " m" : e.toFixed(e < 10 ? 1 : 0).replace(".", ",") + " km")(entfernung(p.lat, p.lon, heim.lat, heim.lon)) + "</div>" : "") + "</div>").join("") + "</div>";
}
function karteZeichnen() {
  if (typeof L === "undefined" || !document.getElementById("karte")) return;
  const punkte = D.personen.filter(p => p.lat != null).map(p => [p.lat, p.lon]);
  const heim = D.zonen.find(z => z.heim);
  karte = L.map("karte", { zoomControl: false, attributionControl: true });
  L.tileLayer("https://tile.openstreetmap.de/{z}/{x}/{y}.png", { maxZoom: 18, attribution: "© OpenStreetMap-Mitwirkende" }).addTo(karte);
  for (const z of D.zonen) L.circle([z.lat, z.lon], { radius: z.radius, color: z.heim ? "#30d158" : "#0a84ff", weight: 1, fillOpacity: .15 }).addTo(karte);
  for (const p of D.personen.filter(p => p.lat != null)) L.marker([p.lat, p.lon], { icon: L.divIcon({ className: "", html: '<div class="punkt" style="background:' + p.farbe + '">' + esc(p.name[0]) + "</div>", iconSize: [34, 34], iconAnchor: [17, 17] }) }).addTo(karte);
  const alle = punkte.concat(heim ? [[heim.lat, heim.lon]] : []);
  if (alle.length) karte.fitBounds(alle, { padding: [40, 40], maxZoom: 15 });
}
function zeichnen() {
  if (!D) return;
  const titel = { lampen: "Lampen", steckdosen: "Steckdosen", heizung: "Heizung", energie: "Energie", personen: "Personen" };
  document.getElementById("titel").textContent = titel[reiter];
  const s = new Date(D.stand || Date.now());
  document.getElementById("unter").textContent = (D.fehler ? "⚠️ " + D.fehler + " · " : "") + "Stand " + s.toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });
  const sel = document.getElementById("instanz");
  sel.style.display = D.instanzen.length > 1 ? "" : "none";
  sel.innerHTML = D.instanzen.map(i => '<option value="' + i.id + '"' + (i.name === D.instanz ? " selected" : "") + ">" + esc(i.name) + "</option>").join("");
  const y = window.scrollY;
  if (reiter === "personen" && karte && document.getElementById("karte")) { /* Karte behalten, nur Liste neu */ }
  document.getElementById("inhalt").innerHTML = ({ lampen: seiteLampen, steckdosen: seiteSteckdosen, heizung: seiteHeizung, energie: seiteEnergie, personen: seitePersonen })[reiter]();
  if (reiter === "personen") { karte = null; karteZeichnen(); }
  window.scrollTo(0, y);
  document.getElementById("nav").innerHTML = REITER.map(([id, t, p]) => '<button class="' + (id === reiter ? "an" : "") + '" onclick="reiter=\\'' + id + '\\'; zeichnen(); window.scrollTo(0,0)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="' + p + '"/></svg>' + t + "</button>").join("");
}
function zeigen(d) { D = d; zeichnen(); }
</script></body></html>`;
}

// ---------------------------------------------------------------- Einstellungen (in der App)

async function frage(titel, nachricht, knoepfe, abbruch = "Abbrechen") {
  const a = new Alert();
  a.title = titel;
  if (nachricht) a.message = nachricht;
  for (const k of knoepfe) a.addAction(k);
  a.addCancelAction(abbruch);
  return await a.presentSheet();
}

async function eingabe(titel, nachricht, felder) {
  const a = new Alert();
  a.title = titel;
  if (nachricht) a.message = nachricht;
  for (const f of felder) { if (f.geheim) a.addSecureTextField(f.platz, f.wert || ""); else a.addTextField(f.platz, f.wert || ""); }
  a.addAction("OK");
  a.addCancelAction("Abbrechen");
  const i = await a.presentAlert();
  if (i < 0) return null;
  return felder.map((_, n) => a.textFieldValue(n).trim());
}

async function instanzHinzufuegen() {
  const werte = await eingabe("Home Assistant hinzufügen", "Adresse und langlebiger Zugriffstoken (In Home Assistant: dein Name → Sicherheit → Token erstellen).",
    [{ platz: "https://…:8123" }, { platz: "Token", geheim: true }, { platz: "Name (optional)" }]);
  if (!werte || !werte[0] || !werte[1]) return;
  const liste = instanzenLaden();
  const i = { id: Logik.neueInstanzId(liste), name: werte[2] || "", adresse: werte[0].replace(/\/+$/, ""), token: werte[1], favorit: liste.length === 0 };
  try {
    const cfg = await ha(i, "GET", "/api/config");
    if (!i.name && cfg && cfg.location_name) i.name = cfg.location_name;
  } catch (e) {
    if (await frage("Keine Verbindung", String(e.message || e) + "\nTrotzdem speichern?", ["Speichern"]) !== 0) return;
  }
  liste.push(i);
  instanzenSpeichern(liste);
}

async function instanzBearbeiten(i) {
  const liste = instanzenLaden();
  const wahl = await frage(i.name || i.adresse, i.adresse, ["Als Favorit", "Umbenennen", "Adresse/Token ändern", "Hauptzähler wählen", "Zähler (Strom/Wasser/Gas)", "Entfernen", "Ausblenden …"]);
  const x = liste.find((y) => y.id === i.id);
  if (wahl === 0) liste.forEach((y) => (y.favorit = y.id === i.id));
  else if (wahl === 1) { const w = await eingabe("Name", "", [{ platz: "Name", wert: x.name }]); if (w) x.name = w[0]; }
  else if (wahl === 2) { const w = await eingabe("Verbindung", "", [{ platz: "Adresse", wert: x.adresse }, { platz: "Token (leer = unverändert)", geheim: true }]); if (w) { x.adresse = w[0].replace(/\/+$/, ""); if (w[1]) x.token = w[1]; } }
  else if (wahl === 3 || wahl === 4) {
    const c = await datenLaden(x, {});
    const z = c.zustaende || {};
    if (wahl === 3) {
      const kand = Object.values(z).filter((e) => e.entity_id.startsWith("sensor.") && e.attributes.device_class === "power");
      const n = await frage("Hauptzähler", "Leistungssensor deines Stromzählers", ["Keiner (Summe der Messsteckdosen)"].concat(kand.map((e) => Logik.name(e) + " (" + e.state + " " + (e.attributes.unit_of_measurement || "") + ")")));
      if (n === 0) x.hauptzaehler = ""; else if (n > 0) x.hauptzaehler = kand[n - 1].entity_id;
    } else {
      x.zaehler = x.zaehler || {};
      for (const [art, klasse, titel] of [["strom", "energy", "Stromzähler"], ["wasser", "water", "Wasserzähler"], ["gas", "gas", "Gaszähler"]]) {
        const kand = Object.values(z).filter((e) => e.entity_id.startsWith("sensor.") && e.attributes.device_class === klasse);
        if (!kand.length) continue;
        const n = await frage(titel, "", ["Automatisch"].concat(kand.map((e) => Logik.name(e))));
        if (n === 0) delete x.zaehler[art]; else if (n > 0) x.zaehler[art] = kand[n - 1].entity_id;
      }
    }
    const c2 = cacheLesen(x); c2.tageStand = 0; c2.verlaufStand = 0; cacheSchreiben(x, c2);
  }
  else if (wahl === 6) {
    const w = await eingabe("Ausblenden", "Entitäten, die nicht erscheinen sollen – mit Komma, auch mit *, z. B. light.flur_nachtlicht, switch.*_led",
      [{ platz: "light.…, switch.*_led", wert: x.ausgeblendet || "" }]);
    if (w) x.ausgeblendet = w[0];
  }
  else if (wahl === 5) {
    if (await frage("Wirklich entfernen?", i.name || i.adresse, ["Entfernen"]) !== 0) return;
    const neu = liste.filter((y) => y.id !== i.id);
    if (neu.length && !neu.some((y) => y.favorit)) neu[0].favorit = true;
    instanzenSpeichern(neu);
    return;
  }
  instanzenSpeichern(liste);
}

const ANLEITUNG = `So legst du Widgets an:
1. Homebildschirm lange drücken → „+“ → Scriptable → Größe wählen.
2. Widget lange drücken → „Widget bearbeiten“ → Script: ${"„HA Leiste“"}.
3. Bei „Parameter“ eintragen, was es zeigen soll:

• (leer) – Übersicht
• lampen – Lampen (Tippen schaltet)
• heizung – alle Räume, heizung:Wohnzimmer – ein Raum mit Verlauf
• energie – Verbrauch, Verlauf, Strom/Wasser/Gas heute
• personen – wer ist wo
• raum:Küche – Temperatur, Lampen, Steckdosen eines Raums
• lampe:light.flur oder lampe:Stehlampe – eine Entität groß
• …@Ferienhaus – andere Instanz als den Favoriten

Auf dem Sperrbildschirm zeigt das Widget Lampen, Heizung und Verbrauch kurz.`;

async function einstellungen() {
  for (;;) {
    const liste = instanzenLaden();
    const knoepfe = liste.map((i) => (i.favorit ? "★ " : "") + (i.name || i.adresse)).concat(["＋ Home Assistant hinzufügen", "Dashboard öffnen", "Widgets einrichten (Anleitung)", "Nach Updates suchen", "Zwischenspeicher leeren"]);
    const n = await frage("HA Leiste " + VERSION, liste.length ? "Tippe auf eine Instanz, um sie zu bearbeiten." : "Noch keine Instanz – füge Home Assistant hinzu.", knoepfe, "Fertig");
    if (n < 0) return;
    if (n < liste.length) await instanzBearbeiten(liste[n]);
    else if (n === liste.length) await instanzHinzufuegen();
    else if (n === liste.length + 1) { const i = instanzWaehlen(liste); if (i) await dashboard(i, "lampen"); }
    else if (n === liste.length + 2) { const a = new Alert(); a.title = "Widgets einrichten"; a.message = ANLEITUNG; a.addAction("OK"); await a.presentAlert(); }
    else if (n === liste.length + 3) await updatePruefen(true);
    else if (n === liste.length + 4) { if (fm.fileExists(cacheOrdner)) fm.remove(cacheOrdner); }
  }
}

// ---------------------------------------------------------------- Updates

/** Neue Version auf GitHub? Zeigt die Änderungen und ersetzt auf Wunsch dieses Skript. */
async function updatePruefen(immerMelden) {
  try {
    const r = new Request("https://api.github.com/repos/" + PROJEKT + "/releases?per_page=10");
    r.timeoutInterval = 15;
    const releases = await r.loadJSON();
    const u = Logik.updateAusReleases(releases, VERSION, "HA-Leiste.js");
    if (!u) {
      if (immerMelden) { const a = new Alert(); a.title = "HA Leiste ist aktuell"; a.message = "Version " + VERSION; a.addAction("OK"); await a.presentAlert(); }
      return;
    }
    const a = new Alert();
    a.title = "Version " + u.version + " ist da";
    a.message = u.notizen.map((x) => "— " + x.version + " —\n" + x.text.replace(/\*\*/g, "").replace(/^#+\s*/gm, "")).join("\n\n").slice(0, 1800);
    if (u.url) a.addAction("Installieren");
    a.addCancelAction("Später");
    if (await a.presentAlert() !== 0 || !u.url) return;
    const q = new Request(u.url);
    const neu = await q.loadString();
    if (!neu.includes("HA Leiste für iOS") || !neu.includes("widgetBauen")) throw new Error("Die geladene Datei ist kein HA-Leiste-Skript.");
    const icloud = FileManager.iCloud();
    let pfad = icloud.joinPath(icloud.documentsDirectory(), Script.name() + ".js");
    const ziel = icloud.fileExists(pfad) ? icloud : fm;
    if (ziel === fm) pfad = fm.joinPath(fm.documentsDirectory(), Script.name() + ".js");
    ziel.writeString(pfad, neu);
    const b = new Alert(); b.title = "Installiert"; b.message = "Version " + u.version + " ist installiert und gilt ab dem nächsten Start."; b.addAction("OK"); await b.presentAlert();
  } catch (e) {
    if (immerMelden) { const a = new Alert(); a.title = "Update nicht möglich"; a.message = String(e.message || e); a.addAction("OK"); await a.presentAlert(); }
  }
}

// ---------------------------------------------------------------- Start
// (muss am Ende stehen: alles oben ist dann definiert)

async function start() {
  if (config.runsInWidget || config.runsInAccessoryWidget) {
    Script.setWidget(await widgetBauen(config.widgetFamily, args.widgetParameter));
    return;
  }
  const q = args.queryParameters || {};
  const liste = instanzenLaden();
  const instanz = instanzWaehlen(liste, q.instanz);
  if (q.aktion === "schalte" && instanz) {
    try { await schalte(instanz, q.id, q.an === "1"); } catch (e) { /* Dashboard zeigt den Fehler */ }
    await dashboard(instanz, q.id && q.id.startsWith("switch.") ? "steckdosen" : "lampen");
  } else if (q.aktion === "dashboard" && instanz) {
    await dashboard(instanz, q.reiter || "lampen");
  } else if (!liste.length || q.aktion === "einstellungen") {
    await einstellungen();
  } else {
    // Normaler Start in der App: kurze Auswahl
    const n = await frage("HA Leiste", instanz ? (instanz.name || instanz.adresse) : "", ["Dashboard", "Vorschau: Übersicht (mittel)", "Vorschau: Heizung (groß)", "Einstellungen"], "Schließen");
    if (n === 0) await dashboard(instanz, "lampen");
    else if (n === 1) await (await widgetBauen("medium", "")).presentMedium();
    else if (n === 2) await (await widgetBauen("large", "heizung")).presentLarge();
    else if (n === 3) await einstellungen();
    // Gelegentlich (höchstens 1× am Tag) nach Updates schauen – nur in der App, nie im Widget
    const c = fm.joinPath(fm.documentsDirectory(), "ha-leiste-update.txt");
    const zuletzt = fm.fileExists(c) ? Number(fm.readString(c)) : 0;
    if (Date.now() - zuletzt > 86400000) { fm.writeString(c, String(Date.now())); await updatePruefen(false); }
  }
}

await start();
Script.complete();
