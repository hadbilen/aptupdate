import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import "../../service/CommandBuilder.js" as CmdBuilder

Kirigami.ScrollablePage {

    id: debugConfigPage

    // Stub declarations for active config entries and *Default keys injected by Plasma AppletConfiguration
    property var cfg_invertMouseAction
    property var cfg_invertMouseActionDefault
    property var cfg_mainIsRefresh
    property var cfg_mainIsRefreshDefault
    property var cfg_updateInterval
    property var cfg_updateIntervalDefault
    property var cfg_updateIntervalUnit
    property var cfg_updateIntervalUnitDefault
    property var cfg_startupCheckMode
    property var cfg_startupCheckModeDefault
    property var cfg_startupDelaySeconds
    property var cfg_startupDelaySecondsDefault
    property var cfg_debugMode
    property var cfg_debugModeDefault
    property var cfg_retryMode
    property var cfg_retryModeDefault
    property var cfg_notCloseCommand
    property var cfg_notCloseCommandDefault
    property var cfg_enableSnapUpdates
    property var cfg_enableSnapUpdatesDefault
    property var cfg_enableFlatpakUpdates
    property var cfg_enableFlatpakUpdatesDefault
    property var cfg_silentUpdate
    property var cfg_silentUpdateDefault
    property var cfg_notifyOnSilentUpdate
    property var cfg_notifyOnSilentUpdateDefault
    property var cfg_includePhasedUpdates
    property var cfg_includePhasedUpdatesDefault
    property var cfg_notifyOnRebootRequired
    property var cfg_notifyOnRebootRequiredDefault
    property var cfg_hasSnap
    property var cfg_hasSnapDefault
    property var cfg_hasFlatpak
    property var cfg_hasFlatpakDefault
    property var cfg_hasNala
    property var cfg_hasNalaDefault
    property var cfg_useNala
    property var cfg_useNalaDefault
    property var cfg_updateCommandOne
    property var cfg_updateCommandOneDefault
    property var cfg_termCmd
    property var cfg_termCmdDefault
    property var cfg_termNoCloseCmd
    property var cfg_termNoCloseCmdDefault
    property var cfg_termNoCloseSuffix
    property var cfg_termNoCloseSuffixDefault
    property var cfg_icon
    property var cfg_iconDefault
    property var cfg_secondaryIcon
    property var cfg_secondaryIconDefault
    property var cfg_separateResult
    property var cfg_separateResultDefault
    property var cfg_separator
    property var cfg_separatorDefault
    property var cfg_mainDot
    property var cfg_mainDotDefault
    property var cfg_mainDotPosition
    property var cfg_mainDotPositionDefault
    property var cfg_secondDot
    property var cfg_secondDotDefault
    property var cfg_secondDotPosition
    property var cfg_secondDotPositionDefault
    property var cfg_mainDotColor
    property var cfg_mainDotColorDefault
    property var cfg_secondDotColor
    property var cfg_secondDotColorDefault
    property var cfg_mainDotUseCustomColor
    property var cfg_mainDotUseCustomColorDefault
    property var cfg_secondDotUseCustomColor
    property var cfg_secondDotUseCustomColorDefault
    property var cfg_iconColor
    property var cfg_iconColorDefault
    property var cfg_iconUseCustomColor
    property var cfg_iconUseCustomColorDefault
    property var cfg_hideOnZero
    property var cfg_hideOnZeroDefault
    property var cfg_notifyOnUpdates
    property var cfg_notifyOnUpdatesDefault
    property var cfg_notificationThreshold
    property var cfg_notificationThresholdDefault
    property var cfg_notifyOnStartup
    property var cfg_notifyOnStartupDefault
    property var cfg_notifyOnReleaseUpgrade
    property var cfg_notifyOnReleaseUpgradeDefault
    property var cfg_nameUseCustomColor
    property var cfg_nameUseCustomColorDefault
    property var cfg_nameColor
    property var cfg_nameColorDefault
    property var cfg_sourceUseCustomColor
    property var cfg_sourceUseCustomColorDefault
    property var cfg_sourceColor
    property var cfg_sourceColorDefault
    property var cfg_separatorUseCustomColor
    property var cfg_separatorUseCustomColorDefault
    property var cfg_separatorColor
    property var cfg_separatorColorDefault
    property var cfg_separatorText
    property var cfg_separatorTextDefault
    property var cfg_fvUseCustomColor
    property var cfg_fvUseCustomColorDefault
    property var cfg_fvColor
    property var cfg_fvColorDefault
    property var cfg_tvUseCustomColor
    property var cfg_tvUseCustomColorDefault
    property var cfg_tvColor
    property var cfg_tvColorDefault
    property var cfg_groupUpdates
    property var cfg_groupUpdatesDefault
    property var cfg_adaptiveGrouping
    property var cfg_adaptiveGroupingDefault
    property var cfg_adaptiveGroupingThreshold
    property var cfg_adaptiveGroupingThresholdDefault

    property string logContent: ""
    property bool isLoadingLog: false
    property string activeReadCmd: ""
    property string activeClearCmd: ""

    readonly property string cacheDir: {
        var base = StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString().replace(/^file:\/\//, "")
        if (!base) {
            var home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
            base = home ? (home + "/.cache") : ""
        }
        return base ? (base + "/hadbilen.aptupdate.plasmoid") : ""
    }
    readonly property string logFilePath: cacheDir ? (cacheDir + "/debug.log") : ""

    function refreshLog() {
        if (!logFilePath) {
            isLoadingLog = false
            return
        }
        var inner = "f='" + CmdBuilder.bashEscape(logFilePath) + "'; if [ -f \"$f\" ] && [ ! -L \"$f\" ] && [ -O \"$f\" ]; then tail -n 200 \"$f\"; fi"
        var cmdStr = "bash -c '" + CmdBuilder.bashEscape(inner) + "'"
        activeReadCmd = cmdStr
        isLoadingLog = true
        logIoSource.connectSource(cmdStr)
    }

    function clearLog() {
        if (typeof plasmoid !== "undefined" && plasmoid.rootItem && plasmoid.rootItem.debugService) {
            plasmoid.rootItem.debugService.clear()
            logContent = ""
            return
        }
        if (!cacheDir || !logFilePath) return
        var inner = "umask 077; d='" + CmdBuilder.bashEscape(cacheDir) + "'; f='" + CmdBuilder.bashEscape(logFilePath) + "'; " +
            "if [ -d \"$d\" ] && [ ! -L \"$d\" ] && [ -O \"$d\" ]; then " +
              "if [ -e \"$f\" ] && [ ! -L \"$f\" ] && [ -O \"$f\" ]; then : > \"$f\"; fi; " +
            "else exit 1; fi"
        var cmdStr = "bash -c '" + CmdBuilder.bashEscape(inner) + "'"
        activeClearCmd = cmdStr
        logIoSource.connectSource(cmdStr)
    }

    Component.onCompleted: {
        refreshLog()
    }

    Plasma5Support.DataSource {
        id: logIoSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            if (!data || data["exit code"] === undefined) return
            var exitCode = data["exit code"]
            disconnectSource(sourceName)
            var out = (data["stdout"] !== undefined) ? String(data["stdout"]) : ""
            if (sourceName === debugConfigPage.activeReadCmd) {
                debugConfigPage.isLoadingLog = false
                if (exitCode === 0) {
                    debugConfigPage.logContent = out.trimEnd()
                } else {
                    console.warn("APTUPDATE showLog read failed (exit " + exitCode + ")")
                }
            } else if (sourceName === debugConfigPage.activeClearCmd) {
                if (exitCode === 0) {
                    debugConfigPage.logContent = ""
                } else {
                    console.warn("APTUPDATE showLog clear failed (exit " + exitCode + ")")
                }
            }
        }
    }

    Connections {
        target: plasmoid.configuration
        function onHasSnapChanged() { debugConfigPage.cfg_hasSnap = plasmoid.configuration.hasSnap }
        function onHasFlatpakChanged() { debugConfigPage.cfg_hasFlatpak = plasmoid.configuration.hasFlatpak }
        function onHasNalaChanged() { debugConfigPage.cfg_hasNala = plasmoid.configuration.hasNala }
        function onUseNalaChanged() { debugConfigPage.cfg_useNala = plasmoid.configuration.useNala }
    }

    ColumnLayout {
        id: debugFormLayout
        spacing: Kirigami.Units.smallSpacing

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
            margins: Kirigami.Units.smallSpacing
        }

        Kirigami.Heading {
            level: 2
            text: i18n("Debug log")
        }

        Controls.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Stored in cache file: %1", debugConfigPage.logFilePath)
            textFormat: Text.PlainText
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Button {
                icon.name: "view-refresh"
                text: i18n("Refresh")
                enabled: !debugConfigPage.isLoadingLog
                onClicked: debugConfigPage.refreshLog()
            }

            PlasmaComponents.Button {
                icon.name: "edit-copy"
                text: i18n("Copy")
                enabled: debugConfigPage.logContent !== ""
                onClicked: {
                    logTextArea.selectAll()
                    logTextArea.copy()
                    logTextArea.deselect()
                }
            }

            PlasmaComponents.Button {
                icon.name: "edit-clear"
                text: i18n("Clear log data")
                onClicked: debugConfigPage.clearLog()
            }
        }

        Controls.TextArea {
            id: logTextArea
            Layout.fillWidth: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 16
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: Text.PlainText
            font.family: "monospace"
            text: debugConfigPage.logContent !== "" ? debugConfigPage.logContent : i18n("No debug log entries recorded yet.")
        }
    }
}
