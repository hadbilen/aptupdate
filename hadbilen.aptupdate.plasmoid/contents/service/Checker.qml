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

  function validateKonsole(stderr) {
    plasmoid.configuration.konsoleIsValid = stderr === ''
    if (stderr !== '') cmd.exec("kdialog --passivepopup 'Missing dependency (konsole) for apt update plasmoid'")
  }

  function validateCheckupdates(stderr) {
    plasmoid.configuration.checkupdateIsValid = stderr === ''
    if (stderr !== '') cmd.exec("kdialog --passivepopup 'Missing dependency (apt) for apt update plasmoid'")
  }

}
