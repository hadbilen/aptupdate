import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: aboutPage

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        Kirigami.FormLayout {
            wideMode: false

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: "APT Update Counter"
            }

            Controls.Label {
                Kirigami.FormData.label: "Version: "
                text: "1.0.2"
                font.bold: true
            }

            Controls.Label {
                Kirigami.FormData.label: "Description: "
                text: "KDE Plasma 6 update monitor for APT, Snap, and Flatpak on Kubuntu, Ubuntu, and Debian."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Controls.Label {
                Kirigami.FormData.label: "Maintainer: "
                text: "hadbilen (<a href=\"https://github.com/hadbilen/aptupdate\">hadbilen/aptupdate</a>)"
                onLinkActivated: (url) => Qt.openUrlExternally(url)
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: "Credits & Acknowledgements"
            }

            Controls.Label {
                Kirigami.FormData.label: "Original Creator: "
                text: "Alan Bouteiller (A2N)"
            }

            Controls.Label {
                Kirigami.FormData.label: "Upstream Project: "
                text: "<a href=\"https://github.com/bouteillerAlan/archupdate\">bouteillerAlan/archupdate</a>"
                onLinkActivated: (url) => Qt.openUrlExternally(url)
            }

            Controls.Label {
                Kirigami.FormData.label: "License: "
                text: "GNU General Public License v3.0 (GPL-3.0)"
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: "Notes"
            }

            Controls.Label {
                text: "This plasmoid is a dedicated Debian/Ubuntu port with native APT, Snap, and Flatpak integration, derived with gratitude from the original Archupdate widget."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.8
            }
        }
    }
}
