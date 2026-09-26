import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {

    id: notificationConfigPage

    property alias cfg_notifyOnUpdates: notifyOnUpdatesBox.checked
    property alias cfg_notifyOnRebootRequired: notifyOnRebootRequiredBox.checked
    property alias cfg_notifyOnSilentUpdate: notifyOnSilentUpdateBox.checked

    ColumnLayout {

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Kirigami.FormLayout {
            wideMode: false

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Desktop Notifications")
            }

            Controls.CheckBox {
                id: notifyOnUpdatesBox
                Kirigami.FormData.label: i18n("Notify when new updates are found: ")
            }

            Controls.CheckBox {
                id: notifyOnRebootRequiredBox
                Kirigami.FormData.label: i18n("Notify when system restart is required: ")
            }

            Controls.CheckBox {
                id: notifyOnSilentUpdateBox
                Kirigami.FormData.label: i18n("Notify on silent update completion: ")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18n("Critical update failures are always notified regardless of these settings to ensure system stability.")
            type: Kirigami.MessageType.Information
            visible: true
        }

    }

}
