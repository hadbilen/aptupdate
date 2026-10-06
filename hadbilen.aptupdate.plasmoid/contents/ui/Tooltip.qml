import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

ColumnLayout {
    id: root

    property var dividerColor: Kirigami.Theme.textColor
    property var dividerOpacity: 0.1
    property string totalApt: main.tApt
    property string totalSnap: main.tSnap
    property string totalFlatpak: main.tFlatpak
    property bool rebootRequired: main.rebootRequired
    property bool releaseUpgradeAvailable: main.releaseUpgradeAvailable
    property string releaseUpgradeVersion: main.releaseUpgradeVersion

    function noUpdateAvailable() {
        const apt = parseInt(totalApt, 10) || 0
        const snap = parseInt(totalSnap, 10) || 0
        const flatpak = parseInt(totalFlatpak, 10) || 0
        return (apt + snap + flatpak) === 0
    }

    ColumnLayout {
        id: mainLayout;
        Layout.topMargin: Kirigami.Units.gridUnit / 2
        Layout.leftMargin: Kirigami.Units.gridUnit / 2
        Layout.bottomMargin: Kirigami.Units.gridUnit / 2
        Layout.rightMargin: Kirigami.Units.gridUnit / 2
        //Layout.preferredWidth: Kirigami.Units.gridUnit * 50

        PlasmaExtras.Heading {
            id: tooltipMaintext
            level: 3
            elide: Text.ElideRight
            text: main.hasError ? i18n("Update Error") : (noUpdateAvailable() ? (root.releaseUpgradeAvailable ? i18n("Upgrade Available") : i18n("No updates available")) : i18n("Updates are available"))
        }

        RowLayout {
            visible: main.hasError
            Kirigami.Icon {
                source: "dialog-error"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents3.Label {
                text: i18n("An error occurred during update")
                color: Kirigami.Theme.negativeTextColor
                font.bold: true
            }
        }

        RowLayout {
            visible: root.rebootRequired && !main.hasError
            Kirigami.Icon {
                source: "system-reboot"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents3.Label {
                text: i18n("System restart required")
                color: Kirigami.Theme.negativeTextColor
                font.bold: true
            }
        }

        RowLayout {
            visible: root.releaseUpgradeAvailable && !main.hasError
            Kirigami.Icon {
                source: "system-software-update"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents3.Label {
                text: root.releaseUpgradeVersion !== "" ? i18n("Distribution upgrade available: Ubuntu %1", root.releaseUpgradeVersion) : i18n("Distribution upgrade available")
                color: Kirigami.Theme.neutralTextColor
                font.bold: true
            }
        }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            visible: !root.noUpdateAvailable() && !main.hasError

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                visible: (parseInt(root.totalApt, 10) || 0) > 0
                PlasmaComponents3.Label {
                    text: i18n("APT:")
                    opacity: 1
                }
                PlasmaComponents3.Label {
                    text: root.totalApt
                    opacity: .7
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                visible: plasmoid.configuration.enableSnapUpdates && plasmoid.configuration.hasSnap && (parseInt(root.totalSnap, 10) || 0) > 0
                PlasmaComponents3.Label {
                    text: i18n("Snap:")
                    opacity: 1
                }
                PlasmaComponents3.Label {
                    text: root.totalSnap
                    opacity: .7
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                visible: plasmoid.configuration.enableFlatpakUpdates && plasmoid.configuration.hasFlatpak && (parseInt(root.totalFlatpak, 10) || 0) > 0
                PlasmaComponents3.Label {
                    text: i18n("Flatpak:")
                    opacity: 1
                }
                PlasmaComponents3.Label {
                    text: root.totalFlatpak
                    opacity: .7
                }
            }
        }
    }
}
