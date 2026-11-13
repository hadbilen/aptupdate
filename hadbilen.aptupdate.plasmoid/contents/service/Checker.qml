import QtQuick

import org.kde.plasma.plasmoid

Item {

  function checkProviders() {
    cmd.exec("which snap >/dev/null 2>&1 && echo 1 || echo 0")
    cmd.exec("which flatpak >/dev/null 2>&1 && echo 1 || echo 0")
    cmd.exec("which nala >/dev/null 2>&1 && echo 1 || echo 0")
  }

  function validateSnap(stdout) {
    plasmoid.configuration.hasSnap = (stdout.trim() === "1")
  }

  function validateFlatpak(stdout) {
    plasmoid.configuration.hasFlatpak = (stdout.trim() === "1")
  }

  function validateNala(stdout) {
    plasmoid.configuration.hasNala = (stdout.trim() === "1")
  }

}
