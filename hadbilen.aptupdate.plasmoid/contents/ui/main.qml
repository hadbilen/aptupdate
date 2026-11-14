import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

import "../service" as Sv
import "../service/CommandBuilder.js" as CmdBuilder

PlasmoidItem {
    id: main

    readonly property alias debugService: debug
    readonly property alias updaterService: updater

    readonly property string cacheDir: {
        var base = StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString().replace(/^file:\/\//, "")
        if (!base) {
            var home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
            base = home ? (home + "/.cache") : ""
        }
        return base ? (base + "/hadbilen.aptupdate.plasmoid") : ""
    }
    readonly property string cacheFilePath: cacheDir ? (cacheDir + "/cache.json") : ""

    readonly property string logDir: {
        var runtime = StandardPaths.writableLocation(StandardPaths.RuntimeLocation).toString().replace(/^file:\/\//, "")
        var candidate = (runtime && runtime.length > 0) ? (runtime + "/aptupdate") : (cacheDir ? (cacheDir + "/logs") : "")
        var safe = CmdBuilder.resolveSafeLogDir(candidate)
        if (safe) return safe
        return cacheDir ? CmdBuilder.resolveSafeLogDir(cacheDir + "/logs") : ""
    }

    property int intervalConfig: plasmoid.configuration.updateInterval
    property int intervalUnitConfig: plasmoid.configuration.updateIntervalUnit !== undefined ? plasmoid.configuration.updateIntervalUnit : 0
    property bool isOnDebug: plasmoid.configuration.debugMode
    property bool isOnUpdate: false
    property bool hasError: false
    property bool updateError: false
    property bool connectivityError: false
    property bool helperError: false
    property string updateErrorMessage: ""
    property string genericUpdateErrorMessage: ""
    property string helperErrorMessage: ""
    property string lastErrorMessage: ""
    property bool isChecking: false
    property bool isInstalling: false
    property bool hasActiveSilentUpdate: false
    property var repoErrors: ({ "apt": false, "snap": false, "flatpak": false })
    property var checkErrors: ({ "apt": false, "snap": false, "flatpak": false })
    property var checkErrorMessages: ({ "apt": "", "snap": "", "flatpak": "" })
    property var updateErrors: ({ "apt": false, "snap": false, "flatpak": false })
    property var updateErrorMessages: ({ "apt": "", "snap": "", "flatpak": "" })
    property bool isPkgManagerBusy: false
    property bool lockBlockedUpdate: false

    property string osId: ""
    property string osIdLike: ""
    property bool hasSystemdScope: false
    property bool aptIndexStale: false
    property int aptIndexAgeDays: 0
    property bool lastCheckOffline: false
    property string lastCheckIso: ""

    property bool dismissedRebootMsg: false
    property bool dismissedReleaseUpgradeMsg: false
    property bool dismissedBusyLockMsg: false

    onIsPkgManagerBusyChanged: {
        if (!isPkgManagerBusy) {
            main.lockBlockedUpdate = false
            main.dismissedBusyLockMsg = false
        }
    }

    onRebootRequiredChanged: {
        if (!rebootRequired) {
            main.dismissedRebootMsg = false
        }
    }

    onReleaseUpgradeAvailableChanged: {
        if (!releaseUpgradeAvailable) {
            main.dismissedReleaseUpgradeMsg = false
        }
    }

    function recomputeErrorState() {
        var union = {
            "apt": Boolean(main.checkErrors["apt"] || main.updateErrors["apt"]),
            "snap": Boolean(main.checkErrors["snap"] || main.updateErrors["snap"]),
            "flatpak": Boolean(main.checkErrors["flatpak"] || main.updateErrors["flatpak"])
        }
        main.repoErrors = union
        var anyRepoUpdateErr = Boolean(main.updateErrors["apt"] || main.updateErrors["snap"] || main.updateErrors["flatpak"])
        var upMsgs = []
        if (main.genericUpdateErrorMessage) upMsgs.push(main.genericUpdateErrorMessage)
        var repos = ["apt", "snap", "flatpak"]
        for (var i = 0; i < repos.length; i++) {
            var r = repos[i]
            if (main.updateErrorMessages[r] && upMsgs.indexOf(main.updateErrorMessages[r]) === -1) {
                upMsgs.push(main.updateErrorMessages[r])
            }
        }
        main.updateErrorMessage = upMsgs.join("\n")
        main.updateError = Boolean(anyRepoUpdateErr || main.genericUpdateErrorMessage !== "")

        var anyRepoErr = Boolean(union["apt"] || union["snap"] || union["flatpak"])
        main.hasError = Boolean(anyRepoErr || main.updateError || main.connectivityError || main.helperError)

        var msgs = []
        if (main.helperErrorMessage) msgs.push(main.helperErrorMessage)
        if (main.updateErrorMessage) msgs.push(main.updateErrorMessage)
        if (main.checkErrorMessages["apt"]) msgs.push("APT: " + main.checkErrorMessages["apt"])
        if (main.checkErrorMessages["snap"]) msgs.push("Snap: " + main.checkErrorMessages["snap"])
        if (main.checkErrorMessages["flatpak"]) msgs.push("Flatpak: " + main.checkErrorMessages["flatpak"])
        if (main.connectivityError && msgs.length === 0) msgs.push(i18n("Connectivity check timed out or failed."))
        main.lastErrorMessage = msgs.join("\n")

        cmd.errorStatus(main.hasError)
    }

    function setCheckError(repo, err, errMsg) {
        if (!repo || (repo !== "apt" && repo !== "snap" && repo !== "flatpak")) return
        var cCopy = Object.assign({}, main.checkErrors)
        var mCopy = Object.assign({}, main.checkErrorMessages)
        cCopy[repo] = Boolean(err)
        mCopy[repo] = (err && errMsg) ? String(errMsg) : ""
        main.checkErrors = cCopy
        main.checkErrorMessages = mCopy
        main.recomputeErrorState()
    }

    function setRepoError(repo, err, errMsg) {
        setCheckError(repo, err, errMsg)
    }

    function setUpdateErrorState(err, errMsg, failedRepos) {
        var uCopy = Object.assign({}, main.updateErrors)
        var mCopy = Object.assign({}, main.updateErrorMessages)
        var msgStr = errMsg ? String(errMsg) : ""
        var hasList = Boolean(failedRepos && failedRepos.length > 0)

        if (!err) {
            if (hasList) {
                for (var i = 0; i < failedRepos.length; i++) {
                    var cr = String(failedRepos[i]).toLowerCase()
                    if (cr === "apt" || cr === "snap" || cr === "flatpak") {
                        uCopy[cr] = false
                        mCopy[cr] = ""
                    }
                }
            } else {
                uCopy = { "apt": false, "snap": false, "flatpak": false }
                mCopy = { "apt": "", "snap": "", "flatpak": "" }
                main.genericUpdateErrorMessage = ""
            }
        } else if (hasList) {
            for (var j = 0; j < failedRepos.length; j++) {
                var rr = String(failedRepos[j]).toLowerCase()
                if (rr === "apt" || rr === "snap" || rr === "flatpak") {
                    uCopy[rr] = true
                    mCopy[rr] = msgStr
                }
            }
        } else {
            main.genericUpdateErrorMessage = msgStr
        }
        main.updateErrors = uCopy
        main.updateErrorMessages = mCopy
        main.recomputeErrorState()
    }

    function setHelperError(err, errMsg) {
        main.helperError = Boolean(err)
        main.helperErrorMessage = (err && errMsg) ? String(errMsg) : ""
        main.recomputeErrorState()
    }

    function clearRepoErrors() {
        main.checkErrors = { "apt": false, "snap": false, "flatpak": false }
        main.checkErrorMessages = { "apt": "", "snap": "", "flatpak": "" }
        main.updateErrors = { "apt": false, "snap": false, "flatpak": false }
        main.updateErrorMessages = { "apt": "", "snap": "", "flatpak": "" }
        main.genericUpdateErrorMessage = ""
        main.repoErrors = { "apt": false, "snap": false, "flatpak": false }
        main.updateError = false
        main.updateErrorMessage = ""
        main.connectivityError = false
        main.helperError = false
        main.helperErrorMessage = ""
        main.lastErrorMessage = ""
        main.hasError = false
        cmd.errorStatus(false)
    }

    function clearCheckErrorsOnly() {
        main.checkErrors = { "apt": false, "snap": false, "flatpak": false }
        main.checkErrorMessages = { "apt": "", "snap": "", "flatpak": "" }
        main.connectivityError = false
        main.recomputeErrorState()
    }

    function clearPendingRetries() {
        retryTimer.stop()
        retryTimer.pendingJobs = []
        main.retryCounts = ({})
    }

    function getCmdRepo(sourceCmd) {
        if (!sourceCmd) return ""
        var reg = main.activeJobsRegistry[sourceCmd]
        if (reg && (reg.repo === "apt" || reg.repo === "snap" || reg.repo === "flatpak")) {
            return reg.repo
        }
        if ((updater.lastCountArchCmd !== "" && sourceCmd === updater.lastCountArchCmd) ||
            (updater.lastListArchCmd !== "" && sourceCmd === updater.lastListArchCmd)) {
            return "apt"
        }
        if (updater.lastListSnapCmd !== "" && sourceCmd === updater.lastListSnapCmd) {
            return "snap"
        }
        if (updater.lastListFlatpakCmd !== "" && sourceCmd === updater.lastListFlatpakCmd) {
            return "flatpak"
        }
        return ""
    }

    function abortUpdate(isTimeout) {
        if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - aborting update operations", true)
        var units = []
        var pgidFiles = []
        var tempFiles = []
        for (var k in main.activeJobsRegistry) {
            var entry = main.activeJobsRegistry[k]
            if (entry) {
                if (entry.unitName && units.indexOf(entry.unitName) === -1) {
                    units.push(entry.unitName)
                }
                if (entry.pgidFile && pgidFiles.indexOf(entry.pgidFile) === -1) {
                    pgidFiles.push(entry.pgidFile)
                }
                if (entry.logFile && tempFiles.indexOf(entry.logFile) === -1) {
                    tempFiles.push(entry.logFile)
                }
                if (entry.rcFile && tempFiles.indexOf(entry.rcFile) === -1) {
                    tempFiles.push(entry.rcFile)
                }
            }
        }
        const sources = [].concat(cmd.connectedSources)
        for (let i = 0; i < sources.length; i++) {
            cmd.disconnectSource(sources[i])
        }
        main.isUpdatingAll = false
        main.updatingRepos = { "apt": false, "snap": false, "flatpak": false }
        main.updatingPackages = ({})
        main.activeUpdateJobs = ({})
        main.activeJobsRegistry = ({})
        main.connectivityProbePending = false
        main.providerProbePending = { "snap": false, "flatpak": false }
        main.countAllSnapArmed = false
        main.countAllFlatpakArmed = false
        main.updateAggregateStates()
        main.activeJobSources = ({})
        main.activeCheckSources = ({})
        main.activeJobs = 0
        main.activeCheckJobs = 0
        main.isChecking = false
        main.clearPendingRetries()
        cmd.isUpdating(false)
        cmd.checkingStatus(false)
        if (units.length > 0) {
            var stopParts = []
            for (var u = 0; u < units.length; u++) {
                stopParts.push("'" + CmdBuilder.bashEscape(units[u] + ".scope") + "'")
            }
            var stopCmd = "systemctl --user stop --no-block " + stopParts.join(" ") + " 2>/dev/null || true"
            execTaggedJob(stopCmd, "helper", "scope-stop")
        }
        if (pgidFiles.length > 0) {
            var killPgidCmd = CmdBuilder.buildSafeKillPgidAndRemoveCmd(pgidFiles)
            if (killPgidCmd) execTaggedJob(killPgidCmd, "helper", "pgid-stop")
        }
        for (var tf = 0; tf < tempFiles.length; tf++) {
            execTaggedJob(CmdBuilder.buildSafeRemoveCmd(tempFiles[tf]), "helper", "abort-clean")
        }
        if (isTimeout === true) {
            main.setUpdateErrorState(true, i18n("Background update timed out after 10 minutes."))
        }
        updater.checkLock()
        sendNotify(i18n("Update Aborted"), i18n("Update operation timed out or was cancelled."), "dialog-warning", isTimeout === true ? "critical" : "normal")
    }

    property bool isInitialized: false
    property var activeJobsRegistry: ({})
    property var activeJobSources: ({})
    property var activeCheckSources: ({})
    property int activeJobs: 0
    property int activeCheckJobs: 0
    property var providerProbePending: ({ "snap": false, "flatpak": false })
    property bool connectivityProbePending: false
    property bool countAllSnapArmed: false
    property bool countAllFlatpakArmed: false

    function execTaggedJob(cmdStr, role, repo, extra) {
        if (!cmdStr) return
        var reg = Object.assign({}, main.activeJobsRegistry)
        reg[cmdStr] = {
            role: role || "check",
            repo: repo || "",
            targetRepo: (extra && extra.targetRepo) ? extra.targetRepo : "",
            silent: false,
            unitName: "",
            pgidFile: "",
            logFile: "",
            rcFile: ""
        }
        main.activeJobsRegistry = reg
        cmd.exec(cmdStr)
    }

    function trackJobConnected(source, isCheckJob) {
        if (!source) return
        if (!main.activeJobSources[source]) {
            var jobs = Object.assign({}, main.activeJobSources)
            jobs[source] = true
            main.activeJobSources = jobs
            main.activeJobs = Object.keys(jobs).length
        }
        if (isCheckJob && !main.activeCheckSources[source]) {
            var checks = Object.assign({}, main.activeCheckSources)
            checks[source] = true
            main.activeCheckSources = checks
            main.activeCheckJobs = Object.keys(checks).length
        }
    }

    function trackJobFinished(source) {
        if (!source) return
        if (main.activeJobSources[source]) {
            var jobs = Object.assign({}, main.activeJobSources)
            delete jobs[source]
            main.activeJobSources = jobs
            main.activeJobs = Object.keys(jobs).length
        }
        if (main.activeCheckSources[source]) {
            var checks = Object.assign({}, main.activeCheckSources)
            delete checks[source]
            main.activeCheckSources = checks
            main.activeCheckJobs = Object.keys(checks).length
        }
    }

    property string tApt: "0"
    property string tSnap: "0"
    property string tFlatpak: "0"
    property string listSnap: ""
    property string listFlatpak: ""
    property string listApt: ""
    property bool rebootRequired: false
    property bool previousRebootRequired: false
    property bool releaseUpgradeAvailable: false
    property string releaseUpgradeVersion: ""
    property bool lastNotifiedReleaseUpgrade: false

    property bool hasSnapRuntime: plasmoid.configuration.hasSnap
    property bool hasFlatpakRuntime: plasmoid.configuration.hasFlatpak
    property bool hasNalaRuntime: plasmoid.configuration.hasNala
    readonly property bool hasSnap: hasSnapRuntime
    readonly property bool hasFlatpak: hasFlatpakRuntime
    readonly property bool hasNala: hasNalaRuntime
    property bool enableSnapUpdates: plasmoid.configuration.enableSnapUpdates
    property bool enableFlatpakUpdates: plasmoid.configuration.enableFlatpakUpdates

    function setProviderAvailability(provider, val) {
        var b = Boolean(val)
        if (provider === "snap") main.hasSnapRuntime = b
        else if (provider === "flatpak") main.hasFlatpakRuntime = b
        else if (provider === "nala") main.hasNalaRuntime = b
    }

    onEnableSnapUpdatesChanged: {
        if (!main.isInitialized) return
        if (!enableSnapUpdates) {
            main.tSnap = "0"
            main.listSnap = ""
            main.setCheckError("snap", false)
            cmd.totalSnap("0")
        } else if (main.hasSnap && !main.isInstalling && !main.isOnUpdate && !main.isChecking) {
            updater.countSnap()
        }
    }

    onEnableFlatpakUpdatesChanged: {
        if (!main.isInitialized) return
        if (!enableFlatpakUpdates) {
            main.tFlatpak = "0"
            main.listFlatpak = ""
            main.setCheckError("flatpak", false)
            cmd.totalFlatpak("0")
        } else if (main.hasFlatpak && !main.isInstalling && !main.isOnUpdate && !main.isChecking) {
            updater.countFlatpak()
        }
    }

    property int startupCheckMode: plasmoid.configuration.startupCheckMode !== undefined ? plasmoid.configuration.startupCheckMode : 2
    property int startupDelaySeconds: plasmoid.configuration.startupDelaySeconds !== undefined ? plasmoid.configuration.startupDelaySeconds : 30
    property string lastCheckTime: ""
    property bool hasCheckedOnce: false
    property bool hasScannedThisSession: false
    readonly property bool isStartupDelaying: startupDelayTimer.running
    readonly property alias startupDelayTimer: startupDelayTimer
    readonly property bool isRetrying: retryTimer.running || retryTimer.pendingJobs.length > 0
    property int previousTotal: -1
    property int lastNotifiedTotal: 0
    property bool lastNotifiedHasSecurity: false
    property var retryCounts: ({})
    property bool pendingAutoCheck: false
    property bool isPrewarmed: false
    property var updatingRepos: ({ "apt": false, "snap": false, "flatpak": false })
    property var updatingPackages: ({})
    property bool isUpdatingAll: false
    property var activeUpdateJobs: ({})

    function isRepoBusy(repo) {
        if (!repo) return false
        if (main.isUpdatingAll) return true
        if (Boolean(main.updatingRepos[repo])) return true
        for (let key in main.updatingPackages) {
            if (main.updatingPackages[key] && key.startsWith(repo + ":")) {
                return true
            }
        }
        return false
    }

    function isPackageBusy(repo, name, appId) {
        if (!repo) return false
        if (main.isUpdatingAll) return true
        if (Boolean(main.updatingRepos[repo])) return true
        const key1 = repo + ":" + (name || "")
        const key2 = appId ? (repo + ":" + appId) : ""
        return Boolean((key1 && main.updatingPackages[key1]) || (key2 && main.updatingPackages[key2]))
    }

    function canUpdate(repo) {
        if (main.isChecking || main.isUpdatingAll) return false
        if (main.lastCheckOffline || main.connectivityError) return false
        if (isRepoBusy(repo)) return false
        if (repo === "apt" && main.isPkgManagerBusy) return false
        return true
    }

    function canUpdatePackage(repo, name, appId) {
        if (main.isChecking || main.isUpdatingAll) return false
        if (main.lastCheckOffline || main.connectivityError) return false
        if (isPackageBusy(repo, name, appId)) return false
        if (repo === "apt" && main.isPkgManagerBusy) return false
        return true
    }

    function canUpdateAll() {
        if (main.isChecking) return false
        if (main.lastCheckOffline || main.connectivityError) return false
        if (!main.hasUpdate()) return false
        if (main.isUpdatingAll || main.isInstalling || main.isOnUpdate) return false
        if (main.isPkgManagerBusy && (parseInt(main.tApt, 10) || 0) > 0) return false
        return true
    }

    function setRepoUpdating(repo, isUpdating) {
        var copy = Object.assign({}, main.updatingRepos)
        copy[repo] = isUpdating
        main.updatingRepos = copy
        main.updateAggregateStates()
    }

    function setPackageUpdating(repo, name, appId, isUpdating) {
        var copy = Object.assign({}, main.updatingPackages)
        var key1 = repo + ":" + (name || "")
        var key2 = appId ? (repo + ":" + appId) : ""
        if (isUpdating) {
            if (key1) copy[key1] = true
            if (key2) copy[key2] = true
        } else {
            if (key1) delete copy[key1]
            if (key2) delete copy[key2]
        }
        main.updatingPackages = copy
        main.updateAggregateStates()
    }

    function updateAggregateStates() {
        var hasRepo = Boolean(main.updatingRepos["apt"] || main.updatingRepos["snap"] || main.updatingRepos["flatpak"])
        var hasPkg = Object.keys(main.updatingPackages).length > 0
        var busy = main.isUpdatingAll || hasRepo || hasPkg
        var anySilent = false
        for (var k in main.activeUpdateJobs) {
            if (main.activeUpdateJobs[k] && main.activeUpdateJobs[k].silent) {
                anySilent = true
                break
            }
        }
        main.hasActiveSilentUpdate = busy && anySilent
        main.isInstalling = busy
        main.isOnUpdate = busy
        cmd.updateRunning(busy)
    }

    function registerUpdateJob(sourceCmd, type, repo, name, appId, branch, extra) {
        if (!sourceCmd) return
        var info = {
            role: "update",
            type: type,
            repo: repo,
            name: name || "",
            appId: appId || "",
            branch: branch || "",
            silent: Boolean(extra && extra.silent),
            unitName: (extra && extra.unitName) ? extra.unitName : "",
            pgidFile: (extra && extra.pgidFile) ? extra.pgidFile : "",
            logFile: (extra && extra.logFile) ? extra.logFile : "",
            rcFile: (extra && extra.rcFile) ? extra.rcFile : ""
        }
        var jobs = Object.assign({}, main.activeUpdateJobs)
        jobs[sourceCmd] = info
        main.activeUpdateJobs = jobs

        var reg = Object.assign({}, main.activeJobsRegistry)
        reg[sourceCmd] = info
        main.activeJobsRegistry = reg

        if (type === "all") {
            main.isUpdatingAll = true
            main.setRepoUpdating("apt", true)
            main.setRepoUpdating("snap", true)
            main.setRepoUpdating("flatpak", true)
        } else if (type === "group") {
            main.setRepoUpdating(repo, true)
        } else if (type === "single") {
            main.setPackageUpdating(repo, name, appId, true)
        }
    }

    function isHelperCommand(source) {
        if (!source) return true
        var reg = main.activeJobsRegistry[source]
        if (reg && (reg.role === "helper" || reg.role === "probe")) return true
        if (reg && (reg.role === "check" || reg.role === "update")) return false
        if (source.indexOf("lock-frontend") !== -1) return true
        if (source.indexOf("do-release-upgrade") !== -1) return true
        if (source.indexOf("org.kde.LogoutPrompt") !== -1) return true
        if (source.indexOf("org.freedesktop.Notifications") !== -1) return true
        if (source.indexOf("systemctl --user stop") !== -1) return true
        if (source.startsWith("command -v ")) return true
        if (source.startsWith("notify-send ")) return true
        if (source.startsWith("kdialog ")) return true
        if (source.startsWith("test -f /var/run/reboot-required")) return true
        if (source.startsWith("test -s /var/lib/ubuntu-release-upgrader")) return true
        return false
    }

    function handleSilentUpdateError(output, failedReposHint) {
        var classified = CmdBuilder.classifySilentLog(output)
        if (classified.status === "cancelled") {
            if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - update cancelled by user", false)
            main.setUpdateErrorState(false, "", (failedReposHint && failedReposHint.length > 0) ? failedReposHint : undefined)
            return
        }

        if (classified.status === "pkexec_failed") {
            var pkMsg = i18n("Authorization or elevation helper failed (pkexec exit code %1).", classified.code)
            var pkRepos = (classified.failedRepos && classified.failedRepos.length > 0) ? classified.failedRepos : []
            if (pkRepos.length > 0) {
                pkMsg += "\n" + i18n("Update failed for: %1", pkRepos.join(", "))
            }
            main.setUpdateErrorState(true, pkMsg, pkRepos)
            if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - " + pkMsg, true)
            sendNotify(i18n("Update Failed"), pkMsg, "dialog-error", "critical")
            return
        }

        var failed = classified.failedRepos
        if (failed.length === 0 && failedReposHint && failedReposHint.length > 0) {
            failed = failedReposHint
        }
        var msg = (failed.length > 0)
            ? i18n("Update failed for: %1", failed.join(", "))
            : i18n("An error occurred during the background update.")

        main.setUpdateErrorState(true, msg, failed)
        if (main.isOnDebug) {
            debug.log("APTUPDATE - " + plasmoid.id + " - silent update error details: " + (failed.length > 0 ? failed.join(", ") : classified.raw || "unknown error"), true)
        }
        sendNotify(i18n("Update Failed"), msg, "dialog-error", "critical")
    }

    property string pendingCacheWriteJson: ""
    property bool cacheWriting: false

    function formatLastCheckDisplay(isoStr, nowDate) {
        const parsedDate = CmdBuilder.parseIsoDate(isoStr)
        if (!parsedDate) {
            return String(isoStr || "")
        }
        const refDate = (nowDate instanceof Date && !isNaN(nowDate.getTime())) ? nowDate : new Date()
        const dayDiff = CmdBuilder.localCalendarDayDiff(parsedDate, refDate)
        const timeStr = Qt.formatTime(parsedDate, Qt.DefaultLocaleShortDate)
        if (dayDiff === 0) {
            return i18n("Today %1", timeStr)
        }
        if (dayDiff === 1) {
            return i18n("Yesterday %1", timeStr)
        }
        return Qt.formatDateTime(parsedDate, Qt.DefaultLocaleShortDate)
    }

    function refreshLastCheckTime(nowDate) {
        if (!main.lastCheckIso) return
        main.lastCheckTime = main.formatLastCheckDisplay(main.lastCheckIso, nowDate)
    }

    function applyLoadedCache(rawJson) {
        if (main.hasScannedThisSession || main.isChecking) return
        var text = String(rawJson || "").trim()
        if (!text) return
        try {
            var data = JSON.parse(text)
            if (!data || typeof data !== "object") return
            var snapEnabled = Boolean(plasmoid.configuration.enableSnapUpdates && main.hasSnap)
            var flatpakEnabled = Boolean(plasmoid.configuration.enableFlatpakUpdates && main.hasFlatpak)

            main.tApt = (data.tApt !== undefined && /^\d+$/.test(String(data.tApt))) ? String(data.tApt) : "0"
            main.tSnap = (snapEnabled && data.tSnap !== undefined && /^\d+$/.test(String(data.tSnap))) ? String(data.tSnap) : "0"
            main.tFlatpak = (flatpakEnabled && data.tFlatpak !== undefined && /^\d+$/.test(String(data.tFlatpak))) ? String(data.tFlatpak) : "0"
            main.listApt = String(data.listApt || "")
            main.listSnap = snapEnabled ? String(data.listSnap || "") : ""
            main.listFlatpak = flatpakEnabled ? String(data.listFlatpak || "") : ""
            main.lastCheckIso = String(data.lastCheckIso || "")
            main.lastCheckOffline = Boolean(data.lastCheckOffline)
            if (main.lastCheckIso) {
                main.refreshLastCheckTime()
                main.hasCheckedOnce = !main.lastCheckOffline
            }
            if (main.startupCheckMode !== 1 && main.startupCheckMode !== 2) {
                const cachedTotal = (parseInt(main.tApt, 10) || 0) +
                    (snapEnabled ? (parseInt(main.tSnap, 10) || 0) : 0) +
                    (flatpakEnabled ? (parseInt(main.tFlatpak, 10) || 0) : 0)
                main.previousTotal = cachedTotal
            }
            cmd.totalApt(main.tApt)
            cmd.totalSnap(main.tSnap)
            cmd.totalFlatpak(main.tFlatpak)
        } catch (e) {
            if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - ignoring invalid cache.json: " + e, true)
        }
    }

    function loadCache() {
        if (!main.cacheFilePath) return
        var inner = "f='" + CmdBuilder.bashEscape(main.cacheFilePath) + "'; if [ -f \"$f\" ] && [ ! -L \"$f\" ] && [ -O \"$f\" ]; then cat \"$f\" 2>/dev/null || true; fi"
        var readCmd = "bash -c '" + CmdBuilder.bashEscape(inner) + "'"
        cacheSource.pendingOps[readCmd] = "read"
        cacheSource.connectSource(readCmd)
    }

    function flushCacheWrite() {
        if (main.cacheWriting || !main.pendingCacheWriteJson) return
        if (!main.cacheDir || !main.cacheFilePath) {
            main.pendingCacheWriteJson = ""
            return
        }
        var payloadJson = main.pendingCacheWriteJson
        main.pendingCacheWriteJson = ""
        var safeDir = CmdBuilder.bashEscape(main.cacheDir)
        var safeFile = CmdBuilder.bashEscape(main.cacheFilePath)
        var safePayload = CmdBuilder.bashEscape(payloadJson)
        var writeScript =
            "umask 077; cachedir='" + safeDir + "'; cachefile='" + safeFile + "'; " +
            "mkdir -p -m 0700 \"$cachedir\" 2>/dev/null || exit 1; " +
            "if ! test -d \"$cachedir\" || ! test -O \"$cachedir\" || test -L \"$cachedir\"; then exit 1; fi; " +
            "chmod 0700 \"$cachedir\" 2>/dev/null || true; " +
            "tmpfile=\"$(mktemp \"$cachedir/cache.XXXXXX\")\" || exit 1; " +
            "printf '%s' '" + safePayload + "' > \"$tmpfile\" && chmod 0600 \"$tmpfile\" && mv -f \"$tmpfile\" \"$cachefile\" || { rm -f \"$tmpfile\"; exit 1; }"
        var writeCmd = "bash -c '" + CmdBuilder.bashEscape(writeScript) + "'"
        main.cacheWriting = true
        cacheSource.pendingOps[writeCmd] = "write"
        cacheSource.connectSource(writeCmd)
    }

    function saveCache() {
        if (main.lastCheckOffline || !updater.isConnected) {
            return
        }
        const snapEnabled = Boolean(main.enableSnapUpdates && main.hasSnap)
        const flatpakEnabled = Boolean(main.enableFlatpakUpdates && main.hasFlatpak)
        const now = new Date()
        const isoStr = now.toISOString()

        main.lastCheckIso = isoStr
        main.refreshLastCheckTime(now)
        main.hasCheckedOnce = true
        main.hasScannedThisSession = true

        var payload = {
            tApt: main.tApt,
            tSnap: snapEnabled ? main.tSnap : "0",
            tFlatpak: flatpakEnabled ? main.tFlatpak : "0",
            listApt: main.listApt || "",
            listSnap: snapEnabled ? (main.listSnap || "") : "",
            listFlatpak: flatpakEnabled ? (main.listFlatpak || "") : "",
            lastCheckIso: isoStr,
            lastCheckOffline: false
        }
        main.pendingCacheWriteJson = JSON.stringify(payload)
        flushCacheWrite()
    }

    Plasma5Support.DataSource {
        id: cacheSource
        engine: "executable"
        connectedSources: []
        property var pendingOps: ({})
        onNewData: (sourceName, data) => {
            if (!data || data["exit code"] === undefined) return
            var op = pendingOps[sourceName] || ""
            delete pendingOps[sourceName]
            var exitCode = data["exit code"]
            var stdout = data["stdout"] || ""
            disconnectSource(sourceName)
            if (op === "read" && exitCode === 0 && stdout) {
                main.applyLoadedCache(stdout)
            } else if (op === "write") {
                main.cacheWriting = false
                if (exitCode !== 0) {
                    console.warn("APTUPDATE cache.json write failed (exit " + exitCode + ")")
                }
                if (main.pendingCacheWriteJson) {
                    main.flushCacheWrite()
                }
            }
        }
    }

    function refreshAll(preserveUpdateErrors) {
        if (main.isInstalling || main.isOnUpdate || main.isChecking) {
            if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - refreshAll skipped, check or update currently in progress", false)
            return
        }
        if (preserveUpdateErrors) {
            main.clearCheckErrorsOnly()
        } else {
            main.clearRepoErrors()
        }
        main.lockBlockedUpdate = false
        main.pendingAutoCheck = false
        main.clearPendingRetries()
        if (startupDelayTimer.running) {
            startupDelayTimer.stop()
        }
        main.providerProbePending = { "snap": true, "flatpak": true }
        main.connectivityProbePending = true
        main.countAllSnapArmed = true
        main.countAllFlatpakArmed = true
        updater.countAll()
    }

    function triggerAutoCheck() {
        if (main.expanded) {
            if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - popup is expanded, deferring auto-check", false)
            main.pendingAutoCheck = true
            return
        }
        main.refreshAll(true)
    }

    function sendNotify(title, message, icon, urgency) {
        updater.sendNotify(title, message, icon, urgency)
    }

    function checkNotification() {
        const res = CmdBuilder.evaluateNotification({
            notifyOnUpdates: plasmoid.configuration.notifyOnUpdates,
            busy: (main.activeJobs > 0 || main.isChecking || main.isInstalling || main.isOnUpdate),
            expanded: main.expanded,
            numApt: main.tApt,
            numSnap: main.tSnap,
            numFlatpak: main.tFlatpak,
            enableSnap: main.enableSnapUpdates,
            hasSnap: main.hasSnap,
            enableFlatpak: main.enableFlatpakUpdates,
            hasFlatpak: main.hasFlatpak,
            threshold: plasmoid.configuration.notificationThreshold !== undefined ? plasmoid.configuration.notificationThreshold : 1,
            previousTotal: main.previousTotal,
            lastNotifiedTotal: main.lastNotifiedTotal,
            lastNotifiedHasSecurity: main.lastNotifiedHasSecurity,
            notifyOnStartup: plasmoid.configuration.notifyOnStartup,
            listApt: main.listApt
        })

        if (res.action === "skip") return
        if (res.action === "expanded_suppress") {
            if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - popup is expanded, suppressing notification", false)
            return
        }
        if (res.action === "reset" || res.action === "below_threshold") {
            main.lastNotifiedTotal = res.lastNotifiedTotal
            main.lastNotifiedHasSecurity = res.lastNotifiedHasSecurity
            main.previousTotal = res.previousTotal
            return
        }

        if (res.shouldNotify) {
            const numApt = parseInt(main.tApt, 10) || 0
            const numSnap = (main.enableSnapUpdates && main.hasSnap) ? (parseInt(main.tSnap, 10) || 0) : 0
            const numFlatpak = (main.enableFlatpakUpdates && main.hasFlatpak) ? (parseInt(main.tFlatpak, 10) || 0) : 0
            const parts = []
            if (numApt > 0) parts.push(numApt + " APT")
            if (numSnap > 0) parts.push(numSnap + " Snap")
            if (numFlatpak > 0) parts.push(numFlatpak + " Flatpak")

            let msg = ""
            if (parts.length > 0) {
                const breakdown = parts.join(", ")
                msg = i18np("%1 update available: %2", "%1 updates available: %2", res.currentTotal, breakdown)
            } else {
                msg = i18np("%1 update available", "%1 updates available", res.currentTotal)
            }

            if (res.isCritical) {
                sendNotify(i18n("Critical System Updates"), msg, "security-high", "critical")
            } else {
                sendNotify(i18n("System Updates"), msg, "system-software-update", "normal")
            }
        }

        main.lastNotifiedTotal = res.lastNotifiedTotal
        main.lastNotifiedHasSecurity = res.lastNotifiedHasSecurity
        main.previousTotal = res.previousTotal
    }

    Timer {
        id: notifyDebounceTimer
        interval: 500
        repeat: false
        onTriggered: checkNotification()
    }

    Timer {
        id: retryTimer
        interval: 5000
        repeat: false
        property var pendingJobs: []
        onTriggered: {
            const queue = [].concat(pendingJobs)
            pendingJobs = []
            if (main.isInstalling || main.isOnUpdate) {
                for (let j = 0; j < queue.length; j++) {
                    if (queue[j]) {
                        if (queue[j].cmd) delete main.retryCounts[queue[j].cmd]
                        if (queue[j].repo) {
                            main.setCheckError(queue[j].repo, true, queue[j].errDetail || i18n("Update check interrupted by installation."))
                        }
                    }
                }
                return
            }
            for (let i = 0; i < queue.length; i++) {
                if (queue[i] && queue[i].cmd) {
                    main.execTaggedJob(queue[i].cmd, "check", queue[i].repo || "")
                }
            }
        }
    }

    Timer {
        id: busyPollTimer
        interval: 5000
        repeat: true
        running: main.isPkgManagerBusy && !main.isInstalling && !main.isOnUpdate
        onTriggered: {
            updater.checkLock()
        }
    }

    Timer {
        id: watchdogTimer
        interval: 45000
        repeat: false
        running: main.isChecking
        onTriggered: {
            if (main.isChecking) {
                if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - watchdog timeout: clearing hung checking jobs", true)
                const sources = [].concat(cmd.connectedSources)
                let timedOutApt = false
                let timedOutSnap = false
                let timedOutFlatpak = false
                let timedOutConnectivity = false
                let clearedCount = 0
                for (let i = 0; i < sources.length; i++) {
                    const src = sources[i]
                    const reg = main.activeJobsRegistry[src]
                    if (reg && reg.role === "check") {
                        if (reg.repo === "connectivity" || src === updater.connectivityCmd) timedOutConnectivity = true
                        else if (reg.repo === "snap") timedOutSnap = true
                        else if (reg.repo === "flatpak") timedOutFlatpak = true
                        else if (reg.repo === "apt") timedOutApt = true
                        main.trackJobFinished(src)
                        cmd.disconnectSource(src)
                        clearedCount++
                    }
                }
                main.clearPendingRetries()
                main.activeCheckSources = ({})
                main.activeCheckJobs = 0
                main.connectivityProbePending = false
                main.providerProbePending = { "snap": false, "flatpak": false }
                main.countAllSnapArmed = false
                main.countAllFlatpakArmed = false
                main.isChecking = false
                cmd.isUpdating(false)
                cmd.checkingStatus(false)
                const timeoutMsg = i18n("Update check timed out.")
                if (timedOutApt) main.setCheckError("apt", true, timeoutMsg)
                if (timedOutSnap) main.setCheckError("snap", true, timeoutMsg)
                if (timedOutFlatpak) main.setCheckError("flatpak", true, timeoutMsg)
                if (timedOutConnectivity) {
                    main.connectivityError = true
                    main.recomputeErrorState()
                } else if (!timedOutApt && !timedOutSnap && !timedOutFlatpak && clearedCount > 0) {
                    main.setCheckError("apt", true, timeoutMsg)
                }
            }
        }
    }

    Timer {
        id: installWatchdogTimer
        interval: 600000
        repeat: false
        running: main.hasActiveSilentUpdate
        onTriggered: {
            if (main.hasActiveSilentUpdate) {
                if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - install watchdog timeout: aborting hung silent update", true)
                main.abortUpdate(true)
            }
        }
    }

    Sv.Updater { id: updater }
    Sv.Checker { id: checker }
    Sv.Debug { id: debug }

    Plasma5Support.DataSource {
        id: cmd
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            var exitCode = data["exit code"]
            var exitStatus = data["exit status"]
            var stdout = data["stdout"]
            var stderr = data["stderr"]
            if (exitCode !== undefined) {
                exited(sourceName, exitCode, exitStatus, stdout, stderr)
                disconnectSource(sourceName)
            }
        }

        onSourceConnected: function (source) {
            if (isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - cmd connected: " + source, false)

            var reg = main.activeJobsRegistry[source]
            if ((reg && (reg.role === "helper" || reg.role === "probe")) || (!reg && isHelperCommand(source))) {
                return
            }

            const isUp = Boolean((reg && reg.role === "update") || main.activeUpdateJobs[source] !== undefined)
            main.trackJobConnected(source, !isUp)
            if (isUp) {
                var upInfo = (reg && reg.role === "update") ? reg : main.activeUpdateJobs[source]
                if (upInfo && upInfo.type === "all") {
                    main.setUpdateErrorState(false, "")
                } else if (upInfo && upInfo.repo) {
                    main.setUpdateErrorState(false, "", [upInfo.repo])
                }
                if (upInfo && upInfo.silent) {
                    installWatchdogTimer.restart()
                }
            } else {
                main.isChecking = true
                checkingStatus(true)
                isUpdating(true)
                watchdogTimer.restart()
            }
        }

        onSourceDisconnected: function (source) {
            var reg = main.activeJobsRegistry[source]
            const wasCheck = Boolean(main.activeCheckSources[source])
            main.trackJobFinished(source)
            if (reg && reg.role !== "update" && retryTimer.pendingJobs.every(function (j) { return j.cmd !== source })) {
                var rCopy = Object.assign({}, main.activeJobsRegistry)
                delete rCopy[source]
                main.activeJobsRegistry = rCopy
            }
            if (wasCheck && main.activeCheckJobs === 0 && main.isChecking) {
                watchdogTimer.stop()
                isUpdating(false)
                main.isChecking = false
                checkingStatus(false)
            }
        }

        onExited: function (sourceCmd, exitCode, exitStatus, stdout, stderr) {
            var reg = main.activeJobsRegistry[sourceCmd]
            var outStr = String(stdout || "")
            var errStr = String(stderr || "")

            if (isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - cmd exited (code " + exitCode + "): " + sourceCmd + (errStr ? " - err: " + errStr.trim() : ""), errStr !== "")

            if (reg && reg.role === "probe") {
                if (reg.repo === "provider-snap") {
                    checker.validateSnap(outStr)
                    main.providerProbePending = { "snap": false, "flatpak": main.providerProbePending.flatpak }
                    if (!main.hasSnap) {
                        main.tSnap = "0"
                        main.listSnap = ""
                        main.setCheckError("snap", false)
                        totalSnap("0")
                        main.countAllSnapArmed = false
                    } else if (main.countAllSnapArmed && !main.connectivityProbePending && updater.isConnected && !main.isInstalling && !main.isOnUpdate) {
                        main.countAllSnapArmed = false
                        updater.countSnap()
                    }
                } else if (reg.repo === "provider-flatpak") {
                    checker.validateFlatpak(outStr)
                    main.providerProbePending = { "snap": main.providerProbePending.snap, "flatpak": false }
                    if (!main.hasFlatpak) {
                        main.tFlatpak = "0"
                        main.listFlatpak = ""
                        main.setCheckError("flatpak", false)
                        totalFlatpak("0")
                        main.countAllFlatpakArmed = false
                    } else if (main.countAllFlatpakArmed && !main.connectivityProbePending && updater.isConnected && !main.isInstalling && !main.isOnUpdate) {
                        main.countAllFlatpakArmed = false
                        updater.countFlatpak()
                    }
                } else if (reg.repo === "provider-nala") {
                    checker.validateNala(outStr)
                } else if (reg.repo === "provider-os") {
                    var osInfo = CmdBuilder.parseOsRelease(outStr)
                    main.osId = osInfo.id
                    main.osIdLike = osInfo.idLike
                    if (CmdBuilder.isDebianFamilyNonUbuntu(main.osId, main.osIdLike)) {
                        main.releaseUpgradeAvailable = false
                        main.releaseUpgradeVersion = ""
                    }
                } else if (reg.repo === "provider-systemd") {
                    main.hasSystemdScope = (outStr.trim() === "1")
                } else if (reg.repo === "apt-index") {
                    var tsTrim = outStr.trim()
                    if (/^\d+$/.test(tsTrim) && parseInt(tsTrim, 10) > 0) {
                        var epochSec = parseInt(tsTrim, 10)
                        var ageDays = Math.max(0, Math.floor((Math.floor(Date.now() / 1000) - epochSec) / 86400))
                        main.aptIndexAgeDays = ageDays
                        main.aptIndexStale = (ageDays > 3)
                    } else {
                        main.aptIndexAgeDays = 0
                        main.aptIndexStale = false
                    }
                }
                return
            }

            if (reg && reg.role === "helper") {
                if (reg.repo === "lock") {
                    main.isPkgManagerBusy = (outStr.trim() === "1")
                } else if (reg.repo === "reboot-check") {
                    const isReboot = (outStr.trim() === "1")
                    if (isReboot && !main.previousRebootRequired && plasmoid.configuration.notifyOnRebootRequired && !main.expanded) {
                        sendNotify(i18n("System Restart Required"), i18n("A system restart is required to complete updates."), "system-reboot", "normal")
                    }
                    main.previousRebootRequired = isReboot
                    main.rebootRequired = isReboot
                    rebootStatus(main.rebootRequired)
                } else if (reg.repo === "release-check") {
                    const match = outStr.match(/New release '([^']+)' available/)
                    if (match && match[1]) {
                        main.releaseUpgradeAvailable = true
                        main.releaseUpgradeVersion = match[1]
                        if (!main.lastNotifiedReleaseUpgrade && plasmoid.configuration.notifyOnReleaseUpgrade && !main.expanded) {
                            sendNotify(i18n("Distribution Upgrade Available"), i18n("Ubuntu %1 is now available for upgrade.", main.releaseUpgradeVersion), "system-software-update", "normal")
                            main.lastNotifiedReleaseUpgrade = true
                        }
                    } else {
                        main.releaseUpgradeAvailable = false
                        main.releaseUpgradeVersion = ""
                        main.lastNotifiedReleaseUpgrade = false
                    }
                } else if (reg.repo === "release-upgrade") {
                    if (exitCode !== 0) {
                        var ruMsg = (exitCode === 127)
                            ? i18n("Failed to launch terminal (command not found: %1).", plasmoid.configuration.termCmd)
                            : i18n("Distribution upgrade launcher failed with exit code %1.", exitCode)
                        main.setHelperError(true, ruMsg)
                        sendNotify(i18n("Upgrade Error"), ruMsg, "dialog-error", "critical")
                    } else {
                        main.setHelperError(false, "")
                    }
                } else if (reg.repo === "reboot-prompt") {
                    if (exitCode !== 0) {
                        var rbMsg = i18n("Could not open the KDE logout prompt via session D-Bus.")
                        main.setHelperError(true, rbMsg)
                        sendNotify(i18n("Restart Failed"), rbMsg, "dialog-error", "critical")
                    } else {
                        main.setHelperError(false, "")
                    }
                } else if (reg.repo === "silent-log-read") {
                    var hint = reg.targetRepo ? [reg.targetRepo] : []
                    main.handleSilentUpdateError(outStr, hint)
                } else if (reg.repo === "term-rc-read") {
                    var rcHint = reg.targetRepo ? [reg.targetRepo] : []
                    var trimmedRc = outStr.trim()
                    if (/^\d+$/.test(trimmedRc)) {
                        var innerRc = parseInt(trimmedRc, 10)
                        if (innerRc !== 0) {
                            var innerMsg = i18n("Update failed with exit code %1.", innerRc)
                            main.setUpdateErrorState(true, innerMsg, rcHint)
                            sendNotify(i18n("Update Failed"), innerMsg, "dialog-error", "critical")
                        } else {
                            main.setUpdateErrorState(false, "", rcHint.length > 0 ? rcHint : undefined)
                        }
                    } else {
                        var missMsg = i18n("Could not read terminal update exit status.")
                        main.setUpdateErrorState(true, missMsg, rcHint)
                        sendNotify(i18n("Update Failed"), missMsg, "dialog-error", "critical")
                    }
                }
                return
            }

            if (reg && reg.role === "check" && reg.repo === "connectivity") {
                main.connectivityProbePending = false
                const online = (outStr.trim() === "1")
                updater.isConnected = online
                main.lastCheckOffline = !online
                if (online) {
                    main.connectivityError = false
                    main.recomputeErrorState()
                    if (!main.isInstalling && !main.isOnUpdate) {
                        if (main.countAllSnapArmed && !main.providerProbePending.snap) {
                            main.countAllSnapArmed = false
                            updater.countSnap()
                        }
                        if (main.countAllFlatpakArmed && !main.providerProbePending.flatpak) {
                            main.countAllFlatpakArmed = false
                            updater.countFlatpak()
                        }
                    }
                } else {
                    main.countAllSnapArmed = false
                    main.countAllFlatpakArmed = false
                    if (isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - offline detected, preserving cached counts", false)
                }
            }

            if (isHelperCommand(sourceCmd)) {
                return
            }

            const jobInfo = main.activeUpdateJobs[sourceCmd]
            const isUpdateCmd = Boolean(jobInfo !== undefined || (reg && reg.role === "update"))
            const isOnError = exitCode !== 0

            const cmdIsArch = (updater.lastCountArchCmd !== "" && sourceCmd === updater.lastCountArchCmd)
            if (cmdIsArch && exitCode === 0) {
                let clean = outStr.trim()
                let total = /^\d+$/.test(clean) ? clean : "0"
                main.tApt = total
                totalApt(total)
                main.setCheckError("apt", false)
                if (total === "0") {
                    main.listApt = ""
                } else {
                    updater.listArch()
                }
                notifyDebounceTimer.restart()
            }

            const cmdIsListSnap = (updater.lastListSnapCmd !== "" && sourceCmd === updater.lastListSnapCmd)
            const cmdIsListFlatpak = (updater.lastListFlatpakCmd !== "" && sourceCmd === updater.lastListFlatpakCmd)
            const cmdIsListArch = (updater.lastListArchCmd !== "" && sourceCmd === updater.lastListArchCmd)

            if (cmdIsListArch && exitCode === 0) {
                main.listApt = outStr
                main.setCheckError("apt", false)
                notifyDebounceTimer.restart()
            }
            if (cmdIsListSnap && exitCode === 0) {
                const snapLines = outStr ? outStr.trim().split("\n").filter(function (l) { return l.trim() !== "" }) : []
                main.tSnap = String(snapLines.length)
                totalSnap(main.tSnap)
                main.listSnap = snapLines.length > 0 ? outStr : ""
                main.setCheckError("snap", false)
                notifyDebounceTimer.restart()
            }
            if (cmdIsListFlatpak && exitCode === 0) {
                const flatpakLines = outStr ? outStr.trim().split("\n").filter(function (l) { return l.trim() !== "" }) : []
                main.tFlatpak = String(flatpakLines.length)
                totalFlatpak(main.tFlatpak)
                main.listFlatpak = flatpakLines.length > 0 ? outStr : ""
                main.setCheckError("flatpak", false)
                notifyDebounceTimer.restart()
            }

            const cmdRepo = main.getCmdRepo(sourceCmd)
            const cleanErrLines = errStr ? errStr.split("\n").filter(function (l) {
                return l.indexOf("qt.core.qobject") === -1 &&
                       l.indexOf("kf.") === -1 &&
                       l.indexOf("This plugin does not support") === -1 &&
                       l.indexOf("Failed to create secure directory") === -1
            }).join("\n").trim() : ""
            const errDetail = (cleanErrLines !== "") ? cleanErrLines : ((exitCode === 124 || exitCode === 137) ? i18n("Update check timed out.") : i18n("Command failed with exit code %1", exitCode))
            if (isOnError && !isUpdateCmd) {
                if (plasmoid.configuration.retryMode && cmdRepo) {
                    const currentRetries = main.retryCounts[sourceCmd] || 0
                    if (currentRetries < 2) {
                        main.retryCounts[sourceCmd] = currentRetries + 1
                        if (isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - scheduled retry (attempt " + (currentRetries + 1) + ") in 5s: " + cmdRepo, true)
                        var exists = retryTimer.pendingJobs.some(function (j) { return j.cmd === sourceCmd })
                        if (!exists) {
                            retryTimer.pendingJobs = retryTimer.pendingJobs.concat([{ cmd: sourceCmd, repo: cmdRepo, errDetail: errDetail }])
                        }
                        if (!retryTimer.running) {
                            retryTimer.start()
                        }
                    } else {
                        delete main.retryCounts[sourceCmd]
                        main.setCheckError(cmdRepo, true, errDetail)
                    }
                } else if (cmdRepo) {
                    main.setCheckError(cmdRepo, true, errDetail)
                }
            } else if (!isOnError && main.retryCounts[sourceCmd]) {
                delete main.retryCounts[sourceCmd]
            }

            if (isUpdateCmd) {
                if (isOnDebug) debug.log("APTUPDATE - an update ended (" + exitCode + "): " + sourceCmd, exitCode !== 0)
                var job = jobInfo || { type: "all", repo: null, silent: Boolean(plasmoid.configuration.silentUpdate), logFile: "", rcFile: "", pgidFile: "" }
                var jobType = job.type || "all"
                var jobRepo = job.repo || null
                var wasSilent = Boolean(job.silent)

                var jobsCopy = Object.assign({}, main.activeUpdateJobs)
                delete jobsCopy[sourceCmd]
                main.activeUpdateJobs = jobsCopy

                var regCopy = Object.assign({}, main.activeJobsRegistry)
                delete regCopy[sourceCmd]
                main.activeJobsRegistry = regCopy

                if (job.pgidFile) {
                    execTaggedJob(CmdBuilder.buildSafeRemoveCmd(job.pgidFile), "helper", "pgid-clean")
                }

                if (!wasSilent) {
                    if (exitCode === 127) {
                        var termName = plasmoid.configuration.notCloseCommand ? plasmoid.configuration.termNoCloseCmd : plasmoid.configuration.termCmd
                        var termErrMsg = i18n("Failed to launch terminal (command not found: %1).", termName)
                        main.setUpdateErrorState(true, termErrMsg, jobRepo ? [jobRepo] : [])
                        sendNotify(i18n("Update Failed"), termErrMsg, "dialog-error", "critical")
                        if (job.rcFile) execTaggedJob(CmdBuilder.buildSafeRemoveCmd(job.rcFile), "helper", "rc-clean")
                    } else if (job.rcFile) {
                        execTaggedJob(CmdBuilder.buildSafeReadAndRemoveCmd(job.rcFile), "helper", "term-rc-read", { targetRepo: jobRepo || "" })
                    } else if (exitCode !== 0) {
                        var exitErrMsg = i18n("Update failed with exit code %1.", exitCode)
                        main.setUpdateErrorState(true, exitErrMsg, jobRepo ? [jobRepo] : [])
                        sendNotify(i18n("Update Failed"), exitErrMsg, "dialog-error", "critical")
                    } else {
                        main.setUpdateErrorState(false, "", jobType === "all" ? [] : (jobRepo ? [jobRepo] : []))
                    }
                } else {
                    if (exitCode === 0 || exitCode === 126) {
                        main.setUpdateErrorState(false, "", jobType === "all" ? [] : (jobRepo ? [jobRepo] : []))
                        if (job.logFile) {
                            execTaggedJob(CmdBuilder.buildSafeRemoveCmd(job.logFile), "helper", "log-clean")
                        }
                        if (exitCode === 0 && plasmoid.configuration.notifyOnSilentUpdate) {
                            if (jobType === "all") {
                                sendNotify(i18n("System Updates"), i18n("All system updates were installed successfully."), "system-software-update", "normal")
                            } else if (jobType === "group") {
                                var repoDisplayName = (jobRepo === "apt" ? "APT" : (jobRepo === "snap" ? "Snap" : "Flatpak"))
                                sendNotify(i18n("System Updates"), i18n("%1 updates were installed successfully.", repoDisplayName), "system-software-update", "normal")
                            } else {
                                sendNotify(i18n("System Updates"), i18n("%1 was updated successfully.", (job.name || job.appId)), "system-software-update", "normal")
                            }
                        }
                    } else {
                        if (job.logFile) {
                            main.setUpdateErrorState(true, i18n("An error occurred during the background update."), jobRepo ? [jobRepo] : [])
                            execTaggedJob(CmdBuilder.buildSafeReadAndRemoveCmd(job.logFile), "helper", "silent-log-read", { targetRepo: jobRepo || "" })
                        } else {
                            main.handleSilentUpdateError("", jobRepo ? [jobRepo] : [])
                        }
                    }
                }

                if (jobType === "all") {
                    main.isUpdatingAll = false
                    main.updatingRepos = { "apt": false, "snap": false, "flatpak": false }
                    main.updateAggregateStates()
                    main.refreshAll(true)
                } else if (jobType === "group") {
                    main.setRepoUpdating(jobRepo, false)
                    if (jobRepo === "apt") {
                        updater.checkLock()
                        updater.countArch()
                        updater.checkReboot()
                    } else if (jobRepo === "snap") updater.countSnap()
                    else if (jobRepo === "flatpak") updater.countFlatpak()
                } else if (jobType === "single") {
                    main.setPackageUpdating(jobRepo, job.name, job.appId, false)
                    if (jobRepo === "apt") {
                        updater.checkLock()
                        updater.countArch()
                        updater.checkReboot()
                    } else if (jobRepo === "snap") updater.countSnap()
                    else if (jobRepo === "flatpak") updater.countFlatpak()
                }
                main.updateAggregateStates()
            }

            const wasTrackedCheck = Boolean(main.activeCheckSources[sourceCmd])
            main.trackJobFinished(sourceCmd)
            if (!isUpdateCmd && wasTrackedCheck) {
                if (main.activeCheckJobs === 0) {
                    watchdogTimer.stop()
                    isUpdating(false)
                    main.isChecking = false
                    checkingStatus(false)
                    updater.checkLock()
                    if (!main.isRetrying && !main.connectivityProbePending &&
                        !main.isInstalling && !main.isOnUpdate &&
                        !main.hasError && !main.lastCheckOffline) {
                        main.saveCache()
                        notifyDebounceTimer.restart()
                    }
                } else {
                    watchdogTimer.restart()
                }
            }
        }

        function exec(cmdStr: string) {
            if (!cmdStr) return
            if (connectedSources.indexOf(cmdStr) !== -1) return
            connectSource(cmdStr)
        }

        signal isUpdating(bool status)
        signal updateRunning(bool running)
        signal checkingStatus(bool checking)
        signal errorStatus(bool error)
        signal totalApt(string total)
        signal totalSnap(string total)
        signal totalFlatpak(string total)
        signal rebootStatus(bool required)
        signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)
    }

    Timer {
        id: timer
        interval: {
            let mult = 60000
            if (main.intervalUnitConfig === 1) {
                mult = 3600000
            } else if (main.intervalUnitConfig === 2) {
                mult = 86400000
            }
            return Math.min(2147483647, Math.max(60000, (main.intervalConfig || 30) * mult))
        }
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            main.refreshLastCheckTime()
            main.triggerAutoCheck()
        }
    }

    onExpandedChanged: {
        if (main.expanded) {
            main.refreshLastCheckTime()
            main.isPrewarmed = true
        } else if (main.pendingAutoCheck) {
            main.pendingAutoCheck = false
            if (main.isOnDebug) debug.log("APTUPDATE - " + plasmoid.id + " - popup closed, executing deferred auto-check", false)
            main.refreshAll(true)
        }
    }

    Timer {
        id: startupDelayTimer
        interval: Math.max(1000, main.startupDelaySeconds * 1000)
        repeat: false
        running: false
        onTriggered: {
            main.isPrewarmed = true
            main.triggerAutoCheck()
        }
    }

    Timer {
        id: prewarmTimer
        interval: 1500
        repeat: false
        running: false
        onTriggered: {
            main.isPrewarmed = true
        }
    }

    function hasUpdate() {
        const numApt = parseInt(main.tApt, 10) || 0
        const numSnap = (main.enableSnapUpdates && main.hasSnap) ? (parseInt(main.tSnap, 10) || 0) : 0
        const numFlatpak = (main.enableFlatpakUpdates && main.hasFlatpak) ? (parseInt(main.tFlatpak, 10) || 0) : 0
        return (numApt + numSnap + numFlatpak) > 0
    }
    Plasmoid.status: (hasUpdate() || main.hasError || main.rebootRequired || main.releaseUpgradeAvailable) ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    compactRepresentation: Compact {}
    fullRepresentation: Loader {
        id: fullLoader
        active: Boolean(main.expanded || main.isPrewarmed)
        source: "Full.qml"
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Update")
            icon.name: "install-symbolic"
            enabled: main.canUpdateAll()
            onTriggered: {
                updater.launchUpdate()
            }
        },
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh-symbolic"
            enabled: !main.isInstalling && !main.isOnUpdate && !main.isChecking
            onTriggered: {
                main.refreshAll()
            }
        }
    ]

    toolTipItem: Loader {
        id: tooltipLoader
        Layout.minimumWidth: item ? item.implicitWidth : 0
        Layout.maximumWidth: item ? item.implicitWidth : 0
        Layout.minimumHeight: item ? item.implicitHeight : 0
        Layout.maximumHeight: item ? item.implicitHeight : 0
        source: "Tooltip.qml"
    }

    function _plasmaConfigTabTranslations() {
        i18nc("@action:button set keyboard shortcut for", "Activate widget as if clicked:")
    }

    Component.onCompleted: {
        main.loadCache()
        main.isInitialized = true
        if (main.startupCheckMode === 1) {
            main.refreshAll()
            prewarmTimer.start()
        } else if (main.startupCheckMode === 2) {
            checker.checkProviders()
            startupDelayTimer.start()
        } else {
            checker.checkProviders()
            prewarmTimer.start()
        }
    }
}
