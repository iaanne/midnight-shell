pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Persistent state of the desktop icons: where each icon sits, the virtual
// groups and the view preferences. Kept out of the C++ config so that it can
// change at runtime without a plugin rebuild.
//
// Widgets are positioned on their own free layer, not on the icon grid: each
// widget carries fractional cell geometry ({x, y, w, h}) plus a per-instance
// scale and stacking order. The icon grid only ever holds files and groups, so
// moving a widget can never displace an icon and vice versa. See
// `widgetPlacement` for how much the free coordinates snap.
Singleton {
    id: root

    readonly property string layoutPath: `${Paths.data}/desktop_layout.json`
    readonly property var iconSizes: [48, 64, 80, 96]
    readonly property var snapSteps: [0.25, 0.5, 1]
    readonly property var placementModes: ["grid", "snap", "free"]

    property bool loaded: false
    // Item key ("f/<file name>" or "g/<group id>") -> { col, row }.
    property var positions: ({})
    // Group id -> { name, members: [file name, ...], size: { w, h } }. A size
    // above 1x1 shows the group as a large folder.
    property var groups: ({})
    // Widget id -> { type, variant, x, y, w, h, scale, z, overlap, config }.
    // Geometry is in fractional grid cells so it survives icon-size and
    // resolution changes; x/y are the top-left corner.
    property var widgets: ({})
    property int iconSize: 64
    property bool autoArrange: false
    // Clip full-colour icons to a rounded square.
    property bool roundIcons: true
    // "" keeps the manual order; otherwise name, type, modified or size.
    property string sortKey: ""

    // ── Widget placement ───────────────────────────────────────────────────
    // How much a widget's free coordinates snap. "grid" rounds to whole cells,
    // "snap" to `snapStep`, "free" leaves them continuous.
    property string widgetPlacement: "snap"
    // Snap step in cells, used by "snap" and "grid".
    property real snapStep: 0.5
    // Whether the same step applies while dragging the resize grip.
    property bool snapResize: true
    // Whether widgets may sit on top of icons and each other. With it off a
    // widget snaps to whole cells and is kept clear of the icons.
    property bool allowOverlap: true
    // Global multiplier applied on top of every widget's own scale.
    property real widgetsScale: 1.0

    property bool defaultsSeeded: false
    property bool defaultsNeeded: false
    // Which legacy fixed-position desktop elements to reproduce as widgets the
    // first time the layout is created. Each value is the retired position
    // ("bottom-right", ...) or "" to skip it. ConfigMigrations fills this from
    // the desktopClock/desktopLyrics flags before seedDefaults runs, so an
    // upgrading user keeps what they had and a fresh user gets nothing (both
    // elements used to default to disabled).
    property var seedSpec: ({ clock: "", lyrics: "" })

    // Single click opens files; set from the Desktop Nexus page (Phase 7).
    // KDE read this from kdeglobals; there is no equivalent here.
    property bool singleClick: false
    // Whether the clipboard holds files, checked when the desktop menu opens.
    property bool clipboardHasFiles: false
    // Screen name -> DesktopIcons controller instance
    property var controllers: ({})

    signal pasteRequested(string screenName, real x, real y)
    signal viewOptionsRequested(string screenName, real x, real y)
    signal addWidgetRequested(string screenName, real x, real y)
    signal arrangeRequested(string screenName, string sortKey)
    signal openIconContextMenu(string screenName, real x, real y, var keys, string inGroup)
    signal openDropMenu(string screenName, real x, real y, var urls, string target, var cell)

    function registerController(screenName: string, controller: var): void {
        const next = Object.assign({}, controllers);
        next[screenName] = controller;
        controllers = next;
    }

    function unregisterController(screenName: string): void {
        const next = Object.assign({}, controllers);
        delete next[screenName];
        controllers = next;
    }

    function controllerFor(screenName: string): var {
        return controllers[screenName] ?? null;
    }

    function fileKey(name: string): string {
        return "f/" + name;
    }

    function groupKey(id: string): string {
        return "g/" + id;
    }

    function widgetKey(id: string): string {
        return "w/" + id;
    }

    function setWidgets(next: var): void {
        widgets = next;
        scheduleSave();
    }

    function setWidgetConfig(id: string, patch: var): void {
        const w = widgets[id];
        if (!w)
            return;
        const next = Object.assign({}, widgets);
        next[id] = Object.assign({}, w, { config: Object.assign({}, w.config, patch) });
        setWidgets(next);
    }

    // Geometry patch keys: x, y, w, h (fractional cells).
    function setWidgetGeometry(id: string, patch: var): void {
        const w = widgets[id];
        if (!w)
            return;
        const next = Object.assign({}, widgets);
        next[id] = Object.assign({}, w, patch);
        setWidgets(next);
    }

    function setWidgetVariant(id: string, variant: string): void {
        setWidgetGeometry(id, { variant });
    }

    function setWidgetScale(id: string, scale: real): void {
        setWidgetGeometry(id, { scale: Math.max(0.25, Math.min(4, scale)) });
    }

    // Stacking order among widgets; higher sits on top. +1 keeps it above any
    // z currently in use, which is fine as they are only ever re-stacked.
    function bringToFront(id: string): void {
        const w = widgets[id];
        if (!w)
            return;
        let top = 0;
        for (const k in widgets)
            top = Math.max(top, widgets[k].z ?? 0);
        if ((w.z ?? 0) >= top)
            return;
        setWidgetGeometry(id, { z: top + 1 });
    }

    function setWidgetOverlap(id: string, mode: string): void {
        setWidgetGeometry(id, { overlap: mode });
    }

    function removeWidget(id: string): void {
        if (!widgets[id])
            return;
        const next = Object.assign({}, widgets);
        delete next[id];
        setWidgets(next);
    }

    // Quantise every widget's geometry to the current placement step. Handy
    // after switching modes, or for tidying a desktop that was dragged freely.
    function snapWidgets(): void {
        if (widgetPlacement === "free")
            return;
        const step = widgetPlacement === "grid" ? 1 : snapStep;
        const next = {};
        for (const id in widgets) {
            const w = widgets[id];
            next[id] = Object.assign({}, w, {
                x: Math.round(w.x / step) * step,
                y: Math.round(w.y / step) * step,
                w: Math.max(step, Math.round(w.w / step) * step),
                h: Math.max(step, Math.round(w.h / step) * step)
            });
        }
        setWidgets(next);
    }

    function setWidgetPlacement(mode: string): void {
        if (placementModes.indexOf(mode) === -1 || mode === widgetPlacement)
            return;
        widgetPlacement = mode;
        scheduleSave();
    }

    function setSnapStep(step: real): void {
        if (snapSteps.indexOf(step) === -1 || step === snapStep)
            return;
        snapStep = step;
        scheduleSave();
    }

    function setSnapResize(on: bool): void {
        if (snapResize === on)
            return;
        snapResize = on;
        scheduleSave();
    }

    function setAllowOverlap(on: bool): void {
        if (allowOverlap === on)
            return;
        allowOverlap = on;
        scheduleSave();
    }

    function setWidgetsScale(scale: real): void {
        const clamped = Math.max(0.5, Math.min(2, scale));
        if (clamped === widgetsScale)
            return;
        widgetsScale = clamped;
        scheduleSave();
    }

    function setPositions(next: var): void {
        positions = next;
        scheduleSave();
    }

    function setGroups(next: var): void {
        groups = next;
        scheduleSave();
    }

    function setIconSize(size: int): void {
        if (iconSizes.indexOf(size) === -1 || size === iconSize)
            return;
        iconSize = size;
        scheduleSave();
    }

    function stepIconSize(delta: int): void {
        const idx = Math.max(0, iconSizes.indexOf(iconSize));
        setIconSize(iconSizes[Math.max(0, Math.min(iconSizes.length - 1, idx + delta))]);
    }

    function setAutoArrange(on: bool): void {
        if (autoArrange === on)
            return;
        autoArrange = on;
        scheduleSave();
    }

    function setRoundIcons(on: bool): void {
        if (roundIcons === on)
            return;
        roundIcons = on;
        scheduleSave();
    }

    function setSortKey(key: string): void {
        if (sortKey === key)
            return;
        sortKey = key;
        scheduleSave();
    }

    function newGroupId(): string {
        let id;
        do
            id = Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
        while (id in groups || id in widgets);
        return id;
    }

    function refreshClipboard(): void {
        clipboardProc.running = true;
    }

    function scheduleSave(): void {
        if (loaded)
            saveTimer.restart();
    }

    function parseLayout(text: string): void {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            data = null;
        }
        const nextPositions = {};
        const nextGroups = {};
        const nextWidgets = {};
        const size = v => v && v.w >= 1 && v.h >= 1 ? { w: v.w | 0, h: v.h | 0 } : { w: 1, h: 1 };
        const num = (v, d) => typeof v === "number" && isFinite(v) ? v : d;
        if (Array.isArray(data)) {
            // Version 1: a bare list of { name, col, row }.
            for (const it of data)
                if (it && typeof it.name === "string")
                    nextPositions[fileKey(it.name)] = { col: it.col | 0, row: it.row | 0 };
        } else if (data && typeof data === "object") {
            // Items are icons and groups only; widget keys ("w/…") from older
            // layouts are folded into the widget records below.
            const legacyCells = {};
            for (const it of data.items ?? []) {
                if (!it || typeof it.key !== "string")
                    continue;
                if (it.key.startsWith("w/"))
                    legacyCells[it.key.substring(2)] = { col: it.col | 0, row: it.row | 0 };
                else
                    nextPositions[it.key] = { col: it.col | 0, row: it.row | 0 };
            }
            for (const g of data.groups ?? [])
                if (g && typeof g.id === "string" && Array.isArray(g.members))
                    nextGroups[g.id] = { name: String(g.name ?? ""), members: g.members.filter(m => typeof m === "string"), size: size(g.size) };
            for (const w of data.widgets ?? []) {
                if (!w || typeof w.id !== "string" || typeof w.type !== "string")
                    continue;
                const legacy = legacyCells[w.id];
                nextWidgets[w.id] = {
                    type: w.type,
                    variant: typeof w.variant === "string" ? w.variant : "",
                    x: num(w.x, legacy ? legacy.col : 0),
                    y: num(w.y, legacy ? legacy.row : 0),
                    w: num(w.w, w.size ? size(w.size).w : 1),
                    h: num(w.h, w.size ? size(w.size).h : 1),
                    scale: num(w.scale, 1),
                    z: num(w.z, 0),
                    overlap: typeof w.overlap === "string" ? w.overlap : "inherit",
                    config: w.config && typeof w.config === "object" ? w.config : {}
                };
            }
            const prefs = data.prefs ?? {};
            if (iconSizes.indexOf(prefs.iconSize) !== -1)
                iconSize = prefs.iconSize;
            autoArrange = prefs.autoArrange === true;
            roundIcons = prefs.roundIcons !== false;
            sortKey = typeof prefs.sortKey === "string" ? prefs.sortKey : "";
            if (placementModes.indexOf(prefs.widgetPlacement) !== -1)
                widgetPlacement = prefs.widgetPlacement;
            if (snapSteps.indexOf(prefs.snapStep) !== -1)
                snapStep = prefs.snapStep;
            snapResize = prefs.snapResize !== false;
            allowOverlap = prefs.allowOverlap !== false;
            widgetsScale = num(prefs.widgetsScale, 1.0);
            defaultsSeeded = prefs.defaultsSeeded === true;
        }
        if (data === null || (!defaultsSeeded && Object.keys(nextWidgets).length === 0))
            defaultsNeeded = true;
        positions = nextPositions;
        groups = nextGroups;
        widgets = nextWidgets;
        loaded = true;
    }

    // Maps a retired "top-center"-style position onto a grid cell, clamped so
    // the whole widget fits on the grid.
    function positionToCell(position: string, cols: int, rows: int, w: int, h: int): var {
        const parts = position.split("-");
        const vert = parts[0];
        const horiz = parts[1] ?? "center";
        const col = horiz === "left" ? 0 : horiz === "right" ? cols - w : Math.floor((cols - w) / 2);
        const row = vert === "top" ? 0 : vert === "bottom" ? rows - h : Math.floor((rows - h) / 2);
        return {
            col: Math.max(0, Math.min(cols - w, col)),
            row: Math.max(0, Math.min(rows - h, row))
        };
    }

    function seedDefaults(cols: int, rows: int): void {
        if (!defaultsNeeded || cols <= 0 || rows <= 0)
            return;
        defaultsNeeded = false;
        defaultsSeeded = true;

        const nextWidgets = Object.assign({}, widgets);

        // Retired fixed-position elements become widgets at the cell matching
        // the position the user had. "" means it was disabled, so skip it.
        const place = (type, position, w, h) => {
            if (!position)
                return;
            const id = newGroupId();
            const cell = positionToCell(position, cols, rows, w, h);
            nextWidgets[id] = { type, variant: "", x: cell.col, y: cell.row, w, h, scale: 1, z: Object.keys(nextWidgets).length, overlap: "inherit", config: {} };
        };
        place("lyrics", seedSpec.lyrics, 3, 2);
        place("desktopClock", seedSpec.clock, 2, 2);

        widgets = nextWidgets;
        scheduleSave();
    }

    function serialise(): string {
        const items = [];
        for (const key in positions)
            items.push({ key, col: positions[key].col, row: positions[key].row });
        const groupList = [];
        for (const id in groups)
            groupList.push({ id, name: groups[id].name, members: groups[id].members, size: groups[id].size ?? { w: 1, h: 1 } });
        const widgetList = [];
        for (const id in widgets)
            widgetList.push({
                id,
                type: widgets[id].type,
                variant: widgets[id].variant ?? "",
                x: widgets[id].x,
                y: widgets[id].y,
                w: widgets[id].w,
                h: widgets[id].h,
                scale: widgets[id].scale ?? 1,
                z: widgets[id].z ?? 0,
                overlap: widgets[id].overlap ?? "inherit",
                config: widgets[id].config
            });
        return JSON.stringify({
            version: 3,
            prefs: {
                iconSize,
                autoArrange,
                sortKey,
                roundIcons,
                widgetPlacement,
                snapStep,
                snapResize,
                allowOverlap,
                widgetsScale,
                defaultsSeeded
            },
            items,
            groups: groupList,
            widgets: widgetList
        });
    }

    Process {
        id: clipboardProc

        command: ["wl-paste", "--list-types"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboardHasFiles = text.split("\n").some(t => t.trim() === "text/uri-list")
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.clipboardHasFiles = false;
        }
    }

    Timer {
        id: saveTimer

        interval: 400
        onTriggered: layoutFile.setText(root.serialise())
    }

    FileView {
        id: layoutFile

        path: root.layoutPath
        printErrors: false
        onLoaded: root.parseLayout(text())
        onLoadFailed: root.parseLayout("")
    }
}
