import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.kde.plasma.plasmoid

import org.kde.kirigami as Kirigami

Item {
    id: debug

    property var logBuffer: []

    function log(message: string, onError: bool) {
        let date = Qt.formatTime(new Date(), "hh:mm:ss")
        let msg = '<font color="' + (onError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.positiveTextColor) + '">' + date + "</font>" + ' - ' + message + '<br/>'
        console.log(date + ' - ' + message)
        logBuffer.push(msg)
        if (logBuffer.length > 200) {
            logBuffer.shift()
        }
    }

    function getFormattedLog() {
        return logBuffer.join("")
    }

    function clear() {
        logBuffer = []
    }
}
