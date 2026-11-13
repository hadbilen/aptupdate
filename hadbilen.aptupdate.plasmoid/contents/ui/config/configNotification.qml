import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Kirigami.ScrollablePage {

    id: notificationConfigPage

    property alias cfg_notifyOnUpdates: notifyOnUpdatesBox.checked
    property alias cfg_notificationThreshold: notificationThresholdSpin.value
    property alias cfg_notifyOnStartup: notifyOnStartupBox.checked
    property alias cfg_notifyOnRebootRequired: notifyOnRebootRequiredBox.checked
    property alias cfg_notifyOnReleaseUpgrade: notifyOnReleaseUpgradeBox.checked
    property alias cfg_notifyOnSilentUpdate: notifyOnSilentUpdateBox.checked

    // Stub declarations for other config entries and *Default keys injected by Plasma AppletConfiguration
    property var cfg_notifyOnUpdatesDefault
    property var cfg_notificationThresholdDefault
    property var cfg_notifyOnStartupDefault
    property var cfg_notifyOnRebootRequiredDefault
    property var cfg_notifyOnReleaseUpgradeDefault
    property var cfg_notifyOnSilentUpdateDefault
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
    property var cfg_includePhasedUpdates
    property var cfg_includePhasedUpdatesDefault
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

    Connections {
        target: plasmoid.configuration
        function onHasSnapChanged() { notificationConfigPage.cfg_hasSnap = plasmoid.configuration.hasSnap }
        function onHasFlatpakChanged() { notificationConfigPage.cfg_hasFlatpak = plasmoid.configuration.hasFlatpak }
        function onHasNalaChanged() { notificationConfigPage.cfg_hasNala = plasmoid.configuration.hasNala }
        function onUseNalaChanged() { notificationConfigPage.cfg_useNala = plasmoid.configuration.useNala }
    }

    Kirigami.FormLayout {
        id: notificationFormLayout
        wideMode: false

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Desktop Notifications")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            text: i18n("Critical update failures are always notified regardless of these settings to ensure system stability.\nEven if desktop notifications are turned off, system restart requirements will still be shown as a status banner in the popup.")
            type: Kirigami.MessageType.Information
            visible: true
        }

        Controls.CheckBox {
            id: notifyOnUpdatesBox
            text: i18n("Notify when new updates are found")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing
            enabled: notifyOnUpdatesBox.checked

            Controls.Label {
                text: i18n("Minimum pending updates required to notify: ")
            }

            Controls.SpinBox {
                id: notificationThresholdSpin
                from: 1
                to: 20
                value: 1
                editable: true
            }

            Controls.Label {
                text: i18n("updates")
            }
        }

        Controls.CheckBox {
            id: notifyOnStartupBox
            text: i18n("Notify if updates exceed threshold on session login")
            enabled: notifyOnUpdatesBox.checked
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: notifyOnRebootRequiredBox
            text: i18n("Send desktop notification when system restart is required")
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: notifyOnReleaseUpgradeBox
            text: i18n("Notify when a new distribution release is available")
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: notifyOnSilentUpdateBox
            text: i18n("Notify on silent update completion")
            Kirigami.FormData.isSection: true
        }
    }

}
