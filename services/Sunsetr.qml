pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Thin integration with the external sunsetr daemon (https://github.com/psi4j/sunsetr).
//
// The shell never spawns sunsetr: it is expected to already be running (systemd
// user service / compositor autostart). We mirror its live state from the event
// socket and drive it via the `sunsetr` CLI.
//
// The OSD's icon tap cycles a 3-state override through sunsetr presets:
//   auto -> on (warmPreset) -> off (offPreset) -> auto ...
// "auto" is sunsetr's own default schedule; the other two are static presets the
// user must define under ~/.config/sunsetr/presets/<name>/sunsetr.toml.
Singleton {
    id: root

    // Preset directories under ~/.config/sunsetr/presets/. Edit these if you
    // name your presets differently. "auto" always maps to `sunsetr preset default`.
    readonly property string onPreset: "night"
    readonly property string offPreset: "day"

    // Neutral daylight temperature; at or above this the warm filter is considered off.
    readonly property int neutralTemp: 6500

    property bool available: false
    readonly property bool running: eventSocket.connected

    // Live state mirrored from sunsetr.
    property string activePreset: "default"
    property string period: "day"
    property string state: "stable"
    property int temperature: neutralTemp
    property real gamma: 100

    // "auto" | "on" | "off", derived from which preset sunsetr reports active.
    readonly property string mode: activePreset === onPreset ? "on" : activePreset === offPreset ? "off" : "auto"

    // True when the warm filter is actually engaged, regardless of how we got there
    // (a forced preset, or the auto schedule currently being in its night window).
    readonly property bool active: temperature < neutralTemp

    readonly property string socketPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/sunsetr-events.sock`

    // Cycle: auto -> on -> off -> auto.
    function toggle(): void {
        if (mode === "auto")
            setPreset(onPreset);
        else if (mode === "on")
            setPreset(offPreset);
        else
            setPreset("default");
    }

    function setPreset(name: string): void {
        Quickshell.execDetached(["sunsetr", "preset", name]);
    }

    function applyStatus(json: string): void {
        let o;
        try {
            o = JSON.parse(json);
        } catch (e) {
            return;
        }
        activePreset = o.active_preset ?? activePreset;
        period = o.period ?? period;
        state = o.state ?? state;
        temperature = Math.round(o.current_temp ?? temperature);
        gamma = o.current_gamma ?? gamma;
    }

    function handleEvent(line: string): void {
        const trimmed = line.trim();
        if (trimmed.length === 0)
            return;

        let o;
        try {
            o = JSON.parse(trimmed);
        } catch (e) {
            return;
        }

        switch (o.event_type) {
        case "state_applied":
            activePreset = o.active_preset ?? activePreset;
            period = o.period ?? period;
            state = o.state ?? state;
            temperature = Math.round(o.current_temp ?? temperature);
            gamma = o.current_gamma ?? gamma;
            break;
        case "period_changed":
            period = o.to_period ?? period;
            break;
        case "preset_changed":
            activePreset = o.to_preset ?? "default";
            period = o.target_period ?? period;
            temperature = Math.round(o.target_temp ?? temperature);
            gamma = o.target_gamma ?? gamma;
            break;
        case "config_changed":
            period = o.target_period ?? period;
            temperature = Math.round(o.target_temp ?? temperature);
            gamma = o.target_gamma ?? gamma;
            break;
        }
    }

    function requestConnection(): void {
        eventSocket.connected = false;
        eventSocket.connected = true;
    }

    onAvailableChanged: {
        if (available)
            requestConnection();
    }

    Process {
        id: availProc

        running: true
        command: ["sh", "-c", "command -v sunsetr >/dev/null"]

        onExited: exitCode => root.available = exitCode === 0 // qmllint disable signal-handler-parameters
    }

    // Seed full state on connect: the event socket only streams changes, not a snapshot.
    Process {
        id: statusProc

        command: ["sunsetr", "status", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t.length > 0)
                    root.applyStatus(t);
            }
        }
    }

    Socket {
        id: eventSocket

        path: root.socketPath
        parser: SplitParser {
            onRead: data => root.handleEvent(data) // qmllint disable signal-handler-parameters
        }

        onConnectedChanged: {
            if (eventSocket.connected)
                statusProc.running = true;
        }
    }

    // Retry the socket while sunsetr is installed but not (yet) reachable, so we
    // pick it up if it starts after the shell. connected reads as the actual state,
    // so this only polls while we're genuinely disconnected.
    Timer {
        interval: 4000
        repeat: true
        running: root.available && !eventSocket.connected

        onTriggered: root.requestConnection()
    }
}
