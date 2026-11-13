import QtQuick
import QtQuick.Controls
import QtCore
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes

Button {
  id: configIcon

  property string defaultValue: "software-update-available.svg"
  property string value: ""

  readonly property bool isPanel: plasmoid.formFactor === PlasmaCore.Types.Vertical || plasmoid.formFactor === PlasmaCore.Types.Horizontal

  implicitWidth: previewFrame.width + Kirigami.Units.smallSpacing * 2
  implicitHeight: previewFrame.height + Kirigami.Units.smallSpacing * 2

  KIconThemes.IconDialog {
    id: iconDialog
    onIconNameChanged: {
      configIcon.value = iconName || configIcon.defaultValue;
    }
  }

  onPressed: iconMenu.opened ? iconMenu.close() : iconMenu.open()

  KSvg.FrameSvgItem {
    id: previewFrame
    anchors.centerIn: parent
    imagePath: configIcon.isPanel ? "widgets/panel-background" : "widgets/background"
    width: Kirigami.Units.iconSizes.large + fixedMargins.left + fixedMargins.right
    height: Kirigami.Units.iconSizes.large + fixedMargins.top + fixedMargins.bottom

    Kirigami.Icon {
      anchors.centerIn: parent
      width: Kirigami.Units.iconSizes.large
      height: width
      source: {
        let path = configIcon.value;
        if (!path || path === configIcon.defaultValue) return Qt.resolvedUrl("../../assets/" + configIcon.defaultValue);
        if (path.includes("://")) return path;
        if (path.startsWith("/")) return "file://" + path;
        if (path.startsWith("~/")) {
          let home = StandardPaths.standardLocations(StandardPaths.HomeLocation)[0].toString().replace(/^file:\/\//, "");
          return "file://" + home + path.slice(1);
        }
        return path;
      }
    }
  }

  Menu {
    id: iconMenu

    // Appear below the button
    y: +parent.height

    MenuItem {
      text: i18ndc("plasma_applet_org.kde.plasma.kickoff", "@item:inmenu Open icon chooser dialog", "Choose...")
      icon.name: "document-open-folder"
      onClicked: iconDialog.open()
    }
    MenuItem {
      text: i18ndc("plasma_applet_org.kde.plasma.kickoff", "@item:inmenu Reset icon to default", "Clear Icon")
      icon.name: "edit-clear"
      onClicked: configIcon.value = configIcon.defaultValue
    }
  }
}

