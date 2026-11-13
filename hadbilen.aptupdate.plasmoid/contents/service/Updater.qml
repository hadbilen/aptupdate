import QtQuick

import org.kde.plasma.plasmoid

import "CommandBuilder.js" as CmdBuilder

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
    property string connectivityCmd: CmdBuilder.buildConnectivityCmd()
    property bool isConnected: true

    property string lastCountArchCmd: ""
    property string lastListArchCmd: ""
    property string lastListSnapCmd: ""
    property string lastListFlatpakCmd: ""
    property string lastUpdateCmd: ""
    property int jobSeq: 0

    function nextJobMeta(prefix) {
        jobSeq += 1
        var rawDir = (typeof main !== "undefined" && main.logDir) ? main.logDir : ""
        var dir = CmdBuilder.resolveSafeLogDir(rawDir)
        var useScope = (typeof main !== "undefined" && Boolean(main.hasSystemdScope))
        return {
            seq: jobSeq,
            unitName: useScope ? ("aptupdate-job-" + jobSeq + "-" + Math.floor(Date.now() / 1000)) : "",
            pgidFile: (!useScope && dir) ? (dir + "/aptupdate_pgid_" + jobSeq) : "",
            logFileName: "aptupdate_" + (prefix || "job") + "_" + jobSeq + ".log",
            rcFile: (dir ? (dir + "/aptupdate_rc_" + jobSeq) : "")
        }
    }

    function bashEscape(s) {
        return CmdBuilder.bashEscape(s)
    }

    function runCmd(c, role, repo) {
        if (!c) return
        if (typeof main !== "undefined" && typeof main.execTaggedJob === "function") {
            main.execTaggedJob(c, role || "check", repo || "")
        } else if (typeof cmd !== "undefined" && typeof cmd.exec === "function") {
            cmd.exec(c)
        }
    }

    function getCountArchCmd() {
        return CmdBuilder.buildCountArchCmd(includePhasedUpdates)
    }

    function getListArchCmd() {
        return CmdBuilder.buildListArchCmd(includePhasedUpdates)
    }

    function getListSnapCmd() {
        if (!enableSnapUpdates || !plasmoid.configuration.hasSnap) return ""
        return CmdBuilder.buildListSnapCmd()
    }

    function getListFlatpakCmd() {
        if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) return ""
        return CmdBuilder.buildListFlatpakCmd()
    }

    function buildSilentWrapper(logFileName, innerScript, inhibitReason, unitName, pgidFile) {
        var dir = (typeof main !== "undefined" && main.logDir) ? main.logDir : ""
        var useScope = (typeof main !== "undefined" && Boolean(main.hasSystemdScope))
        return CmdBuilder.buildSilentWrapper(dir, logFileName, innerScript, inhibitReason, unitName || "", useScope, pgidFile || "")
    }

    function buildTerminalCommand(innerCmd, rcFile, unitName, pgidFile) {
        var dir = (typeof main !== "undefined" && main.logDir) ? main.logDir : ""
        var useScope = (typeof main !== "undefined" && Boolean(main.hasSystemdScope))
        return CmdBuilder.buildTerminalCommand({
            innerCmd: innerCmd,
            notCloseCommand: notCloseCommand,
            termCmd: termCmd,
            termNoCloseCmd: termNoCloseCmd,
            termNoCloseSuffix: termNoCloseSuffix,
            errPrompt: i18n("An error occurred during update. Press Enter to close..."),
            logDir: dir,
            rcFile: rcFile || "",
            unitName: unitName || "",
            pgidFile: pgidFile || "",
            useScope: useScope
        })
    }

    function getTerminalAptUpgradeCommand() {
        return CmdBuilder.buildTerminalAptUpgradeCmd({
            useNala: useNala,
            hasNala: plasmoid.configuration.hasNala,
            includePhasedUpdates: includePhasedUpdates
        })
    }

    function getEffectiveUpdateCommand() {
        return CmdBuilder.buildEffectiveUpdateCmd({
            aptCount: (typeof main !== "undefined") ? main.tApt : 0,
            snapCount: (typeof main !== "undefined") ? main.tSnap : 0,
            flatpakCount: (typeof main !== "undefined") ? main.tFlatpak : 0,
            enableSnapUpdates: enableSnapUpdates,
            hasSnap: plasmoid.configuration.hasSnap,
            enableFlatpakUpdates: enableFlatpakUpdates,
            hasFlatpak: plasmoid.configuration.hasFlatpak,
            useNala: useNala,
            hasNala: plasmoid.configuration.hasNala,
            includePhasedUpdates: includePhasedUpdates
        })
    }

    function getEffectiveSilentUpdateCommand(overrideApt, overrideSnap, overrideFlatpak, unitName, logFileName, pgidFile) {
        var opts = {
            aptCount: (typeof main !== "undefined") ? main.tApt : 0,
            snapCount: (typeof main !== "undefined") ? main.tSnap : 0,
            flatpakCount: (typeof main !== "undefined") ? main.tFlatpak : 0,
            enableSnapUpdates: enableSnapUpdates,
            hasSnap: plasmoid.configuration.hasSnap,
            enableFlatpakUpdates: enableFlatpakUpdates,
            hasFlatpak: plasmoid.configuration.hasFlatpak,
            includePhasedUpdates: includePhasedUpdates,
            logDir: (typeof main !== "undefined" && main.logDir) ? main.logDir : "",
            logFileName: logFileName || "aptupdate_last_error_all.log",
            unitName: unitName || "",
            pgidFile: pgidFile || "",
            useScope: (typeof main !== "undefined" && Boolean(main.hasSystemdScope))
        }
        if (typeof overrideApt === "boolean") opts.runApt = overrideApt
        if (typeof overrideSnap === "boolean") opts.runSnap = overrideSnap
        if (typeof overrideFlatpak === "boolean") opts.runFlatpak = overrideFlatpak
        return CmdBuilder.buildEffectiveSilentUpdateCmd(opts)
    }

    function countArch() {
        var c = getCountArchCmd()
        lastCountArchCmd = c
        if (c !== "") runCmd(c, "check", "apt")
    }

    function countSnap() {
        if (!enableSnapUpdates || !plasmoid.configuration.hasSnap) {
            main.tSnap = "0"
            if (typeof cmd !== "undefined") cmd.totalSnap("0")
            main.listSnap = ""
            return
        }
        listSnap()
    }

    function countFlatpak() {
        if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) {
            main.tFlatpak = "0"
            if (typeof cmd !== "undefined") cmd.totalFlatpak("0")
            main.listFlatpak = ""
            return
        }
        listFlatpak()
    }

    function listArch() {
        var c = getListArchCmd()
        lastListArchCmd = c
        if (c !== "") runCmd(c, "check", "apt")
    }

    function listSnap() {
        if (!enableSnapUpdates || !plasmoid.configuration.hasSnap) {
            main.listSnap = ""
            return
        }
        var c = getListSnapCmd()
        lastListSnapCmd = c
        if (c !== "") runCmd(c, "check", "snap")
    }

    function listFlatpak() {
        if (!enableFlatpakUpdates || !plasmoid.configuration.hasFlatpak) {
            main.listFlatpak = ""
            return
        }
        var c = getListFlatpakCmd()
        lastListFlatpakCmd = c
        if (c !== "") runCmd(c, "check", "flatpak")
    }

    function checkReboot() {
        runCmd("test -f /var/run/reboot-required && echo 1 || echo 0", "helper", "reboot-check")
    }

    function checkReleaseUpgrade() {
        if (typeof main !== "undefined" && CmdBuilder.isDebianFamilyNonUbuntu(main.osId, main.osIdLike)) {
            main.releaseUpgradeAvailable = false
            main.releaseUpgradeVersion = ""
            return
        }
        runCmd("test -s /var/lib/ubuntu-release-upgrader/release-upgrade-available && cat /var/lib/ubuntu-release-upgrader/release-upgrade-available 2>/dev/null || true", "helper", "release-check")
    }

    function checkLock() {
        runCmd(CmdBuilder.buildCheckLockCmd(), "helper", "lock")
    }

    function checkConnectivity() {
        runCmd(connectivityCmd, "check", "connectivity")
    }

    function promptReboot() {
        var c = CmdBuilder.buildRebootPromptCmd()
        runCmd(c, "helper", "reboot-prompt")
    }

    function countAll() {
        if (main.isInstalling || main.isOnUpdate || main.isChecking) return
        if (main.startupDelayTimer && main.startupDelayTimer.running) {
            main.startupDelayTimer.stop()
        }
        if (typeof checker !== "undefined" && checker) {
            checker.checkProviders()
        }
        checkLock()
        checkConnectivity()
        countArch()
        checkReboot()
        checkReleaseUpgrade()
    }

    function sendNotify(title, message, icon, urgency) {
        var c = CmdBuilder.buildNotifyCmd(title, message, icon, urgency)
        runCmd(c, "helper", "notify")
    }

    function notifyUpdateBlocked(isAptTarget) {
        if (isAptTarget && main.isPkgManagerBusy) {
            main.lockBlockedUpdate = true
            sendNotify(i18n("Package Manager Busy"), i18n("Another package management process is currently running. Please wait for it to complete."), "dialog-warning", "normal")
        } else if (main.lastCheckOffline || main.connectivityError) {
            sendNotify(i18n("Offline"), i18n("An active internet connection is required to install updates."), "network-offline", "normal")
        } else {
            sendNotify(i18n("Update Unavailable"), i18n("Please wait for the current check or update to finish."), "dialog-warning", "normal")
        }
    }

    function registerJobWithMeta(cmdStr, jobType, repo, pkg, appId, branch, meta) {
        var safeDir = (typeof main !== "undefined" && main.logDir) ? CmdBuilder.resolveSafeLogDir(main.logDir) : ""
        var extra = {
            silent: silentUpdate,
            unitName: meta ? meta.unitName : "",
            pgidFile: (meta && meta.pgidFile) ? meta.pgidFile : "",
            logFile: (silentUpdate && meta && safeDir) ? (safeDir + "/" + meta.logFileName) : "",
            rcFile: (!silentUpdate && notCloseCommand && meta) ? meta.rcFile : ""
        }
        if (main.registerUpdateJob.length >= 7) {
            main.registerUpdateJob(cmdStr, jobType, repo, pkg, appId, branch, extra)
        } else {
            main.registerUpdateJob(cmdStr, jobType, repo, pkg, appId, branch)
        }
    }

    function launchUpdate() {
        if (main.startupDelayTimer && main.startupDelayTimer.running) {
            main.startupDelayTimer.stop()
        }
        if (!main.canUpdateAll()) {
            if (main.hasUpdate()) {
                notifyUpdateBlocked((parseInt(main.tApt, 10) || 0) > 0)
            }
            return
        }
        main.clearPendingRetries()
        main.clearRepoErrors()
        var meta = nextJobMeta("all")
        if (silentUpdate) {
            var silentCmd = getEffectiveSilentUpdateCommand(undefined, undefined, undefined, meta.unitName, meta.logFileName, meta.pgidFile)
            lastUpdateCmd = silentCmd
            registerJobWithMeta(silentCmd, "all", null, "", "", "", meta)
            cmd.exec(silentCmd)
            return
        }
        var effCmd = getEffectiveUpdateCommand()
        if (effCmd !== "") {
            var termFullCmd = buildTerminalCommand(effCmd, meta.rcFile, meta.unitName, meta.pgidFile)
            if (!termFullCmd) {
                sendNotify(i18n("Update Error"), i18n("No terminal command is configured."), "dialog-error", "critical")
                return
            }
            lastUpdateCmd = termFullCmd
            registerJobWithMeta(lastUpdateCmd, "all", null, "", "", "", meta)
            cmd.exec(lastUpdateCmd)
        }
    }

    function launchGroupUpdate(repo) {
        if (main.startupDelayTimer && main.startupDelayTimer.running) {
            main.startupDelayTimer.stop()
        }
        if (repo !== "apt" && repo !== "snap" && repo !== "flatpak") return
        if (!main.canUpdate(repo)) {
            notifyUpdateBlocked(repo === "apt")
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

        var meta = nextJobMeta("group_" + repo)
        if (silentUpdate) {
            var innerScript = ""
            if (repo === "flatpak") {
                innerScript = "flatpak update -y || { fp_rc=$?; echo '[FAILED] flatpak' >> \"$logfile\"; exit $fp_rc; }"
            } else if (repo === "snap") {
                innerScript = CmdBuilder.buildPkexecStep("snap refresh", "snap", 1)
            } else if (repo === "apt") {
                var aptCmd = CmdBuilder.buildSilentAptUpgradeCmd(includePhasedUpdates, "")
                innerScript = CmdBuilder.buildPkexecStep(aptCmd, "apt", 1)
            }
            var silentGroupCmd = buildSilentWrapper(meta.logFileName, innerScript, "Installing " + repo + " updates", meta.unitName, meta.pgidFile)
            lastUpdateCmd = silentGroupCmd
            registerJobWithMeta(silentGroupCmd, "group", repo, "", "", "", meta)
            cmd.exec(silentGroupCmd)
            return
        }

        var termFullCmd = buildTerminalCommand(cmdToRun, meta.rcFile, meta.unitName, meta.pgidFile)
        if (!termFullCmd) {
            sendNotify(i18n("Update Error"), i18n("No terminal command is configured."), "dialog-error", "critical")
            return
        }
        lastUpdateCmd = termFullCmd
        registerJobWithMeta(lastUpdateCmd, "group", repo, "", "", "", meta)
        cmd.exec(lastUpdateCmd)
    }

    function launchOneUpdate(packageName, repo, appId, branch) {
        if (main.startupDelayTimer && main.startupDelayTimer.running) {
            main.startupDelayTimer.stop()
        }
        if (!packageName && !appId) return
        if (!main.canUpdatePackage(repo, packageName, appId)) {
            notifyUpdateBlocked(repo === "apt")
            return
        }
        main.clearPendingRetries()

        var targetRepo = (repo === "flatpak" || repo === "snap") ? repo : "apt"
        var safePackageName = ""
        if (targetRepo === "flatpak") {
            safePackageName = CmdBuilder.buildFlatpakTarget(appId || packageName, branch)
        } else {
            var targetName = (targetRepo === "flatpak" && appId && appId.trim() !== "") ? appId.trim() : packageName
            safePackageName = CmdBuilder.sanitizePackageToken(targetName)
        }
        if (!safePackageName) return

        var meta = nextJobMeta("one_" + targetRepo)
        if (silentUpdate) {
            var innerScript = ""
            if (targetRepo === "flatpak") {
                if (!plasmoid.configuration.hasFlatpak) {
                    sendNotify(i18n("Update Error"), i18n("Flatpak is not installed on this system."), "dialog-error", "critical")
                    return
                }
                innerScript = "flatpak update -y -- " + safePackageName + " || { fp_rc=$?; echo '[FAILED] flatpak' >> \"$logfile\"; exit $fp_rc; }"
            } else if (targetRepo === "snap") {
                if (!plasmoid.configuration.hasSnap) {
                    sendNotify(i18n("Update Error"), i18n("Snap is not installed on this system."), "dialog-error", "critical")
                    return
                }
                innerScript = CmdBuilder.buildPkexecStep("snap refresh -- " + safePackageName, "snap", 1)
            } else {
                var aptCmd = CmdBuilder.buildSilentAptUpgradeCmd(includePhasedUpdates, safePackageName)
                innerScript = CmdBuilder.buildPkexecStep(aptCmd, "apt", 1)
            }
            var silentSingleCmd = buildSilentWrapper(meta.logFileName, innerScript, "Installing " + safePackageName, meta.unitName, meta.pgidFile)
            lastUpdateCmd = silentSingleCmd
            registerJobWithMeta(silentSingleCmd, "single", targetRepo, packageName, appId, branch || "", meta)
            cmd.exec(silentSingleCmd)
            return
        }

        var cmdToRun = ""
        if (targetRepo === "snap") {
            if (!plasmoid.configuration.hasSnap) {
                sendNotify(i18n("Update Error"), i18n("Snap is not installed on this system."), "dialog-error", "critical")
                return
            }
            cmdToRun = "sudo snap refresh -- " + safePackageName
        } else if (targetRepo === "flatpak") {
            if (!plasmoid.configuration.hasFlatpak) {
                sendNotify(i18n("Update Error"), i18n("Flatpak is not installed on this system."), "dialog-error", "critical")
                return
            }
            cmdToRun = "flatpak update -y -- " + safePackageName
        } else {
            cmdToRun = CmdBuilder.buildTerminalSingleAptCmd({
                updateCommandOne: updateCommandOne,
                useNala: useNala,
                hasNala: plasmoid.configuration.hasNala,
                includePhasedUpdates: includePhasedUpdates
            }, safePackageName)
        }

        var termFullCmd = buildTerminalCommand(cmdToRun, meta.rcFile, meta.unitName, meta.pgidFile)
        if (!termFullCmd) {
            sendNotify(i18n("Update Error"), i18n("No terminal command is configured."), "dialog-error", "critical")
            return
        }
        lastUpdateCmd = termFullCmd
        registerJobWithMeta(lastUpdateCmd, "single", targetRepo, packageName, appId, branch || "", meta)
        cmd.exec(lastUpdateCmd)
    }
}
