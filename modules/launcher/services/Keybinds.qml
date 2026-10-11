pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

QtObject {
    id: root

    property var keybinds: []
    property bool initialized: false

    signal loaded

    readonly property string configPath: Compositor.keybindConfigPath
    readonly property string scriptsDir: Quickshell.shellDir + "/modules/keybinds/scripts"
    /// Keybind search supported: capability keybindSource + a config path exist.
    readonly property bool available: Compositor.keybindsAvailable

    property FileView configFileView: FileView {
        path: root.configPath
        // onContentChanged: root.reload()
    }

    property Process parserProcess: Process {
        running: false
        command: ["sh", "-c", `python3 '${root.scriptsDir}/expand.py' < '${root.configPath}' 2>/dev/null | python3 '${root.scriptsDir}/extract_binds.py' 2>/dev/null | python3 '${root.scriptsDir}/pretty_print_binds.py' 2>/dev/null`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (Array.isArray(parsed)) {
                        root.keybinds = parsed;
                        root.initialized = true;
                        root.loaded();
                    }
                } catch (e) {
                    console.error("Failed to parse keybinds: " + e);
                }
            }
        }
        onRunningChanged: {
            if (!running && !root.initialized) {
                root.keybinds = [];
                root.initialized = true;
                root.loaded();
            }
        }
    }

    function loadKeybinds(): void {
        if (!available)
            return;
        if (initialized && keybinds.length > 0)
            return;
        keybinds = [];
        initialized = false;
        parserProcess.running = true;
    }

    function reload(): void {
        if (!available)
            return;
        keybinds = [];
        initialized = false;
        if (!parserProcess.running)
            parserProcess.running = true;
    }

    function query(searchText): var {
        if (!searchText)
            return keybinds;

        const queryText = searchText.toLowerCase().trim();
        return keybinds.filter(k =>
            (k.key && k.key.toLowerCase().includes(queryText)) ||
            (k.action && k.action.toLowerCase().includes(queryText))
        );
    }

    function execute(item): void {
        if (!item)
            return;

        const action = (item.action || "").toLowerCase().trim();
        if (!action)
            return;

        // Map human-readable actions to neutral compositor verbs
        if (action.includes("close window") || action.includes("close-window")) {
            Compositor.closeFocusedWindow();
        } else if (action.includes("toggle floating") || action.includes("toggle-window-floating")) {
            Compositor.toggleWindowFloating();
        } else if (action.includes("toggle fullscreen") || action.includes("fullscreen")) {
            Compositor.toggleFullscreen();
        } else if (action.includes("toggle maximize") || action.includes("maximize")) {
            Compositor.toggleMaximize();
        } else if (action.includes("toggle overview") || action.includes("overview")) {
            Compositor.toggleOverview();
        } else if (action.includes("center window")) {
            Compositor.centerWindow();
        } else if (action.includes("focus column left")) {
            Compositor.focusDirection("left");
        } else if (action.includes("focus column right")) {
            Compositor.focusDirection("right");
        } else if (action.includes("focus window up")) {
            Compositor.focusDirection("up");
        } else if (action.includes("focus window down")) {
            Compositor.focusDirection("down");
        } else if (action.includes("focus workspace up")) {
            Compositor.switchToWorkspaceUpDown("up");
        } else if (action.includes("focus workspace down")) {
            Compositor.switchToWorkspaceUpDown("down");
        } else if (action.includes("move column left")) {
            Compositor.moveDirection("left");
        } else if (action.includes("move column right")) {
            Compositor.moveDirection("right");
        } else if (action.includes("move window up")) {
            Compositor.moveDirection("up");
        } else if (action.includes("move window down")) {
            Compositor.moveDirection("down");
        } else if (action.includes("spawn")) {
            // Extract the command after "spawn " if present
            const spawnMatch = action.match(/spawn\s+(.+)/);
            if (spawnMatch) {
                Quickshell.execDetached(["sh", "-c", spawnMatch[1]]);
            }
        } else {
            console.log("Keybinds: unhandled action:", item.action);
        }
    }

    Component.onCompleted: {
        if (available)
            loadKeybinds();
    }
}
