import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Kirigami.ScrollablePage {

    id: debugConfigPage

    Component.onCompleted: {
        if (typeof plasmoid !== "undefined" && plasmoid.rootItem && plasmoid.rootItem.debugService) {
            logWindow.text = plasmoid.rootItem.debugService.getFormattedLog()
        } else if (typeof plasmoid !== "undefined" && plasmoid.configuration && plasmoid.configuration.debugLog && plasmoid.configuration.debugLog !== "Nothing") {
            logWindow.text = plasmoid.configuration.debugLog
        }
    }

    Kirigami.FormLayout {
        id: debugFormLayout
        wideMode: true

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Debug log")
        }

        PlasmaComponents.Button {
            Kirigami.FormData.isSection: true
            text: i18n("Clear log data")
            onClicked: {
                logWindow.text = ''
                if (typeof plasmoid !== "undefined" && plasmoid.rootItem && plasmoid.rootItem.debugService) {
                    plasmoid.rootItem.debugService.clear()
                }
                if (typeof plasmoid !== "undefined" && plasmoid.configuration) {
                    plasmoid.configuration.debugLog = ""
                }
            }
        }

        Controls.Label {
            id: logWindow
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

    }

}
