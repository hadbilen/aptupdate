import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.ScrollablePage {

  id: commandConfigPage

  property alias cfg_updateInterval: updateIntervalSpin.value
  property alias cfg_debugMode: debugModeBox.checked
  property alias cfg_retryMode: retryModeBox.checked
  property alias cfg_notCloseCommand: notCloseBox.checked
  property alias cfg_enableSnapUpdates: enableSnapUpdatesBox.checked
  property alias cfg_enableFlatpakUpdates: enableFlatpakUpdatesBox.checked
  property alias cfg_silentUpdate: silentUpdateBox.checked
  property alias cfg_includePhasedUpdates: includePhasedUpdatesBox.checked

  property alias cfg_updateCommand: updateCommandInput.text
  property alias cfg_updateCommandOne: updateCommandOneInput.text
  property alias cfg_countArchCommand: countArchCommandInput.text
  property alias cfg_countAurCommand: countAurCommandInput.text

  property alias cfg_listArchCommand: listArchCommandInput.text
  property alias cfg_listRepoArchCommand: listRepoArchCommandInput.text
  property alias cfg_listAurCommand: listAurCommandInput.text

  property alias cfg_termCmd: termCmdInput.text
  property alias cfg_termNoCloseCmd: termNoCloseCmdInput.text
  property alias cfg_termNoCloseSuffix: termNoCloseSuffixInput.text

  function generateCmdExample() {
    const shell = "<font color=\"" + Kirigami.Theme.disabledTextColor + "\">" + cfg_termNoCloseSuffix + "</font>'<br/>"
    const cmdA = "<font color=\"" + Kirigami.Theme.disabledTextColor + "\">" + cfg_termCmd + "</font> '<font color=\"" + Kirigami.Theme.positiveTextColor + "\">" + cfg_updateCommand + "</font>'<br/>"
    const cmdB = "<font color=\"" + Kirigami.Theme.disabledTextColor + "\">" + cfg_termCmd + "</font> '<font color=\"" + Kirigami.Theme.positiveTextColor + "\">" + cfg_updateCommandOne + "</font> packageName'<br/>"
    const cmdC = "<font color=\"" + Kirigami.Theme.disabledTextColor + "\">" + cfg_termNoCloseCmd + "</font> '<font color=\"" + Kirigami.Theme.positiveTextColor + "\">" + cfg_updateCommand + "</font>" + shell
    const cmdD = "<font color=\"" + Kirigami.Theme.disabledTextColor + "\">" + cfg_termNoCloseCmd + "</font> '<font color=\"" + Kirigami.Theme.positiveTextColor + "\">" + cfg_updateCommandOne + "</font> packageName" + shell
    return i18n("Give the following command: <br/>") + cmdA + cmdB + cmdC + cmdD
  }

  ColumnLayout {

    anchors {
      left: parent.left
      top: parent.top
      right: parent.right
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      text: i18n("This option enables logs for each command executed by the plugin.")
      visible: debugModeBox.checked
    }

    Kirigami.FormLayout {
      wideMode: false

      Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("General")
      }
    }

    Kirigami.FormLayout {

      Controls.SpinBox {
        id: updateIntervalSpin
        Kirigami.FormData.label: i18n("Update every: ")
        from: 1
        to: 1440 // 1 day
        editable: true
        textFromValue: (value) => value + " " + i18n("minute(s)")
        valueFromText: (text) => parseInt(text)
      }

      Controls.CheckBox {
        id: notCloseBox
        Kirigami.FormData.label: i18n("Do not close the terminal at the end of the upgrade action: ")
        checked: false
      }

      Controls.CheckBox {
        id: debugModeBox
        Kirigami.FormData.label: i18n("Debug: ")
        checked: false
      }

      Controls.CheckBox {
        id: retryModeBox
        Kirigami.FormData.label: i18n("Retry \"Search & count\" cmd if they are in error: ")
        checked: false
      }

    }
 
   Kirigami.FormLayout {
      wideMode: false

      Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Search & count")
      }
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      text: i18n("Pre-configured for Kubuntu / Ubuntu / Debian with APT. You can optionally use the secondary command fields for Flatpak or Snap updates.")
      visible: true
    }

    Kirigami.FormLayout {

      Controls.CheckBox {
        id: enableSnapUpdatesBox
        enabled: plasmoid.configuration.hasSnap
        Kirigami.FormData.label: plasmoid.configuration.hasSnap
          ? i18n("Enable Snap updates: ")
          : i18n("Enable Snap updates (not installed): ")
      }

      Controls.CheckBox {
        id: enableFlatpakUpdatesBox
        enabled: plasmoid.configuration.hasFlatpak
        Kirigami.FormData.label: plasmoid.configuration.hasFlatpak
          ? i18n("Enable Flatpak updates: ")
          : i18n("Enable Flatpak updates (not installed): ")
      }

      Controls.CheckBox {
        id: includePhasedUpdatesBox
        Kirigami.FormData.label: i18n("Include phased (staged) updates: ")
      }

      Controls.TextField {
        id: countArchCommandInput
        Kirigami.FormData.label: i18n("Count APT command (expected output = number): ")
      }
 
      Controls.TextField {
        id: countAurCommandInput
        Kirigami.FormData.label: i18n("Count secondary (Snap/Flatpak) command: ")
        enabled: (enableSnapUpdatesBox.checked && plasmoid.configuration.hasSnap) || (enableFlatpakUpdatesBox.checked && plasmoid.configuration.hasFlatpak)
      }

      Controls.TextField {
        id: listArchCommandInput
        Kirigami.FormData.label: i18n("List APT command (expected output = package oldver -> newver): ")
      }

      Controls.TextField {
        id: listRepoArchCommandInput
        Kirigami.FormData.label: i18n("List repository detail (optional): ")
      }

      Controls.TextField {
        id: listAurCommandInput
        Kirigami.FormData.label: i18n("List secondary (Snap/Flatpak) command: ")
        enabled: (enableSnapUpdatesBox.checked && plasmoid.configuration.hasSnap) || (enableFlatpakUpdatesBox.checked && plasmoid.configuration.hasFlatpak)
      }
    }

      Kirigami.FormLayout {
        wideMode: false

        Kirigami.Separator {
          Kirigami.FormData.isSection: true
          Kirigami.FormData.label: i18n("Update package")
        }
      }

      Kirigami.FormLayout {

        Controls.CheckBox {
          id: silentUpdateBox
          Kirigami.FormData.label: i18n("Run updates in background silently (pkexec): ")
        }

        Kirigami.Heading {
          level: 3
          width: parent.width
          text: generateCmdExample()
        }

        Controls.TextField {
          id: updateCommandInput
          Kirigami.FormData.label: i18n("Update all packages command: ")
        }

        Controls.TextField {
          id: updateCommandOneInput
          Kirigami.FormData.label: i18n("Update one package command: ")
        }

        Controls.TextField {
          id: termCmdInput
          Kirigami.FormData.label: i18n("Command for the update action: ")
        }

        Controls.TextField {
          id: termNoCloseCmdInput
          Kirigami.FormData.label: i18n("Command for the update action with do no close: ")
        }

        Controls.TextField {
          id: termNoCloseSuffixInput
          Kirigami.FormData.label: i18n("Command that run after the \"do not close\" command: ")
        }
      }

  }

}
