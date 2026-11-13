import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasmoid

Kirigami.ScrollablePage {

  id: displayConfigPage

  property alias cfg_icon: configMainIconField.value
  property alias cfg_secondaryIcon: configSecondaryIconField.value

  property bool cfg_separateResult: false
  property alias cfg_separator: separator.text

  property alias cfg_mainDot: mainDot.checked
  property alias cfg_mainDotColor: mainDotColor.color
  property alias cfg_mainDotUseCustomColor: mainDotUseCustomColor.checked
  property alias cfg_mainDotPosition: mainDotPosition.currentIndex

  property alias cfg_secondDot: secondDot.checked
  property alias cfg_secondDotColor: secondDotColor.color
  property alias cfg_secondDotUseCustomColor: secondDotUseCustomColor.checked
  property alias cfg_secondDotPosition: secondDotPosition.currentIndex

  property alias cfg_iconColor: iconColor.color
  property alias cfg_iconUseCustomColor: iconUseCustomColor.checked

  property alias cfg_hideOnZero: hideOnZero.checked

  // Stub declarations for other config entries and *Default keys injected by Plasma AppletConfiguration
  property var cfg_iconDefault
  property var cfg_secondaryIconDefault
  property var cfg_separateResultDefault
  property var cfg_separatorDefault
  property var cfg_mainDotDefault
  property var cfg_mainDotColorDefault
  property var cfg_mainDotUseCustomColorDefault
  property var cfg_mainDotPositionDefault
  property var cfg_secondDotDefault
  property var cfg_secondDotColorDefault
  property var cfg_secondDotUseCustomColorDefault
  property var cfg_secondDotPositionDefault
  property var cfg_iconColorDefault
  property var cfg_iconUseCustomColorDefault
  property var cfg_hideOnZeroDefault
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
    function onDebugLogChanged() { displayConfigPage.cfg_debugLog = plasmoid.configuration.debugLog }
    function onHasSnapChanged() { displayConfigPage.cfg_hasSnap = plasmoid.configuration.hasSnap }
    function onHasFlatpakChanged() { displayConfigPage.cfg_hasFlatpak = plasmoid.configuration.hasFlatpak }
    function onHasNalaChanged() { displayConfigPage.cfg_hasNala = plasmoid.configuration.hasNala }
    function onUseNalaChanged() { displayConfigPage.cfg_useNala = plasmoid.configuration.useNala }
    function onCachedAptCountChanged() { displayConfigPage.cfg_cachedAptCount = plasmoid.configuration.cachedAptCount }
    function onCachedSnapCountChanged() { displayConfigPage.cfg_cachedSnapCount = plasmoid.configuration.cachedSnapCount }
    function onCachedFlatpakCountChanged() { displayConfigPage.cfg_cachedFlatpakCount = plasmoid.configuration.cachedFlatpakCount }
    function onCachedPackageListChanged() { displayConfigPage.cfg_cachedPackageList = plasmoid.configuration.cachedPackageList }
    function onCachedLastCheckTimeChanged() { displayConfigPage.cfg_cachedLastCheckTime = plasmoid.configuration.cachedLastCheckTime }
  }

  ColumnLayout {
    id: mainColumnLayout
    spacing: Kirigami.Units.largeSpacing

    anchors {
      left: parent.left
      top: parent.top
      right: parent.right
    }

    // --- BÖLÜM 1: SİMGE (ICON) ---
    Kirigami.Heading {
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
      text: i18n("Icon")
      type: Kirigami.Heading.Type.Primary
      level: 2
    }

    Kirigami.InlineMessage {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Math.min(mainColumnLayout.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 32)
      text: i18n("You may need to refresh the widget to see any change if you choose another icon.\nA quick way to do that is just to hit 'Refresh' in the widget menu.")
      visible: true
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Kirigami.Units.largeSpacing * 2

      ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
          Layout.alignment: Qt.AlignHCenter
          text: i18n("Main icon: ")
          font.weight: Font.DemiBold
        }

        ConfigIcon {
          id: configMainIconField
          Layout.alignment: Qt.AlignHCenter
          defaultValue: "software-update-available.svg"
        }
      }

      ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
          Layout.alignment: Qt.AlignHCenter
          text: i18n("Refresh icon: ")
          font.weight: Font.DemiBold
        }

        ConfigIcon {
          id: configSecondaryIconField
          Layout.alignment: Qt.AlignHCenter
          defaultValue: "view-refresh.svg"
        }
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Kirigami.Units.smallSpacing

      Controls.CheckBox {
        id: iconUseCustomColor
        text: i18n("Custom icon color")
        checked: false
      }

      KQuickControls.ColorButton {
        id: iconColor
        enabled: iconUseCustomColor.checked
      }
    }

    Kirigami.Separator {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Math.min(mainColumnLayout.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 32)
    }

    // --- BÖLÜM 2: GÖRÜNÜM (DISPLAY / DOTS) ---
    Kirigami.Heading {
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
      text: i18n("Display")
      type: Kirigami.Heading.Type.Primary
      level: 2
    }

    Kirigami.InlineMessage {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Math.min(mainColumnLayout.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 32)
      text: i18n("The dot is shown only if update is needed.\nThis is the recommended option if you want to use the widget in your system tray or if you tend to have a lot of updates that the label can't handle.")
      visible: true
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Kirigami.Units.smallSpacing

      Controls.CheckBox {
        id: mainDot
        text: i18n("Show a dot in place of the label")
        checked: false
      }

      RowLayout {
        visible: mainDot.checked
        spacing: Kirigami.Units.smallSpacing

        Controls.CheckBox {
          id: mainDotUseCustomColor
          text: i18n("Custom main dot color")
          checked: false
        }

        KQuickControls.ColorButton {
          id: mainDotColor
          enabled: mainDotUseCustomColor.checked
        }

        Controls.ComboBox {
          id: mainDotPosition
          enabled: mainDot.checked
          model: [i18n("Top Right"), i18n("Top Left"), i18n("Bottom Right"), i18n("Bottom Left")]
          onActivated: cfg_mainDotPosition = currentIndex
        }
      }

      Controls.CheckBox {
        id: secondDot
        text: i18n("Separate the dot between the two commands")
        checked: false
        visible: mainDot.checked
      }

      RowLayout {
        visible: secondDot.checked && mainDot.checked
        spacing: Kirigami.Units.smallSpacing

        Controls.CheckBox {
          id: secondDotUseCustomColor
          text: i18n("Custom second dot color")
          checked: false
        }

        KQuickControls.ColorButton {
          id: secondDotColor
          enabled: secondDotUseCustomColor.checked
        }

        Controls.ComboBox {
          id: secondDotPosition
          enabled: secondDot.checked
          model: [i18n("Top Right"), i18n("Top Left"), i18n("Bottom Right"), i18n("Bottom Left")]
          onActivated: cfg_secondDotPosition = currentIndex
        }
      }
    }

    Kirigami.Separator {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Math.min(mainColumnLayout.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 32)
    }

    // --- BÖLÜM 3: GÜNCELLEME SAYISI GÖRÜNÜMÜ (COUNT DISPLAY FORMAT) ---
    Kirigami.Heading {
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
      text: i18n("Count Display Format")
      type: Kirigami.Heading.Type.Primary
      level: 2
    }

    Kirigami.InlineMessage {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Math.min(mainColumnLayout.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 32)
      text: i18n("Choose how the pending update count is displayed on the panel icon.")
      visible: true
    }

    Controls.ButtonGroup {
      id: countDisplayGroup
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Kirigami.Units.smallSpacing

      Controls.RadioButton {
        id: radioMerged
        Controls.ButtonGroup.group: countDisplayGroup
        text: i18n("Merged (single total count, e.g. 45)")
        checked: !displayConfigPage.cfg_separateResult
        onToggled: {
          if (checked) {
            displayConfigPage.cfg_separateResult = false
          }
        }
      }

      Controls.RadioButton {
        id: radioSeparated
        Controls.ButtonGroup.group: countDisplayGroup
        text: i18n("Separated (split by package source, e.g. 41 ~ 0 ~ 4)")
        checked: displayConfigPage.cfg_separateResult
        onToggled: {
          if (checked) {
            displayConfigPage.cfg_separateResult = true
          }
        }
      }

      RowLayout {
        visible: displayConfigPage.cfg_separateResult
        spacing: Kirigami.Units.smallSpacing
        Layout.leftMargin: Kirigami.Units.largeSpacing

        Controls.Label {
          text: i18n("Separator: ")
        }

        Controls.TextField {
          id: separator
          implicitWidth: Kirigami.Units.gridUnit * 6
        }
      }

      Controls.CheckBox {
        id: hideOnZero
        text: i18n("Hide label when 0 updates")
        checked: false
      }
    }

    Item {
      Layout.preferredHeight: Kirigami.Units.largeSpacing
    }
  }

}
