pragma Singleton
import QtQuick

QtObject {
    id: registry
    property var history: []
    property var activeSources: ({})
    property var pending: ({})
    property bool autoComplete: true
    property var handler: null

    function reset() {
        history = []
        activeSources = ({})
        pending = ({})
        autoComplete = true
        handler = null
    }

    function recordConnect(ds, source) {
        var next = history.slice()
        next.push({ engine: ds.engine, source: String(source), dataSource: ds })
        history = next
        var act = Object.assign({}, activeSources)
        act[String(source)] = ds
        activeSources = act
    }

    function recordDisconnect(source) {
        var key = String(source)
        var act = Object.assign({}, activeSources)
        delete act[key]
        activeSources = act
        var pend = Object.assign({}, pending)
        delete pend[key]
        pending = pend
    }

    function holdSource(ds, source) {
        var pend = Object.assign({}, pending)
        pend[String(source)] = ds
        pending = pend
    }

    function completeSource(source, exitCode, stdoutStr, stderrStr) {
        var key = String(source)
        var ds = pending[key] || activeSources[key]
        if (!ds) return false
        var pend = Object.assign({}, pending)
        delete pend[key]
        pending = pend
        ds.emitResult(key, exitCode, stdoutStr, stderrStr)
        return true
    }

    function completeMatching(substr, exitCode, stdoutStr, stderrStr) {
        var keys = Object.keys(pending)
        var count = 0
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].indexOf(substr) !== -1) {
                if (completeSource(keys[i], exitCode, stdoutStr, stderrStr)) count++
            }
        }
        return count
    }

    function pendingList() {
        return Object.keys(pending)
    }

    function countHistoryMatching(substr) {
        var n = 0
        for (var i = 0; i < history.length; i++) {
            if (history[i].source.indexOf(substr) !== -1) n++
        }
        return n
    }
}
