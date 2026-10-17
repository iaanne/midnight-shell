pragma Singleton

import QtQuick
import Caelestia.I18n

QtObject {
    id: root

    // `key` names a page for code that has to open one (the desktop context
    // menu, bar popouts); `indexForKey` resolves it, so entries can be added
    // or reordered without chasing numeric indices.
    readonly property list<var> pages: [
        // Appearance
        {
            key: "wallpaper-style",
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance"
        },
        {
            key: "background",
            label: qsTr("Background elements"),
            icon: "wallpaper",
            description: qsTr("Clock, lyrics, visualiser, shimeji"),
            category: "appearance"
        },
        {
            key: "desktop",
            label: qsTr("Desktop"),
            icon: "desktop_windows",
            description: qsTr("Icons, widgets, arrangement"),
            category: "appearance"
        },
        {
            key: "tokens",
            label: qsTr("Shell Tokens"),
            icon: "tune",
            description: qsTr("Modify interface spacing, rounding, and sizing"),
            category: "appearance",
            developerOnly: true
        },

        // Connectivity
        // TODO
        // {
        //     label: Tr.tr("Display"),
        //     icon: "monitor",
        //     description: Tr.tr("Output configuration"),
        //     category: "connectivity"
        // },
        {
            key: "network",
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity"
        },
        {
            key: "devices",
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },
        {
            key: "audio",
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity"
        },

        // System
        {
            key: "updates",
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            category: "system"
        },
        {
            key: "plugins",
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Manage plugins"),
            category: "system"
        },

        // Shell
        {
            key: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            key: "apps",
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            key: "compositor",
            label: Tr.tr("Compositor"),
            icon: "layers",
            description: Tr.tr("Detected compositor and capabilities"),
            category: "shell"
        },
        {
            key: "services",
            label: qsTr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics backend"),
            category: "shell"
        },
        {
            key: "language-region",
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell"
        },

        // About
        {
            key: "about",
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about"
        },
    ]

    // Index of the page with this key, or the first page for an unknown one so
    // callers always land somewhere valid.
    function indexForKey(key: string): int {
        for (let i = 0; i < pages.length; i++) {
            if (pages[i].key === key)
                return i;
        }
        return 0;
    }
}
