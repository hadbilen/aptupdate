# APT Update Counter - KDE Plasma 6 Widget

<img alt="Platform" src="https://img.shields.io/badge/Platform-KDE%20Plasma%206-blue"> <img alt="Distro" src="https://img.shields.io/badge/Distro-Kubuntu%20%7C%20Ubuntu%20%7C%20Debian-E95420"> <img alt="Version" src="https://img.shields.io/badge/Version-1.2.1-brightgreen"> <img alt="License" src="https://img.shields.io/badge/License-GPL--3.0-green">

A clean, responsive, and customizable KDE Plasma 6 widget / system tray applet to monitor and manage pending **APT**, **Snap**, and **Flatpak** package updates on Kubuntu, Ubuntu, and Debian systems.

Forked and adapted from the excellent [bouteillerAlan/archupdate](https://github.com/bouteillerAlan/archupdate) project with native APT, Snap, and Flatpak support.

![APT Update Counter Preview](git-assets/img/allalt.png)

1 - Custom icon color | 2 - Custom dot color | 3 - Default dot | 4 - Label with separator | 5 - Label without separator | 6 - In the system tray | 7 - Package list popup

---

## Features

- **Multi-Ecosystem (APT, Snap & Flatpak):** Concurrently tracks core system APT packages and modern containerized Snap and Flatpak applications.
- **Selective Ecosystem Toggles:** Independent toggles for Snap and Flatpak updates. Run both, Snap only, Flatpak only, or disable secondary managers completely for a lightweight APT-only setup with zero idle background overhead.
- **Ubuntu Phased Updates Management:** Intelligently filter out staged/deferred phased updates so your badge accurately reflects immediately installable updates, or choose to include and forcibly upgrade phased packages. Individual package clicks always install directly.
- **Optional Nala Support:** Automatically detects if `nala` is installed and lets you opt into faster, more readable terminal upgrades while keeping APT simulations and silent `pkexec` updates on deterministic `apt-get`.
- **Silent Background Updates:** Optional non-interactive background upgrade mode via `pkexec` without opening a terminal window.
- **Rich Icon States & Animation:** Active updates feature a smooth rotation animation and theme accent color; update errors display a negative red error badge (`!`) with diagnostic tooltips.
- **Dedicated Notifications Tab:** Consolidated settings tab for desktop notifications: alerts for newly discovered updates, system restart required alerts, and silent background upgrade completion.
- **Fail-Safe Policy:** Critical package management errors and failure alerts are guaranteed to surface even if optional notifications are turned off.
- **Responsive Popup Layout:** Dynamically constrained popup width (320px - 580px) with elegant text truncation (`...`) for long package names, keeping action buttons aligned and accessible.
- **Interactive Popup:** Click to view available updates (`<package> <installed-version> -> <new-version>`), with direct links to [packages.ubuntu.com](https://packages.ubuntu.com) for APT, [snapcraft.io](https://snapcraft.io) for Snap, and [flathub.org](https://flathub.org) for Flatpak packages.
- **Reboot Required Detection & Notification:** Automatically detects `/var/run/reboot-required` (e.g. following kernel, systemd, or glibc updates) and sends a native desktop alert while displaying clear restart warnings in both the tooltip and popup.
- **Internationalization (i18n):** Full GNU Gettext localization support. The canonical source code is 100% English, while automatically displaying in the user's desktop language (Turkish catalog included, community translations welcome).
- **One-Click Upgrades:** Launch full system upgrades or upgrade individual packages in Konsole or silently in the background directly from the applet or via mouse middle-click.
- **System Tray & Panel Friendly:** Works both as an independent panel widget or integrated into the KDE System Tray (with auto-hide when up to date).
- **Fully Customizable:** Custom refresh intervals, appearance styles (dual dots, badge labels with separators, colors), and fully editable commands.
- **Native Breeze Theming:** Integrates with KDE Plasma's `system-software-update` icon for full theme consistency.
- **Graceful Fallbacks:** Operates seamlessly even if Snap or Flatpak is not installed on the system.

---

## Installation

### 1. Requirements

Ensure you have `konsole` installed on your system (default on Kubuntu):

```bash
sudo apt install konsole
```

### 2. Quick Install (from Source)

Run the following commands in your terminal:

```bash
# Clone the repository
git clone https://github.com/hadbilen/aptupdate.git /tmp/aptupdate

# Install into KDE Plasma 6 user plasmoids directory
mkdir -p ~/.local/share/plasma/plasmoids
cp -r /tmp/aptupdate/hadbilen.aptupdate.plasmoid ~/.local/share/plasma/plasmoids/

# Refresh KDE system cache
kbuildsycoca6 --noincremental

# Restart Plasmashell (flushes in-memory QML cache without closing open apps)
systemctl --user restart plasma-plasmashell.service

# Clean up temporary clone
rm -rf /tmp/aptupdate
```

### 3. Adding to Panel or System Tray

1. **On Panel:** Right-click your KDE panel, select **Add Widgets...** (Gereç Ekle), search for **APT Update Counter**, and drag it onto your panel.
2. **In System Tray:** Right-click the System Tray arrow -> **Configure System Tray...** -> **Entries** -> ensure **APT Update Counter** is set to *Shown when relevant* or *Always shown*.

---

## Default Commands Configuration

The applet comes pre-configured for Debian / Ubuntu / Kubuntu:

| Setting | Default Value / Command | Description |
| :--- | :--- | :--- |
| **Enable Snap Updates** | `true` | Toggle tracking and upgrading Snap packages |
| **Enable Flatpak Updates** | `true` | Toggle tracking and upgrading Flatpak packages |
| **Include Phased Updates** | `false` | Include staged/deferred phased updates in count/list (and force in full upgrade) |
| **Use Nala in Terminal Mode** | `false` | Use `sudo nala upgrade` / `sudo nala install` in terminal mode when `nala` is detected (disabled in Silent Mode) |
| **Silent Background Updates** | `false` | Run upgrades silently via `pkexec` without opening a terminal window |
| **Notify on Silent Update** | `true` | Desktop notification upon completion (critical failure errors are always notified) |
| **Count APT Command (internal)** | `bash -c "set -o pipefail; LC_ALL=C apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade 2>/dev/null \| awk '/^Inst [^ ]+ \\[/ {c++} END {print c+0}'"` | Counts pending APT package updates (with optional phased updates flag) |
| **Count & List Snap / Flatpak (internal)** | `LC_ALL=C timeout --kill-after=5s 20s snap refresh --list` / `flatpak remote-ls --updates` | Single-pass pipelines extracting Snap/Flatpak update counts and versions with `set -o pipefail` |
| **List APT / Snap / Flatpak (internal)** | Managed read-only pipelines with `set -o pipefail` and `LC_ALL=C` | Extracts package names, installed versions, target versions, and origin repositories |
| **Update All Command** | `sudo apt -o DPkg::Lock::Timeout=10 update && sudo apt -o DPkg::Lock::Timeout=10 upgrade` (or `sudo nala upgrade -o DPkg::Lock::Timeout=10`; plus `sudo snap refresh` / `flatpak update -y` when pending) | Full or per-ecosystem upgrade in terminal or via `pkexec` |
| **Update One Command** | `sudo apt install --only-upgrade` (or `sudo nala install -o DPkg::Lock::Timeout=10` when Nala is enabled) | Upgrade single selected APT package (`-o DPkg::Lock::Timeout=10 -y` injected automatically; Snap/Flatpak routed natively) |
| **Terminal Command** | `konsole -e bash -c` | Terminal emulator wrapper |

---

## Contributing & Translations

Translations are managed using standard GNU Gettext under `translate/`:

```bash
# To update template.pot and compile all .po files to .mo:
./translate/build.sh
```

To contribute a new language, copy `translate/template.pot` to `translate/<lang>.po`, translate the strings, and submit a pull request.

---

## Credits & Upstream

- **Original Creator & UI Design:** [Alan Bouteiller (A2N)](https://github.com/bouteillerAlan) - [bouteillerAlan/archupdate](https://github.com/bouteillerAlan/archupdate).
- **Debian / Ubuntu / Snap / Flatpak Port & Maintainer:** [hadbilen](https://github.com/hadbilen) - [hadbilen/aptupdate](https://github.com/hadbilen/aptupdate).

## Trademarks & Attributions

All trademarks, service marks, and logos (Debian/APT, Canonical/Snapcraft, and Flatpak) are the property of their respective owners. They are used in this project strictly for identification and nominative fair use purposes to indicate package management backends. No endorsement or affiliation is implied.

## License

GNU General Public License v3.0 (GPL-3.0). See [LICENSE](LICENSE) for details.
