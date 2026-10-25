pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

// One-shot config migrations that must run before the desktop is laid out.
//
// The retired fixed-position desktop elements (desktopClock, desktopLyrics)
// are now desktop widgets. DesktopLayout.seedDefaults() is what actually places
// widgets the first time a layout file is created; this service tells it which
// of the retired elements to reproduce and where, so an upgrading user's
// desktop looks the same and a fresh user gets nothing (both elements used to
// default to disabled).
//
// Lyrics in "overlay" mode are deliberately not seeded: that mode keeps drawing
// them in the separate overlay window (DesktopLyricsOverlay), so seeding a
// desktop widget as well would show every line twice.
//
// The retired keys themselves are deliberately left in place for one release:
// the Nexus background pages still read them, and resetting them here would
// throw the values away before the cleanup that removes the keys. They are
// dropped, and resetOption() calls added, in the post-port cleanup.
Singleton {
    id: root

    // Reads the retired flags and hands the positions to DesktopLayout.
    function seedDesktopElements(): void {
        const bg = GlobalConfig.background;
        DesktopLayout.seedSpec = {
            lyrics: (bg.desktopLyrics.enabled && !bg.desktopLyrics.overlay) ? bg.desktopLyrics.position : "",
            clock: bg.desktopClock.enabled ? bg.desktopClock.position : ""
        };
    }

    // Built-in quick toggles added after the list was introduced. Insert any
    // missing entries in their intended order so existing configs pick them up
    // without needing a rebuilt config plugin.
    function ensureQuickToggle(id: string, beforeIds: list<string>): void {
        const list = GlobalConfig.utilities.quickToggles;
        if (list.values.some(item => item.id === id))
            return;

        let index = list.count;
        for (const beforeId of beforeIds) {
            const beforeIndex = list.values.findIndex(item => item.id === beforeId);
            if (beforeIndex >= 0) {
                index = beforeIndex;
                break;
            }
        }

        list.insert({
            id,
            enabled: true
        }, index);
    }

    // The bundled font's family is `Caelestia Sans` (its PostScript name is
    // `CaelestiaSans-Regular`). Older configs pinned the PostScript name or the
    // pre-rename `GoogleSansFlex`, neither of which resolves as a family, so the
    // shell rendered a substitute. Clear those pins so the corrected default
    // applies; resetOption() is a no-op when the value was never pinned.
    function migrateFontFamilies(): void {
        const legacy = ["GoogleSansFlex", "CaelestiaSans"];
        const font = GlobalConfig.appearance.font;

        for (const style of [font.headline, font.title, font.body, font.label]) {
            if (legacy.includes(style.family))
                style.resetOption("family");

            for (const size of [style.large, style.medium, style.small]) {
                if (legacy.includes(size.family))
                    size.resetOption("family");
            }
        }

        // Standalone family strings on the same node (an empty value inherits
        // the body font).
        if (legacy.includes(font.clock))
            font.resetOption("clock");
        if (legacy.includes(font.workspaces))
            font.resetOption("workspaces");
        if (legacy.includes(font.barClock))
            font.resetOption("barClock");
        if (legacy.includes(font.activeWindow))
            font.resetOption("activeWindow");
    }

    Component.onCompleted: {
        root.migrateFontFamilies();
        root.seedDesktopElements();
        root.ensureQuickToggle("speaker", ["mic"]);
        root.ensureQuickToggle("visualizer", ["badapple"]);
        root.ensureQuickToggle("desktopLyrics", ["badapple"]);
    }
}
