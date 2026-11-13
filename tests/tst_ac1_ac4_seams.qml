import QtQuick
import QtTest
import QtCore
import org.kde.plasma.plasmoid as PlasmoidMod
import org.kde.kirigami as Kirigami
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
        property string logDir: "/tmp/aptupdate-unit-logdir"
        property string osId: "ubuntu"
        property string osIdLike: "debian"
        property bool hasSystemdScope: false
        property string tApt: "0"
        property string tSnap: "0"
        property string tFlatpak: "0"
        property string listApt: ""
        property string listSnap: ""
        property string listFlatpak: ""
        property string lastCheckTime: "2026-11-13 10:00"
        property bool lastCheckOffline: false
        property bool aptIndexStale: false
        property int aptIndexAgeDays: 0
        property bool isChecking: false
        property bool isRetrying: false
        property bool isInstalling: false
        property bool isOnUpdate: false
        property bool isOnDebug: false
        property bool isUpdatingAll: false
        property bool hasError: false
        property bool updateError: false
        property bool connectivityError: false
        property bool hasCheckedOnce: true
        property bool isStartupDelaying: false
        property bool isPkgManagerBusy: false
        property bool lockBlockedUpdate: false
        property bool expanded: false
        property bool isPrewarmed: false
        property bool rebootRequired: false
        property bool releaseUpgradeAvailable: false
        property string releaseUpgradeVersion: ""
        property bool dismissedRebootMsg: false
        property bool dismissedReleaseUpgradeMsg: false
        property bool dismissedBusyLockMsg: false
        property bool isConnected: true
        property string lastErrorMessage: ""
        property var repoErrors: ({ apt: false, snap: false, flatpak: false })
        property var checkErrors: ({ apt: false, snap: false, flatpak: false })
        property var updateErrors: ({ apt: false, snap: false, flatpak: false })
        property var activeUpdateJobs: ({})
        property bool enableSnapUpdates: PlasmoidMod.Plasmoid.configuration.enableSnapUpdates
        property bool enableFlatpakUpdates: PlasmoidMod.Plasmoid.configuration.enableFlatpakUpdates
        property bool hasSnap: PlasmoidMod.Plasmoid.configuration.hasSnap
        property bool hasFlatpak: PlasmoidMod.Plasmoid.configuration.hasFlatpak
        property var registeredJobs: []
        readonly property var startupDelayTimer: null

        function canUpdateAll() { return !isChecking && !isInstalling && !isOnUpdate && !isUpdatingAll && hasUpdate() }
        function isRepoBusy(repo) { return Boolean(updatingRepos[repo]) }
        property var updatingRepos: ({})
        function canUpdate(repo) { return !isChecking && !isUpdatingAll && !isRepoBusy(repo) && (repo !== "apt" || !isPkgManagerBusy) }
        function canUpdatePackage(repo, pkg, appId) { return canUpdate(repo) }
        function isPackageBusy(repo, pkg, appId) { return false }
        function clearPendingRetries() {}
        function clearRepoErrors() {}
        function hasUpdate() { return (parseInt(tApt, 10) || 0) + (enableSnapUpdates && hasSnap ? (parseInt(tSnap, 10) || 0) : 0) + (enableFlatpakUpdates && hasFlatpak ? (parseInt(tFlatpak, 10) || 0) : 0) > 0 }
        function refreshAll() {}
        function abortUpdate() {}
        function isHelperCommand(s) { return false }
        function registerUpdateJob(c, type, repo, pkg, appId, branch) {
            registeredJobs.push({ cmd: c, type: type, repo: repo, pkg: pkg, appId: appId, branch: branch })
        }
        function reset() {
            osId = "ubuntu"
            osIdLike = "debian"
            tApt = "0"
            tSnap = "0"
            tFlatpak = "0"
            listApt = ""
            listSnap = ""
            listFlatpak = ""
            lastCheckTime = "2026-11-13 10:00"
            lastCheckOffline = false
            aptIndexStale = false
            aptIndexAgeDays = 0
            isChecking = false
            isInstalling = false
            isOnUpdate = false
            isUpdatingAll = false
            hasError = false
            updateError = false
            connectivityError = false
            hasCheckedOnce = true
            isStartupDelaying = false
            isPkgManagerBusy = false
            lockBlockedUpdate = false
            expanded = false
            isPrewarmed = false
            rebootRequired = false
            releaseUpgradeAvailable = false
            releaseUpgradeVersion = ""
            dismissedRebootMsg = false
            dismissedReleaseUpgradeMsg = false
            dismissedBusyLockMsg = false
            isConnected = true
            lastErrorMessage = ""
            repoErrors = { apt: false, snap: false, flatpak: false }
            checkErrors = { apt: false, snap: false, flatpak: false }
            updateErrors = { apt: false, snap: false, flatpak: false }
            activeUpdateJobs = {}
            registeredJobs = []
        }
    }

    property var updater: null

    function resetConfig() {
        var cfg = PlasmoidMod.Plasmoid.configuration
        cfg.updateInterval = 60
        cfg.updateIntervalUnit = 0
        cfg.debugMode = false
        cfg.enableSnapUpdates = true
        cfg.enableFlatpakUpdates = true
        cfg.startupCheckMode = 0
        cfg.startupDelaySeconds = 10
        cfg.updateCommandOne = "sudo apt install --only-upgrade"
        cfg.termCmd = "konsole -e"
        cfg.termNoCloseCmd = "konsole --noclose -e"
        cfg.notCloseCommand = false
        cfg.termNoCloseSuffix = ""
        cfg.silentUpdate = false
        cfg.notifyOnSilentUpdate = true
        cfg.includePhasedUpdates = false
        cfg.useNala = false
        cfg.notifyOnUpdates = true
        cfg.notificationThreshold = 1
        cfg.notifyOnStartup = true
        cfg.notifyOnRebootRequired = true
        cfg.notifyOnReleaseUpgrade = true
        cfg.hasSnap = false
        cfg.hasFlatpak = false
        cfg.hasNala = false
        cfg.icon = "software-update-available.svg"
        cfg.secondaryIcon = "view-refresh.svg"
        cfg.iconUseCustomColor = false
        cfg.iconColor = "#ffffff"
        cfg.separateResult = false
        cfg.separator = " | "
        cfg.hideOnZero = false
        cfg.mainDot = false
        cfg.mainDotUseCustomColor = false
        cfg.mainDotColor = "#ff0000"
        cfg.mainDotPosition = 2
        cfg.secondDot = false
        cfg.secondDotUseCustomColor = false
        cfg.secondDotColor = "#00ff00"
        cfg.secondDotPosition = 3
        cfg.invertMouseAction = false
        cfg.mainIsRefresh = false
        cfg.groupUpdates = true
        cfg.adaptiveGrouping = true
        cfg.adaptiveGroupingThreshold = 5
        cfg.debugLog = ""
        main.reset()
        cmd.reset()
        dbg.logs = []
    }

    function walkItems(item, predicate) {
        var matches = []
        if (!item) return matches
        if (predicate(item)) matches.push(item)
        var lists = []
        if (item.children) lists.push(item.children)
        if (item.contentData) lists.push(item.contentData)
        for (var l = 0; l < lists.length; l++) {
            var arr = lists[l]
            for (var i = 0; i < arr.length; i++) {
                var sub = walkItems(arr[i], predicate)
                for (var k = 0; k < sub.length; k++) matches.push(sub[k])
            }
        }
        return matches
    }

    function hasRedAccentPixel(imgA, imgB) {
        for (var y = 0; y < imgB.height; y++) {
            for (var x = 0; x < imgB.width; x++) {
                var pB = imgB.pixel(x, y)
                var pA = imgA ? imgA.pixel(x, y) : Qt.rgba(0, 0, 0, 0)
                if (pB.a > 0.45 && (pB.r - pB.g > 0.15) && (pB.r - pB.b > 0.15)) {
                    if (!imgA || Math.abs(pB.r - pA.r) > 0.1 || Math.abs(pB.g - pA.g) > 0.1 || Math.abs(pB.b - pA.b) > 0.1) {
                        return true
                    }
                }
            }
        }
        return false
    }

    TestCase {
        name: "AC1toAC4Seams"
        when: windowShown

        function init() {
            harness.resetConfig()
            harness.updater = null
        }

        function createUpdater() {
            var comp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/service/Updater.qml")
            compare(comp.status, Component.Ready, comp.errorString())
            var u = comp.createObject(harness)
            verify(u !== null)
            harness.updater = u
            return u
        }

        function test_ac1_full_reboot_removes_systemctl_fallback() {
            var u = createUpdater()
            main.rebootRequired = true
            var comp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/Full.qml")
            compare(comp.status, Component.Ready, comp.errorString())
            var f = comp.createObject(harness, { width: 420, height: 500 })
            verify(f !== null)

            var msgs = walkItems(f, function(it) {
                return it.actions && it.text && String(it.text).indexOf("restart is required") !== -1
            })
            verify(msgs.length >= 1)
            verify(msgs[0].actions.length >= 1)
            msgs[0].actions[0].trigger()

            compare(cmd.executed.length, 1)
            verify(cmd.executed[0].indexOf("systemctl") === -1, "Forbidden systemctl fallback present: " + cmd.executed[0])

            f.destroy()
            u.destroy()
        }

        function test_ac2_nala_enforces_no_autoremove() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            cfg.useNala = true
            cfg.hasNala = true
            var u = createUpdater()

            var upgradeCmd = u.getTerminalAptUpgradeCommand()
            verify(upgradeCmd.indexOf("nala upgrade") !== -1, "Expected nala upgrade: " + upgradeCmd)
            verify(upgradeCmd.indexOf("--no-autoremove") !== -1, "Missing --no-autoremove on nala upgrade: " + upgradeCmd)

            cmd.reset()
            u.launchOneUpdate("firefox", "apt", "firefox")
            compare(cmd.executed.length, 1)
            verify(cmd.executed[0].indexOf("nala install") !== -1, "Expected nala install: " + cmd.executed[0])
            verify(cmd.executed[0].indexOf("--no-autoremove") !== -1, "Missing --no-autoremove on nala install: " + cmd.executed[0])

            u.destroy()
        }

        function test_ac2_silent_apt_conffile_and_stdin() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            cfg.silentUpdate = true
            cfg.enableSnapUpdates = false
            cfg.enableFlatpakUpdates = false
            var u = createUpdater()

            var silentCmd = u.getEffectiveSilentUpdateCommand(true, false, false)
            verify(silentCmd.indexOf("--force-confdef") !== -1, "Missing --force-confdef: " + silentCmd)
            verify(silentCmd.indexOf("--force-confold") !== -1, "Missing --force-confold: " + silentCmd)
            verify(silentCmd.indexOf("APT_LISTCHANGES_FRONTEND=none") !== -1, "Missing APT_LISTCHANGES_FRONTEND=none: " + silentCmd)
            verify(silentCmd.indexOf("NEEDRESTART_MODE=a") !== -1, "Missing NEEDRESTART_MODE=a: " + silentCmd)
            verify(silentCmd.indexOf("< /dev/null") !== -1, "Missing stdin </dev/null guard: " + silentCmd)

            u.destroy()
        }

        function test_ac2_send_notify_uses_option_delimiter() {
            var u = createUpdater()
            u.sendNotify("--urgency=critical", "Message", "dialog-information", "normal")
            compare(cmd.executed.length, 1)
            verify(cmd.executed[0].indexOf(" -- ") !== -1, "Missing -- delimiter before notification title/body: " + cmd.executed[0])
            u.destroy()
        }

        function test_ac3_token_boundaries_apt_fast_and_dash_y() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            cfg.silentUpdate = false
            var u = createUpdater()

            cfg.updateCommandOne = "sudo apt-fast install -y"
            u.updateCommandOne = cfg.updateCommandOne
            cmd.reset()
            u.launchOneUpdate("vim", "apt", "vim")
            compare(cmd.executed.length, 1)
            verify(cmd.executed[0].indexOf("apt-fast") !== -1, "apt-fast token corrupted: " + cmd.executed[0])
            verify(cmd.executed[0].indexOf("apt -o") === -1, "Corrupted apt-fast into apt -o...: " + cmd.executed[0])

            cfg.updateCommandOne = "sudo my-apt-y install"
            u.updateCommandOne = cfg.updateCommandOne
            cmd.reset()
            u.launchOneUpdate("vim", "apt", "vim")
            compare(cmd.executed.length, 1)
            verify(/(?:^|\s)-y(?:\s|$)/.test(cmd.executed[0]), "Standalone -y missing when command contains -y inside name: " + cmd.executed[0])

            u.destroy()
        }

        function test_ac3_flatpak_branch_preserved_on_single_update() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            cfg.hasFlatpak = true
            cfg.enableFlatpakUpdates = true
            cfg.silentUpdate = false
            var u = createUpdater()

            cmd.reset()
            u.launchOneUpdate("GNOME Platform", "flatpak", "org.gnome.Platform", "46")
            compare(cmd.executed.length, 1)
            verify(cmd.executed[0].indexOf("org.gnome.Platform//46") !== -1, "Terminal flatpak update lost branch: " + cmd.executed[0])

            cfg.silentUpdate = true
            u.silentUpdate = true
            cmd.reset()
            u.launchOneUpdate("GNOME Platform", "flatpak", "org.gnome.Platform", "46")
            compare(cmd.executed.length, 1)
            verify(cmd.executed[0].indexOf("org.gnome.Platform//46") !== -1, "Silent flatpak update lost branch: " + cmd.executed[0])

            u.destroy()
        }

        function test_ac3_command_builder_notification_and_job_seams() {
            // Package literally named "security" from noble-updates must NOT count as security origin
            var nonSecList = "libsecurity-dev 1.0 -> 2.0 Ubuntu:24.04/noble-updates amd64"
            verify(!CmdBuilder.isSecurityUpdateList(nonSecList), "Package named security without security origin should be non-security")
            var secList = "libssl3t64 3.0 -> 3.1 Ubuntu:24.04/noble-security amd64"
            verify(CmdBuilder.isSecurityUpdateList(secList), "Origin containing noble-security must match")

            // Notification critical single-shot latch & expanded suppression preserving previousTotal
            var r1 = CmdBuilder.evaluateNotification({
                numApt: 2, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false,
                enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, notifyOnStartup: false,
                busy: false, expanded: false, threshold: 1,
                previousTotal: 0, lastNotifiedTotal: 0, lastNotifiedHasSecurity: false,
                listApt: secList
            })
            compare(r1.action, "notify_critical")
            verify(r1.lastNotifiedHasSecurity)

            // Subsequent new non-critical batch while security already notified must NOT emit critical spam
            var r2 = CmdBuilder.evaluateNotification({
                numApt: 8, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false,
                enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, notifyOnStartup: false,
                busy: false, expanded: false, threshold: 1,
                previousTotal: 2, lastNotifiedTotal: 2, lastNotifiedHasSecurity: true,
                listApt: secList
            })
            compare(r2.action, "notify_normal")
            verify(!r2.isCritical)

            // Expanded popup preserves previousTotal so notification is not lost when closed
            var r3 = CmdBuilder.evaluateNotification({
                numApt: 3, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false,
                enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, notifyOnStartup: false,
                busy: false, expanded: true, threshold: 1,
                previousTotal: 1, lastNotifiedTotal: 1, lastNotifiedHasSecurity: false,
                listApt: nonSecList
            })
            compare(r3.action, "expanded_suppress")
            compare(r3.previousTotal, 1)

            // Silent failure log classification
            var cPk = CmdBuilder.classifySilentLog("[PKEXEC_FAILED] code=127")
            compare(cPk.status, "pkexec_failed")
            verify(cPk.pkexecFailed)
            compare(cPk.code, 127)
            var cCan = CmdBuilder.classifySilentLog("[CANCELLED]")
            compare(cCan.status, "cancelled")
            var cFail = CmdBuilder.classifySilentLog("[FAILED] apt\n[FAILED] snap")
            compare(cFail.status, "failed")
            compare(cFail.failedRepos.length, 2)

            // systemd-run user scope wrapping & silent --with-new-pkgs parity
            var scoped = CmdBuilder.wrapWithSystemdScope("echo hi", "aptupdate-job-1", true)
            verify(scoped.indexOf("systemd-run --user --scope --quiet --unit='aptupdate-job-1'") === 0)
            var silentApt = CmdBuilder.buildSilentAptUpgradeCmd(false, "")
            verify(silentApt.indexOf("--with-new-pkgs") !== -1)
        }

        function test_ac4_plasmoid_icon_reverse_dns_theme_icon() {
            var comp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/components/PlasmoidIcon.qml")
            compare(comp.status, Component.Ready, comp.errorString())

            var objTheme = comp.createObject(harness, { width: 32, height: 32, source: "org.kde.plasma.softwareupdate" })
            verify(objTheme !== null)
            var iconTheme = walkItems(objTheme, function(it) { return it.isMask !== undefined })[0]
            verify(iconTheme !== undefined)
            compare(String(iconTheme.source), "org.kde.plasma.softwareupdate")

            var objAsset = comp.createObject(harness, { width: 32, height: 32, source: "software-update-available.svg" })
            verify(objAsset !== null)
            var iconAsset = walkItems(objAsset, function(it) { return it.isMask !== undefined })[0]
            verify(String(iconAsset.source).indexOf("/assets/software-update-available.svg") !== -1)

            objTheme.destroy()
            objAsset.destroy()
        }

        function test_ac4_compact_maindot_and_badge_error_visuals() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            var comp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/Compact.qml")
            compare(comp.status, Component.Ready, comp.errorString())

            // Case 1: mainDot = true with zero counts + error state MUST visibly differ from idle & show red indicator
            cfg.mainDot = true
            main.hasError = false
            main.tApt = "0"
            var okDot = comp.createObject(harness, { width: 48, height: 48 })
            verify(okDot !== null)
            waitForRendering(okDot)
            var okDotImg = grabImage(okDot)

            main.hasError = true
            var errDot = comp.createObject(harness, { width: 48, height: 48 })
            verify(errDot !== null)
            waitForRendering(errDot)
            var errDotImg = grabImage(errDot)

            verify(!okDotImg.equals(errDotImg), "Compact mainDot rendered identically on error vs idle")
            verify(hasRedAccentPixel(okDotImg, errDotImg), "Compact mainDot error state lacks negative red error indicator pixels")

            okDot.destroy()
            errDot.destroy()

            // Case 2: mainDot = false with error state MUST render high-contrast negative red error badge
            cfg.mainDot = false
            main.hasError = false
            var okBadge = comp.createObject(harness, { width: 48, height: 48 })
            waitForRendering(okBadge)
            var okBadgeImg = grabImage(okBadge)

            main.hasError = true
            var errBadge = comp.createObject(harness, { width: 48, height: 48 })
            waitForRendering(errBadge)
            var errBadgeImg = grabImage(errBadge)

            var badges = walkItems(errBadge, function(it) { return it.text === "!" && it.customColor !== undefined })
            compare(badges.length, 1, "Expected error badge with '!' text")
            verify(hasRedAccentPixel(okBadgeImg, errBadgeImg), "Compact error badge lacks high-contrast negative red styling")

            okBadge.destroy()
            errBadge.destroy()
        }

        function test_ac4_full_error_plaintext_partial_repo_and_debian_urls() {
            var u = createUpdater()
            main.osId = "debian"
            main.osIdLike = ""
            main.expanded = true
            main.isPrewarmed = true
            main.hasError = true
            main.lastErrorMessage = "<b>XSS-Payload</b>"
            main.repoErrors = { apt: false, snap: true, flatpak: false }
            main.tApt = "2"
            main.listApt = "bash 5.2 -> 5.2.15 Debian/bookworm\nvim 9.0 -> 9.1 Debian/bookworm"

            var comp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/Full.qml")
            compare(comp.status, Component.Ready, comp.errorString())
            var f = comp.createObject(harness, { width: 420, height: 500 })
            verify(f !== null)
            try {
                f.reloadPackages()
                wait(50)

                var labels = walkItems(f, function(it) {
                    return it.text !== undefined && String(it.text).indexOf("XSS-Payload") !== -1
                })
                verify(labels.length >= 1, "Error label not found")
                compare(labels[0].textFormat, Text.PlainText, "errorLabel must use Text.PlainText")

                var scrollViews = walkItems(f, function(it) {
                    return it.contentItem !== undefined && it.background !== undefined && it.title !== undefined
                })
                verify(scrollViews.length >= 1, "ScrollablePage not found")
                verify(scrollViews[0].visible, "Partial Snap error must not hide healthy APT package list")

                verify(f.packageList.indexOf("bash") !== -1)
                var debianLinks = walkItems(f, function(it) {
                    return it.websiteUrl !== undefined && String(it.websiteUrl).indexOf("packages.debian.org") !== -1
                })
                verify(debianLinks.length >= 1, "Debian osId should route package URLs to packages.debian.org")
            } finally {
                f.destroy()
                u.destroy()
                main.expanded = false
                main.isPrewarmed = false
                main.osId = "ubuntu"
                main.osIdLike = "debian"
                main.hasError = false
                main.lastErrorMessage = ""
                main.repoErrors = { apt: false, snap: false, flatpak: false }
                main.tApt = "0"
                main.listApt = ""
            }
        }

        function test_ac4_debug_service_never_writes_kconfig() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            cfg.debugLog = ""
            var comp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/service/Debug.qml")
            compare(comp.status, Component.Ready, comp.errorString())
            var d = comp.createObject(harness)
            verify(d !== null)

            d.log("xdg-cache-sentinel", false)
            wait(450)
            compare(cfg.debugLog, "", "Debug.qml must not write debug logs into plasmoid.configuration.debugLog")

            d.destroy()
        }

        function test_ac3_apt_fast_phased_and_dash_dash_token() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            var origCmd = cfg.updateCommandOne
            var origPhased = cfg.includePhasedUpdates
            var origNala = cfg.useNala
            var origSilent = cfg.silentUpdate
            try {
                cfg.silentUpdate = false
                cfg.useNala = false
                cfg.includePhasedUpdates = true
                cfg.updateCommandOne = "sudo apt-fast install --only-upgrade -y"
                var u = createUpdater()
                cmd.reset()
                u.launchOneUpdate("firefox", "apt", "firefox")
                compare(cmd.executed.length, 1)
                var launched = cmd.executed[0]
                verify(launched.indexOf("apt-fast") !== -1, "apt-fast token preserved: " + launched)
                verify(launched.indexOf("apt -o") === -1, "Must not corrupt apt-fast prefix: " + launched)
                verify(launched.indexOf("DPkg::Lock::Timeout=10") !== -1, "Missing DPkg::Lock::Timeout=10: " + launched)
                verify(launched.indexOf("Always-Include-Phased-Updates=true") !== -1, "Missing phased flag: " + launched)
                verify(launched.indexOf(" -- firefox") !== -1, "Missing -- option delimiter: " + launched)
                u.destroy()
            } finally {
                cfg.updateCommandOne = origCmd
                cfg.includePhasedUpdates = origPhased
                cfg.useNala = origNala
                cfg.silentUpdate = origSilent
            }
        }

        function test_ac3_flatpak_multi_branch_listitem_and_html_escape() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            var origHasFlatpak = cfg.hasFlatpak
            var origEnableFlatpak = cfg.enableFlatpakUpdates
            var origSilent = cfg.silentUpdate
            try {
                cfg.hasFlatpak = true
                cfg.enableFlatpakUpdates = true
                cfg.silentUpdate = false
                var u = createUpdater()
                harness.updater = u

                var liComp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/components/ListItem.qml")
                compare(liComp.status, Component.Ready, liComp.errorString())
                var li = liComp.createObject(harness, {
                    width: 400,
                    height: 60,
                    name: "<script>GNOME</script>",
                    repo: "flatpak",
                    fv: "<img src=x onerror=alert(1)>",
                    tv: "47",
                    branch: "47",
                    websiteUrl: "",
                    appId: "org.gnome.Platform"
                })
                verify(li !== null)

                var richLabels = walkItems(li, function(it) {
                    return it.text !== undefined && String(it.text).indexOf("&lt;img") !== -1
                })
                verify(richLabels.length >= 1, "ListItem must HTML-escape version/name strings inside styled text")
                var rawImg = walkItems(li, function(it) {
                    return it.text !== undefined && String(it.text).indexOf("<img") !== -1
                })
                compare(rawImg.length, 0)

                var buttons = walkItems(li, function(it) {
                    return it.clicked !== undefined && it.icon && it.icon.name === "system-run-symbolic"
                })
                verify(buttons.length >= 1, "actionToolButton not found on ListItem")
                cmd.reset()
                buttons[0].clicked()
                compare(cmd.executed.length, 1)
                verify(cmd.executed[0].indexOf("org.gnome.Platform//47") !== -1, "Multi-branch ListItem click lost //47 target: " + cmd.executed[0])

                li.destroy()
                u.destroy()
            } finally {
                cfg.hasFlatpak = origHasFlatpak
                cfg.enableFlatpakUpdates = origEnableFlatpak
                cfg.silentUpdate = origSilent
            }
        }

        function test_ac4_full_qml_empty_error_offline_lock_retrying_and_debian_banners() {
            var u = createUpdater()
            var fComp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/Full.qml")
            compare(fComp.status, Component.Ready, fComp.errorString())
            var f = fComp.createObject(harness, { width: 420, height: 500 })
            verify(f !== null)

            try {
                // 1. isRetrying = true hides upToDate / waiting labels and shows retry feedback
                main.tApt = "0"
                main.tSnap = "0"
                main.tFlatpak = "0"
                main.hasCheckedOnce = false
                main.hasError = false
                main.lastCheckOffline = false
                main.isChecking = false
                main.isRetrying = true
                wait(20)
                var retryLbls = walkItems(f, function(it) { return it.visible && it.text && String(it.text).indexOf("Retrying failed check") !== -1 })
                verify(retryLbls.length >= 1, "Retrying feedback label missing when main.isRetrying=true")
                var upToDateLbls = walkItems(f, function(it) { return it.visible && it.text && String(it.text).indexOf("system is up to date") !== -1 })
                compare(upToDateLbls.length, 0)

                // 2. Empty model + error uses PlainText & hides upToDate/waiting labels
                main.isRetrying = false
                main.hasCheckedOnce = true
                main.hasError = true
                main.lastErrorMessage = "<img src=x onerror=alert(1)>"
                wait(20)
                var errLbls = walkItems(f, function(it) { return it.visible && it.text && String(it.text).indexOf("<img src=x") !== -1 })
                verify(errLbls.length >= 1, "Error label missing on empty model error state")
                compare(errLbls[0].textFormat, Text.PlainText)
                var upLblsOnErr = walkItems(f, function(it) { return it.visible && it.text && String(it.text).indexOf("system is up to date") !== -1 })
                compare(upLblsOnErr.length, 0)

                // 3. Offline placeholder without error
                main.hasError = false
                main.lastErrorMessage = ""
                main.lastCheckOffline = true
                wait(20)
                var offLbls = walkItems(f, function(it) { return it.visible && it.text && String(it.text).indexOf("Offline") !== -1 })
                verify(offLbls.length >= 1, "Offline placeholder missing when lastCheckOffline=true")
                main.lastCheckOffline = false

                // 4. Busy lock banner
                main.isPkgManagerBusy = true
                main.lockBlockedUpdate = true
                main.dismissedBusyLockMsg = false
                wait(20)
                var lockMsgs = walkItems(f, function(it) { return it.visible && it.text && String(it.text).indexOf("Package manager is currently in use") !== -1 })
                verify(lockMsgs.length >= 1, "Busy lock banner missing when isPkgManagerBusy=true")
                main.isPkgManagerBusy = false
                main.lockBlockedUpdate = false

                // 5. Debian stale APT index banner & no Ubuntu upgrade banner
                main.osId = "debian"
                main.osIdLike = ""
                main.releaseUpgradeAvailable = true
                main.releaseUpgradeVersion = "26.04"
                main.aptIndexStale = true
                main.aptIndexAgeDays = 5
                wait(20)
                var staleMsgs = walkItems(f, function(it) { return it.visible && it.text && String(it.text).indexOf("Local APT package index is 5 days old") !== -1 })
                verify(staleMsgs.length >= 1, "Stale APT index banner missing for Debian")
                var ubuntuMsgs = walkItems(f, function(it) { return it.visible && it.text && String(it.text).indexOf("Upgrade Available: Ubuntu") !== -1 })
                compare(ubuntuMsgs.length, 0)
            } finally {
                main.osId = "ubuntu"
                main.osIdLike = "debian"
                main.releaseUpgradeAvailable = false
                main.releaseUpgradeVersion = ""
                main.aptIndexStale = false
                main.aptIndexAgeDays = 0
                main.isPkgManagerBusy = false
                main.hasError = false
                main.lastErrorMessage = ""
                main.isRetrying = false
                main.lastCheckOffline = false
                f.destroy()
                u.destroy()
            }
        }

        function test_ac4_tooltip_partial_error_counts_and_plaintext_release() {
            main.hasError = true
            main.lastErrorMessage = "Snap refresh timed out"
            main.rebootRequired = true
            main.releaseUpgradeAvailable = true
            main.releaseUpgradeVersion = "<b>26.04</b>"
            main.tApt = "3"

            var ttComp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/Tooltip.qml")
            compare(ttComp.status, Component.Ready, ttComp.errorString())
            var tt = ttComp.createObject(harness, { width: 320, height: 220 })
            verify(tt !== null)

            try {
                wait(20)
                var rebootRows = walkItems(tt, function(it) { return it.visible && it.text && String(it.text).indexOf("System restart required") !== -1 })
                verify(rebootRows.length >= 1, "Tooltip hid rebootRequired row during partial error")

                var ruRows = walkItems(tt, function(it) { return it.visible && it.text && String(it.text).indexOf("<b>26.04</b>") !== -1 })
                verify(ruRows.length >= 1, "Tooltip hid releaseUpgradeVersion row during partial error")
                compare(ruRows[0].textFormat, Text.PlainText)

                var aptRows = walkItems(tt, function(it) { return it.visible && it.text && String(it.text) === "APT:" })
                verify(aptRows.length >= 1, "Tooltip hid healthy APT count row during partial error")
            } finally {
                main.hasError = false
                main.lastErrorMessage = ""
                main.rebootRequired = false
                main.releaseUpgradeAvailable = false
                main.releaseUpgradeVersion = ""
                main.tApt = "0"
                tt.destroy()
            }
        }

        function test_ac4_compact_dual_palette_click_vertical_hide_and_icon_tilde() {
            var cfg = PlasmoidMod.Plasmoid.configuration
            var origForm = harness.plasmoid.formFactor
            var origDot = cfg.mainDot
            var origHideZero = cfg.hideOnZero
            var origText = Kirigami.Theme.textColor
            var origBg = Kirigami.Theme.backgroundColor

            var iconComp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/components/PlasmoidIcon.qml")
            compare(iconComp.status, Component.Ready, iconComp.errorString())
            var homeIcon = iconComp.createObject(harness, { width: 32, height: 32, source: "~/custom-icon.svg" })
            verify(homeIcon !== null)
            var kirIcon = walkItems(homeIcon, function(it) { return it.isMask !== undefined })[0]
            verify(kirIcon !== undefined)
            verify(String(kirIcon.source).indexOf("file://") === 0 && String(kirIcon.source).indexOf("/custom-icon.svg") !== -1, "Expected resolved ~/ path: " + kirIcon.source)
            verify(!kirIcon.isMask, "~/ custom icon path should not force isMask=true")
            homeIcon.destroy()

            var comp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/Compact.qml")
            compare(comp.status, Component.Ready, comp.errorString())

            // Dual light vs dark palette Compact verification
            cfg.mainDot = false
            cfg.hideOnZero = false
            main.tApt = "2"
            main.hasError = false
            Kirigami.Theme.backgroundColor = "#ffffff"
            Kirigami.Theme.textColor = "#111111"
            var lightC = comp.createObject(harness, { width: 64, height: 48 })
            verify(lightC !== null)
            waitForRendering(lightC)
            var lightImg = grabImage(lightC)

            Kirigami.Theme.backgroundColor = "#111111"
            Kirigami.Theme.textColor = "#f5f5f5"
            var darkC = comp.createObject(harness, { width: 64, height: 48 })
            verify(darkC !== null)
            waitForRendering(darkC)
            var darkImg = grabImage(darkC)
            verify(!lightImg.equals(darkImg), "Compact must adapt visibly between light and dark palettes")
            lightC.destroy()
            darkC.destroy()

            // Vertical panel, hideOnZero, click behavior
            Kirigami.Theme.backgroundColor = origBg
            Kirigami.Theme.textColor = origText
            harness.plasmoid.formFactor = 3 // PlasmaCore.Types.Vertical
            cfg.hideOnZero = true
            main.tApt = "0"
            main.expanded = false
            var c = comp.createObject(harness, { width: 48, height: 48 })
            verify(c !== null)
            try {
                wait(20)
                var zeroCountBadges = walkItems(c, function(it) { return it.visible && it.text === "0" })
                compare(zeroCountBadges.length, 0)
                mouseClick(c, c.width / 2, c.height / 2, Qt.LeftButton)
                verify(main.expanded, "Left click on Compact should toggle main.expanded")
            } finally {
                harness.plasmoid.formFactor = origForm
                cfg.mainDot = origDot
                cfg.hideOnZero = origHideZero
                main.tApt = "0"
                main.expanded = false
                c.destroy()
            }
        }

        function test_ac3_evaluate_notification_matrix_and_os_release() {
            // Skip when disabled or busy
            compare(CmdBuilder.evaluateNotification({
                numApt: 5, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false, enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: false, busy: false, expanded: false, threshold: 1,
                previousTotal: -1, lastNotifiedTotal: 0, lastNotifiedHasSecurity: false, listApt: ""
            }).action, "skip")
            compare(CmdBuilder.evaluateNotification({
                numApt: 5, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false, enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, busy: true, expanded: false, threshold: 1,
                previousTotal: -1, lastNotifiedTotal: 0, lastNotifiedHasSecurity: false, listApt: ""
            }).action, "skip")

            // Reset at 0
            var rReset = CmdBuilder.evaluateNotification({
                numApt: 0, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false, enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, busy: false, expanded: false, threshold: 1,
                previousTotal: 4, lastNotifiedTotal: 4, lastNotifiedHasSecurity: true, listApt: ""
            })
            compare(rReset.action, "reset")
            compare(rReset.lastNotifiedTotal, 0)
            verify(!rReset.lastNotifiedHasSecurity)

            // Below threshold when non-security vs security
            compare(CmdBuilder.evaluateNotification({
                numApt: 2, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false, enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, busy: false, expanded: false, threshold: 5,
                previousTotal: -1, lastNotifiedTotal: 0, lastNotifiedHasSecurity: false,
                listApt: "bash 1 -> 2 Ubuntu:24.04/noble-updates amd64"
            }).action, "below_threshold")

            compare(CmdBuilder.evaluateNotification({
                numApt: 1, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false, enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, busy: false, expanded: false, threshold: 5,
                previousTotal: -1, lastNotifiedTotal: 0, lastNotifiedHasSecurity: false,
                listApt: "libssl3t64 1 -> 2 Ubuntu:24.04/noble-security amd64"
            }).action, "notify_critical")

            // Startup & +5 batch hysteresis (+1..+4 suppressed, +5 triggers)
            compare(CmdBuilder.evaluateNotification({
                numApt: 3, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false, enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, notifyOnStartup: true, busy: false, expanded: false, threshold: 1,
                previousTotal: -1, lastNotifiedTotal: 0, lastNotifiedHasSecurity: false, listApt: ""
            }).action, "notify_normal")

            for (var delta = 1; delta <= 4; delta++) {
                compare(CmdBuilder.evaluateNotification({
                    numApt: 2 + delta, numSnap: 0, numFlatpak: 0,
                    enableSnap: false, hasSnap: false, enableFlatpak: false, hasFlatpak: false,
                    notifyOnUpdates: true, notifyOnStartup: false, busy: false, expanded: false, threshold: 1,
                    previousTotal: 2, lastNotifiedTotal: 2, lastNotifiedHasSecurity: false, listApt: ""
                }).action, "noop")
            }
            compare(CmdBuilder.evaluateNotification({
                numApt: 7, numSnap: 0, numFlatpak: 0,
                enableSnap: false, hasSnap: false, enableFlatpak: false, hasFlatpak: false,
                notifyOnUpdates: true, notifyOnStartup: false, busy: false, expanded: false, threshold: 1,
                previousTotal: 6, lastNotifiedTotal: 2, lastNotifiedHasSecurity: false, listApt: ""
            }).action, "notify_normal")

            // OS release parsing & Debian-family check
            var uInfo = CmdBuilder.parseOsRelease("ID=ubuntu\nID_LIKE=\"debian\"\n")
            compare(uInfo.id, "ubuntu")
            compare(uInfo.idLike, "debian")
            verify(!CmdBuilder.isDebianFamilyNonUbuntu("ubuntu", "debian"))
            verify(CmdBuilder.isDebianFamilyNonUbuntu("debian", ""))
            verify(!CmdBuilder.isDebianFamilyNonUbuntu("linuxmint", "ubuntu debian"))
        }

        function test_ac4_config_command_preview_parity() {
            var ccComp = Qt.createComponent("file:///home/tugay/Projeler/aptupdate/hadbilen.aptupdate.plasmoid/contents/ui/config/configCommand.qml")
            compare(ccComp.status, Component.Ready, ccComp.errorString())
            var cc = ccComp.createObject(harness, {
                width: 500,
                height: 600,
                cfg_hasNala: false,
                cfg_useNala: false,
                cfg_hasSnap: false,
                cfg_hasFlatpak: false,
                cfg_enableSnapUpdates: false,
                cfg_enableFlatpakUpdates: false,
                cfg_silentUpdate: false,
                cfg_notCloseCommand: false,
                cfg_includePhasedUpdates: true,
                cfg_termCmd: "konsole -e",
                cfg_termNoCloseCmd: "konsole --noclose -e",
                cfg_termNoCloseSuffix: "; exec $SHELL"
            })
            verify(cc !== null)
            try {
                wait(20)
                var countLbls = walkItems(cc, function(it) {
                    return it.text && String(it.text).indexOf("apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade -o APT::Get::Always-Include-Phased-Updates=true") !== -1
                })
                verify(countLbls.length >= 2, "configCommand count/list previews must match CommandBuilder phased APT commands")
            } finally {
                cc.destroy()
            }
        }
    }
}
