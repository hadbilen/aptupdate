import QtQuick
import QtTest
import org.kde.plasma.plasmoid as PlasmoidMod
import "../../hadbilen.aptupdate.plasmoid/contents/service/CommandBuilder.js" as CmdBuilder

Item {
    id: root
    width: 480
    height: 480

    function i18n(text) {
        var out = String(text)
        for (var i = 1; i < arguments.length; i++) {
            out = out.replace("%" + i, String(arguments[i]))
        }
        return out
    }
    function i18np(singular, plural, count) {
        var out = (Number(count) === 1) ? String(singular) : String(plural)
        for (var i = 2; i < arguments.length; i++) {
            out = out.replace("%" + (i - 1), String(arguments[i]))
        }
        return out
    }
    function i18nc(ctx, text) {
        var args = [text]
        for (var i = 2; i < arguments.length; i++) args.push(arguments[i])
        return i18n.apply(this, args)
    }

    property var plasmoid: QtObject {
        property string id: "test-1"
        property int formFactor: 2
        property var configuration: PlasmoidMod.Plasmoid.configuration
    }

    property var cmd: QtObject {
        signal sourceConnected(string source)
        signal isUpdating(bool status)
        signal errorStatus(bool err)
        signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)
        signal totalApt(string count)
        signal totalSnap(string count)
        signal totalFlatpak(string count)
        signal updateRunning(bool busy)
        property var executed: []
        function exec(command) {
            executed.push(String(command))
        }
        function reset() {
            executed = []
        }
    }

    property var dbg: QtObject {
        property var logs: []
        function log(msg, err) { logs.push({ msg: msg, err: Boolean(err) }) }
    }

    property var main: QtObject {
        property string logDir: "/tmp/aptupdate-export-logdir"
        property string osId: "ubuntu"
        property string osIdLike: "debian"
        property bool hasSystemdScope: false
        property string tApt: "1"
        property string tSnap: "1"
        property string tFlatpak: "0"
        property string listApt: ""
        property string listSnap: ""
        property string listFlatpak: ""
        property string lastCheckTime: "2026-11-13 10:00"
        property bool isChecking: false
        property bool isInstalling: false
        property bool isOnUpdate: false
        property bool isOnDebug: false
        property bool isUpdatingAll: false
        property bool hasError: false
        property bool updateError: false
        property bool hasCheckedOnce: true
        property bool isStartupDelaying: false
        property bool isPkgManagerBusy: false
        property bool lockBlockedUpdate: false
        property bool expanded: false
        property bool isPrewarmed: false
        property bool rebootRequired: true
        property bool releaseUpgradeAvailable: false
        property string releaseUpgradeVersion: ""
        property bool isConnected: true
        property string lastErrorMessage: ""
        property var repoErrors: ({ apt: false, snap: false, flatpak: false })
        property var activeUpdateJobs: ({})
        property bool enableSnapUpdates: PlasmoidMod.Plasmoid.configuration.enableSnapUpdates
        property bool enableFlatpakUpdates: PlasmoidMod.Plasmoid.configuration.enableFlatpakUpdates
        property bool hasSnap: PlasmoidMod.Plasmoid.configuration.hasSnap
        property bool hasFlatpak: PlasmoidMod.Plasmoid.configuration.hasFlatpak
        property var registeredJobs: []
        readonly property var startupDelayTimer: null

        function canUpdateAll() { return true }
        function canUpdate(repo) { return true }
        function canUpdatePackage(repo, pkg, appId) { return true }
        function isPackageBusy(repo, pkg, appId) { return false }
        function clearPendingRetries() {}
        function clearRepoErrors() {}
        function hasUpdate() { return (parseInt(tApt, 10) || 0) > 0 }
        function refreshAll() {}
        function abortUpdate() {}
        function isHelperCommand(s) { return false }
        function registerUpdateJob(c, type, repo, pkg, appId, branch) {
            registeredJobs.push({ cmd: c, type: type, repo: repo, pkg: pkg, appId: appId, branch: branch })
        }
    }

    property var updater: null

    function findActionByText(item, fragment) {
        if (!item) return null
        if (item.actions && item.actions.length !== undefined) {
            for (var i = 0; i < item.actions.length; i++) {
                var act = item.actions[i]
                if (act && act.text && String(act.text).indexOf(fragment) !== -1) {
                    return act
                }
            }
        }
        var lists = []
        if (item.children) lists.push(item.children)
        if (item.contentData) lists.push(item.contentData)
        for (var l = 0; l < lists.length; l++) {
            var arr = lists[l]
            for (var j = 0; j < arr.length; j++) {
                var found = findActionByText(arr[j], fragment)
                if (found) return found
            }
        }
        return null
    }

    TestCase {
        name: "ExportCommands"
        function test_export() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            cfg.hasSnap = true
            cfg.hasFlatpak = true
            cfg.hasNala = true
            cfg.useNala = true
            cfg.enableSnapUpdates = true
            cfg.enableFlatpakUpdates = true
            cfg.silentUpdate = true
            cfg.includePhasedUpdates = false
            cfg.notCloseCommand = true
            cfg.termNoCloseCmd = "sh -c"
            cfg.termNoCloseSuffix = "; echo DONE"

            var uComp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/service/Updater.qml")
            compare(uComp.status, Component.Ready, uComp.errorString())
            var u = uComp.createObject(root)
            verify(u !== null)
            root.updater = u

            var fComp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/Full.qml")
            compare(fComp.status, Component.Ready, fComp.errorString())
            var f = fComp.createObject(root, { width: 400, height: 500 })
            verify(f !== null)

            cmd.reset()
            var restartAct = findActionByText(f, "Restart")
            verify(restartAct !== null)
            restartAct.trigger()
            console.log("EXPORT_CMD|reboot|" + JSON.stringify(cmd.executed[0] || ""))

            var silentWrapErr = u.buildSilentWrapper("apt_empty_test.log", "exit 7", "Test fail")
            console.log("EXPORT_CMD|silent_empty_fail|" + JSON.stringify(silentWrapErr))

            var silentAptSnap = u.getEffectiveSilentUpdateCommand(true, true, false)
            console.log("EXPORT_CMD|silent_apt_snap|" + JSON.stringify(silentAptSnap))

            var silentAptOnly = u.getEffectiveSilentUpdateCommand(true, false, false)
            console.log("EXPORT_CMD|silent_apt_only|" + JSON.stringify(silentAptOnly))

            var termNotClose = u.buildTerminalCommand("false")
            console.log("EXPORT_CMD|term_notclose_fail|" + JSON.stringify(termNotClose))

            var flatpakListCmd = u.getListFlatpakCmd()
            console.log("EXPORT_CMD|list_flatpak|" + JSON.stringify(flatpakListCmd))

            cmd.reset()
            u.checkLock()
            console.log("EXPORT_CMD|check_lock|" + JSON.stringify(cmd.executed[0] || ""))

            console.log("EXPORT_CMD|connectivity|" + JSON.stringify(u.connectivityCmd))

            cmd.reset()
            u.sendNotify("Alert Title", "Alert Body", "dialog-error", "critical")
            console.log("EXPORT_CMD|send_notify|" + JSON.stringify(cmd.executed[0] || ""))

            console.log("EXPORT_CMD|count_apt|" + JSON.stringify(CmdBuilder.buildCountArchCmd(false)))
            console.log("EXPORT_CMD|list_apt|" + JSON.stringify(CmdBuilder.buildListArchCmd(false)))

            cfg.hasSnap = true
            cfg.enableSnapUpdates = true
            console.log("EXPORT_CMD|list_snap|" + JSON.stringify(u.getListSnapCmd()))

            cmd.reset()
            u.sendNotify("-u", "--urgency=critical", "dialog-warning", "critical")
            console.log("EXPORT_CMD|send_notify_dash|" + JSON.stringify(cmd.executed[0] || ""))

            var silentAllThree = u.getEffectiveSilentUpdateCommand(true, true, true, "", "aptupdate_all_pk_fp.log", "")
            console.log("EXPORT_CMD|silent_all_three|" + JSON.stringify(silentAllThree))

            var silentPgidWrap = u.buildSilentWrapper("pgid_test.log", "sleep 20", "Test PGID", "", "/tmp/ignored/test.pgid")
            console.log("EXPORT_CMD|silent_pgid_wrap|" + JSON.stringify(silentPgidWrap))
            console.log("EXPORT_CMD|kill_pgid_cmd|" + JSON.stringify(CmdBuilder.buildSafeKillPgidAndRemoveCmd(["__RUNTIME_DIR__/aptupdate/test.pgid"])))

            cfg.notCloseCommand = true
            cfg.termNoCloseCmd = "konsole --noclose -e"
            cfg.termNoCloseSuffix = "; exec $SHELL"
            var termExecShell = u.buildTerminalCommand("false", "/tmp/ignored/term_rc_exec", "", "")
            console.log("EXPORT_CMD|term_exec_shell|" + JSON.stringify(termExecShell))

            cfg.notCloseCommand = false
            cfg.termCmd = "sh -c"
            var termPauseFail = u.buildTerminalCommand("exit 7", "", "", "")
            console.log("EXPORT_CMD|term_pause_fail|" + JSON.stringify(termPauseFail))

            var termSymlinkDir = CmdBuilder.buildTerminalCommand({
                innerCmd: "true",
                notCloseCommand: true,
                termCmd: "sh -c",
                termNoCloseCmd: "sh -c",
                termNoCloseSuffix: "",
                errPrompt: "err",
                logDir: "__SYMLINK_LOGDIR__",
                rcFile: "__SYMLINK_LOGDIR__/term_rc_sym",
                useScope: false
            })
            console.log("EXPORT_CMD|term_symlink_logdir|" + JSON.stringify(termSymlinkDir))

            console.log("EXPORT_CMD|safe_read_payload|" + JSON.stringify(CmdBuilder.buildSafeReadAndRemoveCmd("__PAYLOAD_DIR__/x\"$(touch pwned_read)\"y.txt")))
            console.log("EXPORT_CMD|safe_remove_payload|" + JSON.stringify(CmdBuilder.buildSafeRemoveCmd("__PAYLOAD_DIR__/x\"$(touch pwned_rm)\"y.txt")))

            f.destroy()
            u.destroy()
        }
    }
}
