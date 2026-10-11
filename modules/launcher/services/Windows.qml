pragma Singleton

import QtQuick
import Caelestia.Config
import qs.services

QtObject {
    id: root

    property var items: []

    function reload(): void {
        updateItems();
    }

    function updateItems(): void {
        const windows = [];
        for (const win of Compositor.windows) {
            windows.push({
                id: win.id,
                title: win.title || "",
                class: win.appId || "",
                workspace_id: win.workspaceId ?? "",
                monitor: win.output || "",
                is_focused: win.focused ?? false,
                is_fullscreen: win.fullscreen ?? false,
                is_maximized: win.maximized ?? false,
                is_floating: win.floating ?? false,
                // Stub fields for compatibility
                wayland: null,
                size: [0, 0],
                at: [0, 0],
                mapped: true,
                hidden: false,
                lastIpcObject: {
                    app_id: win.appId,
                    class: win.appId,
                    at: [0, 0],
                    size: [0, 0],
                    mapped: true,
                    hidden: false,
                    floating: win.floating ?? false,
                    pinned: false,
                    xwayland: false,
                    pid: win.pid ?? 0,
                    fullscreen: win.fullscreen ? 1 : 0
                }
            });
        }
        items = windows;
    }

    function query(search: string): var {
        let results = items;
        if (GlobalConfig.launcher.windowSwitcherActiveWorkspaceOnly) {
            const activeWs = Compositor.focusedWorkspaceId;
            if (activeWs) {
                results = results.filter(w => w.workspace_id === activeWs);
            }
        }

        if (!search)
            return results;
        const lower = search.toLowerCase();
        return results.filter(w => w.title.toLowerCase().includes(lower) || w.class.toLowerCase().includes(lower));
    }

    function focusWindow(id: string): void {
        Compositor.focusWindow(id);
    }

    Component.onCompleted: {
        updateItems();
        Compositor.windowOpenedOrChanged.connect(() => updateItems());
        Compositor.windowClosed.connect(() => updateItems());
    }
}
