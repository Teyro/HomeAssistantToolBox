// Markiert sichtbare deutsche Texte in Swift-Quellen mit T("…") (Übersetzung).
// "Text \(x) mehr" wird zu T("Text %1 mehr", "\(x)"). Aufruf: node werkzeuge/swift-texte.mjs <dateien…> [--pruefen]
import fs from 'node:fs';

const NICHT_DAVOR = /(systemImage:|systemName:|SFSymbol\.named\(|named:|forKey:|forInfoDictionaryKey:|URL\(string:|kind:|id:|suiteName:|subdirectory:|withExtension:|forResource:|befehl\(|print\(|NSLog\(|fileURLWithPath:|appendingPathComponent\(|environment\[|contains\(|hasPrefix\(|hasSuffix\(|\.tag\(|setValue\(|forHTTPHeaderField:|Logik\.domain|case |== |!= |\[\s*$|replacingOccurrences\(of:|with:|split\(separator:|konto:|dienst:|T\(|Notification\.Name\(|\.init\(|timeZone|dateFormat|Locale\(identifier:|format:|String\(format:|series:|\.value\(|nicht_übersetzen)\s*$/;
const WOERTER = new Set(['Strom', 'Wasser', 'Gas', 'Ziel', 'Ist', 'heizt', 'Lampen', 'Heizung', 'Energie', 'Personen', 'Steckdosen', 'Name', 'Adresse',
  'Zugriffstoken', 'Abmelden', 'Beenden', 'Aktualisieren', 'Modus', 'Profil', 'Dauer', 'Starten', 'Reiter', 'Sonstiges', 'an', 'aus', 'Unterwegs',
  'Zuhause', 'Unbekannt', 'Temperatur', 'Verbinden', 'Entität', 'Steckdose', 'Lampe', 'Raum', 'Übersicht', 'Gruppen', 'Räume', 'Zählerstände',
  'ruht', 'jetzt', 'aktiv', 'Mehr', 'Hauptzähler', 'Stromzähler', 'Wasserzähler', 'Gaszähler', 'Ausblenden', 'Widgets', 'Installiert', 'Lampen',
  'Verbrauch', 'Aus', 'Heizen', 'Automatik', 'Kühlen', 'Entfeuchten', 'Lüfter', 'Komfort', 'Abwesend', 'Schlafen', 'Aktiv', 'Eco', 'Boost', 'Zuhause',
  'Ist', 'Speichern', 'Entfernen', 'Fertig', 'Schließen', 'Dashboard', 'Einstellungen', 'Abbrechen', 'Später', 'Installieren', 'Grad', 'Thermostate',
  'Schalten', 'Heizung', 'An']);

function deutsch(inhalt) {
  const ohne = inhalt.replace(/\\\([^)]*\)/g, '').replace(/\\[tnr"\\]/g, '');
  if (!/[A-Za-zÄÖÜäöüß]/.test(ohne)) return false;
  if (/^[a-z_]+\.[a-z0-9_.*]+$/.test(ohne)) return false;            // Entitäts-IDs
  if (/^(https?:|\/|#|[a-z]+\.[a-z])/.test(ohne)) return false;       // Adressen, Pfade, Farben, Kennungen
  if (/[äöüÄÖÜß]/.test(ohne) || ohne.includes(' ') || ohne.includes('…')) return true;
  return WOERTER.has(ohne.trim());
}

// Literal ab Position i (") lesen, liefert Ende-Index und Inhalt; beachtet \( … ) mit Klammern und Strings
function literal(s, i) {
  let j = i + 1, inhalt = '';
  while (j < s.length) {
    const c = s[j];
    if (c === '\\' && s[j + 1] === '(') {
      let tiefe = 0, k = j + 1;
      for (; k < s.length; k++) {
        if (s[k] === '"') { const e = literal(s, k); k = e.ende; continue; }
        if (s[k] === '(') tiefe++;
        if (s[k] === ')') { tiefe--; if (tiefe === 0) break; }
      }
      inhalt += s.slice(j, k + 1); j = k + 1; continue;
    }
    if (c === '\\') { inhalt += s.slice(j, j + 2); j += 2; continue; }
    if (c === '"') return { ende: j, inhalt };
    inhalt += c; j++;
  }
  throw new Error('Literal ohne Ende bei ' + i);
}

function umbauen(text) {
  let aus = '', i = 0;
  const funde = [];
  while (i < text.length) {
    // Kommentare überspringen
    if (text.startsWith('//', i)) { const e = text.indexOf('\n', i); aus += text.slice(i, e < 0 ? text.length : e); i = e < 0 ? text.length : e; continue; }
    if (text.startsWith('"""', i)) { const e = text.indexOf('"""', i + 3) + 3; aus += text.slice(i, e); i = e; continue; }
    if (text[i] === '#' && text[i + 1] === '"') { const e = text.indexOf('"#', i + 2) + 2; aus += text.slice(i, e); i = e; continue; }
    if (text[i] !== '"') { aus += text[i++]; continue; }
    const { ende, inhalt } = literal(text, i);
    const davor = aus.slice(-60);
    if (deutsch(inhalt) && !NICHT_DAVOR.test(davor)) {
      // Platzhalter für \( … )
      const args = [];
      let muster = '', k = 0;
      while (k < inhalt.length) {
        if (inhalt[k] === '\\' && inhalt[k + 1] === '(') {
          let tiefe = 0, m = k + 1;
          for (; m < inhalt.length; m++) {
            if (inhalt[m] === '"') { const e = literal(inhalt, m); m = e.ende; continue; }
            if (inhalt[m] === '(') tiefe++;
            if (inhalt[m] === ')') { tiefe--; if (tiefe === 0) break; }
          }
          args.push(inhalt.slice(k + 2, m));
          muster += '%' + args.length;
          k = m + 1;
          continue;
        }
        muster += inhalt[k++];
      }
      funde.push(muster);
      aus += 'T("' + muster + '"' + args.map((a) => ', "\\(' + a + ')"').join('') + ')';
    } else {
      aus += text.slice(i, ende + 1);
    }
    i = ende + 1;
  }
  return { aus, funde };
}

const pruefen = process.argv.includes('--pruefen');
for (const datei of process.argv.slice(2).filter((a) => !a.startsWith('--'))) {
  const { aus, funde } = umbauen(fs.readFileSync(datei, 'utf8'));
  if (pruefen) console.log('== ' + datei + '\n' + funde.map((f) => '   ' + f).join('\n'));
  else fs.writeFileSync(datei, aus);
}
