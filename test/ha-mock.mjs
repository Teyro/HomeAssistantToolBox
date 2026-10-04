// Nachgebautes Home Assistant (REST + WebSocket) mit einer Beispielwohnung – zum Testen (Plasma-Widget und macOS-App).
import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TOKEN = process.env.HA_MOCK_TOKEN || 'test-token';
const NAME = process.env.HA_MOCK_NAME || 'Zuhause';
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
sensor('sensor.wasserzaehler', 'Wasserzähler', 412.873, 'm³', 'water');
sensor('sensor.gaszaehler', 'Gaszähler', 3021.44, 'm³', 'gas');
sensor('sensor.temperatur', 'Temperatur Wohnzimmer', 21.4, '°C', 'temperature');
sensor('sensor.kueche_temperatur', 'Küche Temperatur', 20.7, '°C', 'temperature');
sensor('sensor.wz_feuchte', 'Wohnzimmer Luftfeuchte', 46, '%', 'humidity');
sensor('sensor.bad_feuchte', 'Bad Luftfeuchte', 63, '%', 'humidity');
// Heizung: Thermostate je Raum
function thermostat(id, name, ist, ziel, modus, extra = {}) {
  z[id] = { entity_id: id, state: modus, last_changed: jetzt(), attributes: { friendly_name: name, current_temperature: ist, temperature: ziel,
    hvac_modes: ['off', 'heat', 'auto'], hvac_action: modus === 'off' ? 'off' : ist < ziel - 0.2 ? 'heating' : 'idle',
    preset_modes: ['none', 'eco', 'comfort', 'boost', 'away'], preset_mode: 'none', min_temp: 5, max_temp: 30, target_temp_step: 0.5,
    supported_features: 401, ...extra } };
}
thermostat('climate.wohnzimmer', 'Heizung Wohnzimmer', 20.6, 21.5, 'heat');
thermostat('climate.schlafzimmer', 'Heizung Schlafzimmer', 18.2, 18, 'auto');
thermostat('climate.bad', 'Heizung Bad', 21.9, 23, 'heat');
thermostat('climate.kinderzimmer', 'Heizung Kinderzimmer', 20.1, 20, 'heat', { preset_mode: 'comfort' });
thermostat('climate.buero', 'Heizung Büro', 17.4, 19, 'off');
// Fensterkontakte
function fenster(id, name, offen) { z[id] = { entity_id: id, state: offen ? 'on' : 'off', last_changed: jetzt(), attributes: { friendly_name: name, device_class: 'window' } }; }
fenster('binary_sensor.wz_fenster', 'Fenster Wohnzimmer', false);
fenster('binary_sensor.bad_fenster', 'Fenster Bad', true);
fenster('binary_sensor.schlafzimmer_fenster', 'Fenster Schlafzimmer', false);
// Personen und Zonen (Hamburg)
const HEIM = [53.5656, 10.1172];
z['zone.home'] = { entity_id: 'zone.home', state: '2', last_changed: jetzt(), attributes: { friendly_name: 'Zuhause', latitude: HEIM[0], longitude: HEIM[1], radius: 120, icon: 'mdi:home' } };
z['zone.arbeit'] = { entity_id: 'zone.arbeit', state: '1', last_changed: jetzt(), attributes: { friendly_name: 'Arbeit', latitude: 53.5503, longitude: 9.9925, radius: 150, icon: 'mdi:briefcase' } };
function person(id, name, zustand, lat, lon) { z[id] = { entity_id: id, state: zustand, last_changed: new Date(Date.now() - 3600e3 * (1 + Object.keys(z).length % 5)).toISOString(), attributes: { friendly_name: name, latitude: lat, longitude: lon, gps_accuracy: 12, source: 'device_tracker.' + id.split('.')[1] + '_handy', user_id: 'u_' + id } }; }
person('person.anna', 'Anna', 'home', HEIM[0] + 0.0002, HEIM[1] - 0.0003);
person('person.ben', 'Ben', 'not_home', 53.5585, 10.0601);
person('person.carla', 'Carla', 'Arbeit', 53.5506, 9.9931);

if (NAME !== 'Zuhause') {
  // Zweite Instanz (z. B. "Ferienhaus"): nur ein paar Geräte, damit der Wechsel sichtbar ist
  for (const id of Object.keys(z)) if (!/^(light\.(terrasse|einfahrt|kueche_decke)|switch\.(kaffeemaschine|waschmaschine)|sensor\.(kaffeemaschine_leistung|stromzaehler_leistung|temperatur)|climate\.(wohnzimmer|schlafzimmer)|zone\.home|person\.anna)$/.test(id)) delete z[id];
  z['light.kueche_decke'].attributes.friendly_name = 'Ferienhaus Küche';
}
const BEREICHE = [
  ['wohnzimmer', 'Wohnzimmer', ['light.wz_decke', 'light.wz_stehlampe', 'light.wz_led_strip', 'switch.tv', 'climate.wohnzimmer'], ['sensor.temperatur'], ['sensor.wz_feuchte'], ['binary_sensor.wz_fenster']],
  ['kueche', 'Küche', ['light.kueche_decke', 'light.kueche_spots', 'switch.kaffeemaschine'], ['sensor.kueche_temperatur']],
  ['schlafzimmer', 'Schlafzimmer', ['light.schlafzimmer_nachttisch', 'climate.schlafzimmer'], [], [], ['binary_sensor.schlafzimmer_fenster']],
  ['bad', 'Bad', ['light.bad_spiegel', 'switch.heizluefter', 'climate.bad'], [], ['sensor.bad_feuchte'], ['binary_sensor.bad_fenster']],
  ['kinderzimmer', 'Kinderzimmer', ['light.kinderzimmer', 'climate.kinderzimmer']],
  ['buero', 'Büro', ['light.buero_schreibtisch', 'switch.pc', 'switch.leiste_dose_1', 'switch.leiste_dose_2', 'switch.leiste_dose_3', 'climate.buero']],
  ['flur', 'Flur', ['light.flur']],
  ['keller', 'Keller', ['switch.waschmaschine']],
];
const GERAETE = Object.keys(z).filter((id) => id.startsWith('switch.') && !z[id].attributes.entity_id).map((id) => id.startsWith('switch.leiste_') ? [id, 'leiste1', 'Schreibtischleiste'] : [id, 'dev_' + id, z[id].attributes.friendly_name]);
const LEISTUNG = [['switch.leiste_dose_1', 'sensor.leiste_leistung'], ['switch.leiste_dose_2', 'sensor.leiste_leistung'], ['switch.leiste_dose_3', 'sensor.leiste_leistung'], ['switch.kaffeemaschine', 'sensor.kaffeemaschine_leistung'], ['switch.tv', 'sensor.tv_power'], ['switch.pc', 'sensor.pc_leistung'], ['switch.waschmaschine', 'sensor.waschmaschine_power']];

// Zählerstände für "Verbrauch heute" ohne Live-Verbindung (seit gestern 0 Uhr)
const ZUWACHS = { 'sensor.stromzaehler_bezug': 0.35, 'sensor.wasserzaehler': 0.006, 'sensor.gaszaehler': 0.08 };
function zaehlerVerlauf(id) {
  const start = new Date(); start.setHours(0, 0, 0, 0); start.setDate(start.getDate() - 1);
  const ende = Date.now(), schritte = Math.floor((ende - start) / 3600e3);
  const jetztWert = parseFloat(z[id].state);
  const punkte = [];
  for (let i = 0; i <= schritte; i++) {
    const t = start.getTime() + i * 3600e3;
    const p = { state: (jetztWert - (schritte - i) * ZUWACHS[id]).toFixed(3), last_changed: new Date(t).toISOString() };
    if (i === 0) p.entity_id = id;
    punkte.push(p);
  }
  return punkte;
}
// 24 h Heizungsverlauf: Ziel tagsüber 21,5 °C, nachts 18 °C, Ist-Temperatur läuft hinterher
function klimaVerlauf(id) {
  const liste = [];
  const ende = Date.now();
  let ist = 19;
  const basisZiel = (z[id] && z[id].attributes.temperature) || 21;
  for (let t = ende - 24 * 3600e3, i = 0; t < ende; t += 15 * 60e3, i++) {
    const h = new Date(t).getHours();
    const ziel = h >= 22 || h < 6 ? 18 : basisZiel;
    const heizt = ist < ziel - 0.2;
    ist = Math.round((ist + (heizt ? 0.25 : -0.12) + (Math.random() - 0.5) * 0.05) * 10) / 10;
    liste.push({ entity_id: id, state: 'heat', last_changed: new Date(t).toISOString(),
                 attributes: { ...(z[id] ? z[id].attributes : {}), current_temperature: ist, temperature: ziel, hvac_action: heizt ? 'heating' : 'idle' } });
  }
  return liste;
}
function tempVerlauf(id) {
  return klimaVerlauf('climate.wohnzimmer').map((p, i) => ({ ...(i === 0 ? { entity_id: id } : {}), state: String(Math.round((p.attributes.current_temperature + 0.3) * 10) / 10), last_changed: p.last_changed }));
}
function verlauf(id) {
  const ids = (id || '').split(',');
  if (ids.some((x) => x.startsWith('climate.') || (z[x] && z[x].attributes.device_class === 'temperature')))
    return ids.map((x) => x.startsWith('climate.') ? klimaVerlauf(x) : tempVerlauf(x));
  if (ids.some((x) => ZUWACHS[x])) return ids.filter((x) => ZUWACHS[x]).map(zaehlerVerlauf);
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
    // Nachgebaute GitHub-Releases für den Updater-Test (ohne Anmeldung)
    if (req.url.startsWith('/github/releases')) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      const basis = 'https://github.com/Teyro/homeassistant-leiste/releases/download/';
      return res.end(JSON.stringify([
        { tag_name: 'v2.3.0', name: '2.3.0 – Testversion', draft: false, prerelease: false, html_url: 'https://github.com/Teyro/homeassistant-leiste/releases/tag/v2.3.0',
          body: '**Neu**\n\n- Testfunktion A für die Heizung\n- Testfunktion B: schönere Karte\n\n**Behoben**\n\n- Ein Fehler beim Wechseln der Instanz',
          assets: [{ name: 'home-assistant.plasmoid', browser_download_url: basis + 'v2.3.0/home-assistant.plasmoid' }, { name: 'HA-Leiste-2.3.0.zip', browser_download_url: basis + 'v2.3.0/HA-Leiste-2.3.0.zip' }] },
        { tag_name: 'v2.2.0', name: '2.2.0', draft: false, prerelease: false, body: 'Updater, Fenster offen, Verlauf der Heizung', assets: [] },
        { tag_name: 'v2.1.0', name: '2.1.0', draft: false, prerelease: false, body: 'Instanzen, Heizung, Personen, Widgets', assets: [] }]));
    }
    if (req.headers.authorization !== 'Bearer ' + TOKEN) { res.writeHead(401); res.end('401: Unauthorized'); return; }
    const url = new URL(req.url, 'http://x');
    const json = (o) => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(o)); };
    if (url.pathname === '/api/states') return json(Object.values(z));
    if (url.pathname === '/api/config') return json({ location_name: NAME, latitude: HEIM[0], longitude: HEIM[1], unit_system: { temperature: '°C' }, version: '2026.10.0' });
    if (url.pathname === '/api/template') {
      const t = JSON.parse(body).template;
      if (!t.includes('areas()')) { res.writeHead(400); res.end('?'); return; }
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      return res.end(JSON.stringify({ bereiche: BEREICHE.map(([id, name, e, t = [], h = [], f = []]) => ({ id, name, e, t, h, f })), leistung: LEISTUNG, geraete: GERAETE }));
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
      if (m[1] === 'climate') {
        for (const id of ids) {
          if (!z[id]) continue;
          const a = {};
          let st = z[id].state;
          if (m[2] === 'set_temperature' && d.temperature !== undefined) { a.temperature = d.temperature; if (d.hvac_mode) st = d.hvac_mode; else if (st === 'off') st = 'heat'; }
          if (m[2] === 'set_hvac_mode') st = d.hvac_mode;
          if (m[2] === 'set_preset_mode') a.preset_mode = d.preset_mode;
          if (m[2] === 'turn_off') st = 'off';
          if (m[2] === 'turn_on') st = 'heat';
          const ist = z[id].attributes.current_temperature, zielT = a.temperature ?? z[id].attributes.temperature;
          a.hvac_action = st === 'off' ? 'off' : ist < zielT - 0.2 ? 'heating' : 'idle';
          geaendert.push(aendern(id, { state: st, attributes: a }));
        }
        return json(geaendert.filter(Boolean));
      }
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
      if (n.op === 9) { const d = Buffer.from(n.text); sock.write(Buffer.concat([Buffer.from([0x8a, d.length]), d])); log('WS ping'); continue; }
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
      } else if (m.type === 'energy/get_prefs') {
        wsSenden(sock, { id: m.id, type: 'result', success: true, result: { energy_sources: [
          { type: 'grid', flow_from: [{ stat_energy_from: 'sensor.stromzaehler_bezug' }], flow_to: [] },
          { type: 'solar', stat_energy_from: 'sensor.pv_heute' },
          { type: 'gas', stat_energy_from: 'sensor.gaszaehler' },
          { type: 'water', stat_energy_from: 'sensor.wasserzaehler' } ], device_consumption: [] } });
      } else if (m.type === 'recorder/get_statistics_metadata') {
        wsSenden(sock, { id: m.id, type: 'result', success: true, result: (m.statistic_ids || []).filter((x) => z[x]).map((x) => ({ statistic_id: x, statistics_unit_of_measurement: z[x].attributes.unit_of_measurement })) });
      } else if (m.type === 'recorder/statistic_during_period') {
        const h = new Date().getHours() + new Date().getMinutes() / 60;
        const f = { 'sensor.stromzaehler_bezug': 0.35, 'sensor.wasserzaehler': 0.006, 'sensor.gaszaehler': 0.08 }[m.statistic_id] || 0;
        const change = m.calendar && m.calendar.offset === -1 ? f * 24 * 1.08 : f * h;
        wsSenden(sock, { id: m.id, type: 'result', success: true, result: { change } });
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
  // Ben ist unterwegs nach Hause
  const b = z['person.ben'];
  if (b) {
    const lat = b.attributes.latitude + (HEIM[0] - b.attributes.latitude) * 0.08, lon = b.attributes.longitude + (HEIM[1] - b.attributes.longitude) * 0.08;
    const da = Math.hypot(lat - HEIM[0], (lon - HEIM[1]) * 0.6) < 0.0012;
    aendern('person.ben', da ? { state: 'home', attributes: { latitude: HEIM[0] - 0.0002, longitude: HEIM[1] + 0.0002 } } : { attributes: { latitude: lat, longitude: lon } });
    if (da) z['person.ben'] = { ...z['person.ben'] }; // bleibt dann zu Hause
  }
  // Thermostate nähern sich dem Ziel
  for (const id of Object.keys(z).filter((x) => x.startsWith('climate.'))) {
    const a = z[id].attributes; if (z[id].state === 'off') continue;
    const ist = Math.round((a.current_temperature + (a.temperature > a.current_temperature ? 0.1 : -0.05)) * 10) / 10;
    aendern(id, { attributes: { current_temperature: ist, hvac_action: ist < a.temperature - 0.2 ? 'heating' : 'idle' } });
  }
}, 3000);
server.listen(PORT, '127.0.0.1', () => log('läuft auf ' + PORT));
