import fs from 'node:fs'; import vm from 'node:vm';
const code = fs.readFileSync(new URL('../package/contents/ui/logik.js', import.meta.url), 'utf8').replace('.pragma library', '');
const ctx = {}; vm.createContext(ctx); vm.runInContext(code, ctx);
// Zustände aus dem Mock holen
const r = await fetch('http://127.0.0.1:8123/api/states', { headers: { Authorization: 'Bearer test-token' } });
const liste = await r.json(); const z = {}; for (const e of liste) z[e.entity_id] = e;
const t = await (await fetch('http://127.0.0.1:8123/api/template', { method: 'POST', headers: { Authorization: 'Bearer test-token' }, body: JSON.stringify({ template: ctx.BEREICHE_TEMPLATE }) })).text();
const m = ctx.baueModell(z, JSON.parse(t), { hauptzaehler: 'sensor.stromzaehler_leistung', ausgeblendet: 'switch.router_*' });
console.log('Gruppen:', m.gruppen.map(g => `${g.name}[${g.mitglieder.length}]${g.alt ? '(alt)' : ''}`).join(', '));
console.log('Räume:', m.raeume.map(r => `${r.name}: ${r.lichter.length}L/${r.schalter.length}S`).join(', '));
console.log('Ohne Raum:', m.ohneRaum.join(', '), '| Lichter', m.lichter.length, 'an', m.lichterAn);
console.log('Schalter:', m.schalter.map(s => `${s.name}${s.raum ? '@' + s.raum : ''}${s.leistung ? '⚡' : ''}`).join(', '));
console.log('Leistung:', m.leistung.map(p => `${p.name} ${ctx.formatWatt(p.watt)}`).join(', '), '| Haupt', m.hauptWatt, 'Summe', ctx.formatWatt(m.summeWatt));
console.log('Energie:', m.energie.map(e => `${e.name} ${ctx.formatKwh(e.kwh)}`).join(', '));
for (const g of m.gruppen) console.log('  Status', g.name, JSON.stringify(ctx.gruppenStatus(g.mitglieder, z)), ctx.gruppenFarbe(g.mitglieder, z));
for (const id of ['light.wz_decke', 'light.wz_stehlampe', 'light.kinderzimmer', 'light.bad_spiegel', 'light.flur']) console.log('  ', id, ctx.helligkeit(z[id]), ctx.dimmbar(z[id]), ctx.lampenFarbe(z[id]), ctx.istVerfuegbar(z[id]));
console.log('Achsen', [0.5, 7, 612, 1450, 9000].map(x => ctx.achsenSchritt(x, 3)).join(' '));
console.log('Watt', [0, 4.21, 86.3, 1240, 23456].map(ctx.formatWatt).join(' | '));
const prefs = { energy_sources: [{ type: 'grid', flow_from: [{ stat_energy_from: 'sensor.a' }, { stat_energy_from: 'sensor.b' }] }, { type: 'gas', stat_energy_from: 'sensor.g' }, { type: 'water', stat_energy_from: 'sensor.w' }] };
console.log('Dashboard', JSON.stringify(ctx.zaehlerAusEnergieDashboard(prefs)));
const mn = new Date(2026, 9, 3).getTime(), iso = (h) => new Date(mn + h * 3600e3).toISOString();
console.log('Tag', JSON.stringify(ctx.tagesVerbrauch([{ state: '100', last_changed: iso(-24) }, { state: '103', last_changed: iso(-2) }, { state: '104', last_changed: iso(3) }, { state: '1', last_changed: iso(5) }, { state: '2.5', last_changed: iso(8) }], mn)));
console.log('Menge', ctx.formatMenge(6.17, 'kWh', 'strom'), '|', ctx.formatMenge(0.1057, 'm³', 'wasser'), '|', ctx.formatMenge(1.41, 'm³', 'gas'), '|', ctx.formatMenge(12.3, 'kWh', 'gas'), '|', ctx.formatMenge(NaN, '', 'gas'));

// 2.1: Heizung und Personen
const hz = ctx.heizungen(z, JSON.parse(t), []);
console.log('Heizung:', hz.map(h => { const k = ctx.raumKlima(h, z); return h.name + ' ' + ctx.formatTemp(k.ist) + (k.heizt ? ' heizt' : ''); }).join(', '));
console.log('Personen:', ctx.personen(z).map(p => p.name + '=' + ctx.ortText(p.zustand) + ' ' + p.farbe).join(', '));
console.log('Instanzen:', JSON.stringify(ctx.instanzenLesen('', 'http://x', 'tok')), ctx.neueInstanzId([{ id: 'i1' }]));
console.log('Zoom', ctx.passenderZoom([{ lat: 53.5656, lon: 10.1172 }, { lat: 53.5503, lon: 9.9925 }], 500, 300));

// 1.1: Wo ist? – Personen und Ortungsgeräte, auch aus einer zweiten Installation
const o = ctx.orter(z, ['device_tracker.macbook'], { id: 'i1', name: 'Zuhause' }, false);
console.log('Orter:', o.map((x) => `${x.name}[${x.art}]${x.akku !== null ? ' ' + x.akku + '%' : ''} ${x.ort}`).join(', '));
if (o.some((x) => x.entitaet === 'device_tracker.router_handy')) throw new Error('Tracker ohne GPS darf nicht erscheinen');
if (o.some((x) => x.entitaet === 'device_tracker.macbook')) throw new Error('ausgeblendet');
if (o.find((x) => x.entitaet === 'person.anna').akku !== 57) throw new Error('Akku über Sensor der Companion-App');
if (o.find((x) => x.entitaet === 'device_tracker.fahrrad').art !== 'objekte') throw new Error('Fahrrad = Objekt');
const z2 = {}; for (const e of await (await fetch('http://127.0.0.1:8124/api/states', { headers: { Authorization: 'Bearer ferien-token' } })).json().catch(() => [])) z2[e.entity_id] = e;
if (Object.keys(z2).length) {
  const o2 = ctx.orter(z2, [], { id: 'i2', name: 'Ferienhaus' }, true);
  console.log('Orter Ferienhaus:', o2.map((x) => `${x.id} ${x.ort}`).join(', '));
  if (!o2.every((x) => x.id.endsWith('@i2'))) throw new Error('Schlüssel weiterer Installation');
}
const vb = await (await fetch('http://127.0.0.1:8123/api/history/period/' + encodeURIComponent(new Date(Date.now() - 6 * 3600e3).toISOString()) + '?filter_entity_id=person.ben,device_tracker.fahrrad', { headers: { Authorization: 'Bearer test-token' } })).json();
const spur = ctx.ortSpur(vb, 'person.ben', Date.now() - 6 * 3600e3);
const ben = o.find((x) => x.entitaet === 'person.ben');
const s3 = ctx.spurSeit(spur, 180, Date.now(), ben);
console.log('Spur Ben:', spur.length, 'Punkte (ohne ungenaue), 3 h:', s3.length, 'Punkte,', ctx.formatEntfernung(ctx.streckeKm(s3)), '| Stufen', ctx.VERLAUF_STUFEN.map(ctx.verlaufStufeText).join('/'), '| Akku', ctx.akkuSymbol(23), ctx.akkuSymbol(100));
if (spur.length !== 12) throw new Error('Spur: ' + spur.length);
if (ctx.spurSeit(spur, 0, Date.now(), ben).length) throw new Error('Stufe aus');
