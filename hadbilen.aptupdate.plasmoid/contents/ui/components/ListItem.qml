import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

PlasmaComponents.ItemDelegate {
    id: listItem

    // index      = index of the element in the model
    // repo       = name of the repo
    // websiteUrl = URL to the package repository page
    // name       = package name
    // fv         = from version
    // tv         = to version
    // appId      = application ID (reverse-DNS for flatpak)

    required property string name
    required property string repo
    required property string fv
    required property string tv
    required property string websiteUrl
    required property string appId

    width: ListView.view ? ListView.view.width : (parent ? parent.width : implicitWidth)

    function updateOne() {
        updater.launchOneUpdate(name, repo, appId)
    }

    function openRepoPage() {
        if (websiteUrl) {
            Qt.openUrlExternally(websiteUrl)
        }
    }

    function escapeHtml(text) {
        if (text === undefined || text === null) return ""
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;")
    }

    // generate & style the name of the package
    function generateName() {
        const nc = plasmoid.configuration.nameUseCustomColor ? plasmoid.configuration.nameColor : Kirigami.Theme.textColor
        const sc = plasmoid.configuration.sourceUseCustomColor ? plasmoid.configuration.sourceColor : Kirigami.Theme.disabledTextColor
        return '<font color="' + nc + '"> ' + escapeHtml(name) + ' </font><font color="' + sc + '"> ' + i18n("from %1", escapeHtml(repo)) + '</font>'
    }

    // generate & style the version of the package
    function generateVersion() {
        const fvc = plasmoid.configuration.fvUseCustomColor ? plasmoid.configuration.fvColor : Kirigami.Theme.negativeTextColor
        const sc = plasmoid.configuration.separatorUseCustomColor ? plasmoid.configuration.separatorColor : Kirigami.Theme.textColor
        const tvc = plasmoid.configuration.tvUseCustomColor ? plasmoid.configuration.tvColor : Kirigami.Theme.positiveTextColor
        return '<font color="' + fvc + '">' + escapeHtml(fv) + '</font><font color="' + sc + '"> ' + escapeHtml(plasmoid.configuration.separatorText) + ' </font><font color="' + tvc + '">' + escapeHtml(tv) + '</font>'
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Kirigami.Heading {
                id: itemHeading
                level: 3
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: generateName()
            }

            Controls.Label {
                id: itemLabel
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                text: generateVersion()
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.fillWidth: false
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.BusyIndicator {
                id: itemBusyIndicator
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                visible: !main.isUpdatingAll && !Boolean(main.updatingRepos[repo]) && main.isPackageBusy(repo, name, appId)
                running: visible
            }

            PlasmaComponents.ToolButton {
                id: repoToolButton
                icon.name: "internet-services-symbolic"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("See repository")
                onClicked: openRepoPage()
                visible: websiteUrl !== ''
                PlasmaComponents.ToolTip {
                    text: repoToolButton.text
                }
            }
            PlasmaComponents.ToolButton {
                id: actionToolButton
                icon.name: "system-run-symbolic"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Update %1", name)
                enabled: main.canUpdatePackage(repo, name, appId)
                onClicked: updateOne()
                PlasmaComponents.ToolTip {
                    text: (repo === "apt" && main.isPkgManagerBusy) ? i18n("Package manager is currently in use by another process.") : (!main.canUpdatePackage(repo, name, appId) ? i18n("An update is already in progress.") : actionToolButton.text)
                }
            }
        }
    }

    // separator
    Rectangle {
        id: headerSeparator
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Kirigami.Theme.textColor
        opacity: 0.25
        visible: true
    }

}
