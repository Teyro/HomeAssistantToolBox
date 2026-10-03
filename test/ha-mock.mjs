// Nachgebautes Home Assistant (REST + WebSocket) mit einer Beispielwohnung – zum Testen des Plasmoids.
import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TOKEN = 'test-token';
const PORT = Number(process.argv[2] || 8123);
const LOG = process.env.HA_MOCK_LOG || '/tmp/ha-mock.log';
fs.writeFileSync(LOG, '');
const log = (s) => fs.appendFileSync(LOG, s + '\n');

const jetzt = () => new Date().toISOString();
const z = {};
function lampe(id, name, an, attr = {}) {
  z[id] = { entity_id: id, state: an === null ? 'unavailable' : an ? 'on' : 'off', last_changed: jetzt(), attributes: { friendly_name: name, supported_color_modes: ['color_temp', 'xy'], ...attr } };
  if (!an) delete z[id].attributes.brightness;
}
lampe('light.wz_decke', 'Deckenlampe Wohnzimmer', true, { brightness: 180, color_mode: 'color_temp', color_temp_kelvin: 2700 });
lampe('light.wz_stehlampe', 'Stehlampe', true, { brightness: 90, color_mode: 'xy', rgb_color: [255, 120, 60] });
lampe('light.wz_led_strip', 'LED-Streifen TV', false, {});
lampe('light.kueche_decke', 'Küche Decke', true, { brightness: 255, color_mode: 'color_temp', color_temp_kelvin: 4000 });
lampe('light.kueche_spots', 'Küche Spots', false, { supported_color_modes: ['brightness'] });
lampe('light.schlafzimmer_nachttisch', 'Nachttischlampe', true, { brightness: 40, color_mode: 'color_temp', color_temp_kelvin: 2200 });
lampe('light.bad_spiegel', 'Spiegelschrank', false, { supported_color_modes: ['onoff'] });
lampe('light.flur', 'Flur', null, { supported_color_modes: ['brightness'] });
lampe('light.kinderzimmer', 'Sternenhimmel', true, { brightness: 120, color_mode: 'hs', rgb_color: [80, 120, 255] });
lampe('light.terrasse', 'Terrasse', false, { supported_color_modes: ['onoff'] });
lampe('light.einfahrt', 'Einfahrt', false, { supported_color_modes: ['onoff'] });
lampe('light.buero_schreibtisch', 'Schreibtischlampe', true, { brightness: 210, color_mode: 'color_temp', color_temp_kelvin: 5200 });
// Lichtgruppen (Helfer "Gruppe" → Licht)
z['light.wohnzimmer'] = { entity_id: 'light.wohnzimmer', state: 'on', last_changed: jetzt(), attributes: { friendly_name: 'Wohnzimmer', entity_id: ['light.wz_decke', 'light.wz_stehlampe', 'light.wz_led_strip'], supported_color_modes: ['color_temp', 'xy'], brightness: 135 } };
z['light.kueche_alle'] = { entity_id: 'light.kueche_alle', state: 'on', last_changed: jetzt(), attributes: { friendly_name: 'Küche komplett', entity_id: ['light.kueche_decke', 'light.kueche_spots'], supported_color_modes: ['color_temp'], brightness: 255 } };
// klassische Gruppe
z['group.aussen'] = { entity_id: 'group.aussen', state: 'off', last_changed: jetzt(), attributes: { friendly_name: 'Außenbeleuchtung', entity_id: ['light.terrasse', 'light.einfahrt'] } };
// Steckdosen
function schalter(id, name, an, klasse = 'outlet') { z[id] = { entity_id: id, state: an ? 'on' : 'off', last_changed: jetzt(), attributes: { friendly_name: name, device_class: klasse } }; }
schalter('switch.kaffeemaschine', 'Kaffeemaschine', true);
schalter('switch.tv', 'Fernseher', true);
schalter('switch.pc', 'Rechner', true);
schalter('switch.waschmaschine', 'Waschmaschine', false);
schalter('switch.heizluefter', 'Heizlüfter Bad', false);
schalter('switch.weihnachtsbaum', 'Weihnachtsbaum', false);
schalter('switch.router_neustart', 'Router-Neustart', false, 'switch');
// Steckdosenleiste mit drei Dosen (ein Gerät) und eine Schaltergruppe (Helfer)
schalter('switch.leiste_dose_1', 'Schreibtischleiste Dose 1', true);
schalter('switch.leiste_dose_2', 'Schreibtischleiste Dose 2', true);
schalter('switch.leiste_dose_3', 'Schreibtischleiste Dose 3', false);
schalter('switch.lichterkette', 'Lichterkette Balkon', false);
z['switch.weihnachtsdeko'] = { entity_id: 'switch.weihnachtsdeko', state: 'off', last_changed: jetzt(), attributes: { friendly_name: 'Weihnachtsdeko', entity_id: ['switch.weihnachtsbaum', 'switch.lichterkette'] } };
sensor('sensor.leiste_leistung', 'Schreibtischleiste Leistung', 61.5, 'W', 'power');
// Einstellungs-Schalter von Geräten (entity_category: config) – dürfen nicht als Steckdose erscheinen
schalter('switch.kaffeemaschine_led', 'Kaffeemaschine LED', true, 'switch');
schalter('switch.tv_kindersicherung', 'Fernseher Kindersicherung', false, 'switch');
lampe('light.alter_strahler', 'Alter Strahler (versteckt)', true, { brightness: 200 });
// Sensoren
function sensor(id, name, wert, einheit, klasse) { z[id] = { entity_id: id, state: String(wert), last_changed: jetzt(), attributes: { friendly_name: name, unit_of_measurement: einheit, device_class: klasse, state_class: 'measurement' } }; }
sensor('sensor.kaffeemaschine_leistung', 'Kaffeemaschine Leistung', 4.2, 'W', 'power');
sensor('sensor.tv_power', 'Fernseher Leistung', 86.3, 'W', 'power');
sensor('sensor.pc_leistung', 'Rechner Leistung', 143.8, 'W', 'power');
sensor('sensor.waschmaschine_power', 'Waschmaschine Leistung', 0, 'W', 'power');
sensor('sensor.kuehlschrank_leistung', 'Kühlschrank', 52.1, 'W', 'power');
sensor('sensor.stromzaehler_leistung', 'Stromzähler Leistung', 612, 'W', 'power');
sensor('sensor.waermepumpe_leistung', 'Wärmepumpe', 1.24, 'kW', 'power');
sensor('sensor.stromzaehler_bezug', 'Stromzähler Bezug', 12456.31, 'kWh', 'energy');
sensor('sensor.pv_heute', 'PV-Ertrag heute', 8.42, 'kWh', 'energy');
sensor('sensor.waschmaschine_energie', 'Waschmaschine Energie', 210.5, 'kWh', 'energy');
sensor('sensor.temperatur', 'Temperatur Wohnzimmer', 21.4, '°C', 'temperature');

const BEREICHE = [
  ['wohnzimmer', 'Wohnzimmer', ['light.wz_decke', 'light.wz_stehlampe', 'light.wz_led_strip', 'switch.tv']],
  ['kueche', 'Küche', ['light.kueche_decke', 'light.kueche_spots', 'switch.kaffeemaschine']],
  ['schlafzimmer', 'Schlafzimmer', ['light.schlafzimmer_nachttisch']],
  ['bad', 'Bad', ['light.bad_spiegel', 'switch.heizluefter']],
  ['kinderzimmer', 'Kinderzimmer', ['light.kinderzimmer']],
  ['buero', 'Büro', ['light.buero_schreibtisch', 'switch.pc', 'switch.leiste_dose_1', 'switch.leiste_dose_2', 'switch.leiste_dose_3']],
  ['flur', 'Flur', ['light.flur']],
  ['keller', 'Keller', ['switch.waschmaschine']],
];
const GERAETE = Object.keys(z).filter((id) => id.startsWith('switch.') && !z[id].attributes.entity_id).map((id) => id.startsWith('switch.leiste_') ? [id, 'leiste1', 'Schreibtischleiste'] : [id, 'dev_' + id, z[id].attributes.friendly_name]);
const LEISTUNG = [['switch.leiste_dose_1', 'sensor.leiste_leistung'], ['switch.leiste_dose_2', 'sensor.leiste_leistung'], ['switch.leiste_dose_3', 'sensor.leiste_leistung'], ['switch.kaffeemaschine', 'sensor.kaffeemaschine_leistung'], ['switch.tv', 'sensor.tv_power'], ['switch.pc', 'sensor.pc_leistung'], ['switch.waschmaschine', 'sensor.waschmaschine_power']];

function verlauf(id) {
  const punkte = [];
  const ende = Date.now();
  let w = 400;
  for (let t = ende - 24 * 3600e3; t < ende; t += 10 * 60e3) {
    const h = new Date(t).getHours();
    const basis = h < 6 ? 220 : h < 8 ? 650 : h < 12 ? 380 : h < 14 ? 1450 : h < 18 ? 420 : h < 22 ? 900 : 350;
    w = Math.max(80, basis + Math.sin(t / 3e6) * 90 + (Math.random() - 0.5) * 120);
    punkte.push({ state: w.toFixed(1), last_changed: new Date(t).toISOString() });
  }
  return [punkte];
}

// ---- WebSocket ----
const clients = new Set();
function wsSenden(sock, obj) {
  const daten = Buffer.from(JSON.stringify(obj));
  let kopf;
  if (daten.length < 126) kopf = Buffer.from([0x81, daten.length]);
  else if (daten.length < 65536) { kopf = Buffer.alloc(4); kopf[0] = 0x81; kopf[1] = 126; kopf.writeUInt16BE(daten.length, 2); }
  else { kopf = Buffer.alloc(10); kopf[0] = 0x81; kopf[1] = 127; kopf.writeBigUInt64BE(BigInt(daten.length), 2); }
  sock.write(Buffer.concat([kopf, daten]));
}
function wsLesen(puffer) {
  const nachrichten = [];
  let o = 0;
  while (puffer.length - o >= 2) {
    const op = puffer[o] & 0x0f;
    let len = puffer[o + 1] & 0x7f; let p = o + 2;
    if (len === 126) { len = puffer.readUInt16BE(p); p += 2; } else if (len === 127) { len = Number(puffer.readBigUInt64BE(p)); p += 8; }
    const maske = puffer.slice(p, p + 4); p += 4;
    if (puffer.length < p + len) break;
    const d = Buffer.alloc(len);
    for (let i = 0; i < len; i++) d[i] = puffer[p + i] ^ maske[i % 4];
    nachrichten.push({ op, text: d.toString() });
    o = p + len;
  }
  return { nachrichten, rest: puffer.slice(o) };
}
function aendern(id, aenderung) {
  const alt = z[id];
  if (!alt) return null;
  const neu = { ...alt, ...aenderung, attributes: { ...alt.attributes, ...(aenderung.attributes || {}) }, last_changed: jetzt() };
  if (neu.state === 'off') delete neu.attributes.brightness;
  z[id] = neu;
  for (const c of clients) if (c.auth && c.abo) wsSenden(c.sock, { id: c.abo, type: 'event', event: { event_type: 'state_changed', data: { entity_id: id, old_state: alt, new_state: neu } } });
  return neu;
}
function gruppenAktualisieren() {
  for (const g of ['light.wohnzimmer', 'light.kueche_alle', 'group.aussen', 'switch.weihnachtsdeko']) {
    const m = z[g].attributes.entity_id;
    const an = m.filter((x) => z[x].state === 'on');
    const b = an.length ? Math.round(an.reduce((s, x) => s + (z[x].attributes.brightness || 255), 0) / an.length) : undefined;
    const st = an.length ? 'on' : 'off';
    if (z[g].state !== st || z[g].attributes.brightness !== b) aendern(g, { state: st, attributes: { brightness: b } });
  }
}

const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    log(`${req.method} ${req.url} ${body.slice(0, 200)}`);
    if (req.headers.authorization !== 'Bearer ' + TOKEN) { res.writeHead(401); res.end('401: Unauthorized'); return; }
    const url = new URL(req.url, 'http://x');
    const json = (o) => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(o)); };
    if (url.pathname === '/api/states') return json(Object.values(z));
    if (url.pathname === '/api/template') {
      const t = JSON.parse(body).template;
      if (!t.includes('areas()')) { res.writeHead(400); res.end('?'); return; }
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      return res.end(JSON.stringify({ bereiche: BEREICHE.map(([id, name, e]) => ({ id, name, e })), leistung: LEISTUNG, geraete: GERAETE }));
    }
    if (url.pathname.startsWith('/api/history/period/')) return json(verlauf(url.searchParams.get('filter_entity_id')));
    const m = url.pathname.match(/^\/api\/services\/(\w+)\/(\w+)$/);
    if (m) {
      const d = JSON.parse(body || '{}');
      const ids = [].concat(d.entity_id || []);
      const geaendert = [];
      const ziel = (id) => {
        const e = z[id]; if (!e) return;
        if (e.attributes.entity_id && (id.startsWith('group.') || id.startsWith('light.'))) { e.attributes.entity_id.forEach(ziel); return; }
        if (m[2] === 'turn_off') geaendert.push(aendern(id, { state: 'off' }));
        else if (m[2] === 'turn_on') geaendert.push(aendern(id, { state: 'on', attributes: d.brightness_pct !== undefined ? { brightness: Math.round(d.brightness_pct * 2.55) } : (z[id].attributes.brightness ? {} : (id.startsWith('light.') && z[id].attributes.supported_color_modes[0] !== 'onoff' ? { brightness: 255 } : {})) }));
        else if (m[2] === 'toggle') geaendert.push(aendern(id, { state: z[id].state === 'on' ? 'off' : 'on' }));
      };
      ids.forEach(ziel);
      gruppenAktualisieren();
      return json(geaendert.filter(Boolean));
    }
    res.writeHead(404); res.end('nicht gefunden');
  });
});
server.on('upgrade', (req, sock) => {
  const key = req.headers['sec-websocket-key'];
  const accept = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  sock.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  const c = { sock, auth: false, abo: null };
  clients.add(c);
  log('WS verbunden');
  wsSenden(sock, { type: 'auth_required', ha_version: '2026.10.0' });
  let puffer = Buffer.alloc(0);
  sock.on('data', (d) => {
    puffer = Buffer.concat([puffer, d]);
    const { nachrichten, rest } = wsLesen(puffer);
    puffer = rest;
    for (const n of nachrichten) {
      if (n.op === 8) { sock.end(); return; }
      if (n.op !== 1) continue;
      const m = JSON.parse(n.text);
      log('WS ' + n.text.slice(0, 120));
      if (m.type === 'auth') {
        if (m.access_token === TOKEN) { c.auth = true; wsSenden(sock, { type: 'auth_ok', ha_version: '2026.10.0' }); }
        else { wsSenden(sock, { type: 'auth_invalid', message: 'Invalid access token' }); sock.end(); }
      } else if (m.type === 'config/entity_registry/list_for_display') {
        wsSenden(sock, { id: m.id, type: 'result', success: true, result: { entity_categories: { 0: 'config', 1: 'diagnostic' }, entities: [
          { ei: 'switch.kaffeemaschine_led', ec: 0 }, { ei: 'switch.tv_kindersicherung', ec: 0 }, { ei: 'light.alter_strahler', hb: true },
          { ei: 'switch.kaffeemaschine', di: 'd1' }, { ei: 'light.wz_decke', ai: 'wohnzimmer' } ] } });
      } else if (m.type === 'subscribe_events') { c.abo = m.id; wsSenden(sock, { id: m.id, type: 'result', success: true, result: null }); }
    }
  });
  sock.on('close', () => clients.delete(c));
  sock.on('error', () => clients.delete(c));
});
// Ab und zu ändern sich Werte "von außen" (wie in echt) – sollte live ankommen
setInterval(() => {
  aendern('sensor.stromzaehler_leistung', { state: String(Math.round(500 + Math.random() * 400)) });
  aendern('sensor.pc_leistung', { state: (120 + Math.random() * 60).toFixed(1) });
}, 3000);
server.listen(PORT, '127.0.0.1', () => log('läuft auf ' + PORT));
