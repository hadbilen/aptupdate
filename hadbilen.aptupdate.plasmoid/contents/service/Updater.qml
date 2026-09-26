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
  property bool silentUpdate: Plasmoid.configuration.silentUpdate
  property bool notifyOnSilentUpdate: Plasmoid.configuration.notifyOnSilentUpdate
  property bool includePhasedUpdates: Plasmoid.configuration.includePhasedUpdates

  property string lastCountArchCmd: ""
  property string lastListArchCmd: ""
  property string lastCountAurCmd: ""
  property string lastListAurCmd: ""
  property string lastUpdateCmd: ""

  function getCountArchCmd() {
    if (includePhasedUpdates) {
      return "LANG=C apt-get -s -o DPkg::Lock::Timeout=10 upgrade -o APT::Get::Always-Include-Phased-Updates=true 2>/dev/null | grep -c '^Inst ' || echo 0"
    }
    return "LANG=C apt-get -s -o DPkg::Lock::Timeout=10 upgrade 2>/dev/null | grep -c '^Inst ' || echo 0"
  }

  function getListArchCmd() {
    if (includePhasedUpdates) {
      return "LANG=C apt-get -s -o DPkg::Lock::Timeout=10 upgrade -o APT::Get::Always-Include-Phased-Updates=true 2>/dev/null | awk '/^Inst / {gsub(/[\\[\\]\\(\\)]/, \"\"); print $2, $3, \"->\", $4}'"
    }
    return "LANG=C apt-get -s -o DPkg::Lock::Timeout=10 upgrade 2>/dev/null | awk '/^Inst / {gsub(/[\\[\\]\\(\\)]/, \"\"); print $2, $3, \"->\", $4}'"
  }

  function getCountAurCmd() {
    var snapActive = enableSnapUpdates && plasmoid.configuration.hasSnap
    var flatpakActive = enableFlatpakUpdates && plasmoid.configuration.hasFlatpak
    if (!snapActive && !flatpakActive) return ""
    if (snapActive && flatpakActive) {
      return countAurCommand !== "" ? countAurCommand : "s=0; f=0; s=$(snap refresh --list 2>/dev/null | tail -n +2 | wc -l || echo 0); f=$(flatpak remote-ls --updates 2>/dev/null | wc -l || echo 0); echo $((s + f))"
    }
    if (snapActive) {
      return "snap refresh --list 2>/dev/null | tail -n +2 | wc -l || echo 0"
    }
    if (flatpakActive) {
      return "flatpak remote-ls --updates 2>/dev/null | wc -l || echo 0"
    }
    return ""
  }

  function getListAurCmd() {
    var snapActive = enableSnapUpdates && plasmoid.configuration.hasSnap
    var flatpakActive = enableFlatpakUpdates && plasmoid.configuration.hasFlatpak
    if (!snapActive && !flatpakActive) return ""
    if (snapActive && flatpakActive) {
      return listAurCommand !== "" ? listAurCommand : "(snap refresh --list 2>/dev/null | awk 'NR>1 {print $1, \"snap\", \"->\", $2}') ; (flatpak remote-ls --updates 2>/dev/null | awk '{print $1, \"flatpak\", \"->\", $2}')"
    }
    if (snapActive) {
      return "snap refresh --list 2>/dev/null | awk 'NR>1 {print $1, \"snap\", \"->\", $2}'"
    }
    if (flatpakActive) {
      return "flatpak remote-ls --updates 2>/dev/null | awk '{print $1, \"flatpak\", \"->\", $2}'"
    }
    return ""
  }

  function getEffectiveUpdateCommand() {
    var aptUpgrade = "sudo apt -o DPkg::Lock::Timeout=10 upgrade"
    if (includePhasedUpdates) {
      aptUpgrade = "sudo apt -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade"
    }
    var parts = ["sudo apt -o DPkg::Lock::Timeout=10 update && " + aptUpgrade]
    if (enableSnapUpdates && plasmoid.configuration.hasSnap) {
      parts.push("sudo snap refresh")
    }
    if (enableFlatpakUpdates && plasmoid.configuration.hasFlatpak) {
      parts.push("flatpak update -y")
    }
    return parts.join(" && ")
  }

  function getEffectiveSilentUpdateCommand() {
    var aptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 upgrade -yq"
    if (includePhasedUpdates) {
      aptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade -yq"
    }
    var parts = ["apt-get -o DPkg::Lock::Timeout=10 update && " + aptUpgrade]
    if (enableSnapUpdates && plasmoid.configuration.hasSnap) {
      parts.push("snap refresh")
    }
    if (enableFlatpakUpdates && plasmoid.configuration.hasFlatpak) {
      parts.push("flatpak update -y")
    }
    var innerCmd = parts.join(" && ")
    return "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='Installing system updates' pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + innerCmd + "'"
  }

  function countArch() {
    var c = getCountArchCmd()
    lastCountArchCmd = c
    if (c !== '') cmd.exec(c)
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
    var c = getListArchCmd()
    lastListArchCmd = c
    if (c !== '') cmd.exec(c)
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

  function checkLock() {
    cmd.exec("fuser /var/lib/dpkg/lock-frontend 2>/dev/null && echo 1 || echo 0")
  }

  function countAll() {
    checker.checkProviders()
    checkLock()
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
    if (main.isPkgManagerBusy) {
      cmd.exec("notify-send -u normal -a 'APT Update Counter' -i dialog-warning '" + i18n("Package Manager Busy") + "' '" + i18n("Another package management process is currently running. Please wait for it to complete.") + "'")
      return
    }
    if (silentUpdate) {
      var silentCmd = getEffectiveSilentUpdateCommand()
      lastUpdateCmd = silentCmd
      cmd.exec(silentCmd)
      return
    }
    var effCmd = getEffectiveUpdateCommand()
    if (effCmd !== '') {
      if (notCloseCommand) {
        lastUpdateCmd = termNoCloseCmd + " '" + effCmd + " " + termNoCloseSuffix + "'"
        cmd.exec(lastUpdateCmd)
      } else {
        var baseTerm = termCmd.trim()
        if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
          baseTerm += " bash -c"
        }
        lastUpdateCmd = baseTerm + " '" + effCmd + " || (echo \"\"; echo \"An error occurred during update. Press Enter to close...\"; read -r)'"
        cmd.exec(lastUpdateCmd)
      }
    }
  }

  function launchOneUpdate(packageName, repo) {
    if (!packageName) return
    if (main.isPkgManagerBusy) {
      cmd.exec("notify-send -u normal -a 'APT Update Counter' -i dialog-warning '" + i18n("Package Manager Busy") + "' '" + i18n("Another package management process is currently running. Please wait for it to complete.") + "'")
      return
    }

    var safePackageName = packageName.replace(/[^a-zA-Z0-9.+:_-]/g, "")
    if (!safePackageName) return

    var cmdToRun = updateCommandOne + " " + safePackageName
    if (repo === "snap") {
      if (!plasmoid.configuration.hasSnap) {
        cmd.exec("notify-send -u critical -a 'APT Update Counter' -i dialog-error '" + i18n("Update Error") + "' '" + i18n("Snap is not installed on this system.") + "'")
        return
      }
      cmdToRun = "sudo snap refresh " + safePackageName
    } else if (repo === "flatpak") {
      if (!plasmoid.configuration.hasFlatpak) {
        cmd.exec("notify-send -u critical -a 'APT Update Counter' -i dialog-error '" + i18n("Update Error") + "' '" + i18n("Flatpak is not installed on this system.") + "'")
        return
      }
      cmdToRun = "flatpak update -y " + safePackageName
    }
    if (notCloseCommand) {
      lastUpdateCmd = termNoCloseCmd + " '" + cmdToRun + " " + termNoCloseSuffix + "'"
      cmd.exec(lastUpdateCmd)
    } else {
      var baseTerm = termCmd.trim()
      if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
        baseTerm += " bash -c"
      }
      lastUpdateCmd = baseTerm + " '" + cmdToRun + " || (echo \"\"; echo \"An error occurred during update. Press Enter to close...\"; read -r)'"
      cmd.exec(lastUpdateCmd)
    }
  }

}
