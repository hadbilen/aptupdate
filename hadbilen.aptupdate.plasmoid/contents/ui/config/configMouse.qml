import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.components as PlasmaComponents

Kirigami.ScrollablePage {

    id: mouseConfigPage

    property alias cfg_invertMouseAction: invertMouseAction.checked
    property alias cfg_mainIsRefresh: mainIsRefresh.checked

    Kirigami.FormLayout {
        id: mouseFormLayout
        wideMode: false

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Mouse action")
        }

        ColumnLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.RadioButton {
                text: i18n("Left click to check, middle click to update")
                checked: !invertMouseAction.checked
                autoExclusive: true
            }

            PlasmaComponents.RadioButton {
                id: invertMouseAction
                text: i18n("Middle click to check, left click to update")
                autoExclusive: true
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Main action behavior")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            text: i18n("Doing both at the same time is prone to bug so it's not possible")
            visible: true
        }

        Controls.CheckBox {
            id: mainIsRefresh
            text: i18n("Do a refresh in place of opening the popup")
            checked: false
            Kirigami.FormData.isSection: true
        }

    }

}
