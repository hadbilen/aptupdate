import QtQuick
import QtTest
import org.kde.plasma.plasmoid as PlasmoidMod
import org.kde.plasma.plasma5support as P5S
import "mocks/org/kde/plasma/plasmoid" as MockCfg
import "../hadbilen.aptupdate.plasmoid/contents/service/CommandBuilder.js" as CmdBuilder

Item {
    id: harness
    width: 480
    height: 520

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

    Component {
        id: configFactory
        MockCfg.ConfigDefaults {}
    }

    TestCase {
        name: "MainStateSeams"
        when: windowShown

        function findDataObj(rootObj, pred) {
            if (!rootObj) return null
            if (rootObj.data) {
                for (var i = 0; i < rootObj.data.length; i++) {
                    var item = rootObj.data[i]
                    if (pred(item)) return item
                }
            }
            if (rootObj.children) {
                for (var j = 0; j < rootObj.children.length; j++) {
                    var child = rootObj.children[j]
                    if (pred(child)) return child
                }
            }
            return null
        }

        function findWatchdogTimer(m) {
            return findDataObj(m, function(o) {
                return o && o.interval === 45000 && o.repeat === false && typeof o.triggered === "function"
            })
        }

        function findInstallWatchdogTimer(m) {
            return findDataObj(m, function(o) {
                return o && o.interval === 600000 && o.repeat === false && typeof o.triggered === "function"
            })
        }

        function findRetryTimer(m) {
            return findDataObj(m, function(o) {
                return o && o.pendingJobs !== undefined && typeof o.triggered === "function"
            })
        }

        function createMain(overrides, handlerFn) {
            P5S.DataSourceRegistry.reset()
            var cfg = configFactory.createObject(harness, overrides || {})
            verify(cfg !== null)
            PlasmoidMod.PlasmoidHarness.setConfiguration(cfg)
            if (handlerFn) {
                P5S.DataSourceRegistry.handler = handlerFn
            }
            var comp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/main.qml")
            compare(comp.status, Component.Ready, comp.errorString())
            var m = comp.createObject(harness)
            verify(m !== null)
            return { main: m, cfg: cfg }
        }

        function defaultOnlineHandler(src) {
            if (src.indexOf("command -v snap") !== -1) return { exitCode: 0, stdout: "1\n" }
            if (src.indexOf("command -v flatpak") !== -1) return { exitCode: 0, stdout: "1\n" }
            if (src.indexOf("command -v nala") !== -1) return { exitCode: 0, stdout: "0\n" }
            if (src.indexOf("/etc/os-release") !== -1) return { exitCode: 0, stdout: "ID=ubuntu\nID_LIKE=debian\n" }
            if (src.indexOf("systemd-run") !== -1 && src.indexOf("--scope --quiet -- true") !== -1) return { exitCode: 0, stdout: "1\n" }
            if (src.indexOf("stat -c %Y /var/lib/apt/lists") !== -1) {
                var twoDaysAgo = Math.floor(Date.now() / 1000) - (2 * 86400 + 60)
                return { exitCode: 0, stdout: String(twoDaysAgo) + "\n" }
            }
            if (src.indexOf("ip -o route get") !== -1) return { exitCode: 0, stdout: "1\n" }
            if (src.indexOf("lock-frontend") !== -1) return { exitCode: 0, stdout: "0\n" }
            if (src.indexOf("reboot-required") !== -1) return { exitCode: 0, stdout: "0\n" }
            if (src.indexOf("release-upgrade-available") !== -1) return { exitCode: 0, stdout: "" }
            if (src.indexOf("cache.json") !== -1 && src.indexOf("mktemp") === -1) return { exitCode: 0, stdout: "" }
            if (src.indexOf("apt-get -s") !== -1 && src.indexOf("END {print c+0}") !== -1) return { exitCode: 0, stdout: "0\n" }
            if (src.indexOf("apt-get -s") !== -1) return { exitCode: 0, stdout: "" }
            if (src.indexOf("snap refresh --list") !== -1) return { exitCode: 0, stdout: "" }
            if (src.indexOf("flatpak remote-ls") !== -1) return { exitCode: 0, stdout: "" }
            return { exitCode: 0, stdout: "" }
        }

        function test_01_startup_probe_preserves_cache_and_never_toggles_checking() {
            var expectedLastCheckIso = new Date(Date.now() - 86400 * 1000).toISOString()
            var cachedPayload = JSON.stringify({
                tApt: "4",
                tSnap: "1",
                tFlatpak: "2",
                listApt: "curl 1.0 -> 2.0 Ubuntu:24.04/noble-updates amd64",
                listSnap: "",
                listFlatpak: "",
                lastCheckIso: expectedLastCheckIso,
                lastCheckOffline: false
            })
            var env = createMain({
                startupCheckMode: 0,
                enableSnapUpdates: true,
                enableFlatpakUpdates: true,
                hasSnap: true,
                hasFlatpak: true
            }, function(src) {
                if (src.indexOf("cache.json") !== -1 && src.indexOf("mktemp") === -1) {
                    return { exitCode: 0, stdout: cachedPayload }
                }
                if (src.indexOf("command -v snap") !== -1) {
                    return { hold: true }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                compare(env.main.tApt, "4")
                compare(env.main.lastCheckIso, expectedLastCheckIso)
                verify(env.main.lastCheckTime !== "", "Loaded lastCheckIso must populate lastCheckTime")
                verify(!env.main.isChecking, "Startup provider probe must not set isChecking")
                verify(P5S.DataSourceRegistry.pendingList().some(function(s) { return s.indexOf("command -v snap") !== -1 }), "snap probe should be pending in DataSource")

                compare(P5S.DataSourceRegistry.completeMatching("command -v snap", 0, "1\n", ""), 1)
                wait(40)
                compare(env.main.tApt, "4")
                compare(env.main.tSnap, "1")
                verify(!env.main.isChecking, "Startup probe completion must not leave isChecking set")
                compare(P5S.DataSourceRegistry.countHistoryMatching("cache.XXXXXX"), 0)
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_02_connectivity_tracked_watchdog_and_offline_savecache_barrier() {
            var holdConnectivity = false
            var offlineReply = false
            var env = createMain({ startupCheckMode: 0 }, function(src) {
                if (src.indexOf("ip -o route get") !== -1) {
                    if (holdConnectivity) return { hold: true }
                    if (offlineReply) return { exitCode: 0, stdout: "0\n" }
                    return { exitCode: 0, stdout: "1\n" }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                holdConnectivity = true
                env.main.refreshAll()
                verify(env.main.connectivityProbePending, "connectivityProbePending must be armed")
                verify(env.main.isChecking, "Connectivity check must set isChecking while in flight")
                verify(Object.keys(env.main.activeCheckSources).length >= 1, "activeCheckSources must track connectivity probe")

                var wd = findWatchdogTimer(env.main)
                verify(wd !== null, "watchdogTimer must exist")
                wd.triggered()
                verify(!env.main.isChecking, "Watchdog timeout must clear isChecking")
                verify(!env.main.connectivityProbePending, "Watchdog timeout must clear connectivityProbePending")
                verify(env.main.connectivityError, "Watchdog timeout on connectivity must set connectivityError")
                verify(env.main.hasError, "Watchdog timeout on connectivity must set hasError")
                verify(!env.main.canUpdateAll(), "Connectivity error must block updates")

                P5S.DataSourceRegistry.history = []
                holdConnectivity = false
                offlineReply = true
                env.cfg.hasSnap = true
                env.cfg.hasFlatpak = true
                env.cfg.enableSnapUpdates = true
                env.cfg.enableFlatpakUpdates = true
                env.main.tSnap = "2"
                env.main.tFlatpak = "1"
                env.main.refreshAll()
                wait(40)
                verify(env.main.lastCheckOffline, "Connectivity '0' must mark lastCheckOffline=true")
                compare(env.main.tSnap, "2")
                compare(env.main.tFlatpak, "1")
                compare(P5S.DataSourceRegistry.countHistoryMatching("snap refresh"), 0)
                compare(P5S.DataSourceRegistry.countHistoryMatching("flatpak remote-ls"), 0)
                compare(P5S.DataSourceRegistry.countHistoryMatching("cache.XXXXXX"), 0)
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_03_cross_repo_update_errors_and_trigger_autocheck_preserve() {
            var aptLogFail = true
            var env = createMain({
                startupCheckMode: 0,
                hasSnap: true,
                hasFlatpak: true,
                enableSnapUpdates: true,
                enableFlatpakUpdates: true,
                silentUpdate: true
            }, function(src) {
                if (src.indexOf("systemd-run") !== -1 && src.indexOf("aptupdate-job") !== -1) {
                    return { exitCode: 1, stdout: "", stderr: "failed" }
                }
                if (src.indexOf("cat \"$f\"") !== -1 && src.indexOf(".log") !== -1) {
                    return { exitCode: 0, stdout: aptLogFail ? "[FAILED] apt\n" : "[FAILED] snap\n" }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                env.main.tApt = "1"
                env.main.tSnap = "1"
                env.main.updaterService.launchGroupUpdate("apt")
                wait(60)
                verify(env.main.updateErrors.apt, "APT update error should be recorded")
                verify(!env.main.updateErrors.snap, "Snap update error must still be false")

                aptLogFail = false
                env.main.updaterService.launchGroupUpdate("snap")
                wait(60)
                verify(env.main.updateErrors.apt, "Snap failure must preserve existing APT error")
                verify(env.main.updateErrors.snap, "Snap update error should also be recorded")
                verify(env.main.updateErrorMessages.apt !== "", "APT error message preserved")
                verify(env.main.updateErrorMessages.snap !== "", "Snap error message populated")

                env.main.setCheckError("apt", true, "Transient check error")
                env.main.triggerAutoCheck()
                wait(60)
                verify(!env.main.checkErrors.apt, "Healthy check via triggerAutoCheck clears checkErrors.apt")
                verify(env.main.updateErrors.apt, "triggerAutoCheck must preserve updateErrors.apt")
                verify(env.main.updateErrors.snap, "triggerAutoCheck must preserve updateErrors.snap")
                verify(env.main.hasError, "hasError must remain true while updateErrors remain")
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_04_all_job_post_update_rescan_preserves_partial_repo_errors() {
            var env = createMain({
                startupCheckMode: 0,
                hasSnap: true,
                hasFlatpak: true,
                enableSnapUpdates: true,
                enableFlatpakUpdates: true,
                silentUpdate: true
            }, function(src) {
                if (src.indexOf("systemd-run") !== -1 && src.indexOf("aptupdate-job") !== -1) {
                    return { exitCode: 1, stdout: "", stderr: "" }
                }
                if (src.indexOf("cat \"$f\"") !== -1 && src.indexOf(".log") !== -1) {
                    return { exitCode: 0, stdout: "[FAILED] snap\n" }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                env.main.tApt = "1"
                env.main.tSnap = "1"
                P5S.DataSourceRegistry.history = []
                env.main.updaterService.launchUpdate()
                wait(80)
                verify(env.main.updateErrors.snap, "Partial failure from silent all-update log must set updateErrors.snap")
                verify(!env.main.updateErrors.apt, "Unaffected apt repo must not be marked failed when log names only snap")
                verify(P5S.DataSourceRegistry.countHistoryMatching("ip -o route get") >= 1, "All-update completion triggers post-update rescan")
                verify(env.main.updateErrors.snap, "Post-update rescan after all-update must preserve updateErrors.snap")
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_05_terminal_rc_read_non_zero_zero_and_missing() {
            var rcStdout = "1\n"
            var rcExitCode = 0
            var outerTermExit = 0
            var env = createMain({
                startupCheckMode: 0,
                hasSnap: true,
                enableSnapUpdates: true,
                silentUpdate: false,
                notCloseCommand: true,
                termNoCloseCmd: "konsole --noclose -e",
                termNoCloseSuffix: "; exec $SHELL"
            }, function(src) {
                if (src.indexOf("aptupdate_rc_") !== -1 && src.indexOf("cat \"$f\"") !== -1) {
                    return { exitCode: rcExitCode, stdout: rcStdout }
                }
                if (src.indexOf("konsole") !== -1) {
                    return { exitCode: outerTermExit, stdout: "" }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                // Case A: terminal wrapper exits 0 (e.g. ; exec $SHELL), inner rcFile recorded "1"
                rcExitCode = 0
                rcStdout = "1\n"
                outerTermExit = 0
                env.main.updaterService.launchOneUpdate("curl", "apt", "curl")
                wait(60)
                verify(env.main.updateError, "Non-zero rcFile must set updateError even when terminal wrapper returned 0")
                verify(env.main.updateErrors.apt, "rcFile failure on curl must attribute to apt")
                verify(env.main.lastErrorMessage.indexOf("1") !== -1, "Error message must surface exit code 1: " + env.main.lastErrorMessage)

                // Case B: terminal wrapper exits 1 while rcFile recorded "0"
                env.main.clearRepoErrors()
                rcExitCode = 0
                rcStdout = "0\n"
                outerTermExit = 1
                env.main.updaterService.launchGroupUpdate("snap")
                wait(60)
                verify(!env.main.updateError, "rcFile '0' must succeed even if terminal wrapper exited non-zero")
                verify(!env.main.updateErrors.snap, "snap updateError must stay clear on rcFile '0'")

                // Case C: missing rcFile / empty output when outer exited 0
                rcExitCode = 1
                rcStdout = ""
                outerTermExit = 0
                env.main.updaterService.launchOneUpdate("bash", "apt", "bash")
                wait(60)
                verify(env.main.updateError, "Missing/unreadable rcFile must fail closed with updateError")
                verify(env.main.updateErrors.apt, "Unreadable rcFile for apt package must mark updateErrors.apt")

                // Case D: notCloseCommand = false disables rcFile and trusts direct terminal exit code
                env.main.clearRepoErrors()
                env.cfg.notCloseCommand = false
                outerTermExit = 2
                env.main.updaterService.launchOneUpdate("wget", "apt", "wget")
                wait(60)
                verify(env.main.updateError, "Direct non-zero terminal exit must set updateError when notCloseCommand=false")
                verify(env.main.updateErrors.apt, "Direct failure attributes to apt")
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_06_silent_log_read_empty_uses_job_repo_hint() {
            var env = createMain({
                startupCheckMode: 0,
                hasFlatpak: true,
                enableFlatpakUpdates: true,
                silentUpdate: true
            }, function(src) {
                if (src.indexOf("systemd-run") !== -1 && src.indexOf("aptupdate-job") !== -1) {
                    return { exitCode: 1, stdout: "", stderr: "" }
                }
                if (src.indexOf("cat \"$f\"") !== -1 && src.indexOf(".log") !== -1) {
                    return { exitCode: 1, stdout: "" }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                env.main.updaterService.launchGroupUpdate("flatpak")
                wait(60)
                verify(env.main.updateError, "Empty failed silent log must raise updateError")
                verify(env.main.updateErrors.flatpak, "targetRepo hint must attribute empty silent log failure to flatpak")
                verify(!env.main.updateErrors.apt, "Empty flatpak silent log must not mark apt")
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_07_release_upgrade_nonzero_sets_helper_error() {
            var env = createMain({ startupCheckMode: 0 }, function(src) {
                if (src.indexOf("do-release-upgrade") !== -1) {
                    return { exitCode: 2, stdout: "", stderr: "upgrade failed" }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                env.main.execTaggedJob("konsole -e 'sudo do-release-upgrade'", "helper", "release-upgrade")
                wait(50)
                verify(env.main.helperError, "Non-zero release-upgrade helper exit must set helperError")
                verify(env.main.hasError, "hasError must reflect helperError")
                verify(env.main.lastErrorMessage.indexOf("2") !== -1, "Helper error must include exit code 2: " + env.main.lastErrorMessage)
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_08_retry_timer_is_retrying_barrier_and_install_interruption() {
            var failAptCount = true
            var env = createMain({
                startupCheckMode: 0,
                retryMode: true,
                silentUpdate: true
            }, function(src) {
                if (src.indexOf("apt-get -s") !== -1 && src.indexOf("END {print c+0}") !== -1 && failAptCount) {
                    return { exitCode: 2, stdout: "", stderr: "apt temporary err" }
                }
                if (src.indexOf("systemd-run") !== -1 && src.indexOf("aptupdate-job") !== -1) {
                    return { hold: true }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                P5S.DataSourceRegistry.history = []
                env.main.refreshAll()
                wait(60)
                verify(env.main.isRetrying, "Failed retryable check with retryMode=true must expose isRetrying=true")
                compare(P5S.DataSourceRegistry.countHistoryMatching("cache.XXXXXX"), 0)

                env.main.updaterService.launchOneUpdate("curl", "apt", "curl")
                wait(30)
                verify(env.main.isInstalling, "Install job should now be held in flight")
                verify(env.main.isPackageBusy("apt", "curl", "curl"), "Single package update must track updatingPackages")

                var rt = findRetryTimer(env.main)
                verify(rt !== null, "retryTimer must exist")
                var historyBefore = P5S.DataSourceRegistry.history.length
                rt.triggered()
                wait(30)
                verify(env.main.isInstalling, "retryTimer firing during install must not clobber active isInstalling")
                verify(env.main.isPackageBusy("apt", "curl", "curl"), "retryTimer must not wipe updatingPackages")
                compare(P5S.DataSourceRegistry.history.length, historyBefore)
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_09_install_watchdog_timeout_aborts_and_kills_pgid() {
            var env = createMain({
                startupCheckMode: 0,
                silentUpdate: true
            }, function(src) {
                if (src.indexOf("systemd-run") !== -1 && src.indexOf("--scope --quiet -- true") !== -1) {
                    return { exitCode: 0, stdout: "0\n" }
                }
                if (src.indexOf("setsid -w") !== -1 && src.indexOf("aptupdate_pgid_") !== -1) {
                    return { hold: true }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                verify(!env.main.hasSystemdScope, "Non-systemd probe path should leave hasSystemdScope=false")
                env.main.updaterService.launchGroupUpdate("apt")
                wait(40)
                verify(env.main.isInstalling, "Silent update must be active before watchdog fires")
                verify(env.main.hasActiveSilentUpdate, "hasActiveSilentUpdate must be true for silent job")

                var iwd = findInstallWatchdogTimer(env.main)
                verify(iwd !== null, "installWatchdogTimer must exist")
                iwd.triggered()
                wait(40)
                verify(!env.main.isInstalling, "installWatchdogTimer abortUpdate(true) must clear isInstalling")
                verify(!env.main.hasActiveSilentUpdate, "abortUpdate(true) must clear hasActiveSilentUpdate")
                verify(env.main.updateError, "Timeout abort must set updateError")
                verify(env.main.lastErrorMessage.indexOf("10 minutes") !== -1, "Timeout message expected: " + env.main.lastErrorMessage)
                verify(P5S.DataSourceRegistry.countHistoryMatching("kill -TERM") >= 1, "Timeout abort must issue PGID kill cleanup")
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_10_can_update_guards_offline_lock_checking_installing() {
            var env = createMain({
                startupCheckMode: 0,
                hasSnap: true,
                enableSnapUpdates: true
            }, defaultOnlineHandler)
            try {
                wait(40)
                env.main.tApt = "2"
                env.main.tSnap = "1"
                verify(env.main.canUpdateAll(), "Healthy online state allows canUpdateAll")
                verify(env.main.canUpdate("apt"), "Healthy online state allows canUpdate(apt)")
                verify(env.main.canUpdatePackage("apt", "curl", "curl"), "Healthy online state allows canUpdatePackage")

                env.main.lastCheckOffline = true
                verify(!env.main.canUpdateAll(), "Offline disables canUpdateAll")
                verify(!env.main.canUpdate("apt"), "Offline disables canUpdate")
                verify(!env.main.canUpdatePackage("apt", "curl", "curl"), "Offline disables canUpdatePackage")
                env.main.lastCheckOffline = false

                env.main.connectivityError = true
                verify(!env.main.canUpdateAll(), "connectivityError disables canUpdateAll")
                verify(!env.main.canUpdate("snap"), "connectivityError disables canUpdate")
                env.main.connectivityError = false

                env.main.isPkgManagerBusy = true
                verify(!env.main.canUpdate("apt"), "APT lock disables canUpdate(apt)")
                verify(!env.main.canUpdateAll(), "APT lock disables canUpdateAll when tApt > 0")
                verify(env.main.canUpdate("snap"), "APT lock must not block independent Snap update")
                env.main.isPkgManagerBusy = false

                env.main.isChecking = true
                verify(!env.main.canUpdate("snap"), "Checking disables canUpdate")
                verify(!env.main.canUpdateAll(), "Checking disables canUpdateAll")
                env.main.isChecking = false

                env.main.isInstalling = true
                verify(!env.main.canUpdateAll(), "isInstalling disables canUpdateAll")
                env.main.isInstalling = false
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_11_apt_index_stale_threshold() {
            var ageSeconds = 4 * 86400 + 60
            var env = createMain({ startupCheckMode: 0 }, function(src) {
                if (src.indexOf("stat -c %Y /var/lib/apt/lists") !== -1) {
                    var ts = Math.floor(Date.now() / 1000) - ageSeconds
                    return { exitCode: 0, stdout: String(ts) + "\n" }
                }
                return defaultOnlineHandler(src)
            })
            try {
                wait(40)
                compare(env.main.aptIndexAgeDays, 4)
                verify(env.main.aptIndexStale, "APT index age 4 days must mark aptIndexStale=true")

                ageSeconds = 2 * 86400 + 60
                env.main.execTaggedJob("stat -c %Y /var/lib/apt/lists/*_InRelease", "probe", "apt-index")
                wait(40)
                compare(env.main.aptIndexAgeDays, 2)
                verify(!env.main.aptIndexStale, "APT index age 2 days must mark aptIndexStale=false")
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }

        function test_12_relative_last_check_time_dst_and_midnight_rollover() {
            // Pure DST-safe local calendar day diff checks
            var dSameA = new Date(2026, 2, 29, 0, 5, 0)
            var dSameB = new Date(2026, 2, 29, 23, 55, 0)
            compare(CmdBuilder.localCalendarDayDiff(dSameA, dSameB), 0)

            var dFallA = new Date(2026, 9, 25, 0, 5, 0)
            var dFallB = new Date(2026, 9, 25, 23, 55, 0)
            compare(CmdBuilder.localCalendarDayDiff(dFallA, dFallB), 0)

            var dNewYearsEve = new Date(2025, 11, 31, 23, 59, 0)
            var dNewYearsDay = new Date(2026, 0, 1, 0, 1, 0)
            compare(CmdBuilder.localCalendarDayDiff(dNewYearsEve, dNewYearsDay), 1)

            var dTwoDaysAgo = new Date(2026, 0, 1, 23, 59, 0)
            var dJan3 = new Date(2026, 0, 3, 0, 1, 0)
            compare(CmdBuilder.localCalendarDayDiff(dTwoDaysAgo, dJan3), 2)

            var dFuture = new Date(2026, 0, 4, 8, 0, 0)
            compare(CmdBuilder.localCalendarDayDiff(dFuture, dJan3), -1)
            verify(isNaN(CmdBuilder.localCalendarDayDiff(null, dJan3)))
            verify(isNaN(CmdBuilder.localCalendarDayDiff(new Date("bad"), dJan3)))

            var env = createMain({ startupCheckMode: 0 }, defaultOnlineHandler)
            try {
                wait(40)
                var refAnchor = new Date(2026, 2, 30, 0, 5, 0)
                var todayTarget = new Date(2026, 2, 30, 0, 1, 0)
                var expectedToday = "Today " + Qt.formatTime(todayTarget, Qt.DefaultLocaleShortDate)
                compare(env.main.formatLastCheckDisplay(todayTarget.toISOString(), refAnchor), expectedToday)

                var yestTarget = new Date(2026, 2, 29, 23, 55, 0)
                var expectedYest = "Yesterday " + Qt.formatTime(yestTarget, Qt.DefaultLocaleShortDate)
                compare(env.main.formatLastCheckDisplay(yestTarget.toISOString(), refAnchor), expectedYest)

                var olderTarget = new Date(2026, 2, 28, 14, 15, 0)
                var expectedOlder = Qt.formatDateTime(olderTarget, Qt.DefaultLocaleShortDate)
                compare(env.main.formatLastCheckDisplay(olderTarget.toISOString(), refAnchor), expectedOlder)

                var futureTarget = new Date(2026, 2, 31, 9, 0, 0)
                compare(env.main.formatLastCheckDisplay(futureTarget.toISOString(), refAnchor), Qt.formatDateTime(futureTarget, Qt.DefaultLocaleShortDate))

                compare(env.main.formatLastCheckDisplay("not-an-iso", refAnchor), "not-an-iso")
                compare(env.main.formatLastCheckDisplay("", refAnchor), "")

                // Midnight rollover on popup expansion: stale "Today 23:55" must refresh to "Yesterday <time>"
                var preDay = new Date()
                var liveYesterday = new Date(preDay.getFullYear(), preDay.getMonth(), preDay.getDate() - 1, 23, 55, 0)
                env.main.lastCheckIso = liveYesterday.toISOString()
                env.main.lastCheckTime = "Today 23:55"
                env.main.expanded = false
                env.main.expanded = true
                var postDay = new Date()
                if (CmdBuilder.localCalendarDayDiff(preDay, postDay) !== 0) {
                    liveYesterday = new Date(postDay.getFullYear(), postDay.getMonth(), postDay.getDate() - 1, 23, 55, 0)
                    env.main.lastCheckIso = liveYesterday.toISOString()
                    env.main.lastCheckTime = "Today 23:55"
                    env.main.expanded = false
                    env.main.expanded = true
                }
                compare(env.main.lastCheckTime, "Yesterday " + Qt.formatTime(liveYesterday, Qt.DefaultLocaleShortDate))

                // Periodic timer tick also refreshes stale timestamp across midnight
                var periodicTimer = findDataObj(env.main, function(o) {
                    return o && o.repeat === true && o.interval >= 60000 && typeof o.triggered === "function"
                })
                verify(periodicTimer !== null, "Periodic update timer must exist on main")
                env.main.lastCheckTime = "Today 23:55"
                periodicTimer.triggered()
                compare(env.main.lastCheckTime, "Yesterday " + Qt.formatTime(liveYesterday, Qt.DefaultLocaleShortDate))

                // applyLoadedCache formats loaded lastCheckIso relatively via formatLastCheckDisplay
                env.main.hasScannedThisSession = false
                env.main.isChecking = false
                env.main.lastCheckTime = ""
                env.main.applyLoadedCache(JSON.stringify({
                    tApt: "1",
                    lastCheckIso: liveYesterday.toISOString(),
                    lastCheckOffline: false
                }))
                compare(env.main.lastCheckTime, "Yesterday " + Qt.formatTime(liveYesterday, Qt.DefaultLocaleShortDate))

                // Full online check -> saveCache() writes relative "Today <time>" and persists lastCheckIso into cache payload
                P5S.DataSourceRegistry.history = []
                env.main.lastCheckIso = ""
                env.main.lastCheckTime = ""
                env.main.refreshAll()
                tryVerify(function() { return !env.main.isChecking && env.main.lastCheckIso !== "" }, 2000)
                var savedDate = new Date(env.main.lastCheckIso)
                compare(env.main.lastCheckTime, "Today " + Qt.formatTime(savedDate, Qt.DefaultLocaleShortDate))
                verify(P5S.DataSourceRegistry.history.some(function(entry) {
                    var src = entry && entry.source ? String(entry.source) : ""
                    return src.indexOf("cache.XXXXXX") !== -1 && src.indexOf('"lastCheckIso":"' + env.main.lastCheckIso + '"') !== -1
                }), "saveCache must write lastCheckIso into persisted cache payload")
            } finally {
                env.main.destroy()
                env.cfg.destroy()
                P5S.DataSourceRegistry.reset()
            }
        }
    }
}
