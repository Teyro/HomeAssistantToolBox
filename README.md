# Home Assistant Leiste – für KDE Plasma und macOS

Lampen, Steckdosen und Energieverbrauch aus [Home Assistant](https://www.home-assistant.io/) mit einem Klick –
als **Plasma-Widget für KDE** (neben der Uhr, im Breeze-Look) und als **Menüleisten-App für macOS**
(im Liquid-Glass-Design von macOS 26). Beide können dasselbe; die Logik ist die gleiche.

| KDE Plasma 6 | macOS |
|---|---|
| ![KDE](plasma/bilder/lampen-dunkel.png) | ![macOS](macos/bilder/lampen-dunkel.png) |
| ![KDE Energie](plasma/bilder/energie-dunkel.png) | ![macOS Energie](macos/bilder/energie-dunkel.png) |

## Was beide können

- **Lampen**: Gruppen und Räume zum Aufklappen, Schalter und Helligkeitsregler, Symbol in der Lampenfarbe, „Alle aus“
- **Steckdosen**: Steckdosenleisten und Schaltergruppen mit gemeinsamem Schalter und Verbrauch, einzelne Dosen nach Raum
- **Energie**: aktueller Verbrauch, Verlauf der letzten 24 Stunden, **Verbrauch heute** (Strom, Wasser, Gas),
  größte Verbraucher, Zählerstände
- **Live** über die WebSocket-Schnittstelle von Home Assistant, Schutz vor IP-Sperre bei falschem Token

## Herunterladen

Unter [Releases](https://github.com/Teyro/homeassistant-leiste/releases) liegen beide Programme:

| Datei | Für | Anleitung |
|---|---|---|
| `home-assistant.plasmoid` | KDE Plasma 6 (Manjaro, Arch, Fedora, Kubuntu …) | [plasma/README.md](plasma/README.md) |
| `HA-Leiste-x.y.z.zip` | macOS 14 oder neuer (Apple Silicon und Intel) | [macos/README.md](macos/README.md) |

Kurz:

```bash
# KDE (erstmals -i, Update -u)
kpackagetool6 -t Plasma/Applet -u home-assistant.plasmoid && plasmashell --replace &

# macOS: ZIP entpacken, „HA Leiste“ nach Programme ziehen, dann einmal
xattr -dr com.apple.quarantine "/Applications/HA Leiste.app"
```

## Aufbau

```
plasma/   KDE-Widget (QML, Plasma 6)
macos/    Mac-App (SwiftUI, Swift-Paket)
test/     nachgebautes Home Assistant zum Testen (Token: test-token)
```

Der GitHub-Workflow prüft beide Programme, macht Bildschirmfotos der Mac-App auf macOS 26 und hängt bei
einem Tag `v*` beide Dateien an das Release.

## Lizenz

GPL-3.0-or-later
