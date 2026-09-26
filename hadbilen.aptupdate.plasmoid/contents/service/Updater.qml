import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {

  property string countArchCommand: Plasmoid.configuration.countArchCommand
  property string countAurCommand: Plasmoid.configuration.countAurCommand
  property string listArchCommand: Plasmoid.configuration.listArchCommand
  property string listAurCommand: Plasmoid.configuration.listAurCommand
  property string listRepoArchCommand: Plasmoid.configuration.listRepoArchCommand
  property string updateCommand: Plasmoid.configuration.updateCommand
  property string updateCommandOne: Plasmoid.configuration.updateCommandOne
  property string termCmd: Plasmoid.configuration.termCmd
  property string termNoCloseCmd: Plasmoid.configuration.termNoCloseCmd
  property bool notCloseCommand: Plasmoid.configuration.notCloseCommand
  property string termNoCloseSuffix: Plasmoid.configuration.termNoCloseSuffix

  function countArch() {
    if (countArchCommand !== '') cmd.exec(countArchCommand)
  }

  function countAur() {
    if (countAurCommand !== '') cmd.exec(countAurCommand)
  }

  function listArch() {
    if (listArchCommand !== '') cmd.exec(listArchCommand)
  }

  function listAur() {
    if (listAurCommand !== '') cmd.exec(listAurCommand)
  }

  function listArchRepo() {
    if (listRepoArchCommand !== '') cmd.exec(listRepoArchCommand)
  }

  function countAll() {
    countArch()
    countAur()
    listArchRepo()
  }

  function listAll() {
    listArch()
    listAur()
  }

  function launchUpdate() {
    if (updateCommand !== '') {
      if (notCloseCommand) {
        cmd.exec(termNoCloseCmd + " '" + updateCommand + " " + termNoCloseSuffix + "'")
      } else {
        cmd.exec(termCmd + " '" + updateCommand + "'")
      }
    }
  }

  function launchOneUpdate(packageName, repo) {
    if (!packageName) return
    var cmdToRun = updateCommandOne + " " + packageName
    if (repo === "snap") {
      cmdToRun = "sudo snap refresh " + packageName
    } else if (repo === "flatpak") {
      cmdToRun = "flatpak update -y " + packageName
    }
    if (notCloseCommand) {
      cmd.exec(termNoCloseCmd + " '" + cmdToRun + " " + termNoCloseSuffix + "'")
    } else {
      cmd.exec(termCmd + " '" + cmdToRun + "'")
    }
  }

  function killProcess(process) {
    cmd.exec("kill -9 " + process)
  }

}

