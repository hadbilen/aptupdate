import QtQuick

import org.kde.plasma.core as PlasmaCore
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

  function onLClick() {
    if (!onRefresh && !onUpdate && !main.isChecking && !main.isInstalling && !main.isOnUpdate) {
      main.refreshAll()
    }
  }

  function onMClick() {
    if (!onRefresh && !onUpdate) {
      if (main.canUpdateAll()) {
        main.clearRepoErrors()
      }
      updater.launchUpdate()
    }
  }

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

    // Primary status / error dot
    Rectangle {
      id: mainDotIndicator
      visible: mainDot && (row.hasError || (secondDot ? isAptUpdateNeeded() : isUpdateNeeded()))
      height: Math.max(6, Math.round(container.height * 0.175) * 2)
      width: height
      radius: height / 2
      color: row.hasError ? Kirigami.Theme.negativeTextColor : (mainDotUseCustomColor ? mainDotColor : Kirigami.Theme.textColor)
      x: (mainDotPosition === 0 || mainDotPosition === 2) ? (container.width - width) : 0
      y: (mainDotPosition === 2 || mainDotPosition === 3) ? (container.height - height) : 0
    }

    // Secondary repository indicator dot (Snap / Flatpak)
    Rectangle {
      id: secondDotIndicator
      visible: secondDot && mainDot && isSecondaryUpdateNeeded() && !(row.hasError && secondDotPosition === mainDotPosition)
      height: Math.max(6, Math.round(container.height * 0.175) * 2)
      width: height
      radius: height / 2
      color: secondDotUseCustomColor ? secondDotColor : Kirigami.Theme.textColor
      x: (secondDotPosition === 0 || secondDotPosition === 2) ? (container.width - width) : 0
      y: (secondDotPosition === 2 || secondDotPosition === 3) ? (container.height - height) : 0
    }

    Kirigami.Badge {
      readonly property bool isRefreshBadge: row.onRefresh && !row.hasError
      readonly property bool isSeparateBadge: !row.hasError && !row.onRefresh && row.separateResult && !row.isPanelVertical

      anchors {
        bottom: container.bottom
        horizontalCenter: container.horizontalCenter
      }
      type: row.hasError ? Kirigami.Badge.Type.Error : Kirigami.Badge.Type.Information
      customColor: row.hasError ? Kirigami.Theme.negativeTextColor : Qt.alpha(Kirigami.Theme.backgroundColor, 0.9)
      customTextColor: row.hasError ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
      padding: isRefreshBadge ? 2 : 1
      horizontalPadding: isSeparateBadge ? Kirigami.Units.smallSpacing : padding
      font.bold: row.hasError
      font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
      icon.name: isRefreshBadge ? "view-refresh-symbolic" : ""
      icon.width: Math.round(Kirigami.Units.iconSizes.sizeForLabels * 0.75)
      icon.height: Math.round(Kirigami.Units.iconSizes.sizeForLabels * 0.75)
      icon.color: Kirigami.Theme.textColor
      text: generateResult()
      visible: !mainDot && (row.hasError || !(hideOnZero && !isUpdateNeeded() && !onRefresh))
    }

    MouseArea {
      anchors.fill: container
      cursorShape: Qt.PointingHandCursor
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
