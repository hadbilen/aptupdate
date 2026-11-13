import QtQuick

QtObject {
    id: ds
    property string engine: ""
    property var connectedSources: []
    property int interval: 0
    property int timeout: 0
    signal sourceConnected(string source)
    signal sourceDisconnected(string source)
    signal sourceAdded(string source)
    signal sourceRemoved(string source)
    signal newData(string source, var data)

    function connectSource(source) {
        var src = String(source)
        if (connectedSources.indexOf(src) === -1) {
            var next = connectedSources.slice()
            next.push(src)
            connectedSources = next
        }
        DataSourceRegistry.recordConnect(ds, src)
        ds.sourceAdded(src)
        ds.sourceConnected(src)

        var res = null
        if (typeof DataSourceRegistry.handler === "function") {
            res = DataSourceRegistry.handler(src, ds)
        }
        if (res && res.hold) {
            DataSourceRegistry.holdSource(ds, src)
            return
        }
        if (!DataSourceRegistry.autoComplete && (!res || res.hold !== false)) {
            DataSourceRegistry.holdSource(ds, src)
            return
        }
        var code = (res && res.exitCode !== undefined) ? res.exitCode : 0
        var out = (res && res.stdout !== undefined) ? String(res.stdout) : ""
        var err = (res && res.stderr !== undefined) ? String(res.stderr) : ""
        DataSourceRegistry.holdSource(ds, src)
        Qt.callLater(function() {
            if (ds && DataSourceRegistry.pending[src] === ds) {
                DataSourceRegistry.completeSource(src, code, out, err)
            }
        })
    }

    function disconnectSource(source) {
        var src = String(source)
        var next = []
        for (var i = 0; i < connectedSources.length; i++) {
            if (connectedSources[i] !== src) next.push(connectedSources[i])
        }
        connectedSources = next
        DataSourceRegistry.recordDisconnect(src)
        ds.sourceDisconnected(src)
        ds.sourceRemoved(src)
    }

    function emitResult(source, exitCode, stdoutStr, stderrStr) {
        newData(String(source), {
            "exit code": exitCode,
            "exit status": 0,
            "stdout": stdoutStr !== undefined ? String(stdoutStr) : "",
            "stderr": stderrStr !== undefined ? String(stderrStr) : ""
        })
    }
}
