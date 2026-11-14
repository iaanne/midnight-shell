pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property bool usingAsusctl: false
    property int asusProfile: PowerProfile.Balanced
    // 20-100 when known, -1 until asusctl has reported it.
    property int chargeLimit: -1
    readonly property int profile: usingAsusctl ? asusProfile : PowerProfiles.profile

    // UPower charge threshold (battery care) support, probed on demand.
    property string upowerBatteryPath: ""
    property bool chargeThresholdSupported: false
    property bool chargeThresholdEnabled: false
    property bool chargeThresholdBusy: false
    property int chargeThresholdSettingsSupported: 0
    property int chargeStartThreshold: 0
    property int chargeEndThreshold: 0

    // Bit 4 means the firmware chooses the actual thresholds.
    readonly property bool chargeFirmwareManaged: (chargeThresholdSettingsSupported & 4) !== 0
    // Bit 2 means a charge end threshold is available.
    readonly property bool chargeEndThresholdSupported: (chargeThresholdSettingsSupported & 2) !== 0 && chargeEndThreshold > 0

    function setProfile(p: int): void {
        if (!usingAsusctl) {
            PowerProfiles.profile = p;
            return;
        }

        // Optimistic, so the battery popout pill moves immediately.
        asusProfile = p;

        setProc.pending = p;
        setProc.retry = false;
        setProc.command = ["asusctl", "profile", "set", profileName(p, true)];
        if (setProc.running)
            setProc.running = false;
        setProc.running = true;
    }

    // Re-read the profile from asusctl; the battery popout calls this on open.
    function fetchProfile(): void {
        if (!usingAsusctl || getProc.running || setProc.running)
            return;

        getProc.retry = false;
        getProc.command = ["asusctl", "profile", "get"];
        getProc.running = true;
    }

    // Read the charge limit from asusctl; the battery popout calls this on open.
    function fetchChargeLimit(): void {
        if (!usingAsusctl || batGetProc.running || batSetProc.running)
            return;

        batGetProc.command = ["asusctl", "battery", "info"];
        batGetProc.running = true;
    }

    function setChargeLimit(limit: int): void {
        if (!usingAsusctl)
            return;

        const n = Math.max(20, Math.min(100, limit));

        // Optimistic, so the slider snaps to the committed value.
        chargeLimit = n;

        batSetProc.pending = n;
        batSetProc.retry = false;
        batSetProc.command = ["asusctl", "battery", "limit", n.toString()];
        if (batSetProc.running)
            batSetProc.running = false;
        batSetProc.running = true;
    }

    function profileName(p: int, capitalized: bool): string {
        let name = "balanced";
        if (p === PowerProfile.PowerSaver)
            name = "quiet";
        else if (p === PowerProfile.Performance)
            name = "performance";
        return capitalized ? name.charAt(0).toUpperCase() + name.slice(1) : name;
    }

    function parseProfile(output: string): int {
        const match = output.match(/\b(low-?power|quiet|balanced|performance|custom)\b/i);
        if (!match)
            return -1;

        const name = match[1].toLowerCase();
        if (name === "performance")
            return PowerProfile.Performance;
        if (name === "quiet" || name.startsWith("low"))
            return PowerProfile.PowerSaver;
        return PowerProfile.Balanced;
    }

    function parseChargeLimit(output: string): int {
        const m = output.match(/end[^\d\n]{0,15}(\d{1,3})/i)
            ?? output.match(/(?:limit|threshold)[^\d\n]{0,15}(\d{1,3})/i)
            ?? output.match(/\b(\d{1,3})\b/);
        if (!m)
            return -1;

        const n = parseInt(m[1], 10);
        return n >= 20 && n <= 100 ? n : -1;
    }

    function refreshChargeThreshold(): void {
        if (upowerProc.running || upowerPropsProc.running)
            return;
        upowerProc.running = true;
    }

    function setChargeThresholdEnabled(value: bool): void {
        if (!upowerBatteryPath || chargeSetProc.running)
            return;

        // Optimistic update so the switch responds immediately.
        chargeThresholdEnabled = value;
        chargeThresholdBusy = true;

        chargeSetProc.command = ["busctl", "call", "org.freedesktop.UPower", upowerBatteryPath, "org.freedesktop.UPower.Device", "EnableChargeThreshold", "b", value ? "true" : "false"];
        chargeSetProc.running = true;
    }

    function chargePropertyValue(lines: var, index: int): string {
        const parts = (lines[index] ?? "").trim().split(" ");
        return parts.length > 1 ? parts[1] : "";
    }

    function chargeBoolValue(lines: var, index: int): bool {
        return chargePropertyValue(lines, index) === "true";
    }

    function chargeIntValue(lines: var, index: int): int {
        return parseInt(chargePropertyValue(lines, index), 10) || 0;
    }

    Process {
        id: upowerProc

        command: ["upower", "-e"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(line => line.length > 0);
                const path = lines.find(line => line.includes("battery_"));

                if (!path) {
                    root.upowerBatteryPath = "";
                    root.chargeThresholdSupported = false;
                    return;
                }

                root.upowerBatteryPath = path.trim();
                upowerPropsProc.command = ["busctl", "get-property", "org.freedesktop.UPower", root.upowerBatteryPath, "org.freedesktop.UPower.Device", "ChargeThresholdSupported", "ChargeThresholdEnabled", "ChargeThresholdSettingsSupported", "ChargeStartThreshold", "ChargeEndThreshold"];
                upowerPropsProc.running = true;
            }
        }
    }

    Process {
        id: upowerPropsProc

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 5) {
                    root.chargeThresholdSupported = false;
                    return;
                }

                root.chargeThresholdSupported = root.chargeBoolValue(lines, 0);
                root.chargeThresholdEnabled = root.chargeBoolValue(lines, 1);
                root.chargeThresholdSettingsSupported = root.chargeIntValue(lines, 2);
                root.chargeStartThreshold = root.chargeIntValue(lines, 3);
                root.chargeEndThreshold = root.chargeIntValue(lines, 4);
            }
        }
    }

    Process {
        id: chargeSetProc

        onExited: exitCode => {
            root.chargeThresholdBusy = false;
            if (exitCode !== 0)
                console.warn("PowerCtl: EnableChargeThreshold failed with exit code", exitCode);
            root.refreshChargeThreshold();
        }
    }

    // Returns -1 when the output contains no known profile name.
    // Returns -1 when the output contains no usable limit (20-100).
    Process {
        id: detectProc

        running: true
        command: ["sh", "-c", "command -v asusctl >/dev/null"]

        onExited: exitCode => root.usingAsusctl = exitCode === 0 // qmllint disable signal-handler-parameters
    }

    Process {
        id: getProc

        property bool retry: false

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = root.parseProfile(text);
                if (parsed !== -1)
                    root.asusProfile = parsed;
            }
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode === 0)
                return;

            if (!getProc.retry) {
                // Legacy syntax: asusctl profile --profile-get
                getProc.retry = true;
                getProc.command = ["asusctl", "profile", "--profile-get"];
                getProc.running = true;
            } else {
                // asusctl exists but its profile interface is unusable.
                root.usingAsusctl = false;
            }
        }
    }

    Process {
        id: setProc

        property int pending: PowerProfile.Balanced
        property bool retry: false

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode === 0)
                return;

            if (!setProc.retry) {
                // Legacy syntax: asusctl profile -p <profile>
                setProc.retry = true;
                setProc.command = ["asusctl", "profile", "-p", root.profileName(setProc.pending, false)];
                setProc.running = true;
            } else {
                PowerProfiles.profile = setProc.pending;
            }
        }
    }

    Process {
        id: batGetProc

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = root.parseChargeLimit(text);
                if (parsed !== -1)
                    root.chargeLimit = parsed;
            }
        }
    }

    Process {
        id: batSetProc

        property int pending: 100
        property bool retry: false

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode === 0)
                return;

            if (!batSetProc.retry) {
                // Legacy syntax: asusctl --chg-limit <20-100>
                batSetProc.retry = true;
                batSetProc.command = ["asusctl", "--chg-limit", batSetProc.pending.toString()];
                batSetProc.running = true;
            } else {
                // Both syntaxes failed; resync with the limit actually applied.
                root.fetchChargeLimit();
            }
        }
    }
}
