# Contributing to APT Update Counter

Thank you for your interest in contributing to **APT Update Counter**! We welcome bug reports, feature suggestions, code contributions, and translations.

---

## Code of Conduct & Developer Certificate of Origin

This project adheres to the [Code of Conduct](CODE_OF_CONDUCT.md). By contributing, you certify that:

1. The contribution was created in whole or in part by you and you have the right to submit it under the GPL-3.0 license; or
2. The contribution is based upon previous work covered under an appropriate open-source license compatible with GPL-3.0; or
3. The contribution was provided directly to you by someone who certified (1) or (2).
4. You understand that this project and contributions are public and maintained indefinitely under open-source terms.

---

## Development Setup

### Prerequisites

To test and develop the plasmoid locally, ensure you have KDE Plasma 6 development tools installed:

```bash
# Ubuntu / Kubuntu / Debian
sudo apt install git gettext qml6-tools
```

### Local Installation & Testing

1. Clone your fork or the repository:
   ```bash
   git clone https://github.com/hadbilen/aptupdate.git
   cd aptupdate
   ```

2. Link or copy the plasmoid directory to your local Plasma applets path:
   ```bash
   mkdir -p ~/.local/share/plasma/plasmoids/
   ln -s "$(pwd)/hadbilen.aptupdate.plasmoid" ~/.local/share/plasma/plasmoids/
   # Or copy if preferred:
   # cp -r hadbilen.aptupdate.plasmoid ~/.local/share/plasma/plasmoids/
   ```

3. Restart `plasmashell` to reload QML changes:
   ```bash
   systemctl --user restart plasma-plasmashell.service
   ```

4. Monitor live Plasma and plasmoid logs:
   ```bash
   journalctl --user -u plasma-plasmashell.service -f | grep -E "aptupdate|plasmoid"
   ```

---

## Coding Standards

- **Canonical Language:** All source code, QML identifiers, configuration keys, comments, and commit messages must be written in **English**.
- **User-Facing Strings:** Every user-facing UI text, label, placeholder, and tooltip in QML files must be wrapped inside `i18n("...")` or `i18nd("...", "...")` to enable gettext localization.
- **Fail-Safe Principle:** Critical error feedback (such as failed update commands) must always be reported to the user even if optional notification toggles are disabled.
- **Code Validation:** Always run `qmllint` before submitting a pull request:
  ```bash
  /usr/lib/qt6/bin/qmllint hadbilen.aptupdate.plasmoid/contents/ui/*.qml
  /usr/lib/qt6/bin/qmllint hadbilen.aptupdate.plasmoid/contents/ui/config/*.qml
  ```
  Ensure there are zero syntax or structural errors.

---

## Localization & Translations

Translations are managed via GNU Gettext under the `translate/` directory.

1. When adding or modifying strings in QML files, update the translation template:
   ```bash
   ./translate/build.sh
   ```
2. Update the language catalog (e.g. `translate/tr.po` for Turkish):
   - Translate new or fuzzy strings using Poedit, Lokalize, or any text editor.
3. Re-run `./translate/build.sh` to compile the `.mo` binary catalogs into `hadbilen.aptupdate.plasmoid/contents/locale/`.
4. Test with your target locale:
   ```bash
   LANG=tr_TR.UTF-8 systemctl --user restart plasma-plasmashell.service
   ```

---

## Submitting Pull Requests

1. Fork the repository and create a feature branch (`git checkout -b feat/my-new-feature`).
2. Keep commits atomic, descriptive, and reference relevant issue numbers if applicable.
3. Verify that `qmllint` passes with no errors and translations are compiled.
4. Push your branch to GitHub and open a Pull Request at [hadbilen/aptupdate](https://github.com/hadbilen/aptupdate).
