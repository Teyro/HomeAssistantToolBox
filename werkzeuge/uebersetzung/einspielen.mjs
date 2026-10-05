// Spielt die Übersetzungslisten (<sprache>.tsv: "Nummer<TAB>Text") in i18n/<sprache>.json ein.
// Die Nummern beziehen sich auf die Liste von 2026-10-05 (mit zwei entfallenen Einträgen 5 und 6).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const hier = path.dirname(fileURLToPath(import.meta.url));
const wurzel = path.join(hier, '../..');
const schluessel = Object.keys(JSON.parse(fs.readFileSync(path.join(wurzel, 'i18n/vorlage.json'), 'utf8')));
const alt = schluessel.slice(0, 5).concat([null, null], schluessel.slice(5));
for (const datei of fs.readdirSync(hier).filter((d) => d.endsWith('.tsv'))) {
  const sprache = datei.slice(0, -4);
  const ziel = path.join(wurzel, 'i18n', sprache + '.json');
  const tab = fs.existsSync(ziel) ? JSON.parse(fs.readFileSync(ziel, 'utf8')) : {};
  let n = 0;
  for (const zeile of fs.readFileSync(path.join(hier, datei), 'utf8').split('\n')) {
    const m = zeile.match(/^(\d+)\t(.*)$/);
    if (!m) continue;
    const k = alt[Number(m[1])];
    if (!k) continue;
    // Leerzeichen am Ende wie im Original (z. B. "gestern ")
    let t = m[2].replace(/\\n/g, '\n').trimEnd();
    if (k.endsWith(' ')) t += ' ';
    tab[k] = t;
    n++;
  }
  fs.writeFileSync(ziel, JSON.stringify(tab, null, 1) + '\n');
  console.log(sprache, n, 'Einträge');
}
