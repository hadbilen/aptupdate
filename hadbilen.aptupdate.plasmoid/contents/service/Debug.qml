import QtQuick

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: debug

    property var logBuffer: []

    function escapeHtml(text) {
        if (text === undefined || text === null) return ""
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;")
    }

    function log(message: string, onError: bool) {
        let date = Qt.formatTime(new Date(), "hh:mm:ss")
        let safeMsg = escapeHtml(message)
        let msg = '<font color="' + (onError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.positiveTextColor) + '">' + date + "</font>" + ' - ' + safeMsg + '<br/>'
        console.log(date + ' - ' + message)
        logBuffer.push(msg)
        if (logBuffer.length > 200) {
            logBuffer.shift()
        }
        if (typeof plasmoid !== "undefined" && plasmoid.configuration) {
            plasmoid.configuration.debugLog = getFormattedLog()
        }
    }

    function getFormattedLog() {
        return logBuffer.join("")
    }

    function clear() {
        logBuffer = []
        if (typeof plasmoid !== "undefined" && plasmoid.configuration) {
            plasmoid.configuration.debugLog = ""
        }
    }
}
