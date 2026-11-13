import QtQuick
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "."

Item {
    id: root

    property bool iconUseCustomColor: plasmoid.configuration.iconUseCustomColor
    property string iconColor: plasmoid.configuration.iconColor

    anchors.centerIn: parent
    property var source

    Kirigami.Icon {
        id: svgItem
        opacity: 1
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        smooth: true
        isMask: {
            let src = String(root.source || "")
            return !src.startsWith("/") && !src.startsWith("~/") && !src.includes("://")
        }
        color: iconUseCustomColor ? iconColor : Kirigami.Theme.textColor
        source: {
            let src = String(root.source || "software-update-available.svg")
            if (src.includes("://")) return src
            if (src.startsWith("/")) return "file://" + src
            if (src.startsWith("~/")) {
                let home = StandardPaths.standardLocations(StandardPaths.HomeLocation)[0].toString().replace(/^file:\/\//, "")
                return "file://" + home + src.slice(1)
            }
            if (src.indexOf("/") === -1 && /\.(svgz?|png|jpe?g|webp|ico)$/i.test(src)) {
                return Qt.resolvedUrl("../../assets/" + src)
            }
            return src
        }
    }
}
