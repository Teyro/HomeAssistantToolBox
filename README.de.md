# Home Assistant ToolBox

**Dein Zuhause mit einem Klick – im KDE-Panel, in der Mac-Menüleiste und auf dem iPhone.**

**Sprachen:** [English](README.md) · Deutsch · [中文](docs/README.zh.md) · [हिन्दी](docs/README.hi.md) ·
[Español](docs/README.es.md) · [العربية](docs/README.ar.md) · [Français](docs/README.fr.md) · [বাংলা](docs/README.bn.md)

Lampen, Steckdosen und Energieverbrauch aus [Home Assistant](https://www.home-assistant.io/) mit einem Klick –
als **Plasma-Widget für KDE** (neben der Uhr, im Breeze-Look) und als **Menüleisten-App für macOS**
(im Liquid-Glass-Design von macOS 26). Beide können dasselbe; die Logik ist die gleiche.
Dazu gibt es **Widgets für den Schreibtisch** – und für **iPhone/iPad** eine Version für
[Scriptable](https://scriptable.app) mit Homebildschirm- und Sperrbildschirm-Widgets.

| KDE Plasma 6 | macOS |
|---|---|
| ![KDE](plasma/bilder/lampen-dunkel.png) | ![macOS](macos/bilder/lampen-dunkel.png) |
| ![KDE Heizung](plasma/bilder/heizung-dunkel.png) | ![macOS Heizung](macos/bilder/heizung-dunkel.png) |
| ![KDE Personen](plasma/bilder/personen-hell.png) | ![macOS Personen](macos/bilder/personen-hell.png) |
| ![KDE Kacheln](plasma/bilder/kacheln-dunkel.png) | ![macOS Widgets](macos/bilder/widgets-hell.png) |

## Was alle drei können

- **Lampen**: Gruppen und Räume zum Aufklappen, Schalter und Helligkeitsregler, Symbol in der Lampenfarbe, „Alle aus“
- **Steckdosen**: Steckdosenleisten und Schaltergruppen mit gemeinsamem Schalter und Verbrauch, einzelne Dosen nach Raum
- **Energie**: aktueller Verbrauch, Verlauf der letzten 24 Stunden, **Verbrauch heute** (Strom, Wasser, Gas),
  größte Verbraucher, Zählerstände
- **Heizung**: alle Räume mit Temperatur und Luftfeuchte, Zieltemperatur per Regler, Modus, Profil,
  **Extra heizen** für 30 Minuten bis 4 Stunden
- **Personen**: Karte wie bei „Wo ist?“, wer ist wo und wie weit weg, heizt es gerade?
- **Fenster offen/zu** bei jeder Heizung und **24-Stunden-Verlauf** (Ist, Ziel, Heizphasen) zum Aufklappen
- **Updates mit einem Klick**: neue Version wird gemeldet, „Was ist neu?“ zeigt die Änderungen
- **Mehrere Home-Assistant-Instanzen** mit Favorit, Wechsel über das Menü
- **Widgets/Kacheln** für den Schreibtisch: Übersicht, Lampe, Steckdose, Raum, Heizung, Energie, Personen, Entität
- **Live** über die WebSocket-Schnittstelle von Home Assistant, Schutz vor IP-Sperre bei falschem Token
- **8 Sprachen**: Deutsch, English, 中文, हिन्दी, Español, العربية (von rechts nach links), Français, বাংলা –
  automatisch nach der Systemsprache

## Herunterladen

Unter [Releases](https://github.com/Teyro/HomeAssistantToolBox/releases/latest) liegen alle Dateien:

| Datei | Für | Anleitung |
|---|---|---|
| `homeassistant-toolbox.plasmoid` | KDE Plasma 6 (Manjaro, Arch, Fedora, Kubuntu …) | [plasma/README.de.md](plasma/README.de.md) |
| `HomeAssistantToolBox-macOS-x.y.z.zip` | macOS 14 oder neuer (Apple Silicon und Intel) | [macos/README.de.md](macos/README.de.md) |
| `HomeAssistantToolBox.js` | iPhone/iPad mit der App Scriptable | [ios/README.de.md](ios/README.de.md) |

Kurz:

```bash
# KDE (erstmals -i, Update -u)
kpackagetool6 -t Plasma/Applet -u homeassistant-toolbox.plasmoid && plasmashell --replace &

# macOS: ZIP entpacken, „Home Assistant ToolBox“ nach Programme ziehen, dann einmal
xattr -dr com.apple.quarantine "/Applications/Home Assistant ToolBox.app"
```

## Aufbau

```
plasma/   KDE-Widget (QML, Plasma 6)
macos/    Mac-App (SwiftUI, Swift-Paket)
ios/      Skript für Scriptable (iOS) – wird aus der gemeinsamen Logik gebaut
i18n/     Übersetzungen (eine JSON-Datei je Sprache, deutscher Text als Schlüssel)
werkzeuge/ Texte sammeln, Übersetzungen bauen
presse/   Pressemappe und Checkliste zum Einreichen
packaging/ AUR-Paket (Arch, Manjaro)
docs/     README in weiteren Sprachen
test/     nachgebautes Home Assistant zum Testen (Token: test-token)
```

Der GitHub-Workflow prüft alle drei Programme, macht Bildschirmfotos der Mac-App auf macOS 26 und hängt bei
einem Tag `v*` alle Dateien an das Release.

## Datenschutz und Sicherheit

- Die Programme sprechen **nur mit deinem eigenen Home Assistant** – keine Cloud, kein Tracking.
- Außerdem: GitHub (Update-Prüfung, abschaltbar) und Kartenkacheln von OpenStreetMap für die Personenkarte.
- Token liegen auf dem Mac und auf iOS im **Schlüsselbund**, unter KDE in der Widget-Konfiguration und in
  `~/.config/homeassistanttoolbox/instanzen.json` (nur für dich lesbar).
- Updates werden nur aus den GitHub-Releases dieses Projekts angenommen.
- Geht ein Token verloren: in Home Assistant im Profil unter *Sicherheit* löschen.
- Sicherheitslücke gefunden? Siehe [SECURITY.md](SECURITY.md).

## Umstieg von „Home Assistant Leiste“

Home Assistant ToolBox ist der Nachfolger von *Home Assistant Leiste*. Weil sich die Kennungen geändert haben,
aktualisiert sich die alte Version nicht von selbst: die neue einmal installieren – Instanzen und Einstellungen
werden automatisch übernommen (auf dem Mac fragt macOS evtl. einmal nach dem Schlüsselbund). Danach das alte
Widget bzw. die alte App entfernen.

## Übersetzungen

Die Übersetzungen sind maschinell unterstützt entstanden und auf Vollständigkeit und Platzhalter geprüft, aber noch
nicht in jeder Sprache von Muttersprachlern. Verbesserungen gern als Pull Request in `i18n/<sprache>.json`.

## Lizenz und Marke

GPL-3.0-or-later. Kartendaten © OpenStreetMap-Mitwirkende.

Home Assistant ToolBox ist ein unabhängiges Gemeinschaftsprojekt und steht **in keiner Verbindung** zu Home Assistant,
Nabu Casa oder der Open Home Foundation. „Home Assistant“ ist eine Marke des jeweiligen Inhabers und wird hier nur
genutzt, um die Kompatibilität zu beschreiben.
