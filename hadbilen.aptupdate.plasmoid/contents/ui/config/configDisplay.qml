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

    anchors {
      left: parent.left
      top: parent.top
      right: parent.right
    }

    Kirigami.FormLayout {
      wideMode: false

      Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Icon")
      }
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      text: i18n("You may need to refresh the widget to see any change if you choose another icon.\nA quick way to do that is just to hit 'Refresh' in the widget menu.")
      visible: true
    }

    Kirigami.FormLayout {
      Layout.fillWidth: true

      ConfigIcon {
        id: configMainIconField
        Kirigami.FormData.label: i18n("Main icon: ")
        defaultValue: "software-update-available.svg"
      }
    }

    Kirigami.FormLayout {
      Layout.fillWidth: true

      ConfigIcon {
        id: configSecondaryIconField
        Kirigami.FormData.label: i18n("Refresh icon: ")
        defaultValue: "package-unknown.svg"
      }
    }

    Kirigami.FormLayout {
      RowLayout {
        Kirigami.FormData.label: i18n("Custom icon color: ")
        visible: true
        Controls.CheckBox {
          id: iconUseCustomColor
          checked: false
        }

        KQuickControls.ColorButton {
          id: iconColor
          enabled: iconUseCustomColor.checked
        }
      }

    }

    Kirigami.FormLayout {
      wideMode: false

      Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Display")
      }
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      text: i18n("The dot is shown only if update is needed.\nThis is the recommended option if you want to use the widget in your system tray or if you tend to have a lot of updates that the label can't handle.")
      visible: true
    }

    Kirigami.FormLayout {
      Controls.CheckBox {
        id: mainDot
        Kirigami.FormData.label: i18n("Show a dot in place of the label: ")
        checked: false
      }

      RowLayout {
        Kirigami.FormData.label: i18n("Custom main dot options: ")
        visible: mainDot.checked
        Controls.CheckBox {
          id: mainDotUseCustomColor
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
    }

    Kirigami.FormLayout {
      visible: mainDot.checked
      Controls.CheckBox {
        id: secondDot
        Kirigami.FormData.label: i18n("Separate the dot between the two commands: ")
        checked: false
      }
    }

    Kirigami.FormLayout {
      visible: secondDot.checked && mainDot.checked

      RowLayout {
        Kirigami.FormData.label: i18n("Custom second dot options: ")
        visible: secondDot.checked
        Controls.CheckBox {
          id: secondDotUseCustomColor
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

    Kirigami.FormLayout {
      wideMode: false

      Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Label display")
      }
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      text: i18n("Expected result: APT + separator + Snap/Flatpak")
      visible: true
    }

    Kirigami.FormLayout {
      Controls.CheckBox {
        id: separateResult
        Kirigami.FormData.label: i18n("Separate result: ")
        checked: false
      }

      Controls.TextField {
        id: separator
        Kirigami.FormData.label: i18n("Separator: ")
        visible: separateResult.checked
      }

      Controls.CheckBox {
        id: hideOnZero
        Kirigami.FormData.label: i18n("Hide label when 0 updates: ")
        checked: false
      }
    }

  }

}
