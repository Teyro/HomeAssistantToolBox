# Home Assistant ToolBox

**Tu hogar inteligente a un clic: en el panel de KDE Plasma, en la barra de menús de macOS y en tu iPhone.**

[English](../README.md) · [Deutsch](../README.de.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md) · **Español** · [العربية](README.ar.md) · [Français](README.fr.md) · [বাংলা](README.bn.md)

Luces, enchufes, calefacción, energía y personas de [Home Assistant](https://www.home-assistant.io/) como
**widget nativo de KDE Plasma 6**, **app para la barra de menús de macOS** (Liquid Glass en macOS 26) y
**widgets para iPhone/iPad** con [Scriptable](https://scriptable.app). Las tres comparten la misma lógica y las mismas funciones.

![KDE](../plasma/bilder/en/tiles-dark.png)

## Funciones

- **Luces**: grupos y habitaciones (áreas de Home Assistant), interruptor y brillo para cada luz, «Apagar todo»
- **Enchufes**: regletas y grupos con interruptor común y consumo total
- **Energía**: consumo actual, historial de 24 horas, **consumo de hoy** de electricidad, agua y gas, mayores consumidores
- **Calefacción**: temperatura y humedad por habitación, temperatura objetivo, modo, preajuste, **calor extra**,
  ventana abierta/cerrada y **gráfico de 24 horas**
- **Personas**: mapa con zonas, quién está dónde y a qué distancia
- **Varias instancias** de Home Assistant, **widgets de escritorio**, **actualizaciones en vivo** (WebSocket)
- **8 idiomas** según el idioma del sistema

## Descarga e instalación

Todos los archivos están en [Releases](https://github.com/Teyro/HomeAssistantToolBox/releases/latest):

- **KDE Plasma 6**: `homeassistant-toolbox.plasmoid` → `kpackagetool6 -t Plasma/Applet -i homeassistant-toolbox.plasmoid`,
  luego clic derecho en el panel → Añadir widgets → «Home Assistant ToolBox» ([guía](../plasma/README.md))
- **macOS 14+**: descomprimir `HomeAssistantToolBox-macOS-x.y.z.zip`, arrastrar a Aplicaciones y ejecutar una vez
  `xattr -dr com.apple.quarantine "/Applications/Home Assistant ToolBox.app"` ([guía](../macos/README.md))
- **iPhone/iPad**: guardar `HomeAssistantToolBox.js` en la carpeta de Scriptable ([guía](../ios/README.md))

Necesitas la dirección de tu Home Assistant y un **token de acceso de larga duración**
(Home Assistant → tu perfil → *Seguridad* → *Tokens de acceso de larga duración* → *Crear token*).

## Privacidad

Las apps solo se comunican con **tu propio Home Assistant**: sin nube, sin seguimiento. Además: GitHub (comprobación de
actualizaciones) y mapas de OpenStreetMap. En macOS e iOS el token se guarda en el llavero.

## Traducciones

Las traducciones se han hecho con ayuda automática. ¡Las correcciones son bienvenidas en `i18n/es.json`!

## Licencia y marca

GPL-3.0-or-later. Home Assistant ToolBox es un proyecto independiente y **no está afiliado** a Home Assistant,
Nabu Casa ni a la Open Home Foundation. «Home Assistant» es una marca de su respectivo titular.
