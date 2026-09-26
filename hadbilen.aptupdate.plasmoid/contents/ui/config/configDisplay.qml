import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.ScrollablePage {

  id: displayConfigPage

  property alias cfg_icon: configMainIconField.value
  property alias cfg_secondaryIcon: configSecondaryIconField.value

  property alias cfg_separateResult: separateResult.checked
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
          onActivated: cfg_mainDotPosition = index
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

    // --- BÖLÜM 3: ETİKET GÖRÜNÜMÜ (LABEL DISPLAY) ---
    Kirigami.Heading {
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
      text: i18n("Label display")
      type: Kirigami.Heading.Type.Primary
      level: 2
    }

    Kirigami.InlineMessage {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Math.min(mainColumnLayout.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 32)
      text: i18n("Expected result: APT + separator + Snap/Flatpak")
      visible: true
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Kirigami.Units.smallSpacing

      Controls.CheckBox {
        id: separateResult
        text: i18n("Separate result")
        checked: false
      }

      RowLayout {
        visible: separateResult.checked
        spacing: Kirigami.Units.smallSpacing

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
