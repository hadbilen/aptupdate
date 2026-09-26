# APT Update Counter - KDE Plasma 6 Widget

<img alt="Platform" src="https://img.shields.io/badge/Platform-KDE%20Plasma%206-blue"> <img alt="Distro" src="https://img.shields.io/badge/Distro-Kubuntu%20%7C%20Ubuntu%20%7C%20Debian-E95420"> <img alt="License" src="https://img.shields.io/badge/License-GPL--3.0-green">

A clean, responsive, and customizable KDE Plasma 6 widget / system tray applet to monitor and manage pending APT package updates on Kubuntu, Ubuntu, and Debian systems.

Forked and adapted from the excellent [bouteillerAlan/archupdate](https://github.com/bouteillerAlan/archupdate) project with native APT support.

![APT Update Counter Preview](git-assets/img/allalt.png)

1 - Custom icon color | 2 - Custom dot color | 3 - Default dot | 4 - Label with separator | 5 - Label without separator | 6 - In the system tray | 7 - Package list popup

---

## Features

- **APT Integration:** Automatically counts and lists upgradable packages via `apt` without requiring root locks.
- **Interactive Popup:** Click to view available updates (`<package> <installed-version> -> <new-version>`), with direct links to [packages.ubuntu.com](https://packages.ubuntu.com).
- **One-Click Upgrades:** Launch full system upgrades (`sudo apt update && sudo apt upgrade`) or upgrade individual packages in Konsole directly from the applet or via mouse middle-click.
- **System Tray & Panel Friendly:** Works both as an independent panel widget or integrated into the KDE System Tray (with auto-hide when up to date).
- **Fully Customizable:** Custom refresh intervals, appearance styles (dots, badge labels, colors), and fully editable commands.
- **Secondary Manager Support:** Easily configure the secondary counter for Flatpak (`flatpak remote-ls --updates | wc -l`) or Snap packages.

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

# Clean up temporary clone
rm -rf /tmp/aptupdate
```

### 3. Adding to Panel or System Tray

1. **On Panel:** Right-click your KDE panel, select **Add Widgets...** (Gereç Ekle), search for **APT Update Counter**, and drag it onto your panel.
2. **In System Tray:** Right-click the System Tray arrow -> **Configure System Tray...** -> **Entries** -> ensure **APT Update Counter** is set to *Shown when relevant* or *Always shown*.

---

## Default Commands Configuration

The applet comes pre-configured for Debian / Ubuntu / Kubuntu:

| Setting | Default Command | Description |
| :--- | :--- | :--- |
| **Count APT Command** | `apt list --upgradable 2>/dev/null \| grep -c '\['` | Counts pending package updates |
| **List APT Command** | `apt list --upgradable 2>/dev/null \| grep '\[' \| awk -F'[/ ]+' '{old=$NF; sub(/\]/,"",old); print $1, old, "->", $3}'` | Formats package name and version difference |
| **Update All Command** | `sudo apt update && sudo apt upgrade` | Full system upgrade |
| **Update One Command** | `sudo apt install --only-upgrade` | Upgrade single selected package |
| **Terminal Command** | `konsole -e` | Terminal emulator wrapper |

---

## Credits & Upstream

- Original Arch Linux project and UI design: [bouteillerAlan/archupdate](https://github.com/bouteillerAlan/archupdate) by Alan Bouteiller.
- APT adaptation and packaging for Kubuntu / Debian: [hadbilen/aptupdate](https://github.com/hadbilen/aptupdate).

## License

GPL-3.0 License. See [LICENSE](LICENSE) for details.
