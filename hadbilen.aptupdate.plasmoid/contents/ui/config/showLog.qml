import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Kirigami.ScrollablePage {

    id: debugConfigPage

    property alias cfg_debugLog: logWindow.text

    Kirigami.FormLayout {
        id: debugFormLayout
        wideMode: true

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Component.onCompleted: {
            var lay = debugFormLayout.children[0];
            lay.anchors.horizontalCenter = undefined;
            lay.anchors.left = debugFormLayout.left;
            lay.anchors.right = debugFormLayout.right;
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Debug log")
        }

        PlasmaComponents.Button {
            Kirigami.FormData.isSection: true
            text: i18n("Clear log data (hit apply after)")
            onClicked: logWindow.text = ''
        }

        Controls.Label {
            id: logWindow
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

    }

}
