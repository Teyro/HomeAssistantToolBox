# Veröffentlichung – Checkliste

Alles ist vorbereitet, **eingereicht wird von Hand** (Konten, Anmeldungen und Formulare gehören dem Projektinhaber).
Texte: [texte.md](texte.md) · Pressemitteilung: [DE](pressemitteilung.de.md) / [EN](press-release.en.md) ·
Bilder: `plasma/bilder`, `macos/bilder`, `ios/bilder` (jeweils `en/` für Englisch).

Tipp: Redaktionen bekommen viele Zusendungen – kurz bleiben, Link zum Release und 2–3 Bilder mitschicken, nichts
anhängen, was größer als ein paar MB ist.

## 1. Stores und Pakete

| Wo | Was tun | Erledigt |
|---|---|---|
| **KDE Store** – https://store.kde.org | Anmelden → *Add Product* → Kategorie *Plasma 6 Applets* → Text aus `texte.md`, Datei `homeassistant-toolbox.plasmoid`, Bilder `plasma/bilder/en`. Danach ist das Widget direkt in Plasma unter *Widgets hinzufügen → Neue Widgets holen* zu finden. | ☐ |
| **AUR** (Arch, Manjaro, EndeavourOS) – https://aur.archlinux.org | `packaging/aur/PKGBUILD` (siehe README dort): AUR-Konto mit SSH-Schlüssel, dann `git clone ssh://aur@aur.archlinux.org/plasma6-applets-homeassistant-toolbox.git`, PKGBUILD + `.SRCINFO` hinein, pushen. | ☐ |
| **GitHub** | Repository-Themen (Topics) sind gesetzt; Release 1.0.0 mit allen Dateien. | ☑ |

## 2. Linux-Seiten (deutsch)

| Seite | Hinweis | Erledigt |
|---|---|---|
| **Caschys Blog** – https://stadt-bremerhaven.de | Kontakt/Tipp über die Kontaktseite des Blogs; kurze Mail mit Einzeiler, Link und 2 Bildern (KDE + Mac). | ☐ |
| **LinuxNews** – https://linuxnews.de | Kontakt über die Seite; Pressemitteilung DE. | ☐ |
| **GNU/Linux.ch** – https://gnulinux.ch | Nimmt auch Gastartikel – Pressemitteilung als Artikel anbieten. | ☐ |
| **Linux-Magazin / LinuxUser / heise** | Nur Pressemitteilung schicken, keine Erwartung – Kontakt jeweils über das Impressum/Redaktionsseite. | ☐ |
| **Pro-Linux** – https://www.pro-linux.de | Hat eine Funktion zum Einsenden von Neuigkeiten. | ☐ |

## 3. International

| Seite | Hinweis | Erledigt |
|---|---|---|
| **Home Assistant Community** – https://community.home-assistant.io | Kategorie *Share your Projects!*; Text „Reddit / Forum“ aus `texte.md`. | ☐ |
| **Reddit** | r/homeassistant (Flair *Personal Setup* bzw. Projekt-Regeln beachten), r/kde, r/linux, r/Scriptable, r/MacOS – nicht alles am selben Tag. | ☐ |
| **Hacker News** – https://news.ycombinator.com/submit | „Show HN: Home Assistant ToolBox – Home Assistant in the KDE panel, macOS menu bar and on iPhone“ | ☐ |
| **Mastodon** | Post aus `texte.md`; die offiziellen Konten von KDE und Home Assistant erwähnen. | ☐ |
| **OMG! Ubuntu, It’s FOSS, 9to5Linux** | Tipp über deren Kontaktformular, englische Pressemitteilung. | ☐ |
| **MacStories, 9to5Mac** (Mac/iPhone) | Englische Pressemitteilung, Fokus Menüleiste + Scriptable. | ☐ |

## 4. Vor dem Einreichen kurz prüfen

- Release-Seite öffnet sich und alle drei Dateien sind da
- README auf GitHub zeigt die Bilder
- Ein echtes Home Assistant einmal mit der Release-Datei verbunden (KDE und/oder Mac)
- Übersetzungen: wenn möglich je Sprache jemanden mit Muttersprache kurz drüberschauen lassen

## Rechtliches

- „Home Assistant“ ist eine Marke – immer den Hinweis „nicht verbunden mit Home Assistant / Nabu Casa / Open Home
  Foundation“ dazuschreiben und kein Home-Assistant-Logo verwenden (das Projektsymbol ist ein eigenes).
- Kartenbilder enthalten OpenStreetMap-Daten (© OpenStreetMap-Mitwirkende, ODbL) – bei Veröffentlichung von
  Bildschirmfotos mit Karte die Quelle nennen.
