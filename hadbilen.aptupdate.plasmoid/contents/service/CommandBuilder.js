.pragma library

var SILENT_APT_OPTS = "-o DPkg::Lock::Timeout=10 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
var SILENT_APT_ENV = "DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none NEEDRESTART_MODE=a"

function bashEscape(value) {
    return ("" + (value === undefined || value === null ? "" : value)).replace(/'/g, "'\\''")
}

function sanitizePackageToken(name) {
    return String(name || "").replace(/[^a-zA-Z0-9.+:_-]/g, "").replace(/^-+/, "")
}

function sanitizeBranchToken(branch) {
    return String(branch || "").replace(/[^a-zA-Z0-9.+_-]/g, "").replace(/^-+/, "")
}

function stripFlatpakBranch(appId) {
    var raw = String(appId || "").trim()
    var idx = raw.indexOf("//")
    return idx !== -1 ? raw.slice(0, idx) : raw
}

function buildFlatpakTarget(appId, branch) {
    var base = sanitizePackageToken(stripFlatpakBranch(appId))
    if (!base) return ""
    var cleanBranch = sanitizeBranchToken(branch)
    return cleanBranch ? (base + "//" + cleanBranch) : base
}

function isDebianFamilyNonUbuntu(osId, osIdLike) {
    var id = String(osId || "").trim().toLowerCase()
    var like = String(osIdLike || "").trim().toLowerCase()
    if (id === "ubuntu" || like.indexOf("ubuntu") !== -1) {
        return false
    }
    return id === "debian" || like.indexOf("debian") !== -1
}

function getPackageInfoUrl(repoType, pkgName, appId, osId, osIdLike) {
    var cleanName = String(pkgName || "").trim()
    if (repoType === "snap") {
        return "https://snapcraft.io/" + encodeURIComponent(cleanName)
    }
    if (repoType === "flatpak") {
        var cleanApp = stripFlatpakBranch(appId || cleanName)
        return "https://flathub.org/apps/details/" + encodeURIComponent(cleanApp)
    }
    if (isDebianFamilyNonUbuntu(osId, osIdLike)) {
        return "https://packages.debian.org/search?keywords=" + encodeURIComponent(cleanName)
    }
    return "https://packages.ubuntu.com/search?keywords=" + encodeURIComponent(cleanName)
}

function parseOsRelease(text) {
    var out = { id: "", idLike: "" }
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.indexOf("ID=") === 0) {
            out.id = line.slice(3).replace(/^["']|["']$/g, "").trim().toLowerCase()
        } else if (line.indexOf("ID_LIKE=") === 0) {
            out.idLike = line.slice(8).replace(/^["']|["']$/g, "").trim().toLowerCase()
        }
    }
    return out
}

function buildNalaTerminalCmd(subcommand, includePhasedUpdates) {
    var sub = (subcommand === "install") ? "install" : "upgrade"
    var phased = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    return "sudo nala " + sub + " --no-autoremove -o DPkg::Lock::Timeout=10" + phased
}

function buildTerminalAptUpgradeCmd(opts) {
    var useNala = Boolean(opts && opts.useNala)
    var hasNala = Boolean(opts && opts.hasNala)
    var includePhased = Boolean(opts && opts.includePhasedUpdates)
    if (useNala && hasNala) {
        return buildNalaTerminalCmd("upgrade", includePhased)
    }
    var phased = includePhased ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    return "sudo apt -o DPkg::Lock::Timeout=10 update && sudo apt -o DPkg::Lock::Timeout=10" + phased + " upgrade"
}

function injectAptOptions(rawCmd, includePhasedUpdates, forceNoAutoremoveNala) {
    var out = String(rawCmd || "").trim()
    if (!out) return ""
    var hasLockOpt = /\bDPkg::Lock::Timeout\b/.test(out)
    var hasPhasedOpt = /\bAPT::Get::Always-Include-Phased-Updates\b/.test(out)
    var phasedFlag = (includePhasedUpdates && !hasPhasedOpt) ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""

    if (/(^|\s)(?:sudo\s+)?nala\s+(?:install|upgrade)(?=\s|$)/.test(out)) {
        var nalaAdditions = ""
        if (forceNoAutoremoveNala && !/(^|\s)--no-autoremove(?=\s|$)/.test(out)) {
            nalaAdditions += " --no-autoremove"
        }
        if (!hasLockOpt) {
            nalaAdditions += " -o DPkg::Lock::Timeout=10"
        }
        nalaAdditions += phasedFlag
        if (nalaAdditions) {
            out = out.replace(/(\bnala\s+(?:install|upgrade))(?=\s|$)/, "$1" + nalaAdditions)
        }
        return out
    }

    var aptAdditions = ""
    if (!hasLockOpt) {
        aptAdditions += " -o DPkg::Lock::Timeout=10"
    }
    aptAdditions += phasedFlag
    if (aptAdditions) {
        out = out.replace(/(^|\s)((?:sudo\s+)?apt(?:-get|-fast)?)(?=\s|$)/, "$1$2" + aptAdditions)
    }
    return out
}

function ensureShellDashC(baseTerm) {
    var trimmed = String(baseTerm || "").trim()
    if (!trimmed) return ""
    if (!/(^|\s)(?:[^\s]*\/)?(?:bash|sh)\s+-[^\s]*c(?=\s|$)/.test(trimmed)) {
        return trimmed + " bash -c"
    }
    return trimmed
}

function ensureStandaloneYesFlag(rawCmd) {
    var out = String(rawCmd || "").trim()
    if (!out) return ""
    if (/(^|\s)(?:-y|--yes|--assume-yes)(?=\s|$)/.test(out)) {
        return out
    }
    return out + " -y"
}

function buildTerminalSingleAptCmd(opts, safePkgToken) {
    var raw = String((opts && opts.updateCommandOne) || "sudo apt install --only-upgrade").trim()
    var useNala = Boolean(opts && opts.useNala)
    var hasNala = Boolean(opts && opts.hasNala)
    var includePhased = Boolean(opts && opts.includePhasedUpdates)
    var baseCmd = ""

    if (useNala && hasNala && raw === "sudo apt install --only-upgrade") {
        baseCmd = buildNalaTerminalCmd("install", includePhased)
    } else {
        baseCmd = injectAptOptions(raw, includePhased, true)
    }
    baseCmd = ensureStandaloneYesFlag(baseCmd)
    return baseCmd + " -- " + safePkgToken
}

function buildEffectiveUpdateCmd(opts) {
    var aptCount = parseInt((opts && opts.aptCount) || 0, 10) || 0
    var enableSnap = Boolean(opts && opts.enableSnapUpdates && opts.hasSnap)
    var enableFlatpak = Boolean(opts && opts.enableFlatpakUpdates && opts.hasFlatpak)
    var snapCount = enableSnap ? (parseInt((opts && opts.snapCount) || 0, 10) || 0) : 0
    var flatpakCount = enableFlatpak ? (parseInt((opts && opts.flatpakCount) || 0, 10) || 0) : 0

    var parts = []
    if (aptCount > 0 || (snapCount === 0 && flatpakCount === 0)) {
        parts.push(buildTerminalAptUpgradeCmd(opts))
    }
    if (enableSnap && snapCount > 0) {
        parts.push("sudo snap refresh")
    }
    if (enableFlatpak && flatpakCount > 0) {
        parts.push("flatpak update -y")
    }
    if (parts.length === 0) return ""
    if (parts.length === 1) return parts[0]
    var wrapped = []
    for (var i = 0; i < parts.length; i++) {
        wrapped.push("(" + parts[i] + ") || err=1")
    }
    return "err=0; " + wrapped.join("; ") + "; [ $err -eq 0 ]"
}

function buildSilentAptUpgradeCmd(includePhasedUpdates, singlePkgToken) {
    var phased = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    if (singlePkgToken) {
        return "apt-get " + SILENT_APT_OPTS + phased + " install --only-upgrade -yq -- " + singlePkgToken
    }
    return "apt-get -o DPkg::Lock::Timeout=10 update && apt-get " + SILENT_APT_OPTS + phased + " upgrade -yq --with-new-pkgs"
}

function buildPkexecStep(innerCmd, failKind, maxNormalRc) {
    // Normalize single-repo child non-zero exit codes (e.g. apt-get exit 100) to 1 inside root bash
    // so exit codes 126 (cancelled) and 127 (pkexec/helper failure) remain unambiguous pkexec states.
    var safeInner = (failKind === "both") ? innerCmd : ("( " + innerCmd + " ) || exit 1")
    var logRules =
        "if [ $pkstatus -eq 126 ]; then echo '[CANCELLED]' >> \"$logfile\"; " +
        "elif [ $pkstatus -eq 127 ] || [ $pkstatus -gt " + maxNormalRc + " ]; then echo '[PKEXEC_FAILED] code='\"$pkstatus\" >> \"$logfile\"; "

    if (failKind === "both") {
        logRules +=
            "elif [ $pkstatus -ne 0 ]; then " +
              "if [ $((pkstatus & 1)) -ne 0 ]; then echo '[FAILED] apt' >> \"$logfile\"; fi; " +
              "if [ $((pkstatus & 2)) -ne 0 ]; then echo '[FAILED] snap' >> \"$logfile\"; fi; " +
            "fi"
    } else {
        logRules +=
            "elif [ $pkstatus -ne 0 ]; then echo '[FAILED] " + failKind + "' >> \"$logfile\"; fi"
    }

    return "pkexec env " + SILENT_APT_ENV + " bash -c '" + bashEscape(safeInner) + "' < /dev/null; pkstatus=$?; " + logRules
}

function resolveSafeLogDir(preferredLogDir) {
    var dir = String(preferredLogDir || "").trim()
    if (!dir || dir === "." || dir === ".." || dir.indexOf("./") === 0 || dir === "/tmp" || dir.indexOf("/tmp/") === 0) {
        return ""
    }
    return dir
}

function buildSafeDirInit(dirExpr, dirVar) {
    var safeDir = resolveSafeLogDir(dirExpr)
    var assign = safeDir
        ? (dirVar + "='" + bashEscape(safeDir) + "'")
        : (dirVar + "=\"${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/aptupdate}\"; [ -n \"$" + dirVar + "\" ] || " + dirVar + "=\"${XDG_CACHE_HOME:-$HOME/.cache}/hadbilen.aptupdate.plasmoid/logs\"")
    var verify =
        "mkdir -p -m 0700 \"$" + dirVar + "\" 2>/dev/null && " +
        "test -d \"$" + dirVar + "\" && test -O \"$" + dirVar + "\" && ! test -L \"$" + dirVar + "\" && " +
        "chmod 0700 \"$" + dirVar + "\" 2>/dev/null"
    return { assign: assign, verify: verify }
}

function wrapWithSystemdScope(shellCmd, unitName, useScope) {
    if (!useScope || !unitName) {
        return shellCmd
    }
    return "systemd-run --user --scope --quiet --unit='" + bashEscape(unitName) + "' -- " + shellCmd
}

function wrapWithProcessGroup(shellCmd, pgidFile) {
    if (!pgidFile) {
        return shellCmd
    }
    var dirPart = ""
    var idx = String(pgidFile).lastIndexOf("/")
    if (idx > 0) {
        dirPart = String(pgidFile).slice(0, idx)
    }
    var safeDir = resolveSafeLogDir(dirPart)
    var pgGuard = buildSafeDirInit(safeDir, "__pdir")
    var safeFileName = String(pgidFile).slice(idx + 1).replace(/[^a-zA-Z0-9._-]/g, "_")
    var innerWithPid =
        pgGuard.assign + "; " +
        "if " + pgGuard.verify + "; then " +
          "__pfile=\"$__pdir/" + safeFileName + "\"; " +
          "__ptmp=\"$(mktemp \"$__pdir/aptupdate_pgid_tmp.XXXXXX\" 2>/dev/null)\" && { printf '%s\\n' \"$$\" > \"$__ptmp\" && chmod 0600 \"$__ptmp\" && mv -f \"$__ptmp\" \"$__pfile\"; } || rm -f \"$__ptmp\" 2>/dev/null; " +
        "fi; " +
        shellCmd
    var innerBash = "bash -c '" + bashEscape(innerWithPid) + "'"
    return "if command -v setsid >/dev/null 2>&1 && setsid -w true >/dev/null 2>&1; then " +
        "setsid -w " + innerBash + "; " +
        "else " + innerBash + "; fi"
}

function buildSilentWrapper(logDir, logFileName, innerScript, inhibitReason, unitName, useScope, pgidFile) {
    var dirGuard = buildSafeDirInit(logDir, "logdir")
    var safeName = String(logFileName || "aptupdate_last_error.log").replace(/[^a-zA-Z0-9._-]/g, "_")

    var wrappedPipeline =
        "umask 077; " +
        dirGuard.assign + "; " +
        "logfile=\"$logdir/" + safeName + "\"; " +
        "if ! ( " + dirGuard.verify + " ); then exit 1; fi; " +
        "tmpfile=\"$(mktemp \"$logdir/tmp_" + safeName + ".XXXXXX\")\" || exit 1; " +
        "mv -f \"$tmpfile\" \"$logfile\" || { rm -f \"$tmpfile\"; exit 1; }; " +
        "if test -L \"$logfile\" || ! test -O \"$logfile\" || ! test -f \"$logfile\"; then exit 1; fi; " +
        "( " + innerScript + " ) < /dev/null; " +
        "inner_rc=$?; " +
        "if [ -s \"$logfile\" ]; then " +
            "if grep -q '\\[PKEXEC_FAILED\\]' \"$logfile\" || grep -q '\\[FAILED\\]' \"$logfile\"; then exit 1; " +
            "elif grep -q '\\[CANCELLED\\]' \"$logfile\"; then exit 126; fi; " +
        "fi; " +
        "exit $inner_rc"

    var runInhibit = "systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='" + bashEscape(inhibitReason) + "' bash -c '" + bashEscape(wrappedPipeline) + "'"
    var checkInhibit = "command -v systemd-inhibit >/dev/null 2>&1 && systemd-inhibit --what=shutdown:sleep --who='APT Update Counter' --why='check' true >/dev/null 2>&1"
    var body = "if " + checkInhibit + "; then " + runInhibit + "; else bash -c '" + bashEscape(wrappedPipeline) + "'; fi"
    if (useScope && unitName) {
        return wrapWithSystemdScope("bash -c '" + bashEscape(body) + "'", unitName, true)
    }
    if (pgidFile) {
        return wrapWithProcessGroup("bash -c '" + bashEscape(body) + "'", pgidFile)
    }
    return body
}

function buildEffectiveSilentUpdateCmd(opts) {
    var aptCount = parseInt((opts && opts.aptCount) || 0, 10) || 0
    var enableSnap = Boolean(opts && opts.enableSnapUpdates && opts.hasSnap)
    var enableFlatpak = Boolean(opts && opts.enableFlatpakUpdates && opts.hasFlatpak)
    var snapCount = enableSnap ? (parseInt((opts && opts.snapCount) || 0, 10) || 0) : 0
    var flatpakCount = enableFlatpak ? (parseInt((opts && opts.flatpakCount) || 0, 10) || 0) : 0

    var hasExplicitRunFlags = (opts && (typeof opts.runApt === "boolean" || typeof opts.runSnap === "boolean" || typeof opts.runFlatpak === "boolean"))
    var runApt = hasExplicitRunFlags ? Boolean(opts.runApt) : ((aptCount > 0) || (snapCount === 0 && flatpakCount === 0))
    var runSnap = hasExplicitRunFlags ? Boolean(opts.runSnap) : (enableSnap && snapCount > 0)
    var runFlatpak = hasExplicitRunFlags ? Boolean(opts.runFlatpak) : (enableFlatpak && flatpakCount > 0)

    var includePhased = Boolean(opts && opts.includePhasedUpdates)
    var aptFullCmd = buildSilentAptUpgradeCmd(includePhased, "")
    var steps = []

    if (runApt && runSnap) {
        var bothInner = "rc=0; (" + aptFullCmd + ") || rc=$((rc | 1)); snap refresh || rc=$((rc | 2)); exit $rc"
        steps.push(buildPkexecStep(bothInner, "both", 3))
    } else if (runApt) {
        steps.push(buildPkexecStep(aptFullCmd, "apt", 1))
    } else if (runSnap) {
        steps.push(buildPkexecStep("snap refresh", "snap", 1))
    }

    if (runFlatpak) {
        steps.push("if [ ${pkstatus:-0} -ne 126 ]; then flatpak update -y || { fp_rc=$?; echo '[FAILED] flatpak' >> \"$logfile\"; exit $fp_rc; }; fi")
    }

    var subshellCmd = steps.join("; ")
    var logName = (opts && opts.logFileName) ? opts.logFileName : "aptupdate_last_error_all.log"
    return buildSilentWrapper(opts ? opts.logDir : "", logName, subshellCmd, "Installing system updates", opts ? opts.unitName : "", Boolean(opts && opts.useScope), opts ? opts.pgidFile : "")
}

function buildTerminalCommand(opts) {
    var innerCmd = String((opts && opts.innerCmd) || "")
    var notClose = Boolean(opts && opts.notCloseCommand)
    var rawTerm = notClose ? ((opts && opts.termNoCloseCmd) || "") : ((opts && opts.termCmd) || "")
    var baseTerm = ensureShellDashC(rawTerm)
    if (!baseTerm) return ""

    var script = ""
    if (notClose) {
        var suffix = String((opts && opts.termNoCloseSuffix) || "").trim()
        var rcFile = String((opts && opts.rcFile) || "").trim()
        var setupRc = ""
        if (rcFile) {
            var dirInit = buildSafeDirInit(opts ? opts.logDir : "", "__rcdir")
            var rcIdx = rcFile.lastIndexOf("/")
            var rcBaseName = (rcIdx !== -1 ? rcFile.slice(rcIdx + 1) : rcFile).replace(/[^a-zA-Z0-9._-]/g, "_")
            setupRc =
                dirInit.assign + "; " +
                "__rcfile=''; " +
                "if " + dirInit.verify + "; then " +
                  "__rc_target=\"$__rcdir/" + rcBaseName + "\"; " +
                  "__rctmp=\"$(mktemp \"$__rcdir/aptupdate_rc_tmp.XXXXXX\" 2>/dev/null)\" && { chmod 0600 \"$__rctmp\" && mv -f \"$__rctmp\" \"$__rc_target\" && ! test -L \"$__rc_target\" && test -O \"$__rc_target\" && test -f \"$__rc_target\" && __rcfile=\"$__rc_target\"; } || rm -f \"$__rctmp\" 2>/dev/null; " +
                "fi; "
        }
        var normSuffix = ""
        if (suffix) {
            normSuffix = /^[;|&]/.test(suffix) ? (" " + suffix) : ("; " + suffix)
        }
        var saveRc = rcFile
            ? "; __rc=$?; if [ -n \"$__rcfile\" ]; then printf '%s\\n' \"$__rc\" > \"$__rcfile\" 2>/dev/null || true; fi"
            : "; __rc=$?"
        script = setupRc + "( " + innerCmd + " )" + saveRc + normSuffix + "; exit $__rc"
    } else {
        var errPrompt = String((opts && opts.errPrompt) || "An error occurred during update. Press Enter to close...")
        script = "( " + innerCmd + " ) || { st=$?; echo ''; echo '" + bashEscape(errPrompt) + "'; read -r; exit $st; }"
    }

    var fullCmd = baseTerm + " '" + bashEscape(script) + "'"
    if (opts && opts.useScope && opts.unitName) {
        return wrapWithSystemdScope(fullCmd, opts.unitName, true)
    }
    if (opts && opts.pgidFile) {
        return wrapWithProcessGroup(fullCmd, opts.pgidFile)
    }
    return fullCmd
}

function buildCheckLockCmd() {
    var psExpr = "ps -u 0 -o comm=,args= 2>/dev/null | awk 'BEGIN{l=0} {c=$1; a=$0; sub(/^[^ ]+[ ]*/, \"\", a); if(c~/^(dpkg|synaptic|aptitude|aptd)$/){l=1;exit} if(a~/(unattended-upgrade|aptd)( |$)/){l=1;exit} if(c~/^(apt|apt-get|apt-fast|nala)$/ || a~/(^|\\/)nala( |$)/){if(a!~/( -s| --simulate| --dry-run| --just-print| --no-act)( |$)/){l=1;exit}}} END{exit !l}'"
    var pkExpr = "if pgrep -x packagekitd >/dev/null 2>&1; then " +
        "if command -v gdbus >/dev/null 2>&1; then " +
          "_pk_tx=\"$(gdbus call --system --dest org.freedesktop.PackageKit --object-path /org/freedesktop/PackageKit --method org.freedesktop.PackageKit.GetTransactionList 2>/dev/null || true)\"; " +
          "printf '%s' \"$_pk_tx\" | grep -q \"'/\" && exit 0; " +
          "_pk_lk=\"$(gdbus call --system --dest org.freedesktop.PackageKit --object-path /org/freedesktop/PackageKit --method org.freedesktop.DBus.Properties.Get org.freedesktop.PackageKit Locked 2>/dev/null || true)\"; " +
          "printf '%s' \"$_pk_lk\" | grep -qi \"true\" && exit 0; " +
        "elif command -v busctl >/dev/null 2>&1; then " +
          "_pk_tx=\"$(busctl --system call org.freedesktop.PackageKit /org/freedesktop/PackageKit org.freedesktop.PackageKit GetTransactionList 2>/dev/null || true)\"; " +
          "printf '%s' \"$_pk_tx\" | grep -qE \"/[0-9]+\" && exit 0; " +
          "_pk_lk=\"$(busctl --system get-property org.freedesktop.PackageKit /org/freedesktop/PackageKit org.freedesktop.PackageKit Locked 2>/dev/null || true)\"; " +
          "printf '%s' \"$_pk_lk\" | grep -qi \"true\" && exit 0; " +
        "elif command -v qdbus6 >/dev/null 2>&1; then " +
          "_pk_tx=\"$(qdbus6 --system org.freedesktop.PackageKit /org/freedesktop/PackageKit org.freedesktop.PackageKit.GetTransactionList 2>/dev/null || true)\"; " +
          "printf '%s' \"$_pk_tx\" | grep -q \"/\" && exit 0; " +
          "_pk_lk=\"$(qdbus6 --system org.freedesktop.PackageKit /org/freedesktop/PackageKit org.freedesktop.DBus.Properties.Get org.freedesktop.PackageKit Locked 2>/dev/null || true)\"; " +
          "printf '%s' \"$_pk_lk\" | grep -qi \"true\" && exit 0; " +
        "fi; " +
      "fi; exit 1"
    return "(fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || (" + psExpr + ") || (bash -c '" + bashEscape(pkExpr) + "')) && echo 1 || echo 0"
}

function buildConnectivityCmd() {
    return "((command -v ip >/dev/null 2>&1 && (" +
        "(ip -o route get 1.1.1.1 2>/dev/null | grep -q 'dev ' && ! ip -o route get 1.1.1.1 2>/dev/null | grep -Eq '(^|[[:space:]])dev lo([[:space:]]|$)') || " +
        "(ip -6 -o route get 2606:4700:4700::1111 2>/dev/null | grep -q 'dev ' && ! ip -6 -o route get 2606:4700:4700::1111 2>/dev/null | grep -Eq '(^|[[:space:]])dev lo([[:space:]]|$)') || " +
        "ip route show default 2>/dev/null | grep -q default || " +
        "ip -6 route show default 2>/dev/null | grep -q default)) || " +
        "(command -v nmcli >/dev/null 2>&1 && [ \"$(nmcli -t -f CONNECTIVITY general 2>/dev/null)\" = \"full\" ])) && echo 1 || echo 0"
}

function buildRebootPromptCmd() {
    return "(command -v qdbus6 >/dev/null 2>&1 && qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot >/dev/null 2>&1) || " +
        "(command -v qdbus >/dev/null 2>&1 && qdbus org.kde.LogoutPrompt /LogoutPrompt promptReboot >/dev/null 2>&1) || " +
        "(command -v gdbus >/dev/null 2>&1 && gdbus call --session --dest org.kde.LogoutPrompt --object-path /LogoutPrompt --method org.kde.LogoutPrompt.promptReboot >/dev/null 2>&1) || " +
        "(command -v dbus-send >/dev/null 2>&1 && dbus-send --session --type=method_call --print-reply --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptReboot >/dev/null 2>&1)"
}

function buildNotifyCmd(title, message, icon, urgency) {
    var safeTitle = bashEscape(title)
    var safeMsg = bashEscape(message)
    var safeIcon = bashEscape(icon || "dialog-information")
    var safeUrgency = (urgency === "low" || urgency === "critical") ? urgency : "normal"
    var uByte = (safeUrgency === "critical") ? "2" : (safeUrgency === "low" ? "0" : "1")

    return "if command -v notify-send >/dev/null 2>&1; then " +
        "notify-send -u " + safeUrgency + " -a 'APT Update Counter' -i '" + safeIcon + "' -- '" + safeTitle + "' '" + safeMsg + "'; " +
        "elif command -v gdbus >/dev/null 2>&1; then " +
        "gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify -- 'APT Update Counter' 0 '" + safeIcon + "' '" + safeTitle + "' '" + safeMsg + "' '[]' \"{'urgency': <byte " + uByte + ">}\" 5000 >/dev/null; " +
        "elif command -v kdialog >/dev/null 2>&1; then " +
        "kdialog --passivepopup '" + safeTitle + ": " + safeMsg + "' 5 >/dev/null; " +
        "else exit 1; fi"
}

function buildCountArchCmd(includePhasedUpdates) {
    var phased = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    var inner = "set -o pipefail; errf=$(mktemp) || exit 1; trap 'rm -f \"$errf\"' EXIT; " +
        "LC_ALL=C apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade" + phased + " 2>\"$errf\" | " +
        "awk '/^Inst [^ ]+ \\[/ {c++} END {print c+0}'; " +
        "rc=$?; if [ $rc -ne 0 ]; then tail -n 8 \"$errf\" >&2; fi; exit $rc"
    return "bash -c '" + bashEscape(inner) + "'"
}

function buildListArchCmd(includePhasedUpdates) {
    var phased = includePhasedUpdates ? " -o APT::Get::Always-Include-Phased-Updates=true" : ""
    var inner = "set -o pipefail; errf=$(mktemp) || exit 1; trap 'rm -f \"$errf\"' EXIT; " +
        "LC_ALL=C apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade" + phased + " 2>\"$errf\" | " +
        "awk '/^Inst [^ ]+ \\[/ {gsub(/[][()]/, \"\"); $1=$1; origins=\"\"; for(i=5;i<=NF;i++) origins=(origins==\"\" ? $i : origins \" \" $i); print $2, $3, \"->\", $4, origins}'; " +
        "rc=$?; if [ $rc -ne 0 ]; then tail -n 8 \"$errf\" >&2; fi; exit $rc"
    return "bash -c '" + bashEscape(inner) + "'"
}

function buildListSnapCmd() {
    var inner = "set -o pipefail; errf=$(mktemp) || exit 1; trap 'rm -f \"$errf\"' EXIT; " +
        "(LC_ALL=C snap list 2>/dev/null || true; echo '---SEP---'; LC_ALL=C timeout --kill-after=5s 20s snap refresh --list 2>\"$errf\") | " +
        "awk 'BEGIN { in_up=0 } $0 == \"---SEP---\" { in_up=1; next } !in_up { if ($1 != \"Name\" && NF>=2) { inst[$1]=$2 } next } in_up { if ($1 != \"Name\" && $1 != \"All\" && NF>=2 && $1 != \"\") { name=$1; tv=$2; fv=(name in inst ? inst[name] : \"-\"); print name \"\\t\" name \"\\tsnap\\t\" fv \"\\t\" tv } }'; " +
        "rc=$?; if [ $rc -ne 0 ]; then tail -n 8 \"$errf\" >&2; fi; exit $rc"
    return "bash -c '" + bashEscape(inner) + "'"
}

function buildListFlatpakCmd() {
    var inner = "set -o pipefail; errf=$(mktemp) || exit 1; trap 'rm -f \"$errf\"' EXIT; " +
        "(LC_ALL=C flatpak list --columns=application,branch,version 2>/dev/null || true; echo '---SEP---'; LC_ALL=C timeout --kill-after=5s 20s flatpak remote-ls --updates --columns=application,name,branch,version 2>\"$errf\") | " +
        "awk -F'\\t' 'BEGIN { in_up=0 } $0 == \"---SEP---\" { in_up=1; next } !in_up { if (NF>=2) { ver=($3 != \"\" ? $3 : $2); inst[$1 \"/\" $2]=ver; inst_app[$1]=ver } next } in_up { if (NF>=1 && $1 != \"\") { app=$1; name=($2 != \"\" ? $2 : $1); branch=$3; tv=($4 != \"\" ? $4 : branch); key=app \"/\" branch; fv=(key in inst ? inst[key] : (app in inst_app ? inst_app[app] : \"-\")); print app \"\\t\" name \"\\tflatpak\\t\" fv \"\\t\" tv \"\\t\" branch } }'; " +
        "rc=$?; if [ $rc -ne 0 ]; then tail -n 8 \"$errf\" >&2; fi; exit $rc"
    return "bash -c '" + bashEscape(inner) + "'"
}

function isSecurityUpdateList(listAptText) {
    var lines = String(listAptText || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var arrowIdx = line.indexOf(" -> ")
        if (arrowIdx === -1) continue
        var afterArrow = line.slice(arrowIdx + 4).trim()
        var originPart = afterArrow.replace(/^\S+\s*/, "")
        if (originPart && /security/i.test(originPart)) {
            return true
        }
    }
    return false
}

function evaluateNotification(state) {
    var currentTotal = (parseInt(state.numApt, 10) || 0) +
        (state.enableSnap && state.hasSnap ? (parseInt(state.numSnap, 10) || 0) : 0) +
        (state.enableFlatpak && state.hasFlatpak ? (parseInt(state.numFlatpak, 10) || 0) : 0)

    if (!state.notifyOnUpdates || state.busy) {
        return { action: "skip", previousTotal: state.previousTotal }
    }
    if (state.expanded) {
        return {
            action: "expanded_suppress",
            previousTotal: state.previousTotal,
            lastNotifiedTotal: state.lastNotifiedTotal,
            lastNotifiedHasSecurity: state.lastNotifiedHasSecurity
        }
    }

    var threshold = (state.threshold !== undefined) ? state.threshold : 1
    var isStartup = (state.previousTotal < 0)
    var hasSecurity = isSecurityUpdateList(state.listApt)
    var lastHasSec = hasSecurity ? Boolean(state.lastNotifiedHasSecurity) : false

    if (currentTotal === 0) {
        return {
            action: "reset",
            previousTotal: 0,
            lastNotifiedTotal: 0,
            lastNotifiedHasSecurity: false
        }
    }
    if (currentTotal < threshold && !hasSecurity) {
        return {
            action: "below_threshold",
            previousTotal: currentTotal,
            lastNotifiedTotal: 0,
            lastNotifiedHasSecurity: false
        }
    }

    var shouldNotify = false
    var isCritical = false
    if (hasSecurity && !lastHasSec) {
        shouldNotify = true
        isCritical = true
    } else if (isStartup) {
        if (state.notifyOnStartup && currentTotal >= threshold) {
            shouldNotify = true
        }
    } else if (currentTotal > state.previousTotal) {
        if (state.lastNotifiedTotal <= 0) {
            shouldNotify = (currentTotal >= threshold)
        } else if (currentTotal >= state.lastNotifiedTotal + 5) {
            shouldNotify = true
        }
    }

    return {
        action: shouldNotify ? (isCritical ? "notify_critical" : "notify_normal") : "noop",
        shouldNotify: shouldNotify,
        isCritical: isCritical,
        hasSecurity: hasSecurity,
        currentTotal: currentTotal,
        previousTotal: currentTotal,
        lastNotifiedTotal: shouldNotify ? currentTotal : state.lastNotifiedTotal,
        lastNotifiedHasSecurity: (shouldNotify && isCritical) ? true : lastHasSec
    }
}

function buildSafeReadAndRemoveCmd(filePath) {
    var inner = "f='" + bashEscape(filePath) + "'; if [ -f \"$f\" ] && [ ! -L \"$f\" ] && [ -O \"$f\" ]; then cat \"$f\" 2>/dev/null || true; rm -f \"$f\" 2>/dev/null || true; fi"
    return "bash -c '" + bashEscape(inner) + "'"
}

function buildSafeRemoveCmd(filePath) {
    var inner = "f='" + bashEscape(filePath) + "'; if [ -e \"$f\" ] && [ ! -L \"$f\" ] && [ -O \"$f\" ]; then rm -f \"$f\" 2>/dev/null || true; fi"
    return "bash -c '" + bashEscape(inner) + "'"
}

function buildSafeKillPgidAndRemoveCmd(pgidFiles) {
    var files = (pgidFiles && pgidFiles.length) ? pgidFiles : []
    var parts = []
    for (var i = 0; i < files.length; i++) {
        if (files[i]) parts.push("'" + bashEscape(files[i]) + "'")
    }
    if (parts.length === 0) return ""
    var inner = "for f in " + parts.join(" ") + "; do " +
        "if [ -f \"$f\" ] && [ ! -L \"$f\" ] && [ -O \"$f\" ]; then " +
          "_pg=\"$(cat \"$f\" 2>/dev/null | tr -cd '0-9')\"; " +
          "if [ -n \"$_pg\" ] && [ \"$_pg\" -gt 1 ] 2>/dev/null; then kill -TERM -\"$_pg\" 2>/dev/null || true; fi; " +
          "rm -f \"$f\" 2>/dev/null || true; " +
        "fi; " +
        "done"
    return "bash -c '" + bashEscape(inner) + "'"
}

function classifySilentLog(output) {
    var text = String(output || "").trim()
    if (text.indexOf("[CANCELLED]") !== -1) {
        return { status: "cancelled", failedRepos: [], pkexecFailed: false, raw: text }
    }
    var failed = []
    if (text.indexOf("[FAILED] apt") !== -1) failed.push("APT")
    if (text.indexOf("[FAILED] snap") !== -1) failed.push("Snap")
    if (text.indexOf("[FAILED] flatpak") !== -1) failed.push("Flatpak")
    if (text.indexOf("[PKEXEC_FAILED]") !== -1) {
        var m = text.match(/\[PKEXEC_FAILED\]\s*code=(\d+)/)
        return { status: "pkexec_failed", code: m ? parseInt(m[1], 10) : 127, failedRepos: failed, pkexecFailed: true, raw: text }
    }
    return { status: "failed", failedRepos: failed, pkexecFailed: false, raw: text }
}
