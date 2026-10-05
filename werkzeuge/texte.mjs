// Sammelt alle zu übersetzenden Texte aus KDE-Widget, Mac-App und iOS-Skript und gleicht die
// Sprachdateien i18n/<sprache>.json ab (neue Texte leer, entfallene werden entfernt).
// Aufruf: node werkzeuge/texte.mjs   → zeigt fehlende Übersetzungen je Sprache
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const wurzel = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const SPRACHEN = ['en', 'zh', 'hi', 'es', 'ar', 'fr', 'bn'];

function dateien(ordner, endungen) {
  const aus = [];
  for (const e of fs.readdirSync(ordner, { withFileTypes: true })) {
    const p = path.join(ordner, e.name);
    if (e.isDirectory()) aus.push(...dateien(p, endungen));
    else if (endungen.some((x) => e.name.endsWith(x))) aus.push(p);
  }
  return aus;
}
function unescape(s) { return s.replace(/\\"/g, '"').replace(/\\n/g, '\n').replace(/\\\\/g, '\\'); }

const texte = new Map();   // Text → Fundorte
function merke(text, ort) { if (!text.trim() || text.startsWith('\\(')) return; if (!texte.has(text)) texte.set(text, new Set()); texte.get(text).add(ort); }

// KDE: i18n("…") in QML/JS, t("…") in logik.js
for (const f of dateien(path.join(wurzel, 'plasma/package'), ['.qml', '.js'])) {
  const s = fs.readFileSync(f, 'utf8');
  for (const m of s.matchAll(/\b(?:i18n|t)\(\s*"((?:[^"\\]|\\.)*)"/g)) merke(unescape(m[1]), 'kde');
}
// metadata.json Beschreibung
merke('Lampen, Steckdosen, Heizung, Energie und Personen aus Home Assistant – im Panel und auf dem Schreibtisch', 'kde');
// Mac: T("…") und feste Texte der Widget-Aktionen
for (const f of dateien(path.join(wurzel, 'macos/Sources'), ['.swift'])) {
  const s = fs.readFileSync(f, 'utf8');
  for (const m of s.matchAll(/\bT\(\s*"((?:[^"\\]|\\.)*)"/g)) merke(unescape(m[1]), 'mac');
  if (f.endsWith('Absichten.swift'))
    for (const m of s.matchAll(/(?:title:|LocalizedStringResource =|IntentDescription\(|TypeDisplayRepresentation =)\s*"((?:[^"\\]|\\.)*)"/g)) merke(unescape(m[1]), 'mac');
}
// iOS: T("…") im Skript und in der Dashboard-Seite
for (const f of [path.join(wurzel, 'ios/quelle/HomeAssistantToolBox.js')]) {
  const s = fs.readFileSync(f, 'utf8');
  for (const m of s.matchAll(/\b[Tt]\(\s*"((?:[^"\\]|\\.)*)"/g)) merke(unescape(m[1]), 'ios');
  const anl = s.match(/const ANLEITUNG = `([\s\S]*?)`;/);
  if (anl) merke(anl[1], 'ios');
}

const alle = [...texte.keys()].sort((a, b) => a.localeCompare(b, 'de'));
fs.mkdirSync(path.join(wurzel, 'i18n'), { recursive: true });
fs.writeFileSync(path.join(wurzel, 'i18n/vorlage.json'), JSON.stringify(Object.fromEntries(alle.map((t) => [t, [...texte.get(t)].join(',')])), null, 1) + '\n');
for (const s of SPRACHEN) {
  const datei = path.join(wurzel, 'i18n', s + '.json');
  const alt = fs.existsSync(datei) ? JSON.parse(fs.readFileSync(datei, 'utf8')) : {};
  const neu = Object.fromEntries(alle.map((t) => [t, alt[t] || '']));
  fs.writeFileSync(datei, JSON.stringify(neu, null, 1) + '\n');
  const fehlt = alle.filter((t) => !neu[t]);
  console.log(`${s}: ${alle.length - fehlt.length}/${alle.length} übersetzt`);
}
// Platzhalter prüfen: jede Übersetzung muss dieselben %1 … enthalten
let fehler = 0;
for (const s of SPRACHEN) {
  const tab = JSON.parse(fs.readFileSync(path.join(wurzel, 'i18n', s + '.json'), 'utf8'));
  for (const [k, v] of Object.entries(tab)) {
    if (!v) continue;
    const a = (k.match(/%\d/g) || []).sort().join(), b = (v.match(/%\d/g) || []).sort().join();
    if (a !== b) { fehler++; console.log(`  ${s}: Platzhalter passen nicht: "${k}" → "${v}"`); }
  }
}
if (fehler) process.exitCode = 1;
