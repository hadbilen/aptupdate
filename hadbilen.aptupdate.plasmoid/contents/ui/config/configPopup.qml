import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasmoid

Kirigami.ScrollablePage {

    id: popupConfigPage

    property alias cfg_nameUseCustomColor: nameUseCustomColor.checked
    property alias cfg_nameColor: nameColor.color

    property alias cfg_sourceUseCustomColor: sourceUseCustomColor.checked
    property alias cfg_sourceColor: sourceColor.color

    property alias cfg_fvUseCustomColor: fvUseCustomColor.checked
    property alias cfg_fvColor: fvColor.color

    property alias cfg_separatorUseCustomColor: separatorUseCustomColor.checked
    property alias cfg_separatorColor: separatorColor.color
    property alias cfg_separatorText: separatorText.text

    property alias cfg_tvUseCustomColor: tvUseCustomColor.checked
    property alias cfg_tvColor: tvColor.color

    property alias cfg_groupUpdates: groupUpdatesBox.checked
    property alias cfg_adaptiveGrouping: adaptiveGroupingBox.checked
    property alias cfg_adaptiveGroupingThreshold: adaptiveGroupingThresholdSpin.value

    // Stub declarations for other config entries and *Default keys injected by Plasma AppletConfiguration
    property var cfg_nameUseCustomColorDefault
    property var cfg_nameColorDefault
    property var cfg_sourceUseCustomColorDefault
    property var cfg_sourceColorDefault
    property var cfg_fvUseCustomColorDefault
    property var cfg_fvColorDefault
    property var cfg_separatorUseCustomColorDefault
    property var cfg_separatorColorDefault
    property var cfg_separatorTextDefault
    property var cfg_tvUseCustomColorDefault
    property var cfg_tvColorDefault
    property var cfg_groupUpdatesDefault
    property var cfg_adaptiveGroupingDefault
    property var cfg_adaptiveGroupingThresholdDefault
    property var cfg_debugLog
    property var cfg_debugLogDefault
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
        function onDebugLogChanged() { popupConfigPage.cfg_debugLog = plasmoid.configuration.debugLog }
        function onHasSnapChanged() { popupConfigPage.cfg_hasSnap = plasmoid.configuration.hasSnap }
        function onHasFlatpakChanged() { popupConfigPage.cfg_hasFlatpak = plasmoid.configuration.hasFlatpak }
        function onHasNalaChanged() { popupConfigPage.cfg_hasNala = plasmoid.configuration.hasNala }
        function onUseNalaChanged() { popupConfigPage.cfg_useNala = plasmoid.configuration.useNala }
        function onCachedAptCountChanged() { popupConfigPage.cfg_cachedAptCount = plasmoid.configuration.cachedAptCount }
        function onCachedSnapCountChanged() { popupConfigPage.cfg_cachedSnapCount = plasmoid.configuration.cachedSnapCount }
        function onCachedFlatpakCountChanged() { popupConfigPage.cfg_cachedFlatpakCount = plasmoid.configuration.cachedFlatpakCount }
        function onCachedPackageListChanged() { popupConfigPage.cfg_cachedPackageList = plasmoid.configuration.cachedPackageList }
        function onCachedLastCheckTimeChanged() { popupConfigPage.cfg_cachedLastCheckTime = plasmoid.configuration.cachedLastCheckTime }
    }

    function escapeHtml(text) {
        if (text === undefined || text === null) return ""
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;")
    }

    // generate & style the name of the package
    function generateName() {
        const nc = cfg_nameUseCustomColor ? cfg_nameColor : Kirigami.Theme.textColor
        const sc = cfg_sourceUseCustomColor ? cfg_sourceColor : Kirigami.Theme.disabledTextColor
        return '<font color="' + nc + '"> ' + i18n("PackageName") + ' </font><font color="' + sc + '"> ' + i18n("from source") + '</font>'
    }

    // generate & style the version of the package
    function generateVersion() {
        const fvc = cfg_fvUseCustomColor ? cfg_fvColor : Kirigami.Theme.negativeTextColor
        const sc = cfg_separatorUseCustomColor ? cfg_separatorColor : Kirigami.Theme.textColor
        const tvc = cfg_tvUseCustomColor ? cfg_tvColor : Kirigami.Theme.positiveTextColor
        return '<font color="' + fvc + '">1.0.0</font><font color="' + sc + '"> ' + escapeHtml(cfg_separatorText) + ' </font><font color="' + tvc + '">2.0.0</font>'
    }

    Kirigami.FormLayout {
        id: popupFormLayout
        wideMode: false

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup color")
        }

        ColumnLayout {
            Kirigami.FormData.isSection: true
            spacing: 2

            Kirigami.Heading {
                level: 3
                Layout.fillWidth: true
                text: generateName()
            }

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: generateVersion()
            }
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: nameUseCustomColor
                text: i18n("Custom name color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: nameColor
                enabled: nameUseCustomColor.checked
            }
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: sourceUseCustomColor
                text: i18n("Custom source color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: sourceColor
                enabled: sourceUseCustomColor.checked
            }
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: fvUseCustomColor
                text: i18n("Custom 'from version' color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: fvColor
                enabled: fvUseCustomColor.checked
            }
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: separatorUseCustomColor
                text: i18n("Custom separator color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: separatorColor
                enabled: separatorUseCustomColor.checked
            }
        }

        Controls.TextField {
            id: separatorText
            Layout.fillWidth: true
            Kirigami.FormData.label: i18n("Separator: ")
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: tvUseCustomColor
                text: i18n("Custom 'to version' color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: tvColor
                enabled: tvUseCustomColor.checked
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Grouping")
        }

        Controls.CheckBox {
            id: groupUpdatesBox
            text: i18n("Group updates by repository")
            checked: true
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: adaptiveGroupingBox
            text: i18n("Adaptive accordion (auto-expand groups with few updates)")
            checked: true
            enabled: groupUpdatesBox.checked
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing
            enabled: groupUpdatesBox.checked && adaptiveGroupingBox.checked

            Controls.Label {
                text: i18n("Auto-expand threshold: ")
            }

            Controls.SpinBox {
                id: adaptiveGroupingThresholdSpin
                from: 1
                to: 25
                value: 5
                editable: true
            }

            Controls.Label {
                text: i18n("packages")
            }
        }

    }

}
