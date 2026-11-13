# ADR-0003: Process Lifecycle Isolation, PackageKit D-Bus Lock Checking, Silent Wrapper Exit Integrity, and Safe Reboot Prompting

**Date**: 2026-11-13
**Status**: accepted
**Deciders**: Project maintainer (approved in Phase 0)

## Context

The post-`v1.2.1` Tier 3 audit uncovered four interconnected process and privilege boundary defects:
1. `Full.qml#L428` ran `qdbus org.kde.LogoutPrompt ... || systemctl reboot`, which immediately triggered an unconfirmed `systemctl reboot` whenever `qdbus` (Qt5) was absent on Plasma 6 systems (`qdbus6` only).
2. `buildSilentWrapper` (`Updater.qml#L54-L71`) lost `innerScript` non-zero exit codes when `$logfile` was empty, bitwise `pkstatus` checks misattributed `pkexec` exit `127` to both `[FAILED] apt` and `[FAILED] snap`, silent `apt-get` lacked `Dpkg::Options` conffile defaults and `< /dev/null`, and `logDir` used predictable `/tmp/.aptupdate-*` fallbacks and unguarded `cat` reads.
3. `Plasma5Support.DataSource::disconnectSource()` terminated only top-level `/bin/sh` while leaving compound children alive, `installWatchdogTimer` (600s) killed interactive `konsole` / `notCloseCommand` sessions while `notCloseCommand` masked `innerCmd` exit codes, `abortUpdate()` cleared `isPkgManagerBusy` without re-probing `checkLock()`, and job classification relied on fragile `startsWith(termCmd)` / `indexOf("konsole")` substring heuristics.
4. `checkLock()` omitted `org.freedesktop.PackageKit` D-Bus transaction/lock queries (`MISTAKES.md` forbids matching idle `packagekitd` in `ps`), while `Full.qml` lacked `isHelperCommand` filtering on `onExited` and per-repo error isolation.

## Decision

We adopt structural `mistake-proofing` invariants across `CommandBuilder.js`, `Updater.qml`, `Checker.qml`, `main.qml`, and `Full.qml`:
1. **Safe Reboot Prompting**: Remove all `systemctl reboot` fallbacks completely. Probe `qdbus6`, `qdbus`, and `dbus-send --session --print-reply` exclusively through `CommandBuilder.buildRebootPromptCmd()`, tagged as an explicit helper job that notifies the user with a critical error if D-Bus fails.
2. **Explicit Job Registry & Process-Group Scoping**: Tag every `DataSource` command at launch (`check`, `update` with `silent` snapshot and transient `systemd-run --user --scope` unit name, or `helper`) in a map keyed by command string, removing all `startsWith(termCmd)` / `indexOf("konsole")` guesses. Interactive terminal jobs are exempt from the 600s `installWatchdogTimer`, `notCloseCommand` records `innerCmd`'s exit code to a job-scoped status file before running `termNoCloseSuffix`, and `abortUpdate()` stops active transient scopes (`systemctl --user stop`) and invokes `checkLock()` instead of resetting `isPkgManagerBusy = false`.
3. **Silent Wrapper & `logDir` Isolation**: Capture `inner_rc=$?` inside `buildSilentWrapper`, separate `pkstatus` `126` (cancelled) and `127`/`>3` (`pkexec` failure) from inner repo bitmasks, inject `-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold`, `APT_LISTCHANGES_FRONTEND=none`, `NEEDRESTART_MODE=a`, and `< /dev/null` on silent `apt-get`, enforce `chmod 0700` on `logDir` (using `$XDG_RUNTIME_DIR/aptupdate` or `$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs`, never predictable `/tmp`), allocate per-job log/rc files via `mktemp`, and check `[ -f "$f" ] && [ ! -L "$f" ] && [ -O "$f" ]` before `cat` and removal.
4. **D-Bus PackageKit Lock & Per-Repo Error Partitioning**: Query `org.freedesktop.PackageKit` (`GetTransactionList` and `Locked`) via `gdbus`/`busctl`/`qdbus6` only when `pgrep -x packagekitd` indicates an active daemon (never matching idle `packagekitd` in `ps` and never D-Bus-activating a stopped daemon), and separate `checkErrors`, `updateErrors`, and `connectivityError` so healthy ecosystems remain actionable when one repo fails.

## Alternatives Considered

### Alternative 1: Keep Substring Command Matching and Static Log Paths
- **Pros**: Fewer structural edits to `main.qml` and `Updater.qml`.
- **Cons**: Fails immediately whenever `termCmd` is `"bash -c"`, leaves child processes orphaned on abort, keeps TOCTOU risks in `/tmp`, and allows cross-repo error clearing.
- **Why not**: Fails `AC-2` and `AC-3` safety boundaries and repeats historical `MISTAKES.md` failure classes.

### Alternative 2: Match `packagekitd` in `ps` Instead of Querying D-Bus
- **Pros**: Single `ps` invocation with zero D-Bus calls.
- **Cons**: Documented in `MISTAKES.md` (`2026-10-16`): `packagekitd` idles for 5 minutes after APT triggers, causing false package-manager lock banners.
- **Why not**: Violates the explicit `MISTAKES.md` preventive invariant.

## Consequences

### Positive
- Makes unconfirmed `systemctl reboot`, silent exit-0 masking, `pkstatus=127` bitmask false attributions, `termCmd="bash -c"` misclassification, and `abortUpdate()` lock clearing structurally impossible.
- Preserves clean cancellation teardown and accurate `isPkgManagerBusy` state across privileged/unprivileged boundaries.

### Negative
- Increases command wrapper verbosity (`systemd-run --user --scope` when available) and introduces `CommandBuilder.js` as a shared module imported by both `Updater.qml` and `configCommand.qml`.

### Risks
- **Non-systemd desktop sessions / containers where `systemd-run --user` is unavailable**: Mitigated by probing `command -v systemd-run >/dev/null 2>&1 && systemctl --user is-active default.target >/dev/null 2>&1` (or checking `systemd-run --user --scope` availability once via `Checker.qml`) and falling back to process-group wrapper execution (`setsid` / clean child tracking) when systemd user scopes are absent.
- **Root-owned `pkexec` child continuing after user cancels unprivileged scope**: Mitigated by requiring `abortUpdate()` to run `checkLock()`, which keeps `isPkgManagerBusy = true` and `busyPollTimer` active until root `apt-get`/`dpkg` finishes.
