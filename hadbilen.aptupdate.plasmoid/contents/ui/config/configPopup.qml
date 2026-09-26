import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.ScrollablePage {

    id: popupConfigPage

    property alias cfg_nameUseCustomColor: nameUseCustomColor.checked
    property alias cfg_nameColor: nameColor.color

    property alias cfg_sourceUseCustomColor: sourceUseCustomColor.checked
    property alias cfg_sourceColor: sourceColor.color

    property alias cfg_fvUseCustomColor: fvUseCustomColor.checked
    property alias cfg_fvColor: fvColor.color

    property alias cfg_separatorUseCustomColor: separatorUseCustomColor.checked
    property alias cfg_separatorColor: separatorColor.color
    property alias cfg_separatorText: separatorText.text

    property alias cfg_tvUseCustomColor: tvUseCustomColor.checked
    property alias cfg_tvColor: tvColor.color

    // generate & style the name of the package
    function generateName() {
        const nc = cfg_nameUseCustomColor ? cfg_nameColor : Kirigami.Theme.textColor
        const sc = cfg_sourceUseCustomColor ? cfg_sourceColor : Kirigami.Theme.disabledTextColor
        return '<font color="' + nc + '"> ' + i18n("PackageName") + ' </font><font color="' + sc + '"> ' + i18n("from source") + '</font>'
    }

    // generate & style the version of the package
    function generateVersion() {
        const fvc = cfg_fvUseCustomColor ? cfg_fvColor : Kirigami.Theme.negativeTextColor
        const sc = cfg_separatorUseCustomColor ? cfg_separatorColor : Kirigami.Theme.textColor
        const tvc = cfg_tvUseCustomColor ? cfg_tvColor : Kirigami.Theme.positiveTextColor
        return '<font color="' + fvc + '">1.0.0</font><font color="' + sc + '"> ' + cfg_separatorText + ' </font><font color="' + tvc + '">2.0.0</font>'
    }

    Kirigami.FormLayout {
        id: popupFormLayout
        wideMode: true

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }

        Component.onCompleted: {
            var lay = popupFormLayout.children[0];
            lay.anchors.horizontalCenter = undefined;
            lay.anchors.left = popupFormLayout.left;
            lay.anchors.right = popupFormLayout.right;
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup color")
        }

        ColumnLayout {
            Kirigami.FormData.isSection: true
            spacing: 2

            Kirigami.Heading {
                level: 3
                Layout.fillWidth: true
                text: generateName()
            }

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: generateVersion()
            }
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: nameUseCustomColor
                text: i18n("Custom name color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: nameColor
                enabled: nameUseCustomColor.checked
            }
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: sourceUseCustomColor
                text: i18n("Custom source color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: sourceColor
                enabled: sourceUseCustomColor.checked
            }
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: fvUseCustomColor
                text: i18n("Custom 'from version' color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: fvColor
                enabled: fvUseCustomColor.checked
            }
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: separatorUseCustomColor
                text: i18n("Custom separator color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: separatorColor
                enabled: separatorUseCustomColor.checked
            }
        }

        Controls.TextField {
            id: separatorText
            Layout.fillWidth: true
            Kirigami.FormData.label: i18n("Separator: ")
        }

        RowLayout {
            Kirigami.FormData.isSection: true
            spacing: Kirigami.Units.smallSpacing

            Controls.CheckBox {
                id: tvUseCustomColor
                text: i18n("Custom 'to version' color")
                checked: false
            }

            KQuickControls.ColorButton {
                id: tvColor
                enabled: tvUseCustomColor.checked
            }
        }

    }

}
