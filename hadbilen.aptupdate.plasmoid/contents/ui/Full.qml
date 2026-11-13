import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami

import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents

import "components" as Components

PlasmaExtras.Representation {
  id: full

  property string totalApt: main.tApt
  property string totalSnap: main.tSnap
  property string totalFlatpak: main.tFlatpak
  property string packageList: ""
  property bool onRefresh: Boolean(main.isChecking || main.isInstalling || main.isOnUpdate)
  property bool onError: false
  property string localErrorMessage: ""
  property string errorMessage: main.lastErrorMessage || full.localErrorMessage
  readonly property bool hasAnyError: full.onError || main.hasError
  property bool rebootRequired: main.rebootRequired

  focus: true
  anchors.fill: parent

  Layout.minimumHeight: Kirigami.Units.gridUnit * 12
  Layout.minimumWidth: Kirigami.Units.gridUnit * 18
  Layout.preferredWidth: Kirigami.Units.gridUnit * 24
  Layout.maximumWidth: Kirigami.Units.gridUnit * 35

  function updateAll() {
    if (!onRefresh) {
      updater.launchUpdate()
    }
  }

  function refresh() {
    if (!onRefresh && !main.isInstalling && !main.isOnUpdate) main.refreshAll()
  }

  function applyAdaptiveGrouping() {
    const adaptive = (typeof plasmoid !== "undefined" && plasmoid.configuration && plasmoid.configuration.adaptiveGrouping !== undefined)
      ? plasmoid.configuration.adaptiveGrouping
      : (full.adaptiveGrouping !== undefined ? full.adaptiveGrouping : true)
    const threshold = (typeof plasmoid !== "undefined" && plasmoid.configuration && plasmoid.configuration.adaptiveGroupingThreshold !== undefined)
      ? plasmoid.configuration.adaptiveGroupingThreshold
      : (full.adaptiveGroupingThreshold !== undefined ? full.adaptiveGroupingThreshold : 5)

    if (adaptive) {
      aptGroupCard.isExpanded = (aptListModel.count > 0 && aptListModel.count <= threshold)
      snapGroupCard.isExpanded = (snapListModel.count > 0 && snapListModel.count <= threshold)
      flatpakGroupCard.isExpanded = (flatpakListModel.count > 0 && flatpakListModel.count <= threshold)
    } else {
      aptGroupCard.isExpanded = false
      snapGroupCard.isExpanded = false
      flatpakGroupCard.isExpanded = false
    }
  }

  function reloadPackages() {
    onError = false
    packageListModel.clear()
    aptListModel.clear()
    snapListModel.clear()
    flatpakListModel.clear()
    let combined = ""
    if (main.listApt) {
      combined = main.listApt
      injectList(main.listApt)
    }
    if (main.enableSnapUpdates && main.hasSnap && main.listSnap) {
      combined += (combined ? "\n" : "") + main.listSnap
      injectList(main.listSnap)
    }
    if (main.enableFlatpakUpdates && main.hasFlatpak && main.listFlatpak) {
      combined += (combined ? "\n" : "") + main.listFlatpak
      injectList(main.listFlatpak)
    }
    full.packageList = combined
    applyAdaptiveGrouping()
  }

  Component.onCompleted: {
    reloadPackages()
  }


  /**
   * inject the list into the component
   */
  function injectList(list: string) {
    if (!list) return
    const lines = list.trim().split("\n")

    lines.sort((a, b) => {
      const getPkgName = (str) => {
        if (!str) return ""
        if (str.indexOf("\t") !== -1) {
          const p = str.split("\t")
          return (p[1] || p[0] || "").trim()
        }
        return (str.trim().split(/\s+/)[0] || "").trim()
      }
      return getPkgName(a).localeCompare(getPkgName(b))
    })

    lines.forEach(line => {
      if (!line || !line.trim()) return
      let name = ""
      let appId = ""
      let fv = ""
      let tv = ""
      let repoType = "apt"
      let website = ""

      if (line.indexOf("\t") !== -1) {
        // Tab-separated format: appId \t name \t repo \t fv \t tv
        // Or legacy format: appId \t name \t repo \t -> \t tv
        const parts = line.split("\t")
        appId = parts[0] ? parts[0].trim() : ""
        name = parts[1] ? parts[1].trim() : appId
        repoType = parts[2] ? parts[2].trim() : "flatpak"
        if (parts[3] !== undefined && parts[3].trim() === "->") {
          fv = "-"
          tv = (parts[4] !== undefined && parts[4].trim() !== "") ? parts[4].trim() : "-"
        } else {
          fv = (parts[3] !== undefined && parts[3].trim() !== "") ? parts[3].trim() : "-"
          tv = (parts[4] !== undefined && parts[4].trim() !== "") ? parts[4].trim() : "-"
        }
        if (repoType === "snap") {
          website = 'https://snapcraft.io/' + encodeURIComponent(name)
        } else if (repoType === "flatpak") {
          website = 'https://flathub.org/apps/details/' + encodeURIComponent(appId)
        } else {
          website = 'https://packages.ubuntu.com/search?keywords=' + encodeURIComponent(name)
        }
      } else {
        const packageDetails = line.trim().split(/\s+/)
        name = packageDetails[0]
        appId = name
        fv = packageDetails[1] || ""
        tv = packageDetails[3] || packageDetails[2] || ""
        const isSnap = (fv === "snap" || line.indexOf(" snap ") !== -1)
        const isFlatpak = (fv === "flatpak" || line.indexOf(" flatpak ") !== -1)
        if (isSnap) {
          repoType = 'snap'
          website = 'https://snapcraft.io/' + encodeURIComponent(name)
        } else if (isFlatpak) {
          repoType = 'flatpak'
          website = 'https://flathub.org/apps/details/' + encodeURIComponent(name)
        } else {
          repoType = 'apt'
          website = 'https://packages.ubuntu.com/search?keywords=' + encodeURIComponent(name)
        }
      }

      if (name && name.trim() !== "") {
        const itemObj = {
          name: name,
          appId: appId,
          fv: fv || "-",
          tv: tv || "-",
          repo: repoType,
          websiteUrl: website
        }
        packageListModel.append(itemObj)
        if (repoType === "apt") {
          aptListModel.append(itemObj)
        } else if (repoType === "snap") {
          snapListModel.append(itemObj)
        } else if (repoType === "flatpak") {
          flatpakListModel.append(itemObj)
        }
      }
    });
  }



  // lists of the packages
  ListModel { id: packageListModel }
  ListModel { id: aptListModel }
  ListModel { id: snapListModel }
  ListModel { id: flatpakListModel }

  readonly property bool shouldGroup: plasmoid.configuration.groupUpdates !== undefined ? plasmoid.configuration.groupUpdates : true
  readonly property bool adaptiveGrouping: plasmoid.configuration.adaptiveGrouping !== undefined ? plasmoid.configuration.adaptiveGrouping : true
  readonly property int adaptiveGroupingThreshold: plasmoid.configuration.adaptiveGroupingThreshold !== undefined ? plasmoid.configuration.adaptiveGroupingThreshold : 5
  readonly property bool isPrewarmed: main.isPrewarmed || main.expanded

  onAdaptiveGroupingChanged: applyAdaptiveGrouping()
  onAdaptiveGroupingThresholdChanged: applyAdaptiveGrouping()

  // map the cmd signal
  Connections {
    target: cmd

    function onSourceConnected(source) {
      if (!main.updateError) {
        onError = false
      }
    }

    function onIsUpdating(status) {
      if (status && !main.updateError) {
        onError = false
        localErrorMessage = ""
      }
    }

    function onErrorStatus(err) {
      full.onError = err
      if (err && !full.errorMessage) {
        full.localErrorMessage = i18n("Failed to check for updates. Please verify your connection or package manager.")
      } else if (!err) {
        full.localErrorMessage = ""
      }
    }

    function onExited(cmd, exitCode, exitStatus, stdout, stderr) {
      const tCmd = (plasmoid.configuration.termCmd || "").trim()
      const tNoCloseCmd = (plasmoid.configuration.termNoCloseCmd || "").trim()
      const isUpdate = (main.activeUpdateJobs[cmd] !== undefined ||
                        (updater.lastUpdateCmd !== "" && cmd === updater.lastUpdateCmd) ||
                        cmd.indexOf("aptupdate_last_error") !== -1 ||
                        cmd.indexOf("konsole") !== -1 ||
                        cmd.indexOf("pkexec") !== -1 ||
                        (tCmd !== "" && cmd.startsWith(tCmd)) ||
                        (tNoCloseCmd !== "" && cmd.startsWith(tNoCloseCmd)))
      if (isUpdate) {
        if (exitCode === 0 || exitCode === 126) {
          onError = false
          localErrorMessage = ""
        }
        return
      }
      if (exitCode !== 0 && stderr !== '') {
        const cleanErr = stderr.split("\n").filter(l => {
          return l.indexOf("qt.core.qobject") === -1 &&
                 l.indexOf("kf.") === -1 &&
                 l.indexOf("This plugin does not support") === -1 &&
                 l.indexOf("Failed to create secure directory") === -1
        }).join("\n").trim()
        if (cleanErr !== '') {
          onError = true
          localErrorMessage = cleanErr
        }
      }
    }
   }

   Connections {
     target: main

     function onListAptChanged() { full.reloadPackages() }
     function onListSnapChanged() { full.reloadPackages() }
     function onListFlatpakChanged() { full.reloadPackages() }
     function onEnableSnapUpdatesChanged() { full.reloadPackages() }
     function onEnableFlatpakUpdatesChanged() { full.reloadPackages() }
     function onHasSnapChanged() { full.reloadPackages() }
     function onHasFlatpakChanged() { full.reloadPackages() }
   }

   Connections {
     target: (typeof plasmoid !== "undefined" && plasmoid.configuration) ? plasmoid.configuration : null

     function onAdaptiveGroupingChanged() { full.applyAdaptiveGrouping() }
     function onAdaptiveGroupingThresholdChanged() { full.applyAdaptiveGrouping() }
   }

   // topbar
   RowLayout {
     id: header
     anchors.top: parent.top
     anchors.left: parent.left
     anchors.right: parent.right
     width: parent.width

     ColumnLayout {
       Layout.alignment: Qt.AlignLeft
       spacing: 0

       Controls.Label {
         Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
         verticalAlignment: Text.AlignVCenter
         text: {
           const apt = parseInt(full.totalApt, 10) || 0
           const snap = parseInt(full.totalSnap, 10) || 0
           const flatpak = parseInt(full.totalFlatpak, 10) || 0
           var parts = []
           parts.push("APT: " + apt)
           if (plasmoid.configuration.enableSnapUpdates && plasmoid.configuration.hasSnap) {
             parts.push("Snap: " + snap)
           }
           if (plasmoid.configuration.enableFlatpakUpdates && plasmoid.configuration.hasFlatpak) {
             parts.push("Flatpak: " + flatpak)
           }
           return parts.join(" - ")
         }
       }

       Controls.Label {
         visible: main.lastCheckTime !== ""
         text: i18n("Last check: %1", main.lastCheckTime)
         color: Kirigami.Theme.disabledTextColor
         font.pointSize: Kirigami.Theme.smallFont.pointSize
       }
     }

     RowLayout {
       Layout.alignment: Qt.AlignRight
       spacing: 0

       PlasmaComponents.BusyIndicator {
         id: busyIndicatorUpdatingAll
         Layout.preferredHeight: Kirigami.Units.iconSizes.medium
         Layout.preferredWidth: Kirigami.Units.iconSizes.medium
         visible: main.isUpdatingAll
         PlasmaComponents.ToolTip {
           text: i18n("Installing updates…")
         }
       }

       PlasmaComponents.ToolButton {
         id: cancelUpdateIcon
         Layout.preferredHeight: Kirigami.Units.iconSizes.medium
         icon.name: "dialog-cancel"
         display: PlasmaComponents.AbstractButton.IconOnly
         text: i18n("Cancel update")
         visible: main.isInstalling || main.isOnUpdate
         onClicked: main.abortUpdate()
         PlasmaComponents.ToolTip {
           text: i18n("Abort running update process")
         }
       }

       PlasmaComponents.ToolButton {
         id: updateIcon
         Layout.preferredHeight: Kirigami.Units.iconSizes.medium
         icon.name: "install-symbolic"
         display: PlasmaComponents.AbstractButton.IconOnly
         text: i18n("Install all updates")
         enabled: main.canUpdateAll()
         onClicked: updateAll()
         visible: !main.isInstalling && !main.isUpdatingAll && packageList !== ""
         PlasmaComponents.ToolTip {
           text: (main.isPkgManagerBusy && (parseInt(main.tApt, 10) || 0) > 0) ? i18n("Package manager is currently in use by another process.") : (main.isInstalling ? i18n("An update is already in progress.") : parent.text)
         }
       }

       PlasmaComponents.BusyIndicator {
         id: busyIndicatorCheckUpdatesIcon
         visible: main.isChecking
       }

       PlasmaComponents.ToolButton {
         id: checkUpdatesIcon
         Layout.preferredHeight: Kirigami.Units.iconSizes.medium
         icon.name: "view-refresh-symbolic"
         display: PlasmaComponents.AbstractButton.IconOnly
         text: i18n("Refresh list")
         visible: !main.isChecking
         enabled: !main.isChecking && !main.isInstalling
         onClicked: refresh()
         PlasmaComponents.ToolTip {
           text: parent.text
         }
       }
     }
   }

   // separator
   Rectangle {
     id: headerSeparator
     anchors.top: header.bottom
     width: parent.width
     height: 1
     color: Kirigami.Theme.textColor
     opacity: 0.25
     visible: true
   }

   // distribution release upgrade banner
   Kirigami.InlineMessage {
     id: releaseUpgradeMsg
     visible: main.releaseUpgradeAvailable
     type: Kirigami.MessageType.Information
     showCloseButton: true
     text: main.releaseUpgradeVersion !== "" ? i18n("Upgrade Available: Ubuntu %1", main.releaseUpgradeVersion) : i18n("Distribution upgrade available")
     actions: [
       Kirigami.Action {
         text: i18n("Open in Terminal")
         icon.name: "utilities-terminal"
         onTriggered: {
           var baseTerm = (plasmoid.configuration.termCmd || "").trim()
           if (!baseTerm) {
             updater.sendNotify(i18n("Update Error"), i18n("No terminal command is configured."), "dialog-error", "critical")
             return
           }
           if (baseTerm.indexOf("bash -c") === -1 && baseTerm.indexOf("sh -c") === -1) {
             baseTerm += " bash -c"
           }
           var closePrompt = i18n("Press Enter to close...")
           var innerScript = "sudo do-release-upgrade; echo ''; echo '" + updater.bashEscape(closePrompt) + "'; read -r"
           cmd.exec(baseTerm + " '" + updater.bashEscape(innerScript) + "'")
         }
       }
     ]
     anchors.top: headerSeparator.bottom
     anchors.left: parent.left
     anchors.right: parent.right
   }

   // reboot required banner
   Kirigami.InlineMessage {
     id: rebootMsg
     visible: full.rebootRequired
     type: Kirigami.MessageType.Warning
     showCloseButton: true
     text: i18n("A system restart is required to complete updates.")
     actions: [
       Kirigami.Action {
         text: i18n("Restart...")
         icon.name: "system-reboot"
         onTriggered: cmd.exec("qdbus org.kde.LogoutPrompt /LogoutPrompt promptReboot || systemctl reboot")
       }
     ]
     anchors.top: releaseUpgradeMsg.visible ? releaseUpgradeMsg.bottom : headerSeparator.bottom
     anchors.left: parent.left
     anchors.right: parent.right
   }

   // package manager busy banner
   Kirigami.InlineMessage {
     id: busyLockMsg
     visible: main.isPkgManagerBusy && ((parseInt(main.tApt, 10) || 0) > 0 || main.lockBlockedUpdate)
     type: Kirigami.MessageType.Information
     showCloseButton: true
     text: i18n("Package manager is currently in use by another process.")
     anchors.top: rebootMsg.visible ? rebootMsg.bottom : (releaseUpgradeMsg.visible ? releaseUpgradeMsg.bottom : headerSeparator.bottom)
     anchors.left: parent.left
     anchors.right: parent.right
   }

   // dynamic content container anchored below all active banners
   Item {
     id: contentArea
     anchors.top: busyLockMsg.visible ? busyLockMsg.bottom : (rebootMsg.visible ? rebootMsg.bottom : (releaseUpgradeMsg.visible ? releaseUpgradeMsg.bottom : headerSeparator.bottom))
     anchors.bottom: parent.bottom
     anchors.left: parent.left
     anchors.right: parent.right
   }

   // page view for the list
   Kirigami.ScrollablePage {
     id: scrollView
     visible: !full.hasAnyError && (packageList !== "" || (!main.isChecking && !main.isInstalling)) && packageListModel.count > 0
     background: Rectangle {
       anchors.fill: parent
       color: "transparent"
     }
     anchors.fill: contentArea
     leftPadding: Kirigami.Units.smallSpacing
     rightPadding: Kirigami.Units.smallSpacing

     ColumnLayout {
       id: listContainer
       spacing: Kirigami.Units.largeSpacing
       Layout.fillWidth: true

       // Flat view (when shouldGroup is false)
       ColumnLayout {
         id: flatView
         visible: !full.shouldGroup
         Layout.fillWidth: true
         spacing: 0
         Repeater {
           model: (!full.shouldGroup && full.isPrewarmed) ? packageListModel : null
           delegate: Components.ListItem {
             Layout.fillWidth: true
           }
         }
       }

       // Grouped view (Model A+ Accordion, when shouldGroup is true)
       ColumnLayout {
         id: groupedView
         visible: full.shouldGroup
         Layout.fillWidth: true
         spacing: Kirigami.Units.largeSpacing

       // APT Group Card
       ColumnLayout {
         id: aptGroupCard
         visible: aptListModel.count > 0
         Layout.fillWidth: true
         spacing: Kirigami.Units.smallSpacing

         property bool isExpanded: false

         Item {
           Layout.fillWidth: true
           implicitHeight: aptHeaderRow.implicitHeight + Kirigami.Units.smallSpacing * 2

           Rectangle {
             anchors.fill: parent
             radius: Kirigami.Units.smallSpacing
             color: Kirigami.Theme.highlightColor
             opacity: 0.15
           }

           MouseArea {
             anchors.fill: parent
             cursorShape: Qt.PointingHandCursor
             onClicked: aptGroupCard.isExpanded = !aptGroupCard.isExpanded
           }

           RowLayout {
             id: aptHeaderRow
             anchors.fill: parent
             anchors.leftMargin: Kirigami.Units.smallSpacing
             anchors.rightMargin: Kirigami.Units.smallSpacing
             spacing: 8

             Kirigami.Icon {
               source: aptGroupCard.isExpanded ? "arrow-down" : "arrow-right"
               implicitWidth: Kirigami.Units.iconSizes.small
               implicitHeight: implicitWidth
             }

             Kirigami.Icon {
               source: Qt.resolvedUrl("../assets/apt.svg")
               implicitWidth: Kirigami.Units.iconSizes.smallMedium
               implicitHeight: implicitWidth
             }

             Controls.Label {
               text: i18n("APT (%1)", aptListModel.count)
               font.bold: true
             }

             Item { Layout.fillWidth: true }

             PlasmaComponents.BusyIndicator {
               id: aptBusyIndicator
               Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
               Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
               visible: !main.isUpdatingAll && main.isRepoBusy("apt")
               running: visible
             }

             PlasmaComponents.ToolButton {
               icon.name: "internet-services-symbolic"
               display: PlasmaComponents.AbstractButton.IconOnly
               text: i18n("Repository Home")
               onClicked: Qt.openUrlExternally("https://packages.ubuntu.com")
               PlasmaComponents.ToolTip {
                 text: i18n("Open APT repository website")
               }
             }

             PlasmaComponents.ToolButton {
               icon.name: "install-symbolic"
               display: PlasmaComponents.AbstractButton.IconOnly
               text: i18n("Install APT updates")
               enabled: main.canUpdate("apt")
               onClicked: updater.launchGroupUpdate("apt")
               PlasmaComponents.ToolTip {
                 text: main.isPkgManagerBusy ? i18n("Package manager is currently in use by another process.") : (main.isRepoBusy("apt") ? i18n("An update is already in progress.") : i18n("Install all APT updates"))
               }
             }
           }
         }

         ColumnLayout {
           Layout.fillWidth: true
           visible: aptGroupCard.isExpanded
           spacing: 0
           Repeater {
             model: (aptGroupCard.isExpanded && full.isPrewarmed) ? aptListModel : null
             delegate: Components.ListItem {
               Layout.fillWidth: true
             }
           }
         }
       }

       // Snap Group Card
       ColumnLayout {
         id: snapGroupCard
         visible: main.enableSnapUpdates && main.hasSnap && snapListModel.count > 0
         Layout.fillWidth: true
         spacing: Kirigami.Units.smallSpacing

         property bool isExpanded: false

         Item {
           Layout.fillWidth: true
           implicitHeight: snapHeaderRow.implicitHeight + Kirigami.Units.smallSpacing * 2

           Rectangle {
             anchors.fill: parent
             radius: Kirigami.Units.smallSpacing
             color: Kirigami.Theme.highlightColor
             opacity: 0.15
           }

           MouseArea {
             anchors.fill: parent
             cursorShape: Qt.PointingHandCursor
             onClicked: snapGroupCard.isExpanded = !snapGroupCard.isExpanded
           }

           RowLayout {
             id: snapHeaderRow
             anchors.fill: parent
             anchors.leftMargin: Kirigami.Units.smallSpacing
             anchors.rightMargin: Kirigami.Units.smallSpacing
             spacing: 8

             Kirigami.Icon {
               source: snapGroupCard.isExpanded ? "arrow-down" : "arrow-right"
               implicitWidth: Kirigami.Units.iconSizes.small
               implicitHeight: implicitWidth
             }

             Kirigami.Icon {
               source: Qt.resolvedUrl("../assets/snap.svg")
               implicitWidth: Kirigami.Units.iconSizes.smallMedium
               implicitHeight: implicitWidth
             }

             Controls.Label {
               text: i18n("Snap (%1)", snapListModel.count)
               font.bold: true
             }

             Item { Layout.fillWidth: true }

             PlasmaComponents.BusyIndicator {
               id: snapBusyIndicator
               Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
               Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
               visible: !main.isUpdatingAll && main.isRepoBusy("snap")
               running: visible
             }

             PlasmaComponents.ToolButton {
               icon.name: "internet-services-symbolic"
               display: PlasmaComponents.AbstractButton.IconOnly
               text: i18n("Repository Home")
               onClicked: Qt.openUrlExternally("https://snapcraft.io/store")
               PlasmaComponents.ToolTip {
                 text: i18n("Open Snapcraft store")
               }
             }

             PlasmaComponents.ToolButton {
               icon.name: "install-symbolic"
               display: PlasmaComponents.AbstractButton.IconOnly
               text: i18n("Install Snap updates")
               enabled: main.canUpdate("snap")
               onClicked: updater.launchGroupUpdate("snap")
               PlasmaComponents.ToolTip {
                 text: main.isRepoBusy("snap") ? i18n("An update is already in progress.") : i18n("Install all Snap updates")
               }
             }
           }
         }

         ColumnLayout {
           Layout.fillWidth: true
           visible: snapGroupCard.isExpanded
           spacing: 0
           Repeater {
             model: (snapGroupCard.isExpanded && full.isPrewarmed) ? snapListModel : null
             delegate: Components.ListItem {
               Layout.fillWidth: true
             }
           }
         }
       }

       // Flatpak Group Card
       ColumnLayout {
         id: flatpakGroupCard
         visible: main.enableFlatpakUpdates && main.hasFlatpak && flatpakListModel.count > 0
         Layout.fillWidth: true
         spacing: Kirigami.Units.smallSpacing

         property bool isExpanded: false

         Item {
           Layout.fillWidth: true
           implicitHeight: flatpakHeaderRow.implicitHeight + Kirigami.Units.smallSpacing * 2

           Rectangle {
             anchors.fill: parent
             radius: Kirigami.Units.smallSpacing
             color: Kirigami.Theme.highlightColor
             opacity: 0.15
           }

           MouseArea {
             anchors.fill: parent
             cursorShape: Qt.PointingHandCursor
             onClicked: flatpakGroupCard.isExpanded = !flatpakGroupCard.isExpanded
           }

           RowLayout {
             id: flatpakHeaderRow
             anchors.fill: parent
             anchors.leftMargin: Kirigami.Units.smallSpacing
             anchors.rightMargin: Kirigami.Units.smallSpacing
             spacing: 8

             Kirigami.Icon {
               source: flatpakGroupCard.isExpanded ? "arrow-down" : "arrow-right"
               implicitWidth: Kirigami.Units.iconSizes.small
               implicitHeight: implicitWidth
             }

             Kirigami.Icon {
               source: Qt.resolvedUrl("../assets/flatpak.svg")
               implicitWidth: Kirigami.Units.iconSizes.smallMedium
               implicitHeight: implicitWidth
             }

             Controls.Label {
               text: i18n("Flatpak (%1)", flatpakListModel.count)
               font.bold: true
             }

             Item { Layout.fillWidth: true }

             PlasmaComponents.BusyIndicator {
               id: flatpakBusyIndicator
               Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
               Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
               visible: !main.isUpdatingAll && main.isRepoBusy("flatpak")
               running: visible
             }

             PlasmaComponents.ToolButton {
               icon.name: "internet-services-symbolic"
               display: PlasmaComponents.AbstractButton.IconOnly
               text: i18n("Repository Home")
               onClicked: Qt.openUrlExternally("https://flathub.org")
               PlasmaComponents.ToolTip {
                 text: i18n("Open Flathub website")
               }
             }

             PlasmaComponents.ToolButton {
               icon.name: "install-symbolic"
               display: PlasmaComponents.AbstractButton.IconOnly
               text: i18n("Install Flatpak updates")
               enabled: main.canUpdate("flatpak")
               onClicked: updater.launchGroupUpdate("flatpak")
               PlasmaComponents.ToolTip {
                 text: main.isRepoBusy("flatpak") ? i18n("An update is already in progress.") : i18n("Install all Flatpak updates")
               }
             }
           }
         }

         ColumnLayout {
           Layout.fillWidth: true
           visible: flatpakGroupCard.isExpanded
           spacing: 0
           Repeater {
             model: (flatpakGroupCard.isExpanded && full.isPrewarmed) ? flatpakListModel : null
             delegate: Components.ListItem {
               Layout.fillWidth: true
             }
           }
         }
       }
     }
   }
 }

   // if no check has been performed yet
   PlasmaExtras.PlaceholderMessage {
     id: waitingCheckLabel
     text: i18n("Waiting for update check…")
     anchors.centerIn: contentArea
     visible: (!main.hasCheckedOnce || main.isStartupDelaying) && !main.isChecking && !main.isInstalling && !main.hasUpdate() && (packageList === "" || packageListModel.count === 0) && !full.hasAnyError
   }

   // if not update is needed
   PlasmaExtras.PlaceholderMessage {
     id: upToDateLabel
     text: i18n("You're up-to-date !")
     anchors.centerIn: contentArea
     visible: main.hasCheckedOnce && !main.isStartupDelaying && !main.isChecking && !main.isInstalling && !main.hasUpdate() && (packageList === "" || packageListModel.count === 0) && !full.hasAnyError
   }

   // if an error happend
   Controls.Label {
     id: errorLabel
     width: Math.max(100, contentArea.width - (Kirigami.Units.largeSpacing * 2))
     text: i18n("Something went wrong:\n%1", full.errorMessage || i18n("Check log for details."))
     anchors.centerIn: contentArea
     visible: full.hasAnyError
     wrapMode: Text.Wrap
     horizontalAlignment: Text.AlignHCenter
   }

   // loading indicator with status label (only when list is empty)
   ColumnLayout {
     id: centralLoadingCol
     anchors.centerIn: contentArea
     spacing: Kirigami.Units.smallSpacing
     visible: (packageList === "" || packageListModel.count === 0) && (main.isChecking || main.isInstalling) && !full.hasAnyError

     PlasmaComponents.BusyIndicator {
       Layout.alignment: Qt.AlignHCenter
       running: centralLoadingCol.visible
     }

     Controls.Label {
       Layout.alignment: Qt.AlignHCenter
       text: main.isInstalling ? i18n("Installing updates…") : i18n("Checking for updates…")
       color: Kirigami.Theme.disabledTextColor
     }
   }
 }
