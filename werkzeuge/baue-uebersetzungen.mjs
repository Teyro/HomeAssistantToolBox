// Erzeugt aus i18n/<sprache>.json:
//  - KDE: plasma/package/contents/locale/<code>/LC_MESSAGES/plasma_applet_<id>.mo (gettext)
//  - KDE: übersetzte Namen/Beschreibungen in metadata.json
//  - Mac: macos/ressourcen/i18n/<sprache>.json und macos/ressourcen/sprachen/<lproj>.lproj/Localizable.strings
// Aufruf: node werkzeuge/baue-uebersetzungen.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const wurzel = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const SPRACHEN = { en: { kde: 'en', lproj: 'en' }, zh: { kde: 'zh_CN', lproj: 'zh-Hans' }, hi: { kde: 'hi', lproj: 'hi' }, es: { kde: 'es', lproj: 'es' },
                   ar: { kde: 'ar', lproj: 'ar' }, fr: { kde: 'fr', lproj: 'fr' }, bn: { kde: 'bn', lproj: 'bn' } };
const meta = JSON.parse(fs.readFileSync(path.join(wurzel, 'plasma/package/metadata.json'), 'utf8'));
const id = meta.KPlugin.Id;
const BESCHREIBUNG = 'Lampen, Steckdosen, Heizung, Energie und Personen aus Home Assistant – im Panel und auf dem Schreibtisch';

// gettext .mo (little endian, ohne Hash-Tabelle)
function mo(eintraege) {
  const liste = [['', 'Content-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n'], ...Object.entries(eintraege).filter(([, v]) => v)]
    .map(([k, v]) => [Buffer.from(k, 'utf8'), Buffer.from(v, 'utf8')])
    .sort((a, b) => Buffer.compare(a[0], b[0]));
  const n = liste.length, kopf = 28, tabO = kopf, tabT = kopf + n * 8;
  let daten = tabT + n * 8;
  const teile = [], o = Buffer.alloc(n * 8), t = Buffer.alloc(n * 8);
  liste.forEach(([k], i) => { o.writeUInt32LE(k.length, i * 8); o.writeUInt32LE(daten, i * 8 + 4); teile.push(k, Buffer.from([0])); daten += k.length + 1; });
  liste.forEach(([, v], i) => { t.writeUInt32LE(v.length, i * 8); t.writeUInt32LE(daten, i * 8 + 4); teile.push(v, Buffer.from([0])); daten += v.length + 1; });
  const h = Buffer.alloc(kopf);
  h.writeUInt32LE(0x950412de, 0); h.writeUInt32LE(0, 4); h.writeUInt32LE(n, 8); h.writeUInt32LE(tabO, 12); h.writeUInt32LE(tabT, 16); h.writeUInt32LE(0, 20); h.writeUInt32LE(daten, 24);
  return Buffer.concat([h, o, t, ...teile]);
}
const strings = (tab) => Object.entries(tab).filter(([, v]) => v)
  .map(([k, v]) => `"${k.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')}" = "${v.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')}";`).join('\n') + '\n';

fs.rmSync(path.join(wurzel, 'plasma/package/contents/locale'), { recursive: true, force: true });
fs.mkdirSync(path.join(wurzel, 'macos/ressourcen/i18n'), { recursive: true });
const deutsch = Object.fromEntries(Object.keys(JSON.parse(fs.readFileSync(path.join(wurzel, 'i18n/en.json'), 'utf8'))).map((k) => [k, k]));
fs.mkdirSync(path.join(wurzel, 'macos/ressourcen/sprachen/de.lproj'), { recursive: true });
fs.writeFileSync(path.join(wurzel, 'macos/ressourcen/sprachen/de.lproj/Localizable.strings'), strings(deutsch));
for (const [s, c] of Object.entries(SPRACHEN)) {
  const tab = JSON.parse(fs.readFileSync(path.join(wurzel, 'i18n', s + '.json'), 'utf8'));
  const ordner = path.join(wurzel, 'plasma/package/contents/locale', c.kde, 'LC_MESSAGES');
  fs.mkdirSync(ordner, { recursive: true });
  fs.writeFileSync(path.join(ordner, `plasma_applet_${id}.mo`), mo(tab));
  if (tab[BESCHREIBUNG]) meta.KPlugin[`Description[${c.kde}]`] = tab[BESCHREIBUNG];
  fs.copyFileSync(path.join(wurzel, 'i18n', s + '.json'), path.join(wurzel, 'macos/ressourcen/i18n', s + '.json'));
  fs.mkdirSync(path.join(wurzel, 'macos/ressourcen/sprachen', c.lproj + '.lproj'), { recursive: true });
  fs.writeFileSync(path.join(wurzel, 'macos/ressourcen/sprachen', c.lproj + '.lproj', 'Localizable.strings'), strings(tab));
}
meta.KPlugin.Description = 'Lights, sockets, heating, energy and people from Home Assistant – in the panel and on the desktop';
meta.KPlugin['Description[de]'] = BESCHREIBUNG;
fs.writeFileSync(path.join(wurzel, 'plasma/package/metadata.json'), JSON.stringify(meta, null, 4) + '\n');
console.log('Übersetzungen gebaut:', Object.keys(SPRACHEN).join(', '));
