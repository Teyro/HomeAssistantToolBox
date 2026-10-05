# Security policy

## Supported versions

Only the latest release of Home Assistant ToolBox receives security fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub’s private reporting instead:
[Report a vulnerability](https://github.com/Teyro/HomeAssistantToolBox/security/advisories/new).

Please describe the affected app (KDE, macOS, iOS), the version and how to reproduce the problem. You will get an
answer as soon as possible; fixes are released as a new version with a note in the changelog.

## What the apps do with your data

- The token and address of your Home Assistant are only sent to that Home Assistant.
- macOS and iOS keep the token in the system keychain; KDE keeps it in the Plasma widget configuration and in
  `~/.config/homeassistanttoolbox/instanzen.json` (file mode 0600).
- Other connections: `api.github.com` / `github.com` for the update check and download (can be switched off on KDE and
  macOS) and OpenStreetMap tiles for the people map (iOS dashboard: Leaflet from unpkg.com with subresource integrity).
- Updates are only accepted from `https://github.com/Teyro/HomeAssistantToolBox/releases/download/…`.
