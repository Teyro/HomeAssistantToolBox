.pragma library
// Reine Hilfsfunktionen ohne Qt-Abhängigkeiten – werden auch außerhalb von Plasma getestet.

/** Template für Home Assistant: Räume (Bereiche) mit Lampen/Schaltern und Leistungssensoren je Schalter. */
var BEREICHE_TEMPLATE =
    "{%- set ns = namespace(a=[], p=[]) -%}" +
    "{%- for ar in areas() -%}" +
    "{%- set ns.a = ns.a + [{'id': ar, 'name': area_name(ar), 'e': area_entities(ar) | select('match', '(light|switch)\\\\.') | list}] -%}" +
    "{%- endfor -%}" +
    "{%- for s in states.switch -%}" +
    "{%- set d = device_id(s.entity_id) -%}" +
    "{%- if d -%}{%- for e in device_entities(d) -%}" +
    "{%- if e.startswith('sensor.') and state_attr(e, 'device_class') == 'power' -%}{%- set ns.p = ns.p + [[s.entity_id, e]] -%}{%- endif -%}" +
    "{%- endfor -%}{%- endif -%}" +
    "{%- endfor -%}" +
    "{{ {'bereiche': ns.a, 'leistung': ns.p} | tojson }}";

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
    var lichter = [], gruppen = [], schalter = [], leistung = [], energie = [];
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
            if (nurLicht.length && nurLicht.length === a.entity_id.length) {
                gruppen.push({ id: id, name: name(e), mitglieder: nurLicht, alt: true });
            }
        } else if (d === "switch") {
            if (opt.nurSteckdosen && a.device_class !== "outlet") return;
            // Ohne Entitäten-Register (keine WebSocket-Verbindung): typische Geräte-Einstellungen
            // am Namen erkennen, damit nicht jede "LED"- oder "Kindersicherung"-Option erscheint.
            if (!opt.register || !Object.keys(opt.register).length) {
                if (EINSTELLUNGS_SCHALTER.test(name(e)) || EINSTELLUNGS_SCHALTER.test(id)) return;
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
