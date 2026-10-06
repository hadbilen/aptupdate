import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {

    id: notificationConfigPage

    property alias cfg_notifyOnUpdates: notifyOnUpdatesBox.checked
    property alias cfg_notificationThreshold: notificationThresholdSpin.value
    property alias cfg_notifyOnStartup: notifyOnStartupBox.checked
    property alias cfg_notifyOnRebootRequired: notifyOnRebootRequiredBox.checked
    property alias cfg_notifyOnReleaseUpgrade: notifyOnReleaseUpgradeBox.checked
    property alias cfg_notifyOnSilentUpdate: notifyOnSilentUpdateBox.checked

    Kirigami.FormLayout {
        id: notificationFormLayout
        wideMode: false

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Desktop Notifications")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            text: i18n("Critical update failures are always notified regardless of these settings to ensure system stability.\nEven if desktop notifications are turned off, system restart requirements will still be shown as a status banner in the popup.")
            type: Kirigami.MessageType.Information
            visible: true
        }

        Controls.CheckBox {
            id: notifyOnUpdatesBox
            text: i18n("Notify when new updates are found")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing
            enabled: notifyOnUpdatesBox.checked

            Controls.Label {
                text: i18n("Minimum pending updates required to notify: ")
            }

            Controls.SpinBox {
                id: notificationThresholdSpin
                from: 1
                to: 20
                value: 1
                editable: true
            }

            Controls.Label {
                text: i18n("updates")
            }
        }

        Controls.CheckBox {
            id: notifyOnStartupBox
            text: i18n("Notify if updates exceed threshold on session login")
            enabled: notifyOnUpdatesBox.checked
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: notifyOnRebootRequiredBox
            text: i18n("Send desktop notification when system restart is required")
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: notifyOnReleaseUpgradeBox
            text: i18n("Notify when a new distribution release is available")
            Kirigami.FormData.isSection: true
        }

        Controls.CheckBox {
            id: notifyOnSilentUpdateBox
            text: i18n("Notify on silent update completion")
            Kirigami.FormData.isSection: true
        }
    }

}
