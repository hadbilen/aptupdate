import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

import "../service" as Sv

PlasmoidItem {
    id: main

    property int intervalConfig: plasmoid.configuration.updateInterval
    property int intervalUnitConfig: plasmoid.configuration.updateIntervalUnit !== undefined ? plasmoid.configuration.updateIntervalUnit : 0
    property bool isOnDebug: plasmoid.configuration.debugMode
    property bool isOnUpdate: false
    property bool hasError: false
    property bool isPkgManagerBusy: false
    property int activeJobs: 0
    property string tArch: "0"
    property string tAur: "0"
    property string listAur: ""
    property string listArch: ""
    property string listArchRepo: ""
    property bool rebootRequired: false
    property bool previousRebootRequired: false
    property bool hasSnap: plasmoid.configuration.hasSnap
    property bool hasFlatpak: plasmoid.configuration.hasFlatpak
    property int previousTotal: -1
    property var retryCounts: ({})

    function checkNotification() {
        if (!plasmoid.configuration.notifyOnUpdates) return
        const currentTotal = (parseInt(main.tArch, 10) || 0) + (parseInt(main.tAur, 10) || 0)
        if (main.previousTotal >= 0 && currentTotal > main.previousTotal && currentTotal > 0) {
            const msg = i18np("%1 update available", "%1 updates available", currentTotal)
            cmd.exec("notify-send -a 'APT Update Counter' -i system-software-update '" + i18n("System Updates") + "' '" + msg + "'")
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
        property string pendingCmd: ""
        onTriggered: {
            if (pendingCmd !== "") {
                cmd.exec(pendingCmd)
                pendingCmd = ""
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
            exited(sourceName, exitCode, exitStatus, stdout, stderr)
            disconnectSource(sourceName)
        }

        onSourceConnected: function (source) {
            if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - cmd connected: ' + source, false)
            main.activeJobs++
            isUpdating(true)

            const isUp = source.startsWith(plasmoid.configuration.termCmd) ||
                         source.startsWith(plasmoid.configuration.termNoCloseCmd) ||
                         source.indexOf("konsole") !== -1 ||
                         source.indexOf("pkexec") !== -1 ||
                         (updater.lastUpdateCmd !== "" && source === updater.lastUpdateCmd)
            if (isUp) {
                main.isOnUpdate = true
                main.hasError = false
                errorStatus(false)
                updateRunning(true)
            }
            connected(source)
        }

        onExited: function (sourceCmd, exitCode, exitStatus, stdout, stderr) {
            if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - cmd exited: ' + JSON.stringify({sourceCmd, exitCode, exitStatus, stdout, stderr}), stderr !== "")

            const isUpdateCmd = sourceCmd.startsWith(plasmoid.configuration.termCmd) ||
                                sourceCmd.startsWith(plasmoid.configuration.termNoCloseCmd) ||
                                sourceCmd.indexOf("konsole") !== -1 ||
                                sourceCmd.indexOf("pkexec") !== -1 ||
                                (updater.lastUpdateCmd !== "" && sourceCmd === updater.lastUpdateCmd)
            const isOnError = exitCode !== 0 && stderr !== ""

            // handle lock check
            if (sourceCmd === "fuser /var/lib/dpkg/lock-frontend 2>/dev/null && echo 1 || echo 0") {
                main.isPkgManagerBusy = (stdout.trim() === "1")
                pkgManagerBusyStatus(main.isPkgManagerBusy)
            }

            // handle reboot required
            if (sourceCmd === "test -f /var/run/reboot-required && echo 1 || echo 0") {
                const isReboot = (stdout.trim() === "1")
                if (isReboot && !main.previousRebootRequired && plasmoid.configuration.notifyOnRebootRequired) {
                    cmd.exec("notify-send -u normal -a 'APT Update Counter' -i system-reboot '" + i18n("System Restart Required") + "' '" + i18n("A system restart is required to complete updates.") + "'")
                }
                main.previousRebootRequired = isReboot
                main.rebootRequired = isReboot
                rebootStatus(main.rebootRequired)
            }

            // handle the result for the count with numeric sanitization (anti-NaN)
            const cmdIsAur = sourceCmd === plasmoid.configuration.countAurCommand || (updater.lastCountAurCmd !== "" && sourceCmd === updater.lastCountAurCmd)
            const cmdIsArch = sourceCmd === plasmoid.configuration.countArchCommand || (updater.lastCountArchCmd !== "" && sourceCmd === updater.lastCountArchCmd)
            if (cmdIsArch) {
                let clean = stdout.trim()
                let total = /^\d+$/.test(clean) ? clean : "0"
                totalArch(total)
                main.tArch = total
                updater.listArch()
                notifyDebounceTimer.restart()
            }
            if (cmdIsAur) {
                let clean = stdout.trim()
                let total = /^\d+$/.test(clean) ? clean : "0"
                totalAur(total)
                main.tAur = total
                updater.listAur()
                notifyDebounceTimer.restart()
            }

            // auto-clear error state on clean count
            if (!isOnError && !isUpdateCmd && (cmdIsArch || cmdIsAur)) {
                main.hasError = false
                errorStatus(false)
            }

            // handle the result for the list
            const cmdIsListAur = sourceCmd === plasmoid.configuration.listAurCommand || (updater.lastListAurCmd !== "" && sourceCmd === updater.lastListAurCmd)
            const cmdIsListArch = sourceCmd === plasmoid.configuration.listArchCommand || (updater.lastListArchCmd !== "" && sourceCmd === updater.lastListArchCmd)
            const cmdIsListArchRepo = sourceCmd === plasmoid.configuration.listRepoArchCommand
            if (cmdIsListAur) listAur = stdout
            if (cmdIsListArch) listArch = stdout
            if (cmdIsListArchRepo) listArchRepo = stdout
            if (cmdIsListAur || cmdIsListArch) {
                packagesList(listAur, listArch, listArchRepo)
            }

            // handle the result for the checker
            if (sourceCmd === "konsole -v") checker.validateKonsole(stderr)
            if (sourceCmd === "apt --version") checker.validateCheckupdates(stderr)
            if (sourceCmd === "which snap >/dev/null 2>&1 && echo 1 || echo 0") {
                checker.validateSnap(stdout)
                main.hasSnap = plasmoid.configuration.hasSnap
            }
            if (sourceCmd === "which flatpak >/dev/null 2>&1 && echo 1 || echo 0") {
                checker.validateFlatpak(stdout)
                main.hasFlatpak = plasmoid.configuration.hasFlatpak
            }

            // throttled retry with backoff and cap (prevents unthrottled DoS loops)
            if (isOnError && !isUpdateCmd && plasmoid.configuration.retryMode) {
                const currentRetries = main.retryCounts[sourceCmd] || 0
                if (currentRetries < 2 && !retryTimer.running) {
                    main.retryCounts[sourceCmd] = currentRetries + 1
                    if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - scheduled retry (attempt '+(currentRetries+1)+') in 5s: ' + sourceCmd, true)
                    retryTimer.pendingCmd = sourceCmd
                    retryTimer.restart()
                } else if (currentRetries >= 2) {
                    if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - max retries reached for: ' + sourceCmd, true)
                    delete main.retryCounts[sourceCmd]
                }
            } else if (!isOnError && main.retryCounts[sourceCmd]) {
                delete main.retryCounts[sourceCmd]
            }

            // refresh and notifications after an update action
            if (isUpdateCmd) {
                if (isOnDebug) debug.log('APTUPDATE - an update end, refreshing : ' + sourceCmd, false)
                main.isOnUpdate = false
                updateRunning(false)
                const isSilent = sourceCmd.indexOf("pkexec") !== -1 || (updater.lastUpdateCmd !== "" && sourceCmd === updater.lastUpdateCmd && plasmoid.configuration.silentUpdate)
                if (isSilent) {
                    if (exitCode === 0) {
                        main.hasError = false
                        errorStatus(false)
                        if (plasmoid.configuration.notifyOnSilentUpdate) {
                            cmd.exec("notify-send -a 'APT Update Counter' -i system-software-update '" + i18n("System Updates") + "' '" + i18n("All system updates were installed successfully.") + "'")
                        }
                    } else {
                        main.hasError = true
                        errorStatus(true)
                        cmd.exec("notify-send -u critical -a 'APT Update Counter' -i dialog-error '" + i18n("Update Failed") + "' '" + i18n("An error occurred during the background update.") + "'")
                    }
                }
                updater.countAll()
            }

            // reference-counted completion
            main.activeJobs = Math.max(0, main.activeJobs - 1)
            if (main.activeJobs === 0) {
                isUpdating(false)
            }
        }

        // execute the given cmd
        function exec(cmd: string) {
            if (!cmd) return
            connectSource(cmd)
        }

        signal isUpdating(bool status)
        signal updateRunning(bool running)
        signal errorStatus(bool error)
        signal packagesList(string listAur, string listArch, string listArchRepo)
        signal totalAur(string total)
        signal totalArch(string total)
        signal rebootStatus(bool required)
        signal pkgManagerBusyStatus(bool busy)
        signal connected(string source)
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
            return Math.max(60000, (main.intervalConfig || 30) * mult);
        }
        running: true
        repeat: true
        triggeredOnStart: true // trigger on start for a first check
        onTriggered: updater.countAll()
    }

    // handle the "show when relevant" property for the systray
    function hasUpdate() {
        return !(tArch === "0" && tAur === "0")
    }
    Plasmoid.status: hasUpdate() ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    // map the UI
    compactRepresentation: Compact {}
    fullRepresentation: Full {}

    // map the context menu
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Update")
            icon.name: "install-symbolic"
            enabled: !main.isPkgManagerBusy && !main.isOnUpdate
            onTriggered: {
                updater.launchUpdate()
            }
        },
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh-symbolic"
            onTriggered: {
                updater.countAll()
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
        plasmoid.configuration.debugLog = "" // clear log window
        checker.checkProviders()
    }
}
