# ADR-0002: Enforce `--no-autoremove` for Nala Terminal Upgrades While Preserving `--with-new-pkgs` APT Counts

**Date**: 2026-11-13
**Status**: accepted
**Deciders**: Project maintainer (via `deep-grill` Phase 0)

## Context

`Updater.qml` counts and lists pending APT upgrades using `apt-get -s --with-new-pkgs -o DPkg::Lock::Timeout=10 upgrade`, which surfaces kernel and new-dependency upgrades. Runtime inspection of `nala 0.16.0` (`nala-upgrade(8)`, `nala-install(8)`) establishes two behavioral divergences: (1) `nala upgrade` uses `apt-get upgrade` semantics (`python3-apt` lacks `apt upgrade` / `--with-new-pkgs`) and holds back upgrades needing new packages, and (2) both `nala upgrade` and `nala install` enable `--autoremove` by default, silently removing installed packages unlike `sudo apt upgrade`.

## Decision

We keep `apt-get -s --with-new-pkgs` for APT counting and listing so security and kernel updates are never hidden, pass explicit `--no-autoremove` to `nala upgrade` and `nala install` in terminal mode (`Updater.qml` and shared `CommandBuilder.js`), and add explicit warnings in `configCommand.qml` and `README.md` documenting that Nala (`0.16.0`) holds updates requiring new dependencies until upgraded via standard `apt` or silent `pkexec` mode.

## Alternatives Considered

### Alternative 1: Keep Nala Default `--autoremove` Without Modification
- **Pros**: Shorter generated command string matching stock `nala upgrade`.
- **Cons**: Clicking Update in a status widget can silently uninstall packages that standard `apt upgrade` keeps intact.
- **Why not**: Unannounced package removal violates safe upgrade expectations (`mistake-proofing` boundary).

### Alternative 2: Switch to `nala full-upgrade` or Drop `--with-new-pkgs` from Counts
- **Pros**: Aligns displayed count with Nala execution if counts drop `--with-new-pkgs`, or installs new dependencies under `full-upgrade`.
- **Cons**: `nala full-upgrade` invokes `dist-upgrade` conflict resolution that can remove existing packages; dropping `--with-new-pkgs` from `countArchCmd` conceals critical kernel/security updates from the user.
- **Why not**: Either introduces silent package-removal risk or creates a security blind spot in the update counter.

## Consequences

### Positive
- Prevents unexpected automatic package removals when `useNala` is enabled.
- Preserves accurate visibility of kernel and new-dependency security updates in the badge and list.
- Eliminates ambiguity via aligned UI (`configCommand.qml`) and `README.md` guidance.

### Negative
- If pending upgrades require new dependencies, running `nala upgrade` leaves those packages pending until upgraded with standard `apt` or silent `pkexec` mode.

### Risks
- **Users puzzled why count remains non-zero after a Nala run**: Mitigated by explicit inline warning in `configCommand.qml` and troubleshooting notes in `README.md`.
