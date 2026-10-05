.pragma library
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

// ------------------------------------------------------------------ Sprache
// Übersetzung und Dezimalzeichen setzt das Programm beim Start (KDE: i18n, iOS: eigene Tabelle).
var _uebersetzen = function (s) { return s; };
var _dezimal = ",";
var _rtl = false;
function sprache(uebersetzen, dezimal, rtl) {
    if (uebersetzen) _uebersetzen = uebersetzen;
    if (dezimal) _dezimal = dezimal;
    _rtl = !!rtl;
}
/** Zahl mit Einheit in Rechts-nach-links-Sprachen als Block isolieren (sonst wird aus "21 °C" "C° 21") */
function iso(s) { return _rtl && s !== "–" ? "\u2066" + s + "\u2069" : s; }
/** Text übersetzen; %1, %2 … durch Werte ersetzen */
function t(text) {
    var s = _uebersetzen(text) || text, werte = Array.prototype.slice.call(arguments, 1);
    for (var i = werte.length; i >= 1; i--) s = s.split("%" + i).join(String(werte[i - 1]));
    return s;
}
function komma(zahlText) { return String(zahlText).replace(".", _dezimal); }

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

function formatWatt(w) { return iso(_formatWatt(w)); }
function _formatWatt(w) {
    if (w === null || w === undefined || isNaN(w)) return "–";
    if (w === 0) return "0 W";
    if (Math.abs(w) >= 10000) return komma((w / 1000).toFixed(1)) + " kW";
    if (Math.abs(w) >= 1000) return komma((w / 1000).toFixed(2)) + " kW";
    if (Math.abs(w) >= 10) return Math.round(w) + " W";
    return w.toFixed(1).replace(".", _dezimal) + " W";
}

function formatKwh(k) { return iso(_formatKwh(k)); }
function _formatKwh(k) {
    if (k === null || k === undefined || isNaN(k)) return "–";
    // Zählerstände wie auf dem Zähler: 12.456 kWh
    if (k >= 1000) return Math.round(k).toString().replace(/\B(?=(\d{3})+(?!\d))/g, _dezimal === "," ? "." : ",") + " kWh";
    if (k >= 100) return Math.round(k) + " kWh";
    return k.toFixed(k >= 10 ? 1 : 2).replace(".", _dezimal) + " kWh";
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
function formatMenge(wert, einheit, art) { return iso(_formatMenge(wert, einheit, art)); }
function _formatMenge(wert, einheit, art) {
    if (wert === null || wert === undefined || isNaN(wert)) return "–";
    var e = einheit || "";
    if (art === "strom") {
        var kwh = e === "Wh" ? wert / 1000 : e === "MWh" ? wert * 1000 : wert;
        return formatKwh(kwh);
    }
    if (art === "wasser") {
        var liter = e === "m³" || e === "m3" ? wert * 1000 : e === "gal" ? wert * 3.785 : e === "ft³" ? wert * 28.317 : wert;
        if (liter >= 1000) return komma((liter / 1000).toFixed(2)) + " m³";
        return Math.round(liter) + " L";
    }
    // Gas
    if (e === "kWh" || e === "Wh" || e === "MWh") return formatKwh(e === "Wh" ? wert / 1000 : e === "MWh" ? wert * 1000 : wert);
    return wert.toFixed(wert >= 10 ? 1 : 2).replace(".", _dezimal) + " " + (e || "m³");
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

function formatTemp(t, stellen) { return iso(_formatTemp(t, stellen)); }
function _formatTemp(t, stellen) {
    if (t === null || t === undefined || isNaN(t)) return "–";
    return t.toFixed(stellen === undefined ? 1 : stellen).replace(".", _dezimal) + " °C";
}

/** Name eines Heizmodus bzw. Presets auf Deutsch */
function modusName(m) {
    return ({ off: t("Aus"), heat: t("Heizen"), auto: t("Automatik"), heat_cool: t("Heizen/Kühlen"), cool: t("Kühlen"), dry: t("Entfeuchten"), fan_only: t("Lüfter"),
              eco: t("Eco"), comfort: t("Komfort"), boost: t("Boost"), away: t("Abwesend"), home: t("Zuhause"), sleep: t("Schlafen"), activity: t("Aktiv") })[m] || m;
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
    if (min < 60) return t("%1 min", min);
    var h = Math.floor(min / 60), m = min % 60;
    return m ? t("%1 h %2 min", h, m) : t("%1 h", h);
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
    if (zustand === "home") return t("Zuhause");
    if (zustand === "not_home") return t("Unterwegs");
    if (zustand === "unknown" || zustand === "unavailable") return t("Unbekannt");
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
    return (km < 10 ? km.toFixed(1).replace(".", _dezimal) : Math.round(km)) + " km";
}

/** "seit 2 h", "seit 15 min" */
function formatSeit(ms, jetzt) {
    if (!ms) return "";
    var min = Math.max(0, Math.round((jetzt - ms) / 60000));
    if (min < 1) return t("gerade eben");
    if (min < 60) return t("seit %1 min", min);
    var h = Math.floor(min / 60);
    if (h < 24) return t("seit %1 h", h);
    return t("seit %1 d", Math.floor(h / 24));
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
        liste = [{ id: "i1", name: "", adresse: alteAdresse, token: alterToken, favorit: true }];
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
    var neuer = (releases || []).filter(function (r) { return r && typeof r.tag_name === "string" && !r.draft && !r.prerelease && versionNeuer(r.tag_name, aktuell); });
    neuer.sort(function (a, b) { return versionNeuer(a.tag_name, b.tag_name) ? -1 : 1; });
    if (!neuer.length) return null;
    var asset = (neuer[0].assets || []).filter(function (a) { return a.name === dateiname || (dateiname.indexOf("*") >= 0 && new RegExp("^" + dateiname.replace(/[.]/g, "\\.").replace("*", ".*") + "$").test(a.name)); })[0];
    var url = asset ? asset.browser_download_url : "";
    // nur Downloads aus diesem Projekt auf GitHub
    if (url && (url.indexOf("https://github.com/Teyro/HomeAssistantToolBox/releases/download/") !== 0 || url.indexOf("..") >= 0)) url = "";
    var seite = String(neuer[0].html_url || "");
    if (seite.indexOf("https://github.com/Teyro/HomeAssistantToolBox/") !== 0) seite = "https://github.com/Teyro/HomeAssistantToolBox/releases";
    return {
        version: neuer[0].tag_name.replace(/^v/, ""),
        url: url,
        seite: seite,
        notizen: neuer.map(function (r) { return { version: r.tag_name.replace(/^v/, ""), titel: r.name || r.tag_name, text: r.body || "" }; })
    };
}
