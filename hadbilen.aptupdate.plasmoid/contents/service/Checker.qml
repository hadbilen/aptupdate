import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {

  function konsole() {
    cmd.exec("konsole -v")
  }

  function checkupdates() {
    cmd.exec("apt --version")
  }

  function checkProviders() {
    cmd.exec("which snap >/dev/null 2>&1 && echo 1 || echo 0")
    cmd.exec("which flatpak >/dev/null 2>&1 && echo 1 || echo 0")
  }

  function validateKonsole(stderr) {
    plasmoid.configuration.konsoleIsValid = stderr === ''
    if (stderr !== '') cmd.exec("kdialog --passivepopup 'Missing dependency (konsole) for apt update plasmoid'")
  }

  function validateCheckupdates(stderr) {
    plasmoid.configuration.checkupdateIsValid = stderr === ''
    if (stderr !== '') cmd.exec("kdialog --passivepopup 'Missing dependency (apt) for apt update plasmoid'")
  }

  function validateSnap(stdout) {
    plasmoid.configuration.hasSnap = (stdout.trim() === "1")
  }

  function validateFlatpak(stdout) {
    plasmoid.configuration.hasFlatpak = (stdout.trim() === "1")
  }

}
