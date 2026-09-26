import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

ColumnLayout {
    id: root

    property var dividerColor: Kirigami.Theme.textColor
    property var dividerOpacity: 0.1
    property string totalArch: "0"
    property string totalAur: "0"
    property bool rebootRequired: false

    function noUpdateAvailable() {
        return totalArch === "0" && totalAur === "0"
    }

    // map the cmd signal
    Connections {
        target: cmd

        function onTotalAur(total) {
            root.totalAur = total
        }

        function onTotalArch(total) {
            root.totalArch = total
        }

        function onRebootStatus(required) {
            root.rebootRequired = required
        }
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
            text: main.hasError ? i18n("Update Error") : (noUpdateAvailable() ? i18n("No updates available") : i18n("Updates are available"))
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
            RowLayout {
                PlasmaComponents3.Label {
                    text: i18n("APT:")
                    opacity: 1
                }
                PlasmaComponents3.Label {
                    text: totalArch
                    opacity: .7
                }
            }
            Item { Layout.fillWidth: true }
            RowLayout {
                visible: totalAur !== "" && totalAur !== "0"
                PlasmaComponents3.Label {
                    text: i18n("Extra:")
                    opacity: 1
                }
                PlasmaComponents3.Label {
                    text: totalAur
                    opacity: .7
                }
            }
        }
    }
}
