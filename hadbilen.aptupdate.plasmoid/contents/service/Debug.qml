import QtQuick
import QtCore

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

import "CommandBuilder.js" as CmdBuilder

Item {
    id: debug

    property var logBuffer: []
    property var pendingAppendLines: []
    property bool pendingClear: false
    property bool isFlushing: false

    readonly property string cacheDir: {
        var base = StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString().replace(/^file:\/\//, "")
        if (!base) {
            var home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
            base = home ? (home + "/.cache") : ""
        }
        return base ? (base + "/hadbilen.aptupdate.plasmoid") : ""
    }
    readonly property string logFilePath: cacheDir ? (cacheDir + "/debug.log") : ""

    function escapeHtml(text) {
        if (text === undefined || text === null) return ""
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;")
    }

    function sanitizeSingleLine(text) {
        return String(text === undefined || text === null ? "" : text).replace(/[\r\n]+/g, " ").trim()
    }

    function log(message: string, onError: bool) {
        var stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
        var level = onError ? "[ERROR]" : "[INFO]"
        var line = stamp + " " + level + " " + sanitizeSingleLine(message)
        console.log(line)
        logBuffer.push(line)
        if (logBuffer.length > 200) {
            logBuffer.shift()
        }
        pendingAppendLines.push(line)
        if (pendingAppendLines.length > 200) {
            pendingAppendLines.shift()
        }
        if (!isFlushing) {
            flushTimer.restart()
        }
    }

    function getFormattedLog() {
        return logBuffer.join("\n")
    }

    function clear() {
        logBuffer = []
        pendingAppendLines = []
        pendingClear = true
        flushTimer.stop()
        flushNow()
    }

    function flushNow() {
        if (isFlushing) return
        if (!pendingClear && pendingAppendLines.length === 0) return
        if (!cacheDir || !logFilePath) {
            pendingClear = false
            pendingAppendLines = []
            return
        }

        var doClear = pendingClear
        var batch = pendingAppendLines.slice()
        pendingClear = false
        pendingAppendLines = []

        var safeDir = CmdBuilder.bashEscape(cacheDir)
        var safeFile = CmdBuilder.bashEscape(logFilePath)
        var parts = []
        parts.push("umask 077")
        parts.push("cachedir='" + safeDir + "'; logfile='" + safeFile + "'")
        parts.push("mkdir -p -m 0700 \"$cachedir\" 2>/dev/null || exit 1")
        parts.push("if ! test -d \"$cachedir\" || ! test -O \"$cachedir\" || test -L \"$cachedir\"; then exit 1; fi")
        parts.push("chmod 0700 \"$cachedir\" 2>/dev/null || true")
        if (doClear) {
            parts.push("if test -L \"$logfile\"; then exit 1; fi")
            parts.push("tmpclr=\"$(mktemp \"$cachedir/debug_clr.XXXXXX\")\" || exit 1")
            parts.push("chmod 0600 \"$tmpclr\" && mv -f \"$tmpclr\" \"$logfile\" || { rm -f \"$tmpclr\"; exit 1; }")
        } else {
            parts.push("if test -L \"$logfile\"; then exit 1; fi")
            parts.push("if [ ! -e \"$logfile\" ]; then tmpinit=\"$(mktemp \"$cachedir/debug_init.XXXXXX\")\" || exit 1; chmod 0600 \"$tmpinit\" && mv -f \"$tmpinit\" \"$logfile\" || { rm -f \"$tmpinit\"; exit 1; }; fi")
        }
        parts.push("if test -L \"$logfile\" || ! test -O \"$logfile\" || ! test -f \"$logfile\"; then exit 1; fi")

        if (batch.length > 0) {
            var escapedLines = []
            for (var i = 0; i < batch.length; i++) {
                escapedLines.push("'" + CmdBuilder.bashEscape(batch[i]) + "'")
            }
            parts.push("printf '%s\\n' " + escapedLines.join(" ") + " >> \"$logfile\"")
            parts.push("tmpfile=\"$(mktemp \"$cachedir/debug.XXXXXX\")\" || exit 1")
            parts.push("tail -n 200 \"$logfile\" > \"$tmpfile\" && chmod 0600 \"$tmpfile\" && mv -f \"$tmpfile\" \"$logfile\" || { rm -f \"$tmpfile\"; exit 1; }")
        }

        var cmdLine = "bash -c '" + CmdBuilder.bashEscape(parts.join("; ")) + "'"
        isFlushing = true
        writerSource.connectSource(cmdLine)
    }

    Timer {
        id: flushTimer
        interval: 120
        repeat: false
        onTriggered: debug.flushNow()
    }

    Plasma5Support.DataSource {
        id: writerSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            if (!data || data["exit code"] === undefined) return
            var exitCode = data["exit code"]
            disconnectSource(sourceName)
            debug.isFlushing = false
            if (exitCode !== 0) {
                console.warn("APTUPDATE debug.log write/clear failed (exit " + exitCode + ")")
            }
            if (debug.pendingClear || debug.pendingAppendLines.length > 0) {
                debug.flushNow()
            }
        }
    }
}
