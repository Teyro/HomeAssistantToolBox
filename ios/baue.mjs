// Baut ios/HomeAssistantToolBox.js: setzt die gemeinsame Logik (plasma/…/logik.js) und die Version ein.
// Aufruf: node ios/baue.mjs [version]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
const wurzel = path.join(hier, '..');
const logik = fs.readFileSync(path.join(wurzel, 'plasma/package/contents/ui/logik.js'), 'utf8').replace('.pragma library', '');
const namen = [...logik.matchAll(/^(?:function|var)\s+([A-Za-z_]\w*)/gm)].map((m) => m[1]);
const version = process.argv[2] || JSON.parse(fs.readFileSync(path.join(wurzel, 'plasma/package/metadata.json'), 'utf8')).KPlugin.Version;
const block = `const Logik = (() => {\n${logik}\nreturn { ${namen.join(', ')} };\n})();`;
const quelle = fs.readFileSync(path.join(hier, 'quelle/HomeAssistantToolBox.js'), 'utf8');
// Übersetzungen (nur ausgefüllte Einträge)
const sprachen = {};
for (const d of fs.readdirSync(path.join(wurzel, 'i18n')).filter((d) => /^[a-z]{2}\.json$/.test(d))) {
  const tab = JSON.parse(fs.readFileSync(path.join(wurzel, 'i18n', d), 'utf8'));
  sprachen[d.slice(0, 2)] = Object.fromEntries(Object.entries(tab).filter(([, v]) => v));
}
if (!quelle.includes('// @@LOGIK@@')) throw new Error('Platzhalter fehlt');
if (!quelle.includes('// @@SPRACHEN@@')) throw new Error('Platzhalter Sprachen fehlt');
const fertig = quelle.replace('// @@LOGIK@@', () => block).replace('// @@SPRACHEN@@', () => 'const SPRACHEN = ' + JSON.stringify(sprachen) + ';').replace('@@VERSION@@', version);
fs.writeFileSync(path.join(hier, 'HomeAssistantToolBox.js'), fertig);
console.log('ios/HomeAssistantToolBox.js', version, Math.round(fertig.length / 1024) + ' KB', namen.length + ' Logik-Funktionen');
