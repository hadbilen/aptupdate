import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "components" as Components

Item {
  id: row

  property string iconUpdate: plasmoid.configuration.icon || "software-update-available.svg"
  property string iconRefresh: {
    let sec = plasmoid.configuration.secondaryIcon
    if (!sec || sec === "software-update-available.svg" || sec === "package-unknown.svg") {
      return "view-refresh.svg"
    }
    return sec
  }

  property string totalApt: main.tApt
  property string totalSnap: main.tSnap
  property string totalFlatpak: main.tFlatpak

  property bool separateResult: plasmoid.configuration.separateResult
  property string separator: plasmoid.configuration.separator

  property bool hideOnZero: plasmoid.configuration.hideOnZero

  property bool mainDot: plasmoid.configuration.mainDot
  property bool mainDotUseCustomColor: plasmoid.configuration.mainDotUseCustomColor
  property string mainDotColor: plasmoid.configuration.mainDotColor
  property int mainDotPosition: parseInt(plasmoid.configuration.mainDotPosition, 10)

  property bool secondDot: plasmoid.configuration.secondDot
  property bool secondDotUseCustomColor: plasmoid.configuration.secondDotUseCustomColor
  property string secondDotColor: plasmoid.configuration.secondDotColor
  property int secondDotPosition: parseInt(plasmoid.configuration.secondDotPosition, 10)

  readonly property bool onUpdate: Boolean(main.isInstalling || main.isOnUpdate)
  readonly property bool onRefresh: Boolean(main.isChecking)
  readonly property bool hasError: main.hasError

  property bool isPanelVertical: plasmoid.formFactor === PlasmaCore.Types.Vertical

  property real itemSize: Math.min(row.height, row.width)

  property bool invertMouseAction: plasmoid.configuration.invertMouseAction
  property bool mainIsRefresh: plasmoid.configuration.mainIsRefresh

  // event handler for the left click on MouseArea
  function onLClick() {
    if (!onRefresh && !onUpdate && !main.isChecking && !main.isInstalling && !main.isOnUpdate) {
      main.refreshAll()
    }
  }

  // event handler for the middle click on MouseArea
  function onMClick() {
    if (!onRefresh && !onUpdate) {
      if (main.canUpdateAll()) {
        main.clearRepoErrors()
      }
      updater.launchUpdate()
    }
  }

  // generate the text for the count result
  function generateResult() {
    if (row.hasError) return "!"
    if (onRefresh) return ""
    const apt = parseInt(row.totalApt, 10) || 0
    const snap = (main.enableSnapUpdates && main.hasSnap) ? (parseInt(row.totalSnap, 10) || 0) : 0
    const flatpak = (main.enableFlatpakUpdates && main.hasFlatpak) ? (parseInt(row.totalFlatpak, 10) || 0) : 0
    if (separateResult && !isPanelVertical) {
      let parts = [row.totalApt || "0"]
      if (main.enableSnapUpdates && main.hasSnap) {
        parts.push(row.totalSnap || "0")
      }
      if (main.enableFlatpakUpdates && main.hasFlatpak) {
        parts.push(row.totalFlatpak || "0")
      }
      return parts.join(separator)
    }
    return `${apt + snap + flatpak}`
  }

  // return true if update is needed (total > 0)
  function isUpdateNeeded() {
    const apt = parseInt(row.totalApt, 10) || 0
    const snap = (main.enableSnapUpdates && main.hasSnap) ? (parseInt(row.totalSnap, 10) || 0) : 0
    const flatpak = (main.enableFlatpakUpdates && main.hasFlatpak) ? (parseInt(row.totalFlatpak, 10) || 0) : 0
    return (apt + snap + flatpak) > 0
  }

  function isAptUpdateNeeded() {
    return (parseInt(row.totalApt, 10) > 0)
  }

  function isSecondaryUpdateNeeded() {
    const snap = (main.enableSnapUpdates && main.hasSnap) ? (parseInt(row.totalSnap, 10) || 0) : 0
    const flatpak = (main.enableFlatpakUpdates && main.hasFlatpak) ? (parseInt(row.totalFlatpak, 10) || 0) : 0
    return (snap + flatpak) > 0
  }

  Item {
    id: container
    height: row.itemSize
    width: height

    anchors.centerIn: parent

    Components.PlasmoidIcon {
      id: updateIcon
      height: container.height
      width: height
      source: (row.onUpdate || row.onRefresh) ? row.iconRefresh : row.iconUpdate
      transformOrigin: Item.Center

      RotationAnimation {
        target: updateIcon
        property: "rotation"
        from: 0
        to: 360
        duration: 1200
        loops: Animation.Infinite
        running: row.onUpdate || row.onRefresh
        onRunningChanged: {
          if (!running) {
            updateIcon.rotation = 0
          }
        }
      }
    }

    // MAIN BR
    Rectangle {
      visible: (secondDot ? mainDot && isAptUpdateNeeded() : mainDot && isUpdateNeeded()) && mainDotPosition === 2
      height: container.height / 2.5
      width: height
      radius: height / 2
      color: mainDotUseCustomColor ? mainDotColor : Kirigami.Theme.textColor
      anchors {
        right: container.right
        bottom: container.bottom
      }
    }

    // MAIN BL
    Rectangle {
      visible: (secondDot ? mainDot && isAptUpdateNeeded() : mainDot && isUpdateNeeded()) && mainDotPosition === 3
      height: container.height / 2.5
      width: height
      radius: height / 2
      color: mainDotUseCustomColor ? mainDotColor : Kirigami.Theme.textColor
      anchors {
        left: container.left
        bottom: container.bottom
      }
    }

    // MAIN TR
    Rectangle {
      visible: (secondDot ? mainDot && isAptUpdateNeeded() : mainDot && isUpdateNeeded()) && mainDotPosition === 0
      height: container.height / 2.5
      width: height
      radius: height / 2
      color: mainDotUseCustomColor ? mainDotColor : Kirigami.Theme.textColor
      anchors {
        right: container.right
        top: container.top
      }
    }

    // MAIN TL
    Rectangle {
      visible: (secondDot ? mainDot && isAptUpdateNeeded() : mainDot && isUpdateNeeded()) && mainDotPosition === 1
      height: container.height / 2.5
      width: height
      radius: height / 2
      color: mainDotUseCustomColor ? mainDotColor : Kirigami.Theme.textColor
      anchors {
        left: container.left
        top: container.top
      }
    }

    // SECOND BR
    Rectangle {
      visible: (secondDot && mainDot && isSecondaryUpdateNeeded()) && secondDotPosition === 2
      height: container.height / 2.5
      width: height
      radius: height / 2
      color: secondDotUseCustomColor ? secondDotColor : Kirigami.Theme.textColor
      anchors {
        right: container.right
        bottom: container.bottom
      }
    }

    // SECOND BL
    Rectangle {
      visible: (secondDot && mainDot && isSecondaryUpdateNeeded()) && secondDotPosition === 3
      height: container.height / 2.5
      width: height
      radius: height / 2
      color: secondDotUseCustomColor ? secondDotColor : Kirigami.Theme.textColor
      anchors {
        left: container.left
        bottom: container.bottom
      }
    }

    // SECOND TR
    Rectangle {
      visible: (secondDot && mainDot && isSecondaryUpdateNeeded()) && secondDotPosition === 0
      height: container.height / 2.5
      width: height
      radius: height / 2
      color: secondDotUseCustomColor ? secondDotColor : Kirigami.Theme.textColor
      anchors {
        right: container.right
        top: container.top
      }
    }

    // SECOND TL
    Rectangle {
      visible: (secondDot && mainDot && isSecondaryUpdateNeeded()) && secondDotPosition === 1
      height: container.height / 2.5
      width: height
      radius: height / 2
      color: secondDotUseCustomColor ? secondDotColor : Kirigami.Theme.textColor
      anchors {
        left: container.left
        top: container.top
     }
    }

    Kirigami.Badge {
      readonly property bool isRefreshBadge: row.onRefresh && !row.hasError
      readonly property bool isSeparateBadge: !row.hasError && !row.onRefresh && row.separateResult && !row.isPanelVertical

      anchors {
        bottom: container.bottom
        horizontalCenter: container.horizontalCenter
      }
      customColor: Qt.alpha(Kirigami.Theme.backgroundColor, 0.9)
      padding: isRefreshBadge ? 2 : 1
      horizontalPadding: isSeparateBadge ? Kirigami.Units.smallSpacing : padding
      font.bold: false
      font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
      icon.name: isRefreshBadge ? "view-refresh-symbolic" : ""
      icon.width: Math.round(Kirigami.Units.iconSizes.sizeForLabels * 0.75)
      icon.height: Math.round(Kirigami.Units.iconSizes.sizeForLabels * 0.75)
      icon.color: Kirigami.Theme.textColor
      text: generateResult()
      visible: !mainDot && (row.hasError || !(hideOnZero && !isUpdateNeeded() && !onRefresh))
    }

    MouseArea {
      anchors.fill: container // cover all the zone
      cursorShape: Qt.PointingHandCursor // give user feedback
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      onClicked: (mouse) => {
        if (invertMouseAction) {
          if (mouse.button == Qt.MiddleButton) {
            mainIsRefresh ? onLClick() : main.expanded = !main.expanded
          }
          if (mouse.button == Qt.LeftButton) onMClick()
        } else {
          if (mouse.button == Qt.LeftButton) {
            mainIsRefresh ? onLClick() : main.expanded = !main.expanded
          }
          if (mouse.button == Qt.MiddleButton) onMClick()
        }
      }
    }
  }
}
