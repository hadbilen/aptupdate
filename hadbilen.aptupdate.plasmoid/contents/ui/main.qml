import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

import "../service" as Sv

PlasmoidItem {
    id: main

    readonly property alias debugService: debug

    readonly property string logDir: {
        var runtime = StandardPaths.writableLocation(StandardPaths.RuntimeLocation).toString().replace(/^file:\/\//, "")
        if (runtime && runtime.length > 0) {
            return runtime + "/aptupdate"
        }
        var temp = StandardPaths.writableLocation(StandardPaths.TempLocation).toString().replace(/^file:\/\//, "") || "/tmp"
        return temp + "/.aptupdate-" + (plasmoid ? plasmoid.id : "user")
    }

    property int intervalConfig: plasmoid.configuration.updateInterval
    property int intervalUnitConfig: plasmoid.configuration.updateIntervalUnit !== undefined ? plasmoid.configuration.updateIntervalUnit : 0
    property bool isOnDebug: plasmoid.configuration.debugMode
    property bool isOnUpdate: false
    property bool hasError: false
    property bool updateError: false
    property string lastErrorMessage: ""
    property bool isChecking: false
    property bool isInstalling: false
    property var repoErrors: ({ "apt": false, "snap": false, "flatpak": false })
    property bool isPkgManagerBusy: false
    property bool lockBlockedUpdate: false

    onIsPkgManagerBusyChanged: {
        if (!isPkgManagerBusy) {
            main.lockBlockedUpdate = false
        }
    }

    function recomputeErrorState() {
        var anyRepoErr = Boolean(main.repoErrors["apt"] || main.repoErrors["snap"] || main.repoErrors["flatpak"])
        main.hasError = Boolean(anyRepoErr || main.updateError)
        cmd.errorStatus(main.hasError)
    }

    function setRepoError(repo, err, errMsg) {
        if (!repo) return
        var copy = Object.assign({}, main.repoErrors)
        copy[repo] = Boolean(err)
        main.repoErrors = copy
        if (err && errMsg) {
            main.lastErrorMessage = errMsg
        } else if (!err && !main.updateError && !copy["apt"] && !copy["snap"] && !copy["flatpak"]) {
            main.lastErrorMessage = ""
        }
        main.recomputeErrorState()
    }

    function clearRepoErrors() {
        main.repoErrors = { "apt": false, "snap": false, "flatpak": false }
        main.updateError = false
        main.lastErrorMessage = ""
        main.hasError = false
        cmd.errorStatus(false)
    }

    function clearPendingRetries() {
        retryTimer.stop()
        retryTimer.pendingCmds = []
        main.retryCounts = ({})
    }

    function getCmdRepo(sourceCmd) {
        if (!sourceCmd) return ""
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

    function abortUpdate() {
        if (main.isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - aborting update operations', true)
        const sources = [].concat(cmd.connectedSources)
        for (let i = 0; i < sources.length; i++) {
            cmd.disconnectSource(sources[i])
        }
        main.isUpdatingAll = false
        main.updatingRepos = { "apt": false, "snap": false, "flatpak": false }
        main.updatingPackages = ({})
        main.activeUpdateJobs = ({})
        main.updateAggregateStates()
        main.activeJobSources = ({})
        main.activeCheckSources = ({})
        main.activeJobs = 0
        main.activeCheckJobs = 0
        main.isChecking = false
        main.isPkgManagerBusy = false
        main.lockBlockedUpdate = false
        main.clearPendingRetries()
        cmd.isUpdating(false)
        cmd.checkingStatus(false)
        sendNotify(i18n("Update Aborted"), i18n("Update operation timed out or was cancelled."), "dialog-warning", "normal")
    }
    property bool isInitialized: false
    property var activeJobSources: ({})
    property var activeCheckSources: ({})
    property int activeJobs: 0
    property int activeCheckJobs: 0

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
    property bool hasSnap: plasmoid.configuration.hasSnap
    property bool hasFlatpak: plasmoid.configuration.hasFlatpak
    property bool hasNala: plasmoid.configuration.hasNala
    property bool enableSnapUpdates: plasmoid.configuration.enableSnapUpdates
    property bool enableFlatpakUpdates: plasmoid.configuration.enableFlatpakUpdates

    onEnableSnapUpdatesChanged: {
        if (!main.isInitialized) return
        if (!enableSnapUpdates) {
            main.tSnap = "0"
            main.listSnap = ""
            main.setRepoError("snap", false)
            cmd.totalSnap("0")
        } else if (main.hasSnap && !main.isInstalling && !main.isOnUpdate) {
            updater.countSnap()
        }
    }

    onEnableFlatpakUpdatesChanged: {
        if (!main.isInitialized) return
        if (!enableFlatpakUpdates) {
            main.tFlatpak = "0"
            main.listFlatpak = ""
            main.setRepoError("flatpak", false)
            cmd.totalFlatpak("0")
        } else if (main.hasFlatpak && !main.isInstalling && !main.isOnUpdate) {
            updater.countFlatpak()
        }
    }

    property int startupCheckMode: plasmoid.configuration.startupCheckMode !== undefined ? plasmoid.configuration.startupCheckMode : 2
    property int startupDelaySeconds: plasmoid.configuration.startupDelaySeconds !== undefined ? plasmoid.configuration.startupDelaySeconds : 30
    property string lastCheckTime: plasmoid.configuration.cachedLastCheckTime || ""
    property bool hasCheckedOnce: (plasmoid.configuration.cachedLastCheckTime !== undefined && plasmoid.configuration.cachedLastCheckTime !== "")
    property bool hasScannedThisSession: false
    readonly property bool isStartupDelaying: startupDelayTimer.running
    readonly property alias startupDelayTimer: startupDelayTimer
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
        if (main.isUpdatingAll) return false
        if (isRepoBusy(repo)) return false
        if (repo === "apt" && main.isPkgManagerBusy) return false
        return true
    }

    function canUpdatePackage(repo, name, appId) {
        if (main.isUpdatingAll) return false
        if (isRepoBusy(repo)) return false
        if (isPackageBusy(repo, name, appId)) return false
        if (repo === "apt" && main.isPkgManagerBusy) return false
        return true
    }

    function canUpdateAll() {
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
        main.isInstalling = busy
        main.isOnUpdate = busy
        cmd.updateRunning(busy)
    }

    function registerUpdateJob(sourceCmd, type, repo, name, appId) {
        if (!sourceCmd) return
        var jobs = Object.assign({}, main.activeUpdateJobs)
        jobs[sourceCmd] = {
            type: type,
            repo: repo,
            name: name,
            appId: appId
        }
        main.activeUpdateJobs = jobs
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
        if (source.indexOf("lock-frontend") !== -1) return true
        if (source.indexOf("do-release-upgrade") !== -1) return true
        if (source.startsWith("which ")) return true
        if (source.startsWith("fuser ")) return true
        if (source.startsWith("test -s /var/lib/ubuntu-release-upgrader")) return true
        if (source.startsWith("test ")) return true
        if (source.startsWith("konsole -v")) return true
        if (source.startsWith("apt --version")) return true
        if (source.startsWith("notify-send")) return true
        if (source.startsWith("kdialog")) return true
        if (source.startsWith("qdbus org.kde.LogoutPrompt")) return true
        if (source.startsWith("cat ") && source.indexOf("/aptupdate_last_error") !== -1) return true
        if (source.startsWith("rm -f ") && source.indexOf("/aptupdate_last_error") !== -1) return true
        return false
    }

    function handleSilentUpdateError(output) {
        const text = (output || "").trim()
        if (text.indexOf("[CANCELLED]") !== -1) {
            if (main.isOnDebug) debug.log('APTUPDATE - ' + plasmoid.id + ' - update cancelled by user', false)
            main.updateError = false
            main.lastErrorMessage = ""
            main.recomputeErrorState()
            return
        }

        const failed = []
        if (text.indexOf("[FAILED] apt") !== -1) failed.push("APT")
        if (text.indexOf("[FAILED] snap") !== -1) failed.push("Snap")
        if (text.indexOf("[FAILED] flatpak") !== -1) failed.push("Flatpak")

        let msg = ""
        if (failed.length > 0) {
            msg = i18n("Update failed for: %1", failed.join(", "))
        } else {
            msg = i18n("An error occurred during the background update.")
        }

        main.updateError = true
        main.lastErrorMessage = msg
        main.recomputeErrorState()

        if (main.isOnDebug) {
            debug.log('APTUPDATE - ' + plasmoid.id + ' - silent update error details: ' + (failed.length > 0 ? failed.join(", ") : text || "unknown error"), true)
        }
        sendNotify(i18n("Update Failed"), msg, "dialog-error", "critical")
    }

    function loadCache() {
        const cApt = plasmoid.configuration.cachedAptCount || "0"
        const cSnap = plasmoid.configuration.cachedSnapCount || "0"
        const cFlatpak = plasmoid.configuration.cachedFlatpakCount || "0"
        const cPkgList = plasmoid.configuration.cachedPackageList || ""
        const cLastTime = plasmoid.configuration.cachedLastCheckTime || ""
        const snapEnabled = Boolean(plasmoid.configuration.enableSnapUpdates && plasmoid.configuration.hasSnap)
        const flatpakEnabled = Boolean(plasmoid.configuration.enableFlatpakUpdates && plasmoid.configuration.hasFlatpak)

        main.tApt = cApt
        main.tSnap = snapEnabled ? cSnap : "0"
        main.tFlatpak = flatpakEnabled ? cFlatpak : "0"
        main.lastCheckTime = cLastTime
        main.hasCheckedOnce = (cLastTime !== "")

        if (cPkgList) {
            const lines = cPkgList.split("\n")
            const aptLines = []
            const snapLines = []
            const flatpakLines = []
            for (let i = 0; i < lines.length; i++) {
                const l = lines[i].trim()
                if (!l) continue
                if (l.indexOf("\tsnap\t") !== -1 || l.indexOf(" snap ") !== -1) {
                    snapLines.push(l)
                } else if (l.indexOf("\tflatpak\t") !== -1 || l.indexOf("\t") !== -1 || l.indexOf(" flatpak ") !== -1) {
                    flatpakLines.push(l)
                } else {
                    aptLines.push(l)
                }
            }
            main.listApt = aptLines.join("\n")
            main.listSnap = snapEnabled ? snapLines.join("\n") : ""
            main.listFlatpak = flatpakEnabled ? flatpakLines.join("\n") : ""
        }

        cmd.totalApt(main.tApt)
        cmd.totalSnap(main.tSnap)
        cmd.totalFlatpak(main.tFlatpak)
    }

    function saveCache() {
        const snapEnabled = Boolean(main.enableSnapUpdates && main.hasSnap)
        const flatpakEnabled = Boolean(main.enableFlatpakUpdates && main.hasFlatpak)
        plasmoid.configuration.cachedAptCount = main.tApt
        plasmoid.configuration.cachedSnapCount = snapEnabled ? main.tSnap : "0"
        plasmoid.configuration.cachedFlatpakCount = flatpakEnabled ? main.tFlatpak : "0"

        let combinedList = (main.listApt ? main.listApt.trim() : "")
        if (snapEnabled && main.listSnap && main.listSnap.trim()) {
            combinedList += (combinedList ? "\n" : "") + main.listSnap.trim()
        }
        if (flatpakEnabled && main.listFlatpak && main.listFlatpak.trim()) {
            combinedList += (combinedList ? "\n" : "") + main.listFlatpak.trim()
        }
        plasmoid.configuration.cachedPackageList = combinedList

        const now = new Date()
        const timeStr = Qt.formatTime(now, "hh:mm")
        main.lastCheckTime = timeStr
        plasmoid.configuration.cachedLastCheckTime = timeStr
        main.hasCheckedOnce = true
        main.hasScannedThisSession = true
    }

    function refreshAll() {
        if (main.isInstalling || main.isOnUpdate || main.isChecking) {
            if (main.isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - refreshAll skipped, check or update currently in progress', false)
            return
        }
        main.clearRepoErrors()
        main.isPkgManagerBusy = false
        main.lockBlockedUpdate = false
        main.pendingAutoCheck = false
        main.clearPendingRetries()
        if (startupDelayTimer.running) {
            startupDelayTimer.stop()
        }
        updater.countAll()
    }

    function triggerAutoCheck() {
        if (main.expanded) {
            if (main.isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - popup is expanded, deferring auto-check', false)
            main.pendingAutoCheck = true
            return
        }
        main.refreshAll()
    }

    function sendNotify(title, message, icon, urgency) {
        var safeTitle = ("" + title).replace(/'/g, "'\\''")
        var safeMsg = ("" + message).replace(/'/g, "'\\''")
        var safeIcon = ("" + (icon || "dialog-information")).replace(/'/g, "'\\''")
        var safeUrgency = (urgency === "low" || urgency === "critical") ? urgency : "normal"
        cmd.exec("notify-send -u " + safeUrgency + " -a 'APT Update Counter' -i '" + safeIcon + "' '" + safeTitle + "' '" + safeMsg + "'")
    }

    function checkNotification() {
        if (!plasmoid.configuration.notifyOnUpdates) return
        if (main.activeJobs > 0 || main.isChecking || main.isInstalling || main.isOnUpdate) return
        const numApt = parseInt(main.tApt, 10) || 0
        const numSnap = (main.enableSnapUpdates && main.hasSnap) ? (parseInt(main.tSnap, 10) || 0) : 0
        const numFlatpak = (main.enableFlatpakUpdates && main.hasFlatpak) ? (parseInt(main.tFlatpak, 10) || 0) : 0
        const currentTotal = numApt + numSnap + numFlatpak
        if (main.expanded) {
            if (main.isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - popup is expanded, suppressing notification', false)
            main.previousTotal = currentTotal
            return
        }
        const threshold = plasmoid.configuration.notificationThreshold !== undefined ? plasmoid.configuration.notificationThreshold : 1
        const isStartup = (main.previousTotal < 0)
        const hasSecurity = Boolean(main.listApt && /security/i.test(main.listApt))

        // Reset security latch if no security updates exist
        if (!hasSecurity) {
            main.lastNotifiedHasSecurity = false
        }

        // Reset tracking if updates are cleared or drop below threshold
        if (currentTotal === 0) {
            main.lastNotifiedTotal = 0
            main.lastNotifiedHasSecurity = false
            main.previousTotal = 0
            return
        }
        if (currentTotal < threshold && !hasSecurity) {
            main.lastNotifiedTotal = 0
            main.lastNotifiedHasSecurity = false
            main.previousTotal = currentTotal
            return
        }

        let shouldNotify = false
        let isCritical = false

        if (hasSecurity && !main.lastNotifiedHasSecurity) {
            // Security updates bypass numeric threshold and startup restrictions
            shouldNotify = true
            isCritical = true
        } else if (isStartup) {
            if (plasmoid.configuration.notifyOnStartup && currentTotal >= threshold) {
                shouldNotify = true
            }
        } else {
            // Periodic checks: must have increased
            if (currentTotal > main.previousTotal) {
                if (main.lastNotifiedTotal <= 0) {
                    // First time reaching threshold
                    shouldNotify = (currentTotal >= threshold)
                } else if (currentTotal >= main.lastNotifiedTotal + 5) {
                    // Significant increase (+5 updates) above last notification
                    shouldNotify = true
                }
            }
        }

        if (shouldNotify) {
            const parts = []
            if (numApt > 0) parts.push(numApt + " APT")
            if (numSnap > 0) parts.push(numSnap + " Snap")
            if (numFlatpak > 0) parts.push(numFlatpak + " Flatpak")

            let msg = ""
            if (parts.length > 0) {
                const breakdown = parts.join(", ")
                msg = i18np("%1 update available: %2", "%1 updates available: %2", currentTotal, breakdown)
            } else {
                msg = i18np("%1 update available", "%1 updates available", currentTotal)
            }

            if (isCritical || hasSecurity) {
                sendNotify(i18n("Critical System Updates"), msg, "security-high", "critical")
                main.lastNotifiedHasSecurity = true
            } else {
                sendNotify(i18n("System Updates"), msg, "system-software-update", "normal")
            }
            main.lastNotifiedTotal = currentTotal
        }

        main.previousTotal = currentTotal
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
        property var pendingCmds: []
        onTriggered: {
            const queue = [].concat(pendingCmds)
            pendingCmds = []
            if (main.isInstalling || main.isOnUpdate) {
                return
            }
            for (let i = 0; i < queue.length; i++) {
                if (queue[i]) cmd.exec(queue[i])
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
                if (main.isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - watchdog timeout: clearing hung checking jobs', true)
                const sources = [].concat(cmd.connectedSources)
                let timedOutApt = false
                let timedOutSnap = false
                let timedOutFlatpak = false
                let timedOutConnectivity = false
                let clearedCount = 0
                for (let i = 0; i < sources.length; i++) {
                    const src = sources[i]
                    if (!isHelperCommand(src) && main.activeUpdateJobs[src] === undefined &&
                        src.indexOf("pkexec") === -1 && src.indexOf("konsole") === -1) {
                        if (src === updater.connectivityCmd) timedOutConnectivity = true
                        else if (src.indexOf("snap ") !== -1) timedOutSnap = true
                        else if (src.indexOf("flatpak ") !== -1) timedOutFlatpak = true
                        else if (src.indexOf("apt-get ") !== -1) timedOutApt = true
                        main.trackJobFinished(src)
                        cmd.disconnectSource(src)
                        clearedCount++
                    }
                }
                main.clearPendingRetries()
                main.activeCheckSources = ({})
                main.activeCheckJobs = 0
                main.isChecking = false
                cmd.isUpdating(false)
                cmd.checkingStatus(false)
                const timeoutMsg = i18n("Update check timed out.")
                if (timedOutApt) main.setRepoError("apt", true, timeoutMsg)
                if (timedOutSnap) main.setRepoError("snap", true, timeoutMsg)
                if (timedOutFlatpak) main.setRepoError("flatpak", true, timeoutMsg)
                if (timedOutConnectivity && !timedOutApt && !timedOutSnap && !timedOutFlatpak) {
                    main.hasError = true
                    main.lastErrorMessage = timeoutMsg
                    cmd.errorStatus(true)
                } else if (!timedOutApt && !timedOutSnap && !timedOutFlatpak && !timedOutConnectivity && clearedCount > 0) {
                    main.setRepoError("apt", true, timeoutMsg)
                }
            }
        }
    }

    Timer {
        id: installWatchdogTimer
        interval: 600000 // 600 seconds (10 minutes)
        repeat: false
        running: main.isInstalling || main.isOnUpdate
        onTriggered: {
            if (main.isInstalling || main.isOnUpdate) {
                if (main.isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - install watchdog timeout: aborting hung update process', true)
                main.abortUpdate()
            }
        }
    }

    // load one instance of each needed service
    Sv.Updater{ id: updater }
    Sv.Checker{ id: checker }
    Sv.Debug{ id: debug }

    // the brain of the widget
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
            if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - cmd connected: ' + source, false)

            if (isHelperCommand(source)) {
                return
            }

            const tCmd = (plasmoid.configuration.termCmd || "").trim()
            const tNoCloseCmd = (plasmoid.configuration.termNoCloseCmd || "").trim()
            const isUp = (main.activeUpdateJobs[source] !== undefined ||
                          (tCmd !== "" && source.startsWith(tCmd)) ||
                          (tNoCloseCmd !== "" && source.startsWith(tNoCloseCmd)) ||
                          source.indexOf("konsole") !== -1 ||
                          source.indexOf("pkexec") !== -1 ||
                          (updater.lastUpdateCmd !== "" && source === updater.lastUpdateCmd))
            main.trackJobConnected(source, !isUp)
            if (isUp) {
                if (main.activeUpdateJobs[source] === undefined) {
                    if (source.indexOf("flatpak") !== -1 && source.indexOf("apt") === -1 && source.indexOf("snap") === -1) {
                        main.registerUpdateJob(source, "group", "flatpak")
                    } else if (source.indexOf("snap") !== -1 && source.indexOf("apt") === -1 && source.indexOf("flatpak") === -1) {
                        main.registerUpdateJob(source, "group", "snap")
                    } else if ((source.indexOf("apt") !== -1 || source.indexOf("nala") !== -1) && source.indexOf("snap") === -1 && source.indexOf("flatpak") === -1) {
                        main.registerUpdateJob(source, "group", "apt")
                    } else {
                        main.registerUpdateJob(source, "all", null)
                    }
                }
                main.updateError = false
                main.lastErrorMessage = ""
                main.recomputeErrorState()
            } else {
                main.isChecking = true
                checkingStatus(true)
                isUpdating(true)
                watchdogTimer.restart()
            }
        }

        onSourceDisconnected: function (source) {
            if (isHelperCommand(source)) {
                return
            }
            const wasCheck = Boolean(main.activeCheckSources[source])
            main.trackJobFinished(source)
            if (wasCheck && main.activeCheckJobs === 0 && main.isChecking) {
                watchdogTimer.stop()
                isUpdating(false)
                main.isChecking = false
                checkingStatus(false)
            }
        }

        onExited: function (sourceCmd, exitCode, exitStatus, stdout, stderr) {
            if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - cmd exited (code ' + exitCode + '): ' + sourceCmd + (stderr ? ' - err: ' + stderr.trim() : ''), stderr !== "")

            // handle lock check
            if (sourceCmd.indexOf("lock-frontend") !== -1) {
                main.isPkgManagerBusy = (stdout.trim() === "1")
            }

            // handle reboot required
            if (sourceCmd === "test -f /var/run/reboot-required && echo 1 || echo 0") {
                const isReboot = (stdout.trim() === "1")
                if (isReboot && !main.previousRebootRequired && plasmoid.configuration.notifyOnRebootRequired && !main.expanded) {
                    sendNotify(i18n("System Restart Required"), i18n("A system restart is required to complete updates."), "system-reboot", "normal")
                }
                main.previousRebootRequired = isReboot
                main.rebootRequired = isReboot
                rebootStatus(main.rebootRequired)
            }

            // handle distribution release upgrade
            if (sourceCmd.startsWith("test -s /var/lib/ubuntu-release-upgrader")) {
                const match = stdout.match(/New release '([^']+)' available/)
                if (match && match[1]) {
                    main.releaseUpgradeAvailable = true
                    main.releaseUpgradeVersion = match[1]
                    if (main.isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - release upgrade available: ' + match[1], false)
                    if (!main.lastNotifiedReleaseUpgrade && plasmoid.configuration.notifyOnReleaseUpgrade && !main.expanded) {
                        sendNotify(i18n("Distribution Upgrade Available"), i18n("Ubuntu %1 is now available for upgrade.", main.releaseUpgradeVersion), "system-software-update", "normal")
                        main.lastNotifiedReleaseUpgrade = true
                    }
                } else {
                    main.releaseUpgradeAvailable = false
                    main.releaseUpgradeVersion = ""
                    main.lastNotifiedReleaseUpgrade = false
                }
            }
            if (sourceCmd === "which snap >/dev/null 2>&1 && echo 1 || echo 0") {
                checker.validateSnap(stdout)
                main.hasSnap = plasmoid.configuration.hasSnap
                if (!main.hasSnap) {
                    main.tSnap = "0"
                    main.listSnap = ""
                    main.setRepoError("snap", false)
                    totalSnap("0")
                }
            }
            if (sourceCmd === "which flatpak >/dev/null 2>&1 && echo 1 || echo 0") {
                checker.validateFlatpak(stdout)
                main.hasFlatpak = plasmoid.configuration.hasFlatpak
                if (!main.hasFlatpak) {
                    main.tFlatpak = "0"
                    main.listFlatpak = ""
                    main.setRepoError("flatpak", false)
                    totalFlatpak("0")
                }
            }
            if (sourceCmd === "which nala >/dev/null 2>&1 && echo 1 || echo 0") {
                checker.validateNala(stdout)
                main.hasNala = plasmoid.configuration.hasNala
            }

            // handle silent update error reader
            if (sourceCmd.startsWith("cat ") && sourceCmd.indexOf("/aptupdate_last_error") !== -1) {
                main.handleSilentUpdateError(stdout)
                return
            }

            // early return for helper commands to isolate them from package scan jobs, error retries, and saveCache
            if (isHelperCommand(sourceCmd)) {
                return
            }

            const tCmd = (plasmoid.configuration.termCmd || "").trim()
            const tNoCloseCmd = (plasmoid.configuration.termNoCloseCmd || "").trim()
            const jobInfo = main.activeUpdateJobs[sourceCmd]
            const isUpdateCmd = (jobInfo !== undefined ||
                                 (tCmd !== "" && sourceCmd.startsWith(tCmd)) ||
                                 (tNoCloseCmd !== "" && sourceCmd.startsWith(tNoCloseCmd)) ||
                                 sourceCmd.indexOf("konsole") !== -1 ||
                                 sourceCmd.indexOf("pkexec") !== -1 ||
                                 (updater.lastUpdateCmd !== "" && sourceCmd === updater.lastUpdateCmd))
            const isOnError = exitCode !== 0

            // handle network connectivity check
            if (sourceCmd === updater.connectivityCmd) {
                const online = (stdout.trim() === "1")
                updater.isConnected = online
                if (online) {
                    updater.countSnap()
                    updater.countFlatpak()
                } else {
                    if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - offline detected, skipping snap and flatpak checks and preserving cached counts', false)
                }
            }

            // handle the result for the count with numeric sanitization (anti-NaN)
            const cmdIsArch = (updater.lastCountArchCmd !== "" && sourceCmd === updater.lastCountArchCmd)

            if (cmdIsArch && exitCode === 0) {
                let clean = stdout.trim()
                let total = /^\d+$/.test(clean) ? clean : "0"
                main.tApt = total
                totalApt(total)
                main.setRepoError("apt", false)
                if (total === "0") {
                    main.listApt = ""
                } else {
                    updater.listArch()
                }
                notifyDebounceTimer.restart()
            }

            // handle the result for the list
            const cmdIsListSnap = (updater.lastListSnapCmd !== "" && sourceCmd === updater.lastListSnapCmd)
            const cmdIsListFlatpak = (updater.lastListFlatpakCmd !== "" && sourceCmd === updater.lastListFlatpakCmd)
            const cmdIsListArch = (updater.lastListArchCmd !== "" && sourceCmd === updater.lastListArchCmd)

            if (cmdIsListArch && exitCode === 0) {
                main.listApt = stdout
                main.setRepoError("apt", false)
                notifyDebounceTimer.restart()
            }
            if (cmdIsListSnap && exitCode === 0) {
                const snapLines = stdout ? stdout.trim().split("\n").filter(function (l) { return l.trim() !== "" }) : []
                main.tSnap = String(snapLines.length)
                totalSnap(main.tSnap)
                main.listSnap = snapLines.length > 0 ? stdout : ""
                main.setRepoError("snap", false)
                notifyDebounceTimer.restart()
            }
            if (cmdIsListFlatpak && exitCode === 0) {
                const flatpakLines = stdout ? stdout.trim().split("\n").filter(function (l) { return l.trim() !== "" }) : []
                main.tFlatpak = String(flatpakLines.length)
                totalFlatpak(main.tFlatpak)
                main.listFlatpak = flatpakLines.length > 0 ? stdout : ""
                main.setRepoError("flatpak", false)
                notifyDebounceTimer.restart()
            }

            // throttled retry with backoff and cap (prevents unthrottled DoS loops)
            const cmdRepo = main.getCmdRepo(sourceCmd)
            const errDetail = (stderr && stderr.trim() !== "") ? stderr.trim() : ((exitCode === 124 || exitCode === 137) ? i18n("Update check timed out.") : i18n("Command failed with exit code %1", exitCode))
            if (isOnError && !isUpdateCmd) {
                if (plasmoid.configuration.retryMode) {
                    const currentRetries = main.retryCounts[sourceCmd] || 0
                    if (currentRetries < 2) {
                        main.retryCounts[sourceCmd] = currentRetries + 1
                        if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - scheduled retry (attempt '+(currentRetries+1)+') in 5s: ' + sourceCmd, true)
                        if (retryTimer.pendingCmds.indexOf(sourceCmd) === -1) {
                            retryTimer.pendingCmds = retryTimer.pendingCmds.concat([sourceCmd])
                        }
                        if (!retryTimer.running) {
                            retryTimer.start()
                        }
                    } else {
                        if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - max retries reached for: ' + sourceCmd, true)
                        delete main.retryCounts[sourceCmd]
                        if (cmdRepo) {
                            main.setRepoError(cmdRepo, true, errDetail)
                        } else {
                            main.hasError = true
                            main.lastErrorMessage = errDetail
                            errorStatus(true)
                        }
                    }
                } else {
                    if (cmdRepo) {
                        main.setRepoError(cmdRepo, true, errDetail)
                    } else {
                        main.hasError = true
                        main.lastErrorMessage = errDetail
                        errorStatus(true)
                    }
                }
            } else if (!isOnError && main.retryCounts[sourceCmd]) {
                delete main.retryCounts[sourceCmd]
            }

            // refresh and notifications after an update action
            if (isUpdateCmd) {
                if (isOnDebug) debug.log('APTUPDATE - an update end, refreshing : ' + sourceCmd, false)
                var job = jobInfo || { type: "all", repo: null }
                var jobType = job.type || "all"
                var jobRepo = job.repo || null
                var safeLogDir = updater.bashEscape(main.logDir)

                var jobsCopy = Object.assign({}, main.activeUpdateJobs)
                delete jobsCopy[sourceCmd]
                main.activeUpdateJobs = jobsCopy

                if (!plasmoid.configuration.silentUpdate) {
                    if (exitCode === 127) {
                        var termName = plasmoid.configuration.notCloseCommand ? plasmoid.configuration.termNoCloseCmd : plasmoid.configuration.termCmd
                        var termErrMsg = i18n("Failed to launch terminal (command not found: %1).", termName)
                        main.updateError = true
                        main.lastErrorMessage = termErrMsg
                        main.recomputeErrorState()
                        sendNotify(i18n("Update Failed"), termErrMsg, "dialog-error", "critical")
                    } else if (exitCode !== 0) {
                        var exitErrMsg = i18n("Update failed with exit code %1.", exitCode)
                        main.updateError = true
                        main.lastErrorMessage = exitErrMsg
                        main.recomputeErrorState()
                        sendNotify(i18n("Update Failed"), exitErrMsg, "dialog-error", "critical")
                    } else {
                        main.updateError = false
                        main.lastErrorMessage = ""
                        main.recomputeErrorState()
                    }
                }

                if (jobType === "all") {
                    main.isUpdatingAll = false
                    main.updatingRepos = { "apt": false, "snap": false, "flatpak": false }
                    main.updateAggregateStates()
                    main.isPkgManagerBusy = false
                    main.lockBlockedUpdate = false
                    if (plasmoid.configuration.silentUpdate) {
                        if (exitCode === 0) {
                            main.updateError = false
                            main.lastErrorMessage = ""
                            main.recomputeErrorState()
                            cmd.exec("rm -f '" + safeLogDir + "/aptupdate_last_error_all.log' 2>/dev/null")
                            if (plasmoid.configuration.notifyOnSilentUpdate) {
                                sendNotify(i18n("System Updates"), i18n("All system updates were installed successfully."), "system-software-update", "normal")
                            }
                        } else if (exitCode === 126) {
                            main.updateError = false
                            main.lastErrorMessage = ""
                            main.recomputeErrorState()
                            cmd.exec("rm -f '" + safeLogDir + "/aptupdate_last_error_all.log' 2>/dev/null")
                        } else {
                            main.updateError = true
                            main.recomputeErrorState()
                            cmd.exec("cat '" + safeLogDir + "/aptupdate_last_error_all.log' 2>/dev/null")
                        }
                    }
                    updater.countAll()
                } else if (jobType === "group") {
                    main.setRepoUpdating(jobRepo, false)
                    if (jobRepo === "apt") {
                        main.isPkgManagerBusy = false
                        main.lockBlockedUpdate = false
                    }
                    if (plasmoid.configuration.silentUpdate) {
                        if (exitCode === 0) {
                            main.updateError = false
                            main.lastErrorMessage = ""
                            main.recomputeErrorState()
                            cmd.exec("rm -f '" + safeLogDir + "/aptupdate_last_error_" + jobRepo + ".log' 2>/dev/null")
                            if (plasmoid.configuration.notifyOnSilentUpdate) {
                                var repoDisplayName = (jobRepo === "apt" ? "APT" : (jobRepo === "snap" ? "Snap" : "Flatpak"))
                                sendNotify(i18n("System Updates"), i18n("%1 updates were installed successfully.", repoDisplayName), "system-software-update", "normal")
                            }
                        } else if (exitCode === 126) {
                            main.updateError = false
                            main.lastErrorMessage = ""
                            main.recomputeErrorState()
                            cmd.exec("rm -f '" + safeLogDir + "/aptupdate_last_error_" + jobRepo + ".log' 2>/dev/null")
                        } else {
                            main.updateError = true
                            main.recomputeErrorState()
                            cmd.exec("cat '" + safeLogDir + "/aptupdate_last_error_" + jobRepo + ".log' 2>/dev/null")
                        }
                    }
                    if (jobRepo === "apt") {
                        updater.countArch()
                        updater.checkReboot()
                    } else if (jobRepo === "snap") updater.countSnap()
                    else if (jobRepo === "flatpak") updater.countFlatpak()
                } else if (jobType === "single") {
                    main.setPackageUpdating(jobRepo, job.name, job.appId, false)
                    if (jobRepo === "apt") {
                        main.isPkgManagerBusy = false
                        main.lockBlockedUpdate = false
                    }
                    if (plasmoid.configuration.silentUpdate) {
                        if (exitCode === 0) {
                            main.updateError = false
                            main.lastErrorMessage = ""
                            main.recomputeErrorState()
                            cmd.exec("rm -f '" + safeLogDir + "/aptupdate_last_error_" + jobRepo + ".log' 2>/dev/null")
                            if (plasmoid.configuration.notifyOnSilentUpdate) {
                                sendNotify(i18n("System Updates"), i18n("%1 was updated successfully.", (job.name || job.appId)), "system-software-update", "normal")
                            }
                        } else if (exitCode === 126) {
                            main.updateError = false
                            main.lastErrorMessage = ""
                            main.recomputeErrorState()
                            cmd.exec("rm -f '" + safeLogDir + "/aptupdate_last_error_" + jobRepo + ".log' 2>/dev/null")
                        } else {
                            main.updateError = true
                            main.recomputeErrorState()
                            cmd.exec("cat '" + safeLogDir + "/aptupdate_last_error_" + jobRepo + ".log' 2>/dev/null")
                        }
                    }
                    if (jobRepo === "apt") {
                        updater.countArch()
                        updater.checkReboot()
                    } else if (jobRepo === "snap") updater.countSnap()
                    else if (jobRepo === "flatpak") updater.countFlatpak()
                }

                main.updateAggregateStates()
            }

            // reference-counted completion
            const wasTrackedCheck = Boolean(main.activeCheckSources[sourceCmd])
            main.trackJobFinished(sourceCmd)
            if (!isUpdateCmd && wasTrackedCheck) {
                if (main.activeCheckJobs === 0) {
                    watchdogTimer.stop()
                    isUpdating(false)
                    main.isChecking = false
                    checkingStatus(false)
                    updater.checkLock()
                    if (!retryTimer.running && retryTimer.pendingCmds.length === 0 &&
                        !main.isInstalling && !main.isOnUpdate && !main.hasError) {
                        main.saveCache()
                        notifyDebounceTimer.restart()
                    }
                } else {
                    watchdogTimer.restart()
                }
            }
        }

        // execute the given cmd
        function exec(cmd: string) {
            if (!cmd) return
            if (connectedSources.indexOf(cmd) !== -1) return
            connectSource(cmd)
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

    // execute function count each updateInterval (minutes, hours, or days)
    Timer {
        id: timer
        interval: {
            let mult = 60000;
            if (main.intervalUnitConfig === 1) {
                mult = 3600000;
            } else if (main.intervalUnitConfig === 2) {
                mult = 86400000;
            }
            return Math.min(2147483647, Math.max(60000, (main.intervalConfig || 30) * mult));
        }
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            main.triggerAutoCheck()
        }
    }

    onExpandedChanged: {
        if (main.expanded) {
            main.isPrewarmed = true
        } else if (main.pendingAutoCheck) {
            main.pendingAutoCheck = false
            if (main.isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - popup closed, executing deferred auto-check', false)
            main.refreshAll()
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

    // handle the "show when relevant" property for the systray
    function hasUpdate() {
        const numApt = parseInt(main.tApt, 10) || 0
        const numSnap = (main.enableSnapUpdates && main.hasSnap) ? (parseInt(main.tSnap, 10) || 0) : 0
        const numFlatpak = (main.enableFlatpakUpdates && main.hasFlatpak) ? (parseInt(main.tFlatpak, 10) || 0) : 0
        return (numApt + numSnap + numFlatpak) > 0
    }
    Plasmoid.status: hasUpdate() ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    // map the UI
    compactRepresentation: Compact {}
    fullRepresentation: Loader {
        id: fullLoader
        active: Boolean(main.expanded || main.isPrewarmed)
        source: "Full.qml"
    }

    // map the context menu
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

    // load the tooltip
    toolTipItem: Loader {
        id: tooltipLoader
        Layout.minimumWidth: item ? item.implicitWidth : 0
        Layout.maximumWidth: item ? item.implicitWidth : 0
        Layout.minimumHeight: item ? item.implicitHeight : 0
        Layout.maximumHeight: item ? item.implicitHeight : 0
        source: "Tooltip.qml"
    }

    // Fallback translation hooks for Plasma Desktop configuration tabs
    function _plasmaConfigTabTranslations() {
        i18nc("@action:button set keyboard shortcut for", "Activate widget as if clicked:")
    }

    Component.onCompleted: {
        debug.clear()
        main.loadCache()
        main.isInitialized = true
        checker.checkProviders()
        if (main.startupCheckMode === 1) {
            main.refreshAll()
            prewarmTimer.start()
        } else if (main.startupCheckMode === 2) {
            startupDelayTimer.start()
        } else {
            const cachedTotal = (parseInt(main.tApt, 10) || 0) +
                ((main.enableSnapUpdates && main.hasSnap) ? (parseInt(main.tSnap, 10) || 0) : 0) +
                ((main.enableFlatpakUpdates && main.hasFlatpak) ? (parseInt(main.tFlatpak, 10) || 0) : 0)
            main.previousTotal = cachedTotal
            prewarmTimer.start()
        }
    }
}
