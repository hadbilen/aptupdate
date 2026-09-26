import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

import "../_toolbox" as Tb
import "../service" as Sv

PlasmoidItem {
    id: main

    property int intervalConfig: plasmoid.configuration.updateInterval
    property bool isOnDebug: plasmoid.configuration.debugMode
    property bool isOnUpdate: false
    property bool hasError: false
    property string tArch: "0"
    property string tAur: "0"
    property string listAur: ""
    property string listArch: ""
    property string listArchRepo: ""
    property bool rebootRequired: false
    property int previousTotal: -1

    function checkNotification() {
        if (!plasmoid.configuration.notifyOnUpdates) return
        const currentTotal = (parseInt(main.tArch, 10) || 0) + (parseInt(main.tAur, 10) || 0)
        if (main.previousTotal >= 0 && currentTotal > main.previousTotal && currentTotal > 0) {
            const msg = i18np("%1 update available", "%1 updates available", currentTotal)
            cmd.exec("notify-send -a 'APT Update Counter' -i system-software-update '" + i18n("System Updates") + "' '" + msg + "'")
        }
        main.previousTotal = currentTotal
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
            const isUp = source.indexOf("pkexec") !== -1 || source.indexOf("konsole") !== -1 || (updater.lastUpdateCmd !== "" && source === updater.lastUpdateCmd)
            if (isUp) {
                main.isOnUpdate = true
                main.hasError = false
                errorStatus(false)
                updateRunning(true)
            }
            isUpdating(true)
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

            // handle reboot required
            if (sourceCmd === "test -f /var/run/reboot-required && echo 1 || echo 0") {
                main.rebootRequired = (stdout.trim() === "1")
                rebootStatus(main.rebootRequired)
            }

            // handle the result for the count
            const cmdIsAur = sourceCmd === plasmoid.configuration.countAurCommand || (updater.lastCountAurCmd !== "" && sourceCmd === updater.lastCountAurCmd)
            const cmdIsArch = sourceCmd === plasmoid.configuration.countArchCommand || (updater.lastCountArchCmd !== "" && sourceCmd === updater.lastCountArchCmd)
            if (cmdIsArch) {
                let total = stdout.replace(/\n/g, '')
                totalArch(total)
                main.tArch = total
                updater.listArch()
                checkNotification()
            }
            if (cmdIsAur) {
                let total = stdout.replace(/\n/g, '')
                totalAur(total)
                main.tAur = total
                updater.listAur()
                checkNotification()
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

            // retry the cmd if error except for the upgrade (that crash the plasmoid)
            if (isOnError && !isUpdateCmd && plasmoid.configuration.retryMode) {
                if (isOnDebug) debug.log('APTUPDATE - '+plasmoid.id+' - cmd retry after error : ' + sourceCmd, true)
                cmd.exec(sourceCmd)
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

            isUpdating(false)
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
        signal connected(string source)
        signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)
    }

    // execute function count each updateInterval minutes
    Timer {
        id: timer
        interval: intervalConfig * 60000 // minute to milisecond
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

    Component.onCompleted: {
        plasmoid.configuration.debugLog = "" // clear log window
    }
}
