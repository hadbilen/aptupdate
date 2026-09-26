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

  Kirigami.FormLayout {
    id: displayFormLayout
    wideMode: true

    anchors {
      left: parent.left
      top: parent.top
      right: parent.right
    }

    Component.onCompleted: {
      var lay = displayFormLayout.children[0];
      lay.anchors.horizontalCenter = undefined;
      lay.anchors.left = displayFormLayout.left;
      lay.anchors.right = displayFormLayout.right;
    }

    Kirigami.Separator {
      Kirigami.FormData.isSection: true
      Kirigami.FormData.label: i18n("Icon")
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      Kirigami.FormData.isSection: true
      text: i18n("You may need to refresh the widget to see any change if you choose another icon.\nA quick way to do that is just to hit 'Refresh' in the widget menu.")
      visible: true
    }

    ConfigIcon {
      id: configMainIconField
      Kirigami.FormData.label: i18n("Main icon: ")
      defaultValue: "software-update-available.svg"
    }

    ConfigIcon {
      id: configSecondaryIconField
      Kirigami.FormData.label: i18n("Refresh icon: ")
      defaultValue: "package-unknown.svg"
    }

    RowLayout {
      Kirigami.FormData.isSection: true
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
      Kirigami.FormData.isSection: true
      Kirigami.FormData.label: i18n("Display")
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      Kirigami.FormData.isSection: true
      text: i18n("The dot is shown only if update is needed.\nThis is the recommended option if you want to use the widget in your system tray or if you tend to have a lot of updates that the label can't handle.")
      visible: true
    }

    Controls.CheckBox {
      id: mainDot
      text: i18n("Show a dot in place of the label")
      checked: false
      Kirigami.FormData.isSection: true
    }

    RowLayout {
      Kirigami.FormData.isSection: true
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
      Kirigami.FormData.isSection: true
    }

    RowLayout {
      Kirigami.FormData.isSection: true
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

    Kirigami.Separator {
      Kirigami.FormData.isSection: true
      Kirigami.FormData.label: i18n("Label display")
    }

    Kirigami.InlineMessage {
      Layout.fillWidth: true
      Kirigami.FormData.isSection: true
      text: i18n("Expected result: APT + separator + Snap/Flatpak")
      visible: true
    }

    Controls.CheckBox {
      id: separateResult
      text: i18n("Separate result")
      checked: false
      Kirigami.FormData.isSection: true
    }

    Controls.TextField {
      id: separator
      Layout.fillWidth: true
      Kirigami.FormData.label: i18n("Separator: ")
      visible: separateResult.checked
    }

    Controls.CheckBox {
      id: hideOnZero
      text: i18n("Hide label when 0 updates")
      checked: false
      Kirigami.FormData.isSection: true
    }

  }

}
