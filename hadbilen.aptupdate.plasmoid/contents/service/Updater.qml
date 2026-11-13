import QtQuick

import org.kde.plasma.plasmoid

Item {

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
  property bool useNala: Plasmoid.configuration.useNala
  property string connectivityCmd: "(ip route show default 2>/dev/null; ip -6 route show default 2>/dev/null) | grep -q default && echo 1 || echo 0"
  property bool isConnected: true

  property string lastCountArchCmd: ""
  property string lastListArchCmd: ""
  property string lastListSnapCmd: ""
  property string lastListFlatpakCmd: ""
  property string lastUpdateCmd: ""

  function bashEscape(s) {
    return ("" + s).replace(/'/g, "'\\''")
  }

  function getCountArchCmd() {
    var phased = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    return "bash -c \"set -o pipefail; LC_ALL=C apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade" + phased + " 2>/dev/null | awk '/^Inst [^ ]+ \\\\[/ {c++} END {print c+0}'\""
  }

  function getListArchCmd() {
    var phased = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    var inner = "set -o pipefail; LC_ALL=C apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade" + phased + " 2>/dev/null | awk '/^Inst [^ ]+ \\[/ {orig=$0; gsub(/[][()]/, \"\"); $1=$1; origins=\"\"; for(i=5;i<=NF;i++) origins=(origins==\"\" ? $i : origins \" \" $i); print $2, $3, \"->\", $4, origins }'"
    return "bash -c '" + bashEscape(inner) + "'"
  }

  function getListSnapCmd() {
    if (!enableSnapUpdates || !plasmoid.configuration.hasSnap) return ""
    var inner = "set -o pipefail; (LC_ALL=C snap list 2>/dev/null || true; echo '---SEP---'; LC_ALL=C timeout --kill-after=5s 20s snap refresh --list 2>/dev/null) | awk 'BEGIN { in_up=0 } $0 == \"---SEP---\" { in_up=1; next } !in_up { if ($1 != \"Name\" && NF>=2) { inst[$1]=$2 } next } in_up { if ($1 != \"Name\" && $1 != \"All\" && NF>=2 && $1 != \"\") { name=$1; tv=$2; fv=(name in inst ? inst[name] : \"-\"); print name \"\\t\" name \"\\tsnap\\t\" fv \"\\t\" tv } }'"
    return "bash -c '" + bashEscape(inner) + "'"
  }

  function getListFlatpakCmd() {
    if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) return ""
    var inner = "set -o pipefail; (LC_ALL=C flatpak list --columns=application,branch,version 2>/dev/null || true; echo '---SEP---'; LC_ALL=C timeout --kill-after=5s 20s flatpak remote-ls --updates --columns=application,name,branch,version 2>/dev/null) | awk -F'\\t' 'BEGIN { in_up=0 } $0 == \"---SEP---\" { in_up=1; next } !in_up { if (NF>=2) { ver=($3 != \"\" ? $3 : $2); inst[$1 \"/\" $2]=ver; inst_app[$1]=ver } next } in_up { if (NF>=1 && $1 != \"\") { app=$1; name=($2 != \"\" ? $2 : $1); branch=$3; tv=($4 != \"\" ? $4 : branch); key=app \"/\" branch; fv=(key in inst ? inst[key] : (app in inst_app ? inst_app[app] : \"-\")); print app \"\\t\" name \"\\tflatpak\\t\" fv \"\\t\" tv } }'"
    return "bash -c '" + bashEscape(inner) + "'"
  }

  function buildSilentWrapper(logFileName, innerScript, inhibitReason) {
    var safeDir = bashEscape(main.logDir)
    var safeFile = safeDir + "/" + logFileName
    var wrappedPipeline = "logdir='" + safeDir + "'; logfile='" + safeFile + "'; " +
      "mkdir -p -m 0700 \"$logdir\" 2>/dev/null; " +
      "if ! test -d \"$logdir\" || ! test -O \"$logdir\" || test -L \"$logdir\"; then exit 1; fi; " +
      "rm -f \"$logfile\" 2>/dev/null; " +
      ": > \"$logfile\" 2>/dev/null; " +
      "if test -L \"$logfile\" || ! test -O \"$logfile\"; then exit 1; fi; " +
      "( " + innerScript + " ); " +
      "if [ -s \"$logfile\" ]; then " +
        "if grep -q '\\[FAILED\\]' \"$logfile\"; then exit 1; " +
        "elif grep -q '\\[CANCELLED\\]' \"$logfile\"; then exit 126; fi; " +
      "fi"
    var runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='" + bashEscape(inhibitReason) + "' bash -c '" + bashEscape(wrappedPipeline) + "'"
    var checkInhibit = "command -v systemd-inhibit >/dev/null 2>&1 && systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='check' true >/dev/null 2>&1"
    return "if " + checkInhibit + "; then " + runInhibit + "; else bash -c '" + bashEscape(wrappedPipeline) + "'; fi"
  }

  function buildTerminalCommand(innerCmd) {
    var baseTerm = (notCloseCommand ? termNoCloseCmd : termCmd).trim()
    if (!baseTerm) return ""
    if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
      baseTerm += " bash -c"
    }
    var script = ""
    if (notCloseCommand) {
      var suffix = (termNoCloseSuffix || "").trim()
      script = suffix ? (innerCmd + " " + suffix) : innerCmd
    } else {
      var errPrompt = i18n("An error occurred during update. Press Enter to close...")
      script = "(" + innerCmd + ") || { st=$?; echo ''; echo '" + bashEscape(errPrompt) + "'; read -r; exit $st; }"
    }
    return baseTerm + " '" + bashEscape(script) + "'"
  }

  function getTerminalAptUpgradeCommand() {
    if (useNala && plasmoid.configuration.hasNala) {
      var nalaCmd = "sudo nala upgrade -o DPkg::Lock::Timeout=10"
      if (includePhasedUpdates) {
        nalaCmd += " -o APT::Get::Always-Include-Phased-Updates=true"
      }
      return nalaCmd
    }
    var aptUpgrade = "sudo apt -o DPkg::Lock::Timeout=10 upgrade"
    if (includePhasedUpdates) {
      aptUpgrade = "sudo apt -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade"
    }
    return "sudo apt -o DPkg::Lock::Timeout=10 update && " + aptUpgrade
  }

  function getEffectiveUpdateCommand() {
    var aptCount = parseInt(main.tApt, 10) || 0
    var snapCount = (enableSnapUpdates && plasmoid.configuration.hasSnap) ? (parseInt(main.tSnap, 10) || 0) : 0
    var flatpakCount = (enableFlatpakUpdates && plasmoid.configuration.hasFlatpak) ? (parseInt(main.tFlatpak, 10) || 0) : 0

    var parts = []
    if (aptCount > 0 || (snapCount === 0 && flatpakCount === 0)) {
      parts.push(getTerminalAptUpgradeCommand())
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

    var aptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 upgrade -yq --with-new-pkgs"
    if (includePhasedUpdates) {
      aptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade -yq --with-new-pkgs"
    }
    var aptFullCmd = "apt-get -o DPkg::Lock::Timeout=10 update && " + aptUpgrade

    var steps = []
    if (runApt && runSnap) {
      var bothInner = "rc=0; (" + aptFullCmd + ") || rc=$((rc | 1)); snap refresh || rc=$((rc | 2)); exit $rc"
      var pkexecBoth = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(bothInner) + "'; pkstatus=$?; " +
        "if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> \"$logfile\"; " +
        "elif [ $pkstatus -ne 0 ]; then " +
          "if [ $((pkstatus & 1)) -ne 0 ] || [ $pkstatus -gt 3 ]; then echo '[FAILED] apt' >> \"$logfile\"; fi; " +
          "if [ $((pkstatus & 2)) -ne 0 ] || [ $pkstatus -gt 3 ]; then echo '[FAILED] snap' >> \"$logfile\"; fi; " +
        "fi"
      steps.push(pkexecBoth)
    } else if (runApt) {
      var pkexecApt = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(aptFullCmd) + "'; pkstatus=$?; " +
        "if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> \"$logfile\"; " +
        "elif [ $pkstatus -ne 0 ]; then echo '[FAILED] apt' >> \"$logfile\"; fi"
      steps.push(pkexecApt)
    } else if (runSnap) {
      var pkexecSnap = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c 'snap refresh'; pkstatus=$?; " +
        "if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> \"$logfile\"; " +
        "elif [ $pkstatus -ne 0 ]; then echo '[FAILED] snap' >> \"$logfile\"; fi"
      steps.push(pkexecSnap)
    }

    if (runFlatpak) {
      steps.push("if [ ${pkstatus:-0} -ne 126 ]; then flatpak update -y || echo '[FAILED] flatpak' >> \"$logfile\"; fi")
    }

    var subshellCmd = steps.join("; ")
    return buildSilentWrapper("aptupdate_last_error_all.log", subshellCmd, "Installing system updates")
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
    listSnap()
  }

  function countFlatpak() {
    if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) {
      main.tFlatpak = "0"
      cmd.totalFlatpak("0")
      main.listFlatpak = ""
      return
    }
    listFlatpak()
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
    var c = getListSnapCmd()
    lastListSnapCmd = c
    if (c !== '') cmd.exec(c)
  }

  function listFlatpak() {
    if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) {
      main.listFlatpak = ""
      return
    }
    var c = getListFlatpakCmd()
    lastListFlatpakCmd = c
    if (c !== '') cmd.exec(c)
  }

  function checkReboot() {
    cmd.exec("test -f /var/run/reboot-required && echo 1 || echo 0")
  }

  function checkReleaseUpgrade() {
    cmd.exec("test -s /var/lib/ubuntu-release-upgrader/release-upgrade-available && cat /var/lib/ubuntu-release-upgrader/release-upgrade-available 2>/dev/null || true")
  }

  function checkLock() {
    cmd.exec("(fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || (ps -u 0 -o comm=,args= 2>/dev/null | awk 'BEGIN{l=0} {c=$1; a=$0; sub(/^[^ ]+[ ]*/, \"\", a); if(c~/^(dpkg|synaptic|aptitude|aptd)$/){l=1;exit} if(a~/(unattended-upgrade|aptd)( |$)/){l=1;exit} if(c~/^(apt|apt-get|nala)$/ || a~/(^|\\/)nala( |$)/){if(a!~/( -s| --simulate| --dry-run| --just-print| --no-act)( |$)/){l=1;exit}}} END{exit !l}')) && echo 1 || echo 0")
  }

  function checkConnectivity() {
    cmd.exec(connectivityCmd)
  }

  function countAll() {
    if (main.isInstalling || main.isOnUpdate || main.isChecking) return
    if (main.startupDelayTimer && main.startupDelayTimer.running) {
      main.startupDelayTimer.stop()
    }
    checker.checkProviders()
    checkLock()
    countArch()
    checkConnectivity()
    checkReboot()
    checkReleaseUpgrade()
  }

  function sendNotify(title, message, icon, urgency) {
    var safeTitle = bashEscape(title)
    var safeMsg = bashEscape(message)
    var safeIcon = bashEscape(icon || "dialog-information")
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
      if (main.hasUpdate()) {
        sendNotify(i18n("Package Manager Busy"), i18n("Another package management process is currently running. Please wait for it to complete."), "dialog-warning", "normal")
      }
      return
    }
    main.clearPendingRetries()
    main.clearRepoErrors()
    if (silentUpdate) {
      var silentCmd = getEffectiveSilentUpdateCommand()
      lastUpdateCmd = silentCmd
      main.registerUpdateJob(silentCmd, "all", null)
      cmd.exec(silentCmd)
      return
    }
    var effCmd = getEffectiveUpdateCommand()
    if (effCmd !== '') {
      var termFullCmd = buildTerminalCommand(effCmd)
      if (!termFullCmd) {
        sendNotify(i18n("Update Error"), i18n("No terminal command is configured."), "dialog-error", "critical")
        return
      }
      lastUpdateCmd = termFullCmd
      main.registerUpdateJob(lastUpdateCmd, "all", null)
      cmd.exec(lastUpdateCmd)
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
    main.clearPendingRetries()
    var cmdToRun = ""
    if (repo === "apt") {
      cmdToRun = getTerminalAptUpgradeCommand()
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
      var innerScript = ""
      if (repo === "flatpak") {
        innerScript = "flatpak update -y || echo '[FAILED] flatpak' >> \"$logfile\""
      } else if (repo === "snap") {
        innerScript = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c 'snap refresh'; pkstatus=$?; " +
          "if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> \"$logfile\"; " +
          "elif [ $pkstatus -ne 0 ]; then echo '[FAILED] snap' >> \"$logfile\"; fi"
      } else if (repo === "apt") {
        var silentAptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 upgrade -yq --with-new-pkgs"
        if (includePhasedUpdates) {
          silentAptUpgrade = "apt-get -o DPkg::Lock::Timeout=10 -o APT::Get::Always-Include-Phased-Updates=true upgrade -yq --with-new-pkgs"
        }
        var aptCmd = "apt-get -o DPkg::Lock::Timeout=10 update && " + silentAptUpgrade
        innerScript = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(aptCmd) + "'; pkstatus=$?; " +
          "if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> \"$logfile\"; " +
          "elif [ $pkstatus -ne 0 ]; then echo '[FAILED] apt' >> \"$logfile\"; fi"
      }
      var silentGroupCmd = buildSilentWrapper("aptupdate_last_error_" + repo + ".log", innerScript, "Installing " + repo + " updates")
      lastUpdateCmd = silentGroupCmd
      main.registerUpdateJob(silentGroupCmd, "group", repo)
      cmd.exec(silentGroupCmd)
      return
    }

    var termFullCmd = buildTerminalCommand(cmdToRun)
    if (!termFullCmd) {
      sendNotify(i18n("Update Error"), i18n("No terminal command is configured."), "dialog-error", "critical")
      return
    }
    lastUpdateCmd = termFullCmd
    main.registerUpdateJob(lastUpdateCmd, "group", repo)
    cmd.exec(lastUpdateCmd)
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
    main.clearPendingRetries()

    var targetName = (repo === "flatpak" && appId && appId.trim() !== "") ? appId.trim() : packageName
    var safePackageName = targetName.replace(/[^a-zA-Z0-9.+:_-]/g, "").replace(/^-+/, "")
    if (!safePackageName) return

    var phasedFlag = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    if (silentUpdate) {
      var innerScript = ""
      if (repo === "flatpak") {
        if (!plasmoid.configuration.hasFlatpak) {
          sendNotify(i18n("Update Error"), i18n("Flatpak is not installed on this system."), "dialog-error", "critical")
          return
        }
        innerScript = "flatpak update -y -- " + safePackageName + " || echo '[FAILED] flatpak' >> \"$logfile\""
      } else if (repo === "snap") {
        if (!plasmoid.configuration.hasSnap) {
          sendNotify(i18n("Update Error"), i18n("Snap is not installed on this system."), "dialog-error", "critical")
          return
        }
        var snapCmd = "snap refresh -- " + safePackageName
        innerScript = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(snapCmd) + "'; pkstatus=$?; " +
          "if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> \"$logfile\"; " +
          "elif [ $pkstatus -ne 0 ]; then echo '[FAILED] snap' >> \"$logfile\"; fi"
      } else {
        var aptCmd = "apt-get -o DPkg::Lock::Timeout=10" + phasedFlag + " install --only-upgrade -yq -- " + safePackageName
        innerScript = "pkexec env DEBIAN_FRONTEND=noninteractive bash -c '" + bashEscape(aptCmd) + "'; pkstatus=$?; " +
          "if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> \"$logfile\"; " +
          "elif [ $pkstatus -ne 0 ]; then echo '[FAILED] apt' >> \"$logfile\"; fi"
      }
      var targetRepo = (repo === "flatpak" || repo === "snap") ? repo : "apt"
      var silentSingleCmd = buildSilentWrapper("aptupdate_last_error_" + targetRepo + ".log", innerScript, "Installing " + safePackageName)
      lastUpdateCmd = silentSingleCmd
      main.registerUpdateJob(silentSingleCmd, "single", targetRepo, packageName, appId)
      cmd.exec(silentSingleCmd)
      return
    }

    var rawAptCmd = (updateCommandOne || "sudo apt install --only-upgrade").trim()
    if (useNala && plasmoid.configuration.hasNala && rawAptCmd === "sudo apt install --only-upgrade") {
      rawAptCmd = "sudo nala install -o DPkg::Lock::Timeout=10" + phasedFlag
    } else {
      if (rawAptCmd.indexOf("DPkg::Lock::Timeout") === -1) {
        if (/\bnala\s+(install|upgrade)\b/.test(rawAptCmd)) {
          rawAptCmd = rawAptCmd.replace(/\b(nala\s+(?:install|upgrade))\b/, "$1 -o DPkg::Lock::Timeout=10" + phasedFlag)
        } else {
          rawAptCmd = rawAptCmd.replace(/\b(apt(?:-get)?)\b/, "$1 -o DPkg::Lock::Timeout=10" + phasedFlag)
        }
      } else if (phasedFlag !== "" && rawAptCmd.indexOf("Always-Include-Phased-Updates") === -1) {
        rawAptCmd += phasedFlag
      }
    }
    var baseAptCmd = rawAptCmd.indexOf("-y") === -1 ? (rawAptCmd + " -y") : rawAptCmd
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
    var termFullCmd = buildTerminalCommand(cmdToRun)
    if (!termFullCmd) {
      sendNotify(i18n("Update Error"), i18n("No terminal command is configured."), "dialog-error", "critical")
      return
    }
    lastUpdateCmd = termFullCmd
    main.registerUpdateJob(lastUpdateCmd, "single", repo, packageName, appId)
    cmd.exec(lastUpdateCmd)
  }

}
