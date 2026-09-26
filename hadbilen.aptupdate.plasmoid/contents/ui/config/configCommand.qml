import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

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
    id: mainColumnLayout
    spacing: Kirigami.Units.largeSpacing

    anchors {
      left: parent.left
      top: parent.top
    }
    width: Math.max(commandConfigPage.width, commandsFormLayout.implicitWidth + Kirigami.Units.gridUnit * 2)

    // --- GENEL BÖLÜMÜ (ORTALANMIŞ) ---
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
            to: updateIntervalUnitCombo.currentIndex === 0 ? 1440 : (updateIntervalUnitCombo.currentIndex === 1 ? 168 : 365)
            editable: true
          }

          Controls.ComboBox {
            id: updateIntervalUnitCombo
            model: [i18n("Minute(s)"), i18n("Hour(s)"), i18n("Day(s)")]
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

      Component.onCompleted: {
        var lay = commandsFormLayout.children[0];
        lay.anchors.horizontalCenter = undefined;
        lay.anchors.left = commandsFormLayout.left;
        lay.anchors.right = commandsFormLayout.right;
      }

      Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Search & count")
      }

      Kirigami.InlineMessage {
        Layout.fillWidth: true
        Kirigami.FormData.isSection: true
        text: i18n("Pre-configured for Kubuntu / Ubuntu / Debian with APT. You can optionally use the secondary command fields for Flatpak or Snap updates.")
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

    Controls.TextField {
      id: countArchCommandInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Count APT command (expected output = number): ")
    }

    Controls.TextField {
      id: countAurCommandInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Count secondary (Snap/Flatpak) command: ")
      enabled: (enableSnapUpdatesBox.checked && plasmoid.configuration.hasSnap) || (enableFlatpakUpdatesBox.checked && plasmoid.configuration.hasFlatpak)
    }

    Controls.TextField {
      id: listArchCommandInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("List APT command (expected output = package oldver -> newver): ")
    }

    Controls.TextField {
      id: listRepoArchCommandInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("List repository detail (optional): ")
    }

    Controls.TextField {
      id: listAurCommandInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("List secondary (Snap/Flatpak) command: ")
      enabled: (enableSnapUpdatesBox.checked && plasmoid.configuration.hasSnap) || (enableFlatpakUpdatesBox.checked && plasmoid.configuration.hasFlatpak)
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

    Kirigami.Heading {
      level: 3
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      text: generateCmdExample()
      Kirigami.FormData.isSection: true
    }

    Controls.TextField {
      id: updateCommandInput
      selectByMouse: true
      Layout.fillWidth: true
      Layout.preferredWidth: Math.max(750, contentWidth + Kirigami.Units.gridUnit * 2)
      Kirigami.FormData.label: i18n("Update all packages command: ")
    }

    Controls.TextField {
      id: updateCommandOneInput
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
      Kirigami.FormData.label: i18n("Command for the update action with do no close: ")
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
