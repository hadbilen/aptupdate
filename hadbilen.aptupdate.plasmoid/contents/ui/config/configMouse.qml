import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Kirigami.ScrollablePage {

    id: mouseConfigPage

    property bool cfg_invertMouseAction: false
    property alias cfg_mainIsRefresh: mainIsRefresh.checked

    // Stub declarations for other config entries and *Default keys injected by Plasma AppletConfiguration
    property var cfg_invertMouseActionDefault
    property var cfg_mainIsRefreshDefault
    property var cfg_debugLog
    property var cfg_debugLogDefault
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
    property var cfg_cachedAptCount
    property var cfg_cachedAptCountDefault
    property var cfg_cachedSnapCount
    property var cfg_cachedSnapCountDefault
    property var cfg_cachedFlatpakCount
    property var cfg_cachedFlatpakCountDefault
    property var cfg_cachedPackageList
    property var cfg_cachedPackageListDefault
    property var cfg_cachedLastCheckTime
    property var cfg_cachedLastCheckTimeDefault

    Connections {
        target: plasmoid.configuration
        function onDebugLogChanged() { mouseConfigPage.cfg_debugLog = plasmoid.configuration.debugLog }
        function onHasSnapChanged() { mouseConfigPage.cfg_hasSnap = plasmoid.configuration.hasSnap }
        function onHasFlatpakChanged() { mouseConfigPage.cfg_hasFlatpak = plasmoid.configuration.hasFlatpak }
        function onHasNalaChanged() { mouseConfigPage.cfg_hasNala = plasmoid.configuration.hasNala }
        function onUseNalaChanged() { mouseConfigPage.cfg_useNala = plasmoid.configuration.useNala }
        function onCachedAptCountChanged() { mouseConfigPage.cfg_cachedAptCount = plasmoid.configuration.cachedAptCount }
        function onCachedSnapCountChanged() { mouseConfigPage.cfg_cachedSnapCount = plasmoid.configuration.cachedSnapCount }
        function onCachedFlatpakCountChanged() { mouseConfigPage.cfg_cachedFlatpakCount = plasmoid.configuration.cachedFlatpakCount }
        function onCachedPackageListChanged() { mouseConfigPage.cfg_cachedPackageList = plasmoid.configuration.cachedPackageList }
        function onCachedLastCheckTimeChanged() { mouseConfigPage.cfg_cachedLastCheckTime = plasmoid.configuration.cachedLastCheckTime }
    }

    Kirigami.FormLayout {
        id: mouseFormLayout
        wideMode: false

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Mouse action")
        }

        ColumnLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.RadioButton {
                id: normalMouseAction
                text: i18n("Left click to open popup, middle click to update")
                checked: !mouseConfigPage.cfg_invertMouseAction
                autoExclusive: true
                onToggled: {
                    if (checked) {
                        mouseConfigPage.cfg_invertMouseAction = false
                    }
                }
            }

            PlasmaComponents.RadioButton {
                id: invertMouseAction
                text: i18n("Middle click to open popup, left click to update")
                checked: mouseConfigPage.cfg_invertMouseAction
                autoExclusive: true
                onToggled: {
                    if (checked) {
                        mouseConfigPage.cfg_invertMouseAction = true
                    }
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Main action behavior")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            text: i18n("Doing both at the same time is prone to bug so it's not possible")
            visible: true
        }

        Controls.CheckBox {
            id: mainIsRefresh
            text: i18n("Do a refresh in place of opening the popup")
            checked: false
            Kirigami.FormData.isSection: true
        }

    }

}
