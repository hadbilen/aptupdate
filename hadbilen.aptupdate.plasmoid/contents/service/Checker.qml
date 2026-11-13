import QtQuick

import org.kde.plasma.plasmoid

Item {
    readonly property string snapProbeCmd: "command -v snap >/dev/null 2>&1 && echo 1 || echo 0"
    readonly property string flatpakProbeCmd: "command -v flatpak >/dev/null 2>&1 && echo 1 || echo 0"
    readonly property string nalaProbeCmd: "command -v nala >/dev/null 2>&1 && echo 1 || echo 0"
    readonly property string osReleaseProbeCmd: "cat /etc/os-release 2>/dev/null || true"
    readonly property string systemdScopeProbeCmd: "command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope --quiet -- true >/dev/null 2>&1 && echo 1 || echo 0"
    readonly property string aptIndexProbeCmd: "bash -c 'ts=$(stat -c %Y /var/lib/apt/lists/*_InRelease /var/lib/apt/lists/*_Packages 2>/dev/null | sort -nr | head -n1); echo ${ts:-0}'"

    function execProbe(c, kind) {
        if (typeof main !== "undefined" && typeof main.execTaggedJob === "function") {
            main.execTaggedJob(c, "probe", kind || "provider")
        } else if (typeof cmd !== "undefined" && typeof cmd.exec === "function") {
            cmd.exec(c)
        }
    }

    function checkProviders() {
        execProbe(snapProbeCmd, "provider-snap")
        execProbe(flatpakProbeCmd, "provider-flatpak")
        execProbe(nalaProbeCmd, "provider-nala")
        execProbe(osReleaseProbeCmd, "provider-os")
        execProbe(systemdScopeProbeCmd, "provider-systemd")
        execProbe(aptIndexProbeCmd, "apt-index")
    }

    function syncConfigFlag(key, value) {
        var b = Boolean(value)
        if (typeof plasmoid !== "undefined" && plasmoid.configuration && plasmoid.configuration[key] !== b) {
            plasmoid.configuration[key] = b
        }
    }

    function validateSnap(stdout) {
        var val = (String(stdout || "").trim() === "1")
        if (typeof main !== "undefined" && main.setProviderAvailability) {
            main.setProviderAvailability("snap", val)
        }
        syncConfigFlag("hasSnap", val)
    }

    function validateFlatpak(stdout) {
        var val = (String(stdout || "").trim() === "1")
        if (typeof main !== "undefined" && main.setProviderAvailability) {
            main.setProviderAvailability("flatpak", val)
        }
        syncConfigFlag("hasFlatpak", val)
    }

    function validateNala(stdout) {
        var val = (String(stdout || "").trim() === "1")
        if (typeof main !== "undefined" && main.setProviderAvailability) {
            main.setProviderAvailability("nala", val)
        }
        syncConfigFlag("hasNala", val)
    }
}
