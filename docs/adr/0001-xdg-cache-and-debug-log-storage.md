# ADR-0001: Store Volatile Update Cache and Debug Logs in `$XDG_CACHE_HOME` Instead of KConfig

**Date**: 2026-11-13
**Status**: accepted
**Deciders**: Project maintainer (via `deep-grill` Phase 0)

## Context

Previously, `saveCache()` (`main.qml#L400-L422`) and `Debug.log()` (`Debug.qml#L21-L33`) serialized pending package lists (`cachedPackageList`), counts, short `hh:mm` timestamps, and up to 200 HTML lines of `debugLog` into `plasmoid.configuration` (`main.xml`), triggering repeated rewrites of `~/.config/plasma-org.kde.plasma.desktop-appletsrc` on every periodic scan and command lifecycle event. Furthermore, `showLog.qml` runs in a separate `AppletConfiguration` context where `plasmoid.rootItem` may be `null`, leaving the log-clearing flow broken (`showLog.qml#L171-L176`), and Qt 6 QML `XMLHttpRequest` disables synchronous local `file://` reads by default (`QML_XHR_ALLOW_FILE_READ`).

## Decision

We move volatile update cache state (counts, package list, ISO timestamp, and offline/index staleness metadata) and debug logs out of KConfig (`main.xml` / `plasma-org.kde.plasma.desktop-appletsrc`) into `$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/` (resolved cross-host via `StandardPaths.GenericCacheLocation`). Cache and log files are read/written asynchronously through `Plasma5Support.DataSource` using `0700` directory permissions, `0600` atomic `mktemp` + `mv` writes for cache JSON, serialized 200-line tail-rotated appends for `debug.log`, full localized date+time display, and `/var/lib/apt/lists` staleness tracking.

## Alternatives Considered

### Alternative 1: Capped KConfig Storage
- **Pros**: Synchronous `plasmoid.configuration.*` availability at `Component.onCompleted` with zero filesystem I/O wrappers.
- **Cons**: Continues rewriting `~/.config/plasma-org.kde.plasma.desktop-appletsrc` on every periodic check and `debugMode` event, mixing disposable cache with critical KDE panel/desktop configuration and keeping `showLog.qml` coupled to KConfig or `plasmoid.rootItem`.
- **Why not**: Violates XDG Base Directory separation and leaves configuration churn and `showLog.qml` coupling unresolved.

### Alternative 2: Synchronous QML `XMLHttpRequest` on `file://`
- **Pros**: Instant synchronous load inside `Component.onCompleted`.
- **Cons**: Confirmed blocked by default in Qt 6.11 (`XMLHttpRequest: Using GET on a local file is disabled by default`).
- **Why not**: Fails at runtime under standard `plasmashell` environments where `QML_XHR_ALLOW_FILE_READ` is unset.

## Consequences

### Positive
- Eliminates KConfig write churn on `plasma-org.kde.plasma.desktop-appletsrc` and removes 6 volatile schema keys (`cached*`, `debugLog`) plus their `cfg_*` stubs across all 6 config pages while preserving active cross-page `cfg_*` properties required by KDE Plasma `AppletConfiguration`. Note that upgrading from or rolling back to `<= v1.2.1` cleanly resets cached update counts until the next check runs because old `cached*` appletsrc keys are ignored rather than deleted from user config files.
- Decouples `showLog.qml` from `plasmoid.rootItem`, enabling log viewing and truncation even when `plasmoid.rootItem` is `null`.
- Preserves full date+time timestamps (`lastCheckIso`) and `/var/lib/apt/lists` freshness diagnostics.

### Negative
- Startup cache restoration runs asynchronously (~5–15 ms) via `Plasma5Support.DataSource` rather than synchronously in `Component.onCompleted`.

### Risks
- **Race between async cache load and immediate startup scan (`startupCheckMode === 1`)**: Mitigated by guarding `applyLoadedCache()` with `if (!main.hasScannedThisSession && !main.isChecking)`.
- **Concurrent `debug.log` appends**: Mitigated by a serialized debounce flush queue inside `Debug.qml` and atomic append/trim semantics so log truncation from `showLog.qml` cannot be overwritten by stale in-memory buffers.
