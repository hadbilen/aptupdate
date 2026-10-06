import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.kde.plasma.plasmoid

Item {

  property string countArchCommand: Plasmoid.configuration.countArchCommand
  property string listArchCommand: Plasmoid.configuration.listArchCommand
  property string listRepoArchCommand: Plasmoid.configuration.listRepoArchCommand
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
  property string connectivityCmd: "ip route show default 2>/dev/null | grep -q default && echo 1 || echo 0"
  property bool isConnected: true

  property string lastCountArchCmd: ""
  property string lastListArchCmd: ""
  property string lastCountSnapCmd: ""
  property string lastListSnapCmd: ""
  property string lastCountFlatpakCmd: ""
  property string lastListFlatpakCmd: ""
  property string lastUpdateCmd: ""

  function getCountArchCmd() {
    var phased = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    return "bash -c \"set -o pipefail; LANG=C apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade" + phased + " 2>/dev/null | awk '/^Inst [^ ]+ \\\\[/ {c++} END {print c+0}'\""
  }

  function getListArchCmd() {
    var phased = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    return "LANG=C apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade" + phased + " 2>/dev/null | awk '/^Inst [^ ]+ \\[/ {orig=$0; gsub(/[][()]/, \"\"); $1=$1; origins=\"\"; for(i=5;i<=NF;i++) origins=(origins==\"\" ? $i : origins \" \" $i); print $2, $3, \"->\", $4, origins }'"
  }

  function getCountSnapCmd() {
    if (!enableSnapUpdates || !plasmoid.configuration.hasSnap) return ""
    return "bash -c 'set -o pipefail; timeout --kill-after=5s 15s snap refresh --list 2>/dev/null | awk \"BEGIN{c=0} NR>1 && \\$1!=\\\"All\\\" && \\$1!=\\\"\\\" {c++} END{print c}\"'"
  }

  function getCountFlatpakCmd() {
    if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) return ""
    return "bash -c 'set -o pipefail; timeout --kill-after=5s 15s flatpak remote-ls --updates 2>/dev/null | awk \"BEGIN{c=0} \\$1!=\\\"\\\" {c++} END{print c}\"'"
  }

  function getListSnapCmd() {
    if (!enableSnapUpdates || !plasmoid.configuration.hasSnap) return ""
    return "(snap list 2>/dev/null; echo '---SEP---'; timeout --kill-after=5s 15s snap refresh --list 2>/dev/null) | awk 'BEGIN { in_up=0 } $0 == \"---SEP---\" { in_up=1; next } !in_up { if ($1 != \"Name\" && NF>=2) { inst[$1]=$2 } next } in_up { if ($1 != \"Name\" && NF>=2 && $1 != \"\") { name=$1; tv=$2; fv=(name in inst ? inst[name] : \"-\"); print name \"\\t\" name \"\\tsnap\\t\" fv \"\\t\" tv } }'"
  }

  function getListFlatpakCmd() {
    if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) return ""
    return "(flatpak list --columns=application,branch,version 2>/dev/null; echo '---SEP---'; timeout --kill-after=5s 15s flatpak remote-ls --cached --updates --columns=application,name,branch,version 2>/dev/null) | awk -F'\\t' 'BEGIN { in_up=0 } $0 == \"---SEP---\" { in_up=1; next } !in_up { if (NF>=2) { ver=($3 != \"\" ? $3 : $2); inst[$1 \"/\" $2]=ver; inst_app[$1]=ver } next } in_up { if (NF>=1 && $1 != \"\") { app=$1; name=($2 != \"\" ? $2 : $1); branch=$3; tv=($4 != \"\" ? $4 : branch); key=app \"/\" branch; fv=(key in inst ? inst[key] : (app in inst_app ? inst_app[app] : \"-\")); print app \"\\t\" name \"\\tflatpak\\t\" fv \"\\t\" tv } }'"
  }

  function bashEscape(s) {
    return ("" + s).replace(/'/g, "'\\''")
  }

  function getEffectiveUpdateCommand() {
    var aptUpgrade = "sudo apt -o DPkg::Lock::Timeout=10 upgrade"
    if (includePhasedUpdates) {
      aptUpgrade = "sudo apt -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade"
    }
    var aptCount = parseInt(main.tApt, 10) || 0
    var snapCount = (enableSnapUpdates && plasmoid.configuration.hasSnap) ? (parseInt(main.tSnap, 10) || 0) : 0
    var flatpakCount = (enableFlatpakUpdates && plasmoid.configuration.hasFlatpak) ? (parseInt(main.tFlatpak, 10) || 0) : 0

    var parts = []
    if (aptCount > 0 || (snapCount === 0 && flatpakCount === 0)) {
      parts.push("sudo apt -o DPkg::Lock::Timeout=10 update && " + aptUpgrade)
    }
    if (enableSnapUpdates && plasmoid.configuration.hasSnap && snapCount > 0) {
      parts.push("sudo snap refresh")
    }
    if (enableFlatpakUpdates && plasmoid.configuration.hasFlatpak && flatpakCount > 0) {
      parts.push("flatpak update -y")
    }
    if (parts.length === 0) return ""
    if (parts.length === 1) return parts[0]
    return "err=0; " + parts.map(p => "(" + p + ") || err=1").join("; ") + "; [ $err -eq 0 ]"
  }

  function getEffectiveSilentUpdateCommand() {
    var aptCount = parseInt(main.tApt, 10) || 0
    var snapCount = (enableSnapUpdates && plasmoid.configuration.hasSnap) ? (parseInt(main.tSnap, 10) || 0) : 0
    var flatpakCount = (enableFlatpakUpdates && plasmoid.configuration.hasFlatpak) ? (parseInt(main.tFlatpak, 10) || 0) : 0

    var runApt = (aptCount > 0) || (snapCount === 0 && flatpakCount === 0)
    var runSnap = (enableSnapUpdates && plasmoid.configuration.hasSnap && snapCount > 0)
    var runFlatpak = (enableFlatpakUpdates && plasmoid.configuration.hasFlatpak && flatpakCount > 0)

    var rootParts = []
    if (runApt) {
      var aptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 upgrade -yq --with-new-pkgs"
      if (includePhasedUpdates) {
        aptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade -yq --with-new-pkgs"
      }
      rootParts.push("(apt-get -o DPkg::Lock::Timeout=10 update && " + aptUpgrade + ") || echo '[FAILED] apt' >> '" + main.logDir + "/aptupdate_last_error_all.log'")
    }
    if (runSnap) {
      rootParts.push("snap refresh || echo '[FAILED] snap' >> '" + main.logDir + "/aptupdate_last_error_all.log'")
    }

    var steps = []
    if (rootParts.length > 0) {
      var rootInner = rootParts.join("; ")
      var onFailList = []
      if (runApt) onFailList.push("echo '[FAILED] apt' >> '" + main.logDir + "/aptupdate_last_error_all.log'")
      if (runSnap) onFailList.push("echo '[FAILED] snap' >> '" + main.logDir + "/aptupdate_last_error_all.log'")
      var onAuthFail = onFailList.join("; ")
      var pkexecCmd = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(rootInner) + "'; pkstatus=$?; if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> '" + main.logDir + "/aptupdate_last_error_all.log'; elif [ $pkstatus -ne 0 ]; then " + onAuthFail + "; fi"
      steps.push(pkexecCmd)
    }

    if (runFlatpak) {
      steps.push("flatpak update -y || echo '[FAILED] flatpak' >> '" + main.logDir + "/aptupdate_last_error_all.log'")
    }

    var subshellCmd = steps.join("; ")
    var wrappedPipeline = "mkdir -p -m 0700 '" + main.logDir + "' 2>/dev/null; rm -f '" + main.logDir + "/aptupdate_last_error_all.log' 2>/dev/null; touch '" + main.logDir + "/aptupdate_last_error_all.log'; ( " + subshellCmd + " ); if [ -s '" + main.logDir + "/aptupdate_last_error_all.log' ]; then if grep -q '\\[FAILED\\]' '" + main.logDir + "/aptupdate_last_error_all.log'; then exit 1; elif grep -q '\\[CANCELLED\\]' '" + main.logDir + "/aptupdate_last_error_all.log'; then exit 126; fi; fi"
    var runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='Installing system updates' bash -c '" + bashEscape(wrappedPipeline) + "'"
    return "(command -v systemd-inhibit >/dev/null 2>&1 && " + runInhibit + ") || bash -c '" + bashEscape(wrappedPipeline) + "'"
  }

  function countArch() {
    var c = getCountArchCmd()
    lastCountArchCmd = c
    if (c !== '') cmd.exec(c)
  }

  function countSnap() {
    if (!enableSnapUpdates || !plasmoid.configuration.hasSnap) {
      main.tSnap = "0"
      cmd.totalSnap("0")
      main.listSnap = ""
      return
    }
    if (!isConnected) return
    var c = getCountSnapCmd()
    lastCountSnapCmd = c
    if (c !== '') cmd.exec(c)
  }

  function countFlatpak() {
    if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) {
      main.tFlatpak = "0"
      cmd.totalFlatpak("0")
      main.listFlatpak = ""
      return
    }
    if (!isConnected) return
    var c = getCountFlatpakCmd()
    lastCountFlatpakCmd = c
    if (c !== '') cmd.exec(c)
  }

  function listArch() {
    var c = getListArchCmd()
    lastListArchCmd = c
    if (c !== '') cmd.exec(c)
  }

  function listSnap() {
    if (!enableSnapUpdates || !plasmoid.configuration.hasSnap) {
      main.listSnap = ""
      return
    }
    if (!isConnected) return
    var c = getListSnapCmd()
    lastListSnapCmd = c
    if (c !== '') cmd.exec(c)
  }

  function listFlatpak() {
    if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) {
      main.listFlatpak = ""
      return
    }
    if (!isConnected) return
    var c = getListFlatpakCmd()
    lastListFlatpakCmd = c
    if (c !== '') cmd.exec(c)
  }

  function listArchRepo() {
    if (listRepoArchCommand !== '') cmd.exec(listRepoArchCommand)
  }

  function checkReboot() {
    cmd.exec("test -f /var/run/reboot-required && echo 1 || echo 0")
  }

  function checkReleaseUpgrade() {
    cmd.exec("test -s /var/lib/ubuntu-release-upgrader/release-upgrade-available && cat /var/lib/ubuntu-release-upgrader/release-upgrade-available 2>/dev/null || true")
  }

  function checkLock() {
    cmd.exec("(fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || (ps -u 0 -o comm=,args= 2>/dev/null | awk 'BEGIN{l=0} {c=$1; a=$0; sub(/^[^ ]+[ ]*/, \"\", a); if(c~/^(dpkg|synaptic|packagekitd|aptitude)$/){l=1;exit} if(a~/unattended-upgrade( |$)/){l=1;exit} if(c~/^(apt|apt-get)$/){if(a!~/( -s| --simulate| --dry-run| --just-print| --no-act)( |$)/){l=1;exit}}} END{exit !l}')) && echo 1 || echo 0")
  }

  function checkConnectivity() {
    cmd.exec(connectivityCmd)
  }

  function countAll() {
    if (main.isInstalling || main.isOnUpdate) return
    if (main.startupDelayTimer && main.startupDelayTimer.running) {
      main.startupDelayTimer.stop()
    }
    checker.checkProviders()
    checkLock()
    countArch()
    checkConnectivity()
    listArchRepo()
    checkReboot()
    checkReleaseUpgrade()
  }

  function sendNotify(title, message, icon, urgency) {
    var safeTitle = ("" + title).replace(/'/g, "'\\''")
    var safeMsg = ("" + message).replace(/'/g, "'\\''")
    var safeIcon = ("" + (icon || "dialog-information")).replace(/'/g, "'\\''")
    var safeUrgency = (urgency === "low" || urgency === "critical") ? urgency : "normal"
    cmd.exec("notify-send -u " + safeUrgency + " -a 'APT Update Counter' -i '" + safeIcon + "' '" + safeTitle + "' '" + safeMsg + "'")
  }

  function launchUpdate() {
    if (main.startupDelayTimer && main.startupDelayTimer.running) {
      main.startupDelayTimer.stop()
    }
    if (!main.canUpdateAll()) {
      if (main.isPkgManagerBusy && (parseInt(main.tApt, 10) || 0) > 0) {
        main.lockBlockedUpdate = true
      }
      sendNotify(i18n("Package Manager Busy"), i18n("Another package management process is currently running. Please wait for it to complete."), "dialog-warning", "normal")
      return
    }
    if (silentUpdate) {
      var silentCmd = getEffectiveSilentUpdateCommand()
      lastUpdateCmd = silentCmd
      main.registerUpdateJob(silentCmd, "all", null)
      cmd.exec(silentCmd)
      return
    }
    var effCmd = getEffectiveUpdateCommand()
    if (effCmd !== '') {
      if (notCloseCommand) {
        lastUpdateCmd = termNoCloseCmd + " '" + effCmd + " " + termNoCloseSuffix + "'"
        main.registerUpdateJob(lastUpdateCmd, "all", null)
        cmd.exec(lastUpdateCmd)
      } else {
        var baseTerm = termCmd.trim()
        if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
          baseTerm += " bash -c"
        }
        lastUpdateCmd = baseTerm + " '" + effCmd + " || (echo \"\"; echo \"" + i18n("An error occurred during update. Press Enter to close...") + "\"; read -r)'"
        main.registerUpdateJob(lastUpdateCmd, "all", null)
        cmd.exec(lastUpdateCmd)
      }
    }
  }

  function launchGroupUpdate(repo) {
    if (main.startupDelayTimer && main.startupDelayTimer.running) {
      main.startupDelayTimer.stop()
    }
    if (repo !== "apt" && repo !== "snap" && repo !== "flatpak") return
    if (!main.canUpdate(repo)) {
      if (repo === "apt" && main.isPkgManagerBusy) {
        main.lockBlockedUpdate = true
      }
      sendNotify(i18n("Package Manager Busy"), i18n("Another package management process is currently running. Please wait for it to complete."), "dialog-warning", "normal")
      return
    }
    var cmdToRun = ""
    if (repo === "apt") {
      var aptUpgrade = "sudo apt -o DPkg::Lock::Timeout=10 upgrade"
      if (includePhasedUpdates) {
        aptUpgrade = "sudo apt -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade"
      }
      cmdToRun = "sudo apt -o DPkg::Lock::Timeout=10 update && " + aptUpgrade
    } else if (repo === "snap") {
      if (!plasmoid.configuration.hasSnap) {
        sendNotify(i18n("Update Error"), i18n("Snap is not installed on this system."), "dialog-error", "critical")
        return
      }
      cmdToRun = "sudo snap refresh"
    } else if (repo === "flatpak") {
      if (!plasmoid.configuration.hasFlatpak) {
        sendNotify(i18n("Update Error"), i18n("Flatpak is not installed on this system."), "dialog-error", "critical")
        return
      }
      cmdToRun = "flatpak update -y"
    }
    if (!cmdToRun) return

    if (silentUpdate) {
      var wrappedPipeline = ""
      var runInhibit = ""
      if (repo === "flatpak") {
        var userCmd = "flatpak update -y || echo '[FAILED] flatpak' >> '" + main.logDir + "/aptupdate_last_error_flatpak.log'"
        wrappedPipeline = "mkdir -p -m 0700 '" + main.logDir + "' 2>/dev/null; rm -f '" + main.logDir + "/aptupdate_last_error_flatpak.log' 2>/dev/null; touch '" + main.logDir + "/aptupdate_last_error_flatpak.log'; ( " + userCmd + " ); if [ -s '" + main.logDir + "/aptupdate_last_error_flatpak.log' ]; then if grep -q '\\[FAILED\\]' '" + main.logDir + "/aptupdate_last_error_flatpak.log'; then exit 1; elif grep -q '\\[CANCELLED\\]' '" + main.logDir + "/aptupdate_last_error_flatpak.log'; then exit 126; fi; fi"
        runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='Installing flatpak updates' bash -c '" + bashEscape(wrappedPipeline) + "'"
      } else if (repo === "snap") {
        var snapCmd = "snap refresh || echo '[FAILED] snap' >> '" + main.logDir + "/aptupdate_last_error_snap.log'"
        var pkexecSnap = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(snapCmd) + "'; pkstatus=$?; if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> '" + main.logDir + "/aptupdate_last_error_snap.log'; elif [ $pkstatus -ne 0 ]; then echo '[FAILED] snap' >> '" + main.logDir + "/aptupdate_last_error_snap.log'; fi"
        wrappedPipeline = "mkdir -p -m 0700 '" + main.logDir + "' 2>/dev/null; rm -f '" + main.logDir + "/aptupdate_last_error_snap.log' 2>/dev/null; touch '" + main.logDir + "/aptupdate_last_error_snap.log'; ( " + pkexecSnap + " ); if [ -s '" + main.logDir + "/aptupdate_last_error_snap.log' ]; then if grep -q '\\[FAILED\\]' '" + main.logDir + "/aptupdate_last_error_snap.log'; then exit 1; elif grep -q '\\[CANCELLED\\]' '" + main.logDir + "/aptupdate_last_error_snap.log'; then exit 126; fi; fi"
        runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='Installing snap updates' bash -c '" + bashEscape(wrappedPipeline) + "'"
      } else if (repo === "apt") {
        var aptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 upgrade -yq --with-new-pkgs"
        if (includePhasedUpdates) {
          aptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade -yq --with-new-pkgs"
        }
        var aptCmd = "(apt-get -o DPkg::Lock::Timeout=10 update && " + aptUpgrade + ") || echo '[FAILED] apt' >> '" + main.logDir + "/aptupdate_last_error_apt.log'"
        var pkexecApt = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(aptCmd) + "'; pkstatus=$?; if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> '" + main.logDir + "/aptupdate_last_error_apt.log'; elif [ $pkstatus -ne 0 ]; then echo '[FAILED] apt' >> '" + main.logDir + "/aptupdate_last_error_apt.log'; fi"
        wrappedPipeline = "mkdir -p -m 0700 '" + main.logDir + "' 2>/dev/null; rm -f '" + main.logDir + "/aptupdate_last_error_apt.log' 2>/dev/null; touch '" + main.logDir + "/aptupdate_last_error_apt.log'; ( " + pkexecApt + " ); if [ -s '" + main.logDir + "/aptupdate_last_error_apt.log' ]; then if grep -q '\\[FAILED\\]' '" + main.logDir + "/aptupdate_last_error_apt.log'; then exit 1; elif grep -q '\\[CANCELLED\\]' '" + main.logDir + "/aptupdate_last_error_apt.log'; then exit 126; fi; fi"
        runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='Installing apt updates' bash -c '" + bashEscape(wrappedPipeline) + "'"
      }
      var silentGroupCmd = "(command -v systemd-inhibit >/dev/null 2>&1 && " + runInhibit + ") || bash -c '" + bashEscape(wrappedPipeline) + "'"
      lastUpdateCmd = silentGroupCmd
      main.registerUpdateJob(silentGroupCmd, "group", repo)
      cmd.exec(silentGroupCmd)
      return
    }

    if (notCloseCommand) {
      lastUpdateCmd = termNoCloseCmd + " '" + cmdToRun + " " + termNoCloseSuffix + "'"
      main.registerUpdateJob(lastUpdateCmd, "group", repo)
      cmd.exec(lastUpdateCmd)
    } else {
      var baseTerm = termCmd.trim()
      if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
        baseTerm += " bash -c"
      }
      lastUpdateCmd = baseTerm + " '" + cmdToRun + " || (echo \"\"; echo \"" + i18n("An error occurred during update. Press Enter to close...") + "\"; read -r)'"
      main.registerUpdateJob(lastUpdateCmd, "group", repo)
      cmd.exec(lastUpdateCmd)
    }
  }

  function launchOneUpdate(packageName, repo, appId) {
    if (main.startupDelayTimer && main.startupDelayTimer.running) {
      main.startupDelayTimer.stop()
    }
    if (!packageName && !appId) return
    if (!main.canUpdatePackage(repo, packageName, appId)) {
      if (repo === "apt" && main.isPkgManagerBusy) {
        main.lockBlockedUpdate = true
      }
      sendNotify(i18n("Package Manager Busy"), i18n("Another package management process is currently running. Please wait for it to complete."), "dialog-warning", "normal")
      return
    }

    var targetName = (repo === "flatpak" && appId && appId.trim() !== "") ? appId.trim() : packageName
    var safePackageName = targetName.replace(/[^a-zA-Z0-9.+:_-]/g, "").replace(/^-+/, "")
    if (!safePackageName) return

    if (silentUpdate) {
      var wrappedPipeline = ""
      var runInhibit = ""
      if (repo === "flatpak") {
        if (!plasmoid.configuration.hasFlatpak) {
          sendNotify(i18n("Update Error"), i18n("Flatpak is not installed on this system."), "dialog-error", "critical")
          return
        }
        var userCmd = "flatpak update -y -- " + safePackageName + " || echo '[FAILED] flatpak' >> '" + main.logDir + "/aptupdate_last_error_flatpak.log'"
        wrappedPipeline = "mkdir -p -m 0700 '" + main.logDir + "' 2>/dev/null; rm -f '" + main.logDir + "/aptupdate_last_error_flatpak.log' 2>/dev/null; touch '" + main.logDir + "/aptupdate_last_error_flatpak.log'; ( " + userCmd + " ); if [ -s '" + main.logDir + "/aptupdate_last_error_flatpak.log' ]; then if grep -q '\\[FAILED\\]' '" + main.logDir + "/aptupdate_last_error_flatpak.log'; then exit 1; elif grep -q '\\[CANCELLED\\]' '" + main.logDir + "/aptupdate_last_error_flatpak.log'; then exit 126; fi; fi"
        runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='Installing " + safePackageName + "' bash -c '" + bashEscape(wrappedPipeline) + "'"
      } else if (repo === "snap") {
        if (!plasmoid.configuration.hasSnap) {
          sendNotify(i18n("Update Error"), i18n("Snap is not installed on this system."), "dialog-error", "critical")
          return
        }
        var snapCmd = "snap refresh -- " + safePackageName + " || echo '[FAILED] snap' >> '" + main.logDir + "/aptupdate_last_error_snap.log'"
        var pkexecSnap = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(snapCmd) + "'; pkstatus=$?; if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> '" + main.logDir + "/aptupdate_last_error_snap.log'; elif [ $pkstatus -ne 0 ]; then echo '[FAILED] snap' >> '" + main.logDir + "/aptupdate_last_error_snap.log'; fi"
        wrappedPipeline = "mkdir -p -m 0700 '" + main.logDir + "' 2>/dev/null; rm -f '" + main.logDir + "/aptupdate_last_error_snap.log' 2>/dev/null; touch '" + main.logDir + "/aptupdate_last_error_snap.log'; ( " + pkexecSnap + " ); if [ -s '" + main.logDir + "/aptupdate_last_error_snap.log' ]; then if grep -q '\\[FAILED\\]' '" + main.logDir + "/aptupdate_last_error_snap.log'; then exit 1; elif grep -q '\\[CANCELLED\\]' '" + main.logDir + "/aptupdate_last_error_snap.log'; then exit 126; fi; fi"
        runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='Installing " + safePackageName + "' bash -c '" + bashEscape(wrappedPipeline) + "'"
      } else {
        var aptCmd = "apt-get -o DPkg::Lock::Timeout=10 install --only-upgrade -yq -- " + safePackageName + " || echo '[FAILED] apt' >> '" + main.logDir + "/aptupdate_last_error_apt.log'"
        var pkexecApt = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(aptCmd) + "'; pkstatus=$?; if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> '" + main.logDir + "/aptupdate_last_error_apt.log'; elif [ $pkstatus -ne 0 ]; then echo '[FAILED] apt' >> '" + main.logDir + "/aptupdate_last_error_apt.log'; fi"
        wrappedPipeline = "mkdir -p -m 0700 '" + main.logDir + "' 2>/dev/null; rm -f '" + main.logDir + "/aptupdate_last_error_apt.log' 2>/dev/null; touch '" + main.logDir + "/aptupdate_last_error_apt.log'; ( " + pkexecApt + " ); if [ -s '" + main.logDir + "/aptupdate_last_error_apt.log' ]; then if grep -q '\\[FAILED\\]' '" + main.logDir + "/aptupdate_last_error_apt.log'; then exit 1; elif grep -q '\\[CANCELLED\\]' '" + main.logDir + "/aptupdate_last_error_apt.log'; then exit 126; fi; fi"
        runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='Installing " + safePackageName + "' bash -c '" + bashEscape(wrappedPipeline) + "'"
      }
      var silentSingleCmd = "(command -v systemd-inhibit >/dev/null 2>&1 && " + runInhibit + ") || bash -c '" + bashEscape(wrappedPipeline) + "'"
      lastUpdateCmd = silentSingleCmd
      main.registerUpdateJob(silentSingleCmd, "single", repo, packageName, appId)
      cmd.exec(silentSingleCmd)
      return
    }

    var baseAptCmd = updateCommandOne.indexOf("-y") === -1 ? (updateCommandOne + " -y") : updateCommandOne
    var cmdToRun = baseAptCmd + " -- " + safePackageName
    if (repo === "snap") {
      if (!plasmoid.configuration.hasSnap) {
        sendNotify(i18n("Update Error"), i18n("Snap is not installed on this system."), "dialog-error", "critical")
        return
      }
      cmdToRun = "sudo snap refresh -- " + safePackageName
    } else if (repo === "flatpak") {
      if (!plasmoid.configuration.hasFlatpak) {
        sendNotify(i18n("Update Error"), i18n("Flatpak is not installed on this system."), "dialog-error", "critical")
        return
      }
      cmdToRun = "flatpak update -y -- " + safePackageName
    }
    if (notCloseCommand) {
      lastUpdateCmd = termNoCloseCmd + " '" + cmdToRun + " " + termNoCloseSuffix + "'"
      main.registerUpdateJob(lastUpdateCmd, "single", repo, packageName, appId)
      cmd.exec(lastUpdateCmd)
    } else {
      var baseTerm = termCmd.trim()
      if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
        baseTerm += " bash -c"
      }
      lastUpdateCmd = baseTerm + " '" + cmdToRun + " || (echo \"\"; echo \"" + i18n("An error occurred during update. Press Enter to close...") + "\"; read -r)'"
      main.registerUpdateJob(lastUpdateCmd, "single", repo, packageName, appId)
      cmd.exec(lastUpdateCmd)
    }
  }

}
