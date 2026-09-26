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
  property bool enableSnapUpdates: Plasmoid.configuration.enableSnapUpdates
  property bool enableFlatpakUpdates: Plasmoid.configuration.enableFlatpakUpdates

  property string lastCountAurCmd: ""
  property string lastListAurCmd: ""

  function getCountAurCmd() {
    if (!enableSnapUpdates && !enableFlatpakUpdates) return ""
    if (enableSnapUpdates && enableFlatpakUpdates) {
      return countAurCommand !== "" ? countAurCommand : "s=0; f=0; which snap >/dev/null 2>&1 && s=$(snap refresh --list 2>/dev/null | tail -n +2 | wc -l || echo 0); which flatpak >/dev/null 2>&1 && f=$(flatpak remote-ls --updates 2>/dev/null | wc -l || echo 0); echo $((s + f))"
    }
    if (enableSnapUpdates) {
      return "which snap >/dev/null 2>&1 && snap refresh --list 2>/dev/null | tail -n +2 | wc -l || echo 0"
    }
    if (enableFlatpakUpdates) {
      return "which flatpak >/dev/null 2>&1 && flatpak remote-ls --updates 2>/dev/null | wc -l || echo 0"
    }
    return ""
  }

  function getListAurCmd() {
    if (!enableSnapUpdates && !enableFlatpakUpdates) return ""
    if (enableSnapUpdates && enableFlatpakUpdates) {
      return listAurCommand !== "" ? listAurCommand : "(which snap >/dev/null 2>&1 && snap refresh --list 2>/dev/null | awk 'NR>1 {print $1, \"snap\", \"->\", $2}') ; (which flatpak >/dev/null 2>&1 && flatpak remote-ls --updates 2>/dev/null | awk '{print $1, \"flatpak\", \"->\", $2}')"
    }
    if (enableSnapUpdates) {
      return "which snap >/dev/null 2>&1 && snap refresh --list 2>/dev/null | awk 'NR>1 {print $1, \"snap\", \"->\", $2}'"
    }
    if (enableFlatpakUpdates) {
      return "which flatpak >/dev/null 2>&1 && flatpak remote-ls --updates 2>/dev/null | awk '{print $1, \"flatpak\", \"->\", $2}'"
    }
    return ""
  }

  function getEffectiveUpdateCommand() {
    if (enableSnapUpdates && enableFlatpakUpdates) {
      return updateCommand
    }
    var parts = ["sudo apt update && sudo apt upgrade"]
    if (enableSnapUpdates) {
      parts.push("(which snap >/dev/null 2>&1 && sudo snap refresh || true)")
    }
    if (enableFlatpakUpdates) {
      parts.push("(which flatpak >/dev/null 2>&1 && flatpak update -y || true)")
    }
    return parts.join(" && ")
  }

  function countArch() {
    if (countArchCommand !== '') cmd.exec(countArchCommand)
  }

  function countAur() {
    if (!enableSnapUpdates && !enableFlatpakUpdates) {
      main.tAur = "0"
      cmd.totalAur("0")
      main.listAur = ""
      cmd.packagesList(main.listAur, main.listArch, main.listArchRepo)
      main.checkNotification()
      return
    }
    var c = getCountAurCmd()
    lastCountAurCmd = c
    if (c !== '') cmd.exec(c)
  }

  function listArch() {
    if (listArchCommand !== '') cmd.exec(listArchCommand)
  }

  function listAur() {
    if (!enableSnapUpdates && !enableFlatpakUpdates) {
      main.listAur = ""
      cmd.packagesList(main.listAur, main.listArch, main.listArchRepo)
      return
    }
    var c = getListAurCmd()
    lastListAurCmd = c
    if (c !== '') cmd.exec(c)
  }

  function listArchRepo() {
    if (listRepoArchCommand !== '') cmd.exec(listRepoArchCommand)
  }

  function checkReboot() {
    cmd.exec("test -f /var/run/reboot-required && echo 1 || echo 0")
  }

  function countAll() {
    countArch()
    countAur()
    listArchRepo()
    checkReboot()
  }

  function listAll() {
    listArch()
    listAur()
  }

  function launchUpdate() {
    var effCmd = getEffectiveUpdateCommand()
    if (effCmd !== '') {
      if (notCloseCommand) {
        cmd.exec(termNoCloseCmd + " '" + effCmd + " " + termNoCloseSuffix + "'")
      } else {
        var baseTerm = termCmd.trim()
        if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
          baseTerm += " bash -c"
        }
        cmd.exec(baseTerm + " '" + effCmd + " || (echo \"\"; echo \"An error occurred during update. Press Enter to close...\"; read -r)'")
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
      var baseTerm = termCmd.trim()
      if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
        baseTerm += " bash -c"
      }
      cmd.exec(baseTerm + " '" + cmdToRun + " || (echo \"\"; echo \"An error occurred during update. Press Enter to close...\"; read -r)'")
    }
  }

  function killProcess(process) {
    cmd.exec("kill -9 " + process)
  }

}

