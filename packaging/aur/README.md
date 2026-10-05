# AUR package

`PKGBUILD` for [AUR](https://aur.archlinux.org) – installs the widget system-wide to
`/usr/share/plasma/plasmoids/de.teyro.homeassistanttoolbox`.

After each release:

1. Set `pkgver`, and replace `sha256sums` with the checksum of the release file
   (`sha256sum homeassistant-toolbox.plasmoid`).
2. `makepkg --printsrcinfo > .SRCINFO`
3. Push both files to `ssh://aur@aur.archlinux.org/plasma6-applets-homeassistant-toolbox.git`.

Note: the built-in updater installs updates into your home directory (`~/.local/share/plasma/plasmoids`), which then
takes precedence over the system-wide package. With the AUR package, simply update with your AUR helper instead.
