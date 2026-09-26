import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {

    id: notificationConfigPage

    property alias cfg_notifyOnUpdates: notifyOnUpdatesBox.checked
    property alias cfg_notifyOnRebootRequired: notifyOnRebootRequiredBox.checked
    property alias cfg_notifyOnSilentUpdate: notifyOnSilentUpdateBox.checked

    Kirigami.FormLayout {
        id: notificationFormLayout
        wideMode: true

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Component.onCompleted: {
            var lay = notificationFormLayout.children[0];
            lay.anchors.horizontalCenter = undefined;
            lay.anchors.left = notificationFormLayout.left;
            lay.anchors.right = notificationFormLayout.right;
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Desktop Notifications")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            text: i18n("Critical update failures are always notified regardless of these settings to ensure system stability.")
            type: Kirigami.MessageType.Information
            visible: true
        }

        Controls.CheckBox {
            id: notifyOnUpdatesBox
            text: i18n("Notify when new updates are found")
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: notifyOnRebootRequiredBox
            text: i18n("Notify when system restart is required")
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: notifyOnSilentUpdateBox
            text: i18n("Notify on silent update completion")
            Kirigami.FormData.isSection: true
        }
    }

}
