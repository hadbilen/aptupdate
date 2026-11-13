import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../../service/CommandBuilder.js" as CmdBuilder

Kirigami.ScrollablePage {

  id: commandConfigPage

  horizontalScrollBarPolicy: Controls.ScrollBar.AsNeeded

  // Prevent unwanted horizontal jumping/paging on focus while preserving smooth vertical navigation
  function ensureVisible(item, xOffset, yOffset) {
    if (!item || !flickable) return
    var actualItemY = item.y + (yOffset ?? 0)
    var viewYPosition = (item.height <= flickable.height)
      ? Math.round(actualItemY + item.height / 2 - flickable.height / 2)
      : actualItemY
    if (actualItemY < flickable.contentY) {
      flickable.contentY = Math.max(0, viewYPosition)
    } else if ((actualItemY + item.height) > (flickable.contentY + flickable.height)) {
      flickable.contentY = Math.min(flickable.contentHeight - flickable.height, viewYPosition)
    }
    flickable.returnToBounds()
  }

  Component.onCompleted: {
    flickable.flickableDirection = Flickable.VerticalFlick
    var reqWidth = () => Math.max(commandConfigPage.width, commandsFormLayout.implicitWidth + Kirigami.Units.gridUnit * 2)
    flickable.contentWidth = Qt.binding(reqWidth)
    if (mainColumnLayout.parent && mainColumnLayout.parent.parent) {
      mainColumnLayout.parent.parent.width = Qt.binding(reqWidth)
    }
  }

  property alias cfg_updateInterval: updateIntervalSpin.value
  property alias cfg_updateIntervalUnit: updateIntervalUnitCombo.currentIndex
  property alias cfg_startupCheckMode: startupCheckModeCombo.currentIndex
  property alias cfg_startupDelaySeconds: startupDelaySecondsSpin.value
  property alias cfg_debugMode: debugModeBox.checked
  property alias cfg_retryMode: retryModeBox.checked
  property alias cfg_notCloseCommand: notCloseBox.checked
  property alias cfg_enableSnapUpdates: enableSnapUpdatesBox.checked
  property alias cfg_enableFlatpakUpdates: enableFlatpakUpdatesBox.checked
  property alias cfg_silentUpdate: silentUpdateBox.checked
  property alias cfg_includePhasedUpdates: includePhasedUpdatesBox.checked
  property alias cfg_useNala: useNalaBox.checked

  property alias cfg_updateCommandOne: updateCommandOneInput.text
  property alias cfg_termCmd: termCmdInput.text
  property alias cfg_termNoCloseCmd: termNoCloseCmdInput.text
  property alias cfg_termNoCloseSuffix: termNoCloseSuffixInput.text

  // Stub declarations for other config entries and *Default keys injected by Plasma AppletConfiguration
  property var cfg_updateIntervalDefault
  property var cfg_updateIntervalUnitDefault
  property var cfg_startupCheckModeDefault
  property var cfg_startupDelaySecondsDefault
  property var cfg_debugModeDefault
  property var cfg_retryModeDefault
  property var cfg_notCloseCommandDefault
  property var cfg_enableSnapUpdatesDefault
  property var cfg_enableFlatpakUpdatesDefault
  property var cfg_silentUpdateDefault
  property var cfg_includePhasedUpdatesDefault
  property var cfg_updateCommandOneDefault
  property var cfg_termCmdDefault
  property var cfg_termNoCloseCmdDefault
  property var cfg_termNoCloseSuffixDefault
  property var cfg_invertMouseAction
  property var cfg_invertMouseActionDefault
  property var cfg_mainIsRefresh
  property var cfg_mainIsRefreshDefault
  property var cfg_notifyOnSilentUpdate
  property var cfg_notifyOnSilentUpdateDefault
  property var cfg_notifyOnRebootRequired
  property var cfg_notifyOnRebootRequiredDefault
  property var cfg_hasSnap
  property var cfg_hasSnapDefault
  property var cfg_hasFlatpak
  property var cfg_hasFlatpakDefault
  property var cfg_hasNala
  property var cfg_hasNalaDefault
  property var cfg_useNalaDefault
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

  Connections {
    target: plasmoid.configuration
    function onHasSnapChanged() { commandConfigPage.cfg_hasSnap = plasmoid.configuration.hasSnap }
    function onHasFlatpakChanged() { commandConfigPage.cfg_hasFlatpak = plasmoid.configuration.hasFlatpak }
    function onHasNalaChanged() { commandConfigPage.cfg_hasNala = plasmoid.configuration.hasNala }
  }

  function getEffectiveCountCommand() {
    return CmdBuilder.buildCountArchCmd(includePhasedUpdatesBox.checked)
  }

  function getEffectiveListCommand() {
    return CmdBuilder.buildListArchCmd(includePhasedUpdatesBox.checked)
  }

  function getEffectivePreviewCommand() {
    var opts = {
      aptCount: 1,
      snapCount: (enableSnapUpdatesBox.checked && plasmoid.configuration.hasSnap) ? 1 : 0,
      flatpakCount: (enableFlatpakUpdatesBox.checked && plasmoid.configuration.hasFlatpak) ? 1 : 0,
      enableSnapUpdates: enableSnapUpdatesBox.checked,
      enableFlatpakUpdates: enableFlatpakUpdatesBox.checked,
      hasSnap: plasmoid.configuration.hasSnap,
      hasFlatpak: plasmoid.configuration.hasFlatpak,
      useNala: useNalaBox.checked,
      hasNala: plasmoid.configuration.hasNala,
      includePhasedUpdates: includePhasedUpdatesBox.checked,
      runApt: true,
      runSnap: Boolean(enableSnapUpdatesBox.checked && plasmoid.configuration.hasSnap),
      runFlatpak: Boolean(enableFlatpakUpdatesBox.checked && plasmoid.configuration.hasFlatpak)
    }
    if (silentUpdateBox.checked) {
      return CmdBuilder.buildEffectiveSilentUpdateCmd(opts)
    }
    return CmdBuilder.buildEffectiveUpdateCmd(opts)
  }

  ColumnLayout {
    id: mainColumnLayout
    spacing: Kirigami.Units.largeSpacing

    anchors {
      left: parent.left
      top: parent.top
    }
    width: Math.max(commandConfigPage.width, commandsFormLayout.implicitWidth + Kirigami.Units.gridUnit * 2)

    // --- GENERAL SECTION (CENTERED) ---
    Item {
      Layout.preferredWidth: Math.min(commandConfigPage.width, mainColumnLayout.width)
      Layout.preferredHeight: generalContentCol.implicitHeight

      ColumnLayout {
        id: generalContentCol
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
          Layout.alignment: Qt.AlignHCenter
          horizontalAlignment: Text.AlignHCenter
          text: i18n("General")
          type: Kirigami.Heading.Type.Primary
          level: 2
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Kirigami.Units.smallSpacing

          Controls.Label {
            text: i18n("Update every: ")
          }

          Controls.SpinBox {
            id: updateIntervalSpin
            from: 1
            to: updateIntervalUnitCombo.currentIndex === 0 ? 1440 : (updateIntervalUnitCombo.currentIndex === 1 ? 168 : 24)
            editable: true
          }

          Controls.ComboBox {
            id: updateIntervalUnitCombo
            model: [i18n("Minute(s)"), i18n("Hour(s)"), i18n("Day(s)")]
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Kirigami.Units.smallSpacing

          Controls.Label {
            text: i18n("Startup check: ")
          }

          Controls.ComboBox {
            id: startupCheckModeCombo
            model: [
              i18n("Do not check on startup"),
              i18n("Check immediately"),
              i18n("Check after delay")
            ]
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Kirigami.Units.smallSpacing
          visible: startupCheckModeCombo.currentIndex === 2

          Controls.Label {
            text: i18n("Startup delay: ")
          }

          Controls.SpinBox {
            id: startupDelaySecondsSpin
            from: 5
            to: 3600
            stepSize: 5
            editable: true
          }

          Controls.Label {
            text: i18n("seconds")
          }
        }

        Controls.CheckBox {
          id: notCloseBox
          Layout.alignment: Qt.AlignLeft
          text: i18n("Do not close the terminal at the end of the upgrade action")
          checked: false
        }

        Controls.CheckBox {
          id: debugModeBox
          Layout.alignment: Qt.AlignLeft
          text: i18n("Debug")
          checked: false
        }

        Kirigami.InlineMessage {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: Math.min(commandConfigPage.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 32)
          text: i18n("This option enables logs for each command executed by the plugin.")
          visible: debugModeBox.checked
        }

        Controls.CheckBox {
          id: retryModeBox
          Layout.alignment: Qt.AlignLeft
          text: i18n("Retry \"Search & count\" cmd if they are in error")
          checked: false
        }
      }
    }

    Kirigami.Separator {
      Layout.fillWidth: true
    }

    Kirigami.FormLayout {
      id: commandsFormLayout
      Layout.fillWidth: true
      wideMode: true

      Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Search & count")
      }

      Kirigami.InlineMessage {
        Layout.fillWidth: true
        Kirigami.FormData.isSection: true
        text: i18n("Pre-configured for Kubuntu / Ubuntu / Debian with APT, Snap, and Flatpak support.")
        visible: true
      }

    Controls.CheckBox {
      id: enableSnapUpdatesBox
      enabled: plasmoid.configuration.hasSnap
      text: plasmoid.configuration.hasSnap
        ? i18n("Enable Snap updates")
        : i18n("Enable Snap updates (not installed)")
      Kirigami.FormData.isSection: true
    }

    Controls.CheckBox {
      id: enableFlatpakUpdatesBox
      enabled: plasmoid.configuration.hasFlatpak
      text: plasmoid.configuration.hasFlatpak
        ? i18n("Enable Flatpak updates")
        : i18n("Enable Flatpak updates (not installed)")
      Kirigami.FormData.isSection: true
    }

    Controls.CheckBox {
      id: includePhasedUpdatesBox
      text: i18n("Include phased (staged) updates")
      Kirigami.FormData.isSection: true
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      Kirigami.FormData.isSection: true
      type: Kirigami.MessageType.Information
      text: i18n("Search and count commands are managed internally to match the backend parser's expected output format and are provided as read-only preview.")
      visible: true
    }

    Controls.TextField {
      id: countArchCommandInput
      readOnly: true
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Count APT command (preview): ")
      text: getEffectiveCountCommand()
    }

    Controls.TextField {
      id: listArchCommandInput
      readOnly: true
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("List APT command (preview): ")
      text: getEffectiveListCommand()
    }

    Kirigami.Separator {
      Kirigami.FormData.isSection: true
      Kirigami.FormData.label: i18n("Update package")
    }

    Controls.CheckBox {
      id: silentUpdateBox
      text: i18n("Run updates in background silently (pkexec)")
      Kirigami.FormData.isSection: true
    }

    Controls.CheckBox {
      id: useNalaBox
      text: i18n("Use Nala for APT upgrades (terminal mode only)")
      enabled: Boolean(plasmoid.configuration.hasNala) && !silentUpdateBox.checked
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      type: Kirigami.MessageType.Information
      text: !plasmoid.configuration.hasNala
        ? i18n("Nala was not found on this system (sudo apt install nala).")
        : (silentUpdateBox.checked
          ? i18n("Silent background updates (pkexec) always use apt-get; Nala is only used in terminal mode.")
          : i18n("Uses 'nala upgrade --no-autoremove' in terminal mode. Checks and pending lists use 'apt-get --with-new-pkgs', so Nala may defer new-package transitions and report fewer installed packages than listed."))
      visible: useNalaBox.checked || !plasmoid.configuration.hasNala
    }

    Controls.TextField {
      id: updateCommandPreview
      readOnly: true
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Final update command preview: ")
      text: getEffectivePreviewCommand()
    }

    Controls.TextField {
      id: updateCommandOneInput
      enabled: !silentUpdateBox.checked
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Update one package command: ")
    }

    Controls.TextField {
      id: termCmdInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Command for the update action: ")
    }

    Controls.TextField {
      id: termNoCloseCmdInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Command for the update action with do not close: ")
    }

    Controls.TextField {
      id: termNoCloseSuffixInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Command that run after the \"do not close\" command: ")
    }

  }

  Item {
    Layout.preferredHeight: Kirigami.Units.largeSpacing
  }
}

}
