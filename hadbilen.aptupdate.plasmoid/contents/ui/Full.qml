import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents

import "components" as Components

PlasmaExtras.Representation {
  id: full

  property string totalAur: "0"
  property string totalArch: "0"
  property string packageList: ""
  property bool onRefresh: false
  property bool onError: false
  property string errorMessage: ""
  property bool rebootRequired: false

  focus: true
  anchors.fill: parent

  Layout.minimumHeight: Kirigami.Units.gridUnit * 12
  Layout.minimumWidth: Kirigami.Units.gridUnit * 18
  Layout.preferredWidth: Kirigami.Units.gridUnit * 24
  Layout.maximumWidth: Kirigami.Units.gridUnit * 35

  function updateAll() {
    if (!onRefresh) updater.launchUpdate()
  }

  function refresh() {
    if (!onRefresh) updater.countAll()
  }


  /**
   * inject the list into the component
   */
  function injectList(list: string) {
    if (!list) return
    const lines = list.trim().split("\n")

    lines.sort((a, b) => {
      const aName = a.trim().split(/\s+/)[0] || ""
      const bName = b.trim().split(/\s+/)[0] || ""
      return aName.localeCompare(bName)
    })

    lines.forEach(line => {
      if (!line || !line.trim()) return
      const packageDetails = line.trim().split(/\s+/)
      const name = packageDetails[0]
      const fv = packageDetails[1] || ""
      const tv = packageDetails[3] || packageDetails[2] || ""

      if (name && name.trim() !== "") {
        const isSnap = (fv === "snap" || line.indexOf(" snap ") !== -1)
        const isFlatpak = (fv === "flatpak" || line.indexOf(" flatpak ") !== -1)
        let repoType = 'apt'
        let website = 'https://packages.ubuntu.com/search?keywords=' + encodeURIComponent(name)
        if (isSnap) {
          repoType = 'snap'
          website = 'https://snapcraft.io/' + encodeURIComponent(name)
        } else if (isFlatpak) {
          repoType = 'flatpak'
          website = 'https://flathub.org/apps/search?q=' + encodeURIComponent(name)
        }
        packageListModel.append({
          name: name,
          fv: (isSnap || isFlatpak) ? "-" : fv,
          tv: tv,
          repo: repoType,
          websiteUrl: website
        });
      }
    });
  }

  // list of the packages
  ListModel { id: packageListModel }

  // map the cmd signal
  Connections {
    target: cmd

    function onConnected(source) {
      onError = false
    }

    function onIsUpdating(status) {
      onRefresh = status
      if (status) {
        onError = false
      }
    }

    function onTotalAur(total) {
      full.totalAur = total
    }

    function onTotalArch(total) {
      full.totalArch = total
    }

    function onRebootStatus(required) {
      full.rebootRequired = required
    }

    function onExited(cmd, exitCode, exitStatus, stdout, stderr) {
      const isUpdate = cmd.indexOf("konsole") !== -1 || cmd.startsWith(plasmoid.configuration.termCmd) || cmd.startsWith(plasmoid.configuration.termNoCloseCmd)
      if (isUpdate) {
        onError = false
        refresh()
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
          errorMessage = cleanErr
        }
      }
    }

    function onPackagesList(listAur, listArch, listArchRepo) {
      onError = false
      packageListModel.clear()
      full.packageList = (listArch || "") + (listAur ? "\n" + listAur : "")
      if (listAur) injectList(listAur)
      if (listArch) injectList(listArch)
    }
   }

   // topbar
   RowLayout {
     id: header
     anchors.top: parent.top
     anchors.left: parent.left
     anchors.right: parent.right
     width: parent.width

     RowLayout {
       Layout.alignment: Qt.AlignLeft
       spacing: 0

       Controls.Label {
         height: Kirigami.Units.iconSizes.medium
         text: {
           const aptCount = parseInt(full.totalArch, 10) || 0
           const extraCount = parseInt(full.totalAur, 10) || 0
           if (extraCount > 0) {
             return 'APT ' + aptCount + ' - Extra ' + extraCount
           }
           return 'APT ' + aptCount
         }
       }
     }

     RowLayout {
       Layout.alignment: Qt.AlignRight
       spacing: 0

       PlasmaComponents.BusyIndicator {
         id: busyIndicatorUpdateIcon
         visible: onRefresh && packageList !== ""
       }

       PlasmaComponents.ToolButton {
         id: updateIcon
         height: Kirigami.Units.iconSizes.medium
         icon.name: "install-symbolic"
         display: PlasmaComponents.AbstractButton.IconOnly
         text: i18n("Install all updates")
         onClicked: updateAll()
         visible: !onRefresh && packageList !== ""
         PlasmaComponents.ToolTip {
           text: parent.text
         }
       }

       PlasmaComponents.BusyIndicator {
         id: busyIndicatorCheckUpdatesIcon
         visible: onRefresh
       }

       PlasmaComponents.ToolButton {
         id: checkUpdatesIcon
         height: Kirigami.Units.iconSizes.medium
         icon.name: "view-refresh-symbolic"
         display: PlasmaComponents.AbstractButton.IconOnly
         text: i18n("Refresh list")
         visible: !onRefresh
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

   // reboot required banner
   Kirigami.InlineMessage {
     id: rebootMsg
     visible: full.rebootRequired
     type: Kirigami.MessageType.Warning
     text: i18n("A system restart is required to complete updates.")
     anchors.top: headerSeparator.bottom
     anchors.left: parent.left
     anchors.right: parent.right
   }

   // page view for the list
   Kirigami.ScrollablePage {
     id: scrollView
     visible: !onRefresh && !onError
     background: Rectangle {
       anchors.fill: parent
       color: "transparent"
     }
     anchors.top: full.rebootRequired ? rebootMsg.bottom : headerSeparator.bottom
     anchors.bottom: parent.bottom
     anchors.left: parent.left
     anchors.right: parent.right
     ListView {
       id: packageView
       anchors.rightMargin: Kirigami.Units.gridUnit
       model: packageListModel
       delegate: Components.ListItem {} // automatically inject the data from the model
     }
   }

   // if not update is needed
   PlasmaExtras.PlaceholderMessage {
     id: upToDateLabel
     text: i18n("You're up-to-date !")
     anchors.centerIn: parent
     visible: !onRefresh && packageList === "" && !onError
   }

   // if an error happend
   Controls.Label {
     id: errorLabel
     width: parent.width
     text: i18n("Hu ho something is wrong\n" + errorMessage)
     anchors.centerIn: parent
     visible: onError
     wrapMode: Text.Wrap
   }

   // loading indicator
   PlasmaComponents.BusyIndicator {
     id: busyIndicator
     anchors.centerIn: parent
     visible: onRefresh  && !onError
   }

   Component.onCompleted: {
     refresh()
   }
 }
