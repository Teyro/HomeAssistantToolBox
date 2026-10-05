# Home Assistant ToolBox

**Votre maison connectée en un clic : dans le panneau KDE Plasma, dans la barre des menus de macOS et sur votre iPhone.**

[English](../README.md) · [Deutsch](../README.de.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md) · [Español](README.es.md) · [العربية](README.ar.md) · **Français** · [বাংলা](README.bn.md)

Lumières, prises, chauffage, énergie et personnes de [Home Assistant](https://www.home-assistant.io/) sous forme de
**widget natif KDE Plasma 6**, d’**app pour la barre des menus macOS** (Liquid Glass sous macOS 26) et de
**widgets iPhone/iPad** via [Scriptable](https://scriptable.app). Les trois partagent la même logique et les mêmes fonctions.

![KDE](../plasma/bilder/en/tiles-dark.png)

## Fonctions

- **Lumières** : groupes et pièces (zones de Home Assistant), interrupteur et luminosité pour chaque lampe, « Tout éteindre »
- **Prises** : multiprises et groupes avec interrupteur commun et consommation totale
- **Énergie** : consommation actuelle, historique sur 24 heures, **consommation du jour** (électricité, eau, gaz), plus gros consommateurs
- **Chauffage** : température et humidité par pièce, consigne, mode, préréglage, **chauffage d’appoint**,
  fenêtre ouverte/fermée et **graphique sur 24 heures**
- **Personnes** : carte avec zones, qui est où et à quelle distance
- **Plusieurs instances** Home Assistant, **widgets de bureau**, **mises à jour en direct** (WebSocket)
- **8 langues**, selon la langue du système

## Téléchargement et installation

Tous les fichiers se trouvent dans les [Releases](https://github.com/Teyro/HomeAssistantToolBox/releases/latest) :

- **KDE Plasma 6** : `homeassistant-toolbox.plasmoid` → `kpackagetool6 -t Plasma/Applet -i homeassistant-toolbox.plasmoid`,
  puis clic droit sur le panneau → Ajouter des composants graphiques → « Home Assistant ToolBox » ([guide](../plasma/README.md))
- **macOS 14+** : décompresser `HomeAssistantToolBox-macOS-x.y.z.zip`, glisser dans Applications puis exécuter une fois
  `xattr -dr com.apple.quarantine "/Applications/Home Assistant ToolBox.app"` ([guide](../macos/README.md))
- **iPhone/iPad** : enregistrer `HomeAssistantToolBox.js` dans le dossier Scriptable ([guide](../ios/README.md))

Il vous faut l’adresse de votre Home Assistant et un **jeton d’accès longue durée**
(Home Assistant → votre profil → *Sécurité* → *Jetons d’accès longue durée* → *Créer un jeton*).

## Confidentialité

Les apps ne communiquent qu’avec **votre propre Home Assistant** : pas de cloud, pas de pistage. En plus : GitHub
(vérification des mises à jour) et les cartes OpenStreetMap. Sur macOS et iOS, le jeton est stocké dans le trousseau.

## Traductions

Les traductions ont été réalisées avec une aide automatique. Les corrections sont les bienvenues dans `i18n/fr.json` !

## Licence et marque

GPL-3.0-or-later. Home Assistant ToolBox est un projet indépendant, **sans lien** avec Home Assistant, Nabu Casa ou
l’Open Home Foundation. « Home Assistant » est une marque de son propriétaire.
