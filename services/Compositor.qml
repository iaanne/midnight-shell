pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Internal

Singleton {
    id: root

    // --- Core ---
    readonly property string kind: CompositorIpc.kind
    readonly property string compositorName: CompositorIpc.name
    readonly property var capabilities: CompositorIpc.capabilities
    readonly property bool available: CompositorIpc.available
    readonly property string keybindConfigPath: CompositorIpc.keybindConfigPath
    /// Keybind search available: a parser source + a config file path exist.
    readonly property bool keybindsAvailable: !!capabilities.keybindSource && keybindConfigPath !== ""

    // --- Workspaces ---
    readonly property var allWorkspaces: CompositorIpc.workspaces
    readonly property int focusedWorkspaceIndex: CompositorIpc.focusedWorkspaceIndex
    readonly property string focusedWorkspaceId: CompositorIpc.focusedWorkspaceId
    readonly property string focusedMonitorName: CompositorIpc.focusedMonitorName
    readonly property var currentOutputWorkspaces: allWorkspaces.filter(w => w.output === focusedMonitorName)

    // UI context menu state
    property bool wsContextExpanded: false
    property var wsContextAnchor: null
    property string wsContextType: "none"

    property Timer wsAnchorClearTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            if (root.wsContextAnchor === null) {
                root.wsContextType = "none";
            }
        }
    }

    // State machine for moveColumnToIndexAfterFocus
    property var _moveAfterFocusPendingCb: null
    property string _moveAfterFocusPendingId: ""

    // State machine for sequential group column moves
    property var _seqState: null

    onFocusedWindowIdChanged: {
        // Handle single window move after focus
        if (_moveAfterFocusPendingCb && focusedWindowId === _moveAfterFocusPendingId) {
            var cb = _moveAfterFocusPendingCb;
            _moveAfterFocusPendingCb = null;
            _moveAfterFocusPendingId = "";
            cb();
        }

        // Handle sequential group moves
        var s = _seqState;
        if (s && focusedWindowId === s.curWindowId) {
            if (s.i >= s.windowIds.length) {
                // Done sequential moves, restore initial focus
                _seqState = null;
                root.focusWindow(s.initialWindowId);
            } else {
                // Execute next move in sequence
                var wid = s.windowIds[s.i];
                s.curWindowId = wid;
                s.i++;
                root.moveColumnToIndexAfterFocus(wid, s.targetIndex);
            }
        }
    }

    onWsContextAnchorChanged: {
        wsAnchorClearTimer.stop();
        if (wsContextAnchor === null) {
            wsAnchorClearTimer.start();
        }
    }

    // --- Windows ---
    readonly property var windows: CompositorIpc.windows
    readonly property int focusedWindowIndex: CompositorIpc.focusedWindowIndex
    readonly property string focusedWindowId: CompositorIpc.focusedWindowId
    readonly property string focusedWindowTitle: CompositorIpc.focusedWindowTitle
    readonly property string focusedWindowClass: CompositorIpc.focusedWindowClass
    readonly property var focusedWindow: CompositorIpc.focusedWindow
    readonly property var lastFocusedWindow: CompositorIpc.lastFocusedWindow
    readonly property string scrollDirection: CompositorIpc.scrollDirection
    readonly property bool inOverview: CompositorIpc.inOverview
    signal windowOpenedOrChanged(var windowData)
    signal windowClosed(string id)

    // --- Outputs ---
    // CompositorIpc.outputs is a name-keyed map (QVariantMap → JS object).
    readonly property var outputs: CompositorIpc.outputs
    readonly property var outputsByName: outputs
    function getOutput(name): var {
        return outputs?.[name] ?? null;
    }

    // --- Keyboard ---
    readonly property var kbLayoutsArray: CompositorIpc.kbLayoutsArray
    readonly property int kbLayoutIndex: CompositorIpc.kbLayoutIndex
    readonly property string kbLayouts: CompositorIpc.kbLayouts
    readonly property string defaultKbLayout: CompositorIpc.defaultKbLayout
    readonly property string kbLayout: CompositorIpc.kbLayout
    readonly property bool capsLock: CompositorIpc.capsLock
    readonly property bool numLock: CompositorIpc.numLock

    function switchKbLayout(index): bool {
        if (!available || !capabilities.switchKbLayout) return false;
        return CompositorIpc.switchKbLayout(index);
    }

    property bool _lockKeysInitialized: false
    Timer { interval: 1500; running: true; onTriggered: root._lockKeysInitialized = true }

    onCapsLockChanged: {
        if (!_lockKeysInitialized || !GlobalConfig.utilities.toasts.capsLockChanged)
            return;
        if (capsLock)
            Toaster.toast("Caps lock enabled", "Caps lock is currently enabled", "keyboard_capslock_badge");
        else
            Toaster.toast("Caps lock disabled", "Caps lock is currently disabled", "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!_lockKeysInitialized || !GlobalConfig.utilities.toasts.numLockChanged)
            return;
        if (numLock)
            Toaster.toast("Num lock enabled", "Num lock is currently enabled", "looks_one");
        else
            Toaster.toast("Num lock disabled", "Num lock is currently disabled", "timer_1");
    }

    onKbLayoutChanged: {
        if (!_lockKeysInitialized || !GlobalConfig.utilities.toasts.kbLayoutChanged)
            return;
        Toaster.toast("Keyboard layout changed", "Layout changed to: " + kbLayout, "keyboard");
    }

    // --- Signal fan-out ---
    Connections {
        target: CompositorIpc
        function onWindowOpenedOrChanged(windowData) {
            root.windowOpenedOrChanged(windowData);
        }
        function onWindowClosed(id) {
            root.windowClosed(id);
        }
    }

    Component.onCompleted: console.log("CompositorService: kind=" + kind + " backend=" + compositorName)

    // --- Workspace Functions ---
    function getWorkspaceIdxById(workspaceId) {
        return CompositorIpc.getWorkspaceIdxById(String(workspaceId));
    }

    function getWorkspaceById(workspaceId) {
        return allWorkspaces.find(w => w.id === String(workspaceId)) ?? null;
    }

    function getActiveWorkspaceName() {
        if (allWorkspaces && focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].name || "";
        }
        return "";
    }

    function getWorkspaceNameByIndex(idx) {
        if (allWorkspaces && idx >= 0 && idx < allWorkspaces.length) {
            return allWorkspaces[idx].name || "";
        }
        return "";
    }

    function getWorkspaceNameById(id) {
        const ws = getWorkspaceById(id);
        return ws?.name || "";
    }

    function getWorkspaceByIndex(index) {
        if (index >= 0 && index < allWorkspaces.length) {
            return allWorkspaces[index];
        }
        return null;
    }

    function getWorkspaceCount() {
        return allWorkspaces.length;
    }

    function getOccupiedWorkspaceCount() {
        return allWorkspaces.filter(w => w.occupied).length;
    }

    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(w => w.index);
    }

    function getCurrentWorkspaceNumber() {
        if (focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].index;
        }
        return 1;
    }

    function switchToWorkspace(workspaceId) {
        if (!available) return false;
        return CompositorIpc.focusWorkspace(String(workspaceId));
    }

    function switchToWorkspaceUpDown(direction) {
        if (!available) return false;
        return CompositorIpc.focusWorkspaceRelative(direction === "up" ? -1 : 1);
    }

    function switchToWorkspaceByIndex(index) {
        if (!available || index < 0 || index >= allWorkspaces.length) return false;
        return switchToWorkspace(allWorkspaces[index].id);
    }

    function switchToWorkspaceByNumber(number, output) {
        if (!available) return false;
        const targetOutput = output || focusedMonitorName;
        if (!targetOutput) {
            console.warn("CompositorService: No output specified for workspace switching");
            return false;
        }
        const ws = allWorkspaces.find(w => w.output === targetOutput && w.index === number);
        if (ws) {
            return switchToWorkspace(ws.id);
        }
        console.warn("CompositorService: No workspace", number, "found on output", targetOutput);
        return false;
    }

    function moveWindowToWorkspace(workspaceId) {
        if (!available) return false;
        return CompositorIpc.moveWindowToWorkspace(String(workspaceId));
    }

    // --- Window Functions ---
    function getActiveWorkspaceWindows() {
        if (!allWorkspaces || focusedWorkspaceIndex === undefined) return [];
        const currentWs = allWorkspaces[focusedWorkspaceIndex];
        if (!currentWs?.id) return [];
        return windows.filter(w => w.workspaceId === currentWs.id);
    }

    function getWindowsByWorkspaceId(wsid) {
        return windows.filter(w => w.workspaceId === String(wsid));
    }

    function getWindowsByWorkspaceIndex(index) {
        if (index < 0 || index >= allWorkspaces.length) return [];
        const wsId = allWorkspaces[index].id;
        return windows.filter(w => w.workspaceId === wsId);
    }

    function getWindowsInScreen(screenX, screenY, screenWidth, screenHeight, windowBorder, padding) {
        if (!capabilities.windowGrid || !focusedWindow?.grid) return [];

        const focusedCol = focusedWindow.grid.col;
        const focusedRow = focusedWindow.grid.row;

        return getActiveWorkspaceWindows().map(window => {
            if (!window.grid || !window.width || !window.height) return null;

            const colOffset = window.grid.col - focusedCol;
            const rowOffset = window.grid.row - focusedRow;
            const focusedWidth = focusedWindow.width;

            let focusedScreenX;
            if (focusedWidth < screenWidth - windowBorder) {
                focusedScreenX = scrollDirection === "left" ? 5 : screenWidth - focusedWidth;
            } else {
                focusedScreenX = 0;
            }

            const winX = focusedScreenX + (colOffset * window.width) - windowBorder;
            const winY = rowOffset * window.height + windowBorder;
            const winW = window.width - padding * 2;
            const winH = window.height - padding * 2;

            if (winX < screenWidth + windowBorder && winY < screenHeight && winX + winW > 0 && winY + winH > 0) {
                return { window: window, screenX: winX, screenY: winY, screenW: winW, screenH: winH };
            }
            return null;
        }).filter(item => item !== null);
    }

    function focusWindow(windowID) {
        if (!available) return false;
        return CompositorIpc.focusWindow(String(windowID));
    }

    function closeWindow(windowId) {
        if (!available) return false;
        const id = windowId ? String(windowId) : focusedWindowId;
        return CompositorIpc.closeWindow(id);
    }

    function closeFocusedWindow() {
        if (!available) return false;
        return CompositorIpc.closeWindow();
    }

    function toggleWindowFloating(windowId) {
        if (!available) return false;
        const id = windowId ? String(windowId) : focusedWindowId;
        return CompositorIpc.toggleFloating(id);
    }

    function expandColumnToAvailable() {
        if (!available) return false;
        return CompositorIpc.expandWindow();
    }

    function centerWindow() {
        if (!available) return false;
        return CompositorIpc.centerWindow();
    }

    function screenshotWindow() {
        if (!available) return false;
        return CompositorIpc.screenshotWindow();
    }

    function focusDirection(dir) {
        if (!available || !capabilities.focusDirection) return false;
        return CompositorIpc.focusDirection(dir);
    }

    function moveDirection(dir) {
        if (!available || !capabilities.moveDirection) return false;
        return CompositorIpc.moveDirection(dir);
    }

    function toggleFullscreen() {
        if (!available) return false;
        return CompositorIpc.toggleFullscreen();
    }

    function toggleMaximize() {
        if (!available) return false;
        return CompositorIpc.toggleMaximize();
    }

    function toggleOverview() {
        if (!available) return false;
        return CompositorIpc.toggleOverview();
    }

    function dispatch(command) {
        return CompositorIpc.dispatch(command);
    }

    // --- Column move helpers (niri grid ordering; capability-gated) ---
    function moveColumnToIndex(windowId, index) {
        if (!available || !capabilities.moveWindowToIndex) return false;
        if (focusWindow(windowId)) {
            return CompositorIpc.moveWindowToIndex(index);
        }
        return false;
    }

    function moveColumnToIndexAfterFocus(windowId, index) {
        if (!available || !capabilities.moveWindowToIndex) return false;

        const id = String(windowId);
        if (id === focusedWindowId) {
            return CompositorIpc.moveWindowToIndex(index);
        }

        _moveAfterFocusPendingId = id;
        _moveAfterFocusPendingCb = function() {
            CompositorIpc.moveWindowToIndex(index);
        };

        focusWindow(id);
        return true;
    }

    function moveGroupColumnsSequential(initialWindowId, windowIds, targetIndex) {
        if (!windowIds || windowIds.length === 0) return;

        _seqState = {
            initialWindowId: String(initialWindowId),
            curWindowId: String(windowIds[0]),
            windowIds: windowIds.map(w => String(w)),
            targetIndex: targetIndex,
            i: 1
        };

        moveColumnToIndexAfterFocus(windowIds[0], targetIndex);
    }

    // --- Grouping Functions ---
    function sortWindows(windowList) {
        return windowList.slice().sort((a, b) => {
            const aPos = a.grid ?? { col: 0, row: 0 };
            const bPos = b.grid ?? { col: 0, row: 0 };
            if (aPos.col !== bPos.col) return aPos.col - bPos.col;
            return aPos.row - bPos.row;
        });
    }

    function groupWindowsByApp(windowList) {
        windowList = sortWindows(windowList);
        var groups = {};

        for (var j = 0; j < windowList.length; j++) {
            var w = windowList[j];
            var appId = w.appId || "unknown";
            if (!groups[appId]) {
                groups[appId] = {
                    appId: appId,
                    id: w.id,
                    title: w.title,
                    index: w.index,
                    windows: []
                };
            }
            groups[appId].windows.push(w);
        }

        var result = [];
        for (var key in groups) {
            var g = groups[key];
            g.count = g.windows.length;
            g.main = g.windows[0];
            result.push(g);
        }
        return result;
    }

    function groupWindowsByLayoutAndId(windowList) {
        windowList = sortWindows(windowList);
        var groups = [];
        var currentGroup = null;

        for (var j = 0; j < windowList.length; j++) {
            var w = windowList[j];
            if (!currentGroup || currentGroup.appId !== w.appId) {
                currentGroup = {
                    appId: w.appId,
                    windows: [w],
                    count: 1,
                    title: w.title,
                    id: w.id,
                    main: w
                };
                groups.push(currentGroup);
            } else {
                currentGroup.windows.push(w);
                currentGroup.count++;
            }
        }
        return groups;
    }
}
