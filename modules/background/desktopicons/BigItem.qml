pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

// A desktop item bigger than one cell: a large folder or a widget. Draws the
// card, takes selection, dragging, the context menu and resizing, and loads
// the actual content on top.
//
// A large folder sits on the icon grid and is moved by dragging its body. A
// widget sits on the free layer: its geometry (fractional cells) comes from its
// own record, it carries a per-instance scale, and it is moved and resized by
// the handles in its corners so the controls inside it keep their own clicks.
Item {
    id: root

    required property var controller
    required property string key

    readonly property bool isGroup: controller.isGroupKey(key)
    readonly property string itemId: controller.nameOf(key)
    readonly property var widget: isGroup ? null : (DesktopLayout.widgets[itemId] ?? null)
    readonly property var config: widget?.config ?? ({})
    // For a widget this is the type with its chosen variant merged in, so
    // `source`, `min`, `max` and `frameless` all follow the variant.
    readonly property var info: isGroup ? controller.widgetCatalog.info("group") : controller.widgetCatalog.variantInfo(widget?.type ?? "", widget?.variant ?? "")
    readonly property var span: controller.displaySpans[key] ?? info.size
    readonly property bool frameless: !isGroup && (info.frameless === true || config.frameless === true)
    readonly property var pos: controller.displayPositions[key] ?? DesktopLayout.positions[key] ?? null

    // Natural geometry in pixels, before the live drag/resize offsets.
    readonly property real naturalW: (isGroup ? span.w : (widget?.w ?? 1)) * controller.cellWidth
    readonly property real naturalH: (isGroup ? span.h : (widget?.h ?? 1)) * controller.cellHeight
    readonly property real naturalX: (isGroup ? (pos?.col ?? 0) : (widget?.x ?? 0)) * controller.cellWidth
    readonly property real naturalY: (isGroup ? (pos?.row ?? 0) : (widget?.y ?? 0)) * controller.cellHeight

    // Live offsets while a handle is held; committed to the model on release.
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real resizeOffsetW: 0
    property real resizeOffsetH: 0

    readonly property real widgetScale: isGroup ? 1 : (widget?.scale ?? 1) * DesktopLayout.widgetsScale

    property bool selected: false
    property bool focusVisible: false
    property bool dimmed: false
    property bool mergeTarget: false
    property real appear: 0
    readonly property bool hovered: hover.hovered
    readonly property bool resizing: grip.pressed
    readonly property bool moving: moveHandle.pressed
    readonly property alias content: loader.item
    // Every large item carries its name under the card, like an icon label.
    // The label sits in the gap to the next row, so that gap is kept only a little
    // wider than the one between columns; otherwise rows look much further apart.
    readonly property real sideGap: Tokens.padding.extraLarge / 2
    readonly property real topGap: Tokens.padding.small
    readonly property real labelHeight: Tokens.padding.extraLargeIncreased
    readonly property string label: {
        if (isGroup)
            return DesktopLayout.groups[itemId]?.name ?? "";
        const path = widget?.type === "folder" ? (config.path ?? "").replace(/\/+$/, "") : "";
        return path !== "" ? path.substring(path.lastIndexOf("/") + 1) : info.name;
    }

    signal pressed(var mouse)
    signal clicked(var mouse)
    signal doubleClicked(var mouse)
    signal contextMenuRequested(real x, real y)
    signal dragRequested(real x, real y)

    function setConfig(patch: var): void {
        if (!isGroup)
            DesktopLayout.setWidgetConfig(itemId, patch);
    }

    // Renaming only applies to large folders, through their label.
    function startRename(text: string, selectUntil: int): void {
        if (isGroup)
            title.startRename(text);
    }

    function commitRename(): void {
        title.commitRename();
    }

    function cancelRename(): void {
        title.cancelRename();
    }

    function overIcon(x: real, y: real): bool {
        return true;
    }

    x: naturalX + dragOffsetX
    y: naturalY + dragOffsetY
    width: naturalW + resizeOffsetW
    height: naturalH + resizeOffsetH
    opacity: (dimmed ? 0.4 : 1) * appear
    scale: (0.9 + 0.1 * appear) * (mergeTarget ? 1.02 : 1) * widgetScale
    Component.onCompleted: appear = 1

    Behavior on appear {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on x {
        enabled: !root.moving

        Anim {}
    }

    Behavior on y {
        enabled: !root.moving

        Anim {}
    }

    Behavior on width {
        enabled: !root.resizing

        Anim {}
    }

    Behavior on height {
        enabled: !root.resizing

        Anim {}
    }

    HoverHandler {
        id: hover
    }

    // Frosted glass: the wallpaper behind the card, blurred and clipped to it.
    Loader {
        anchors.fill: card
        active: !root.frameless && !!root.controller.wallpaper && !GameMode.enabled
        asynchronous: true

        sourceComponent: MultiEffect {
            source: ShaderEffectSource {
                sourceItem: root.controller.wallpaper
                sourceRect: Qt.rect(root.controller.gridOrigin.x + root.x + card.x, root.controller.gridOrigin.y + root.y + card.y, card.width, card.height)
            }
            maskSource: cardMask
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 48
            autoPaddingEnabled: false
        }
    }

    StyledRect {
        id: cardMask

        anchors.fill: card
        radius: card.radius
        visible: false
        layer.enabled: true
    }

    StyledRect {
        id: card

        anchors.fill: parent
        anchors.leftMargin: root.frameless ? 0 : root.sideGap
        anchors.rightMargin: root.frameless ? 0 : root.sideGap
        anchors.topMargin: root.frameless ? 0 : root.topGap
        anchors.bottomMargin: root.frameless ? 0 : root.labelHeight
        radius: root.frameless ? Tokens.rounding.medium : Tokens.rounding.extraLarge
        color: root.frameless ? "transparent" : (GlobalConfig.appearance.pitchBlack ? Qt.alpha("#000000", 0.7) : Qt.alpha(Colours.palette.m3surfaceContainer, 0.4))
        border.width: root.selected || root.mergeTarget || root.focusVisible ? 2 : (root.frameless ? 0 : 1)
        border.color: root.selected || root.mergeTarget || root.focusVisible ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.12)

        // Background of the card: selects, opens, drags and resizes the item.
        // Controls inside the content take their own clicks first.
        MouseArea {
            id: bgArea

            property point pressPos
            property bool dragSent: false

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                pressPos = Qt.point(mouse.x, mouse.y);
                dragSent = false;
                root.pressed({
                    x: mouse.x + card.x,
                    y: mouse.y + card.y,
                    button: mouse.button,
                    modifiers: mouse.modifiers
                });
            }
            onPositionChanged: mouse => {
                // A widget moves by its handles; only folders drag by the body.
                if (root.isGroup === false || !(pressedButtons & Qt.LeftButton) || dragSent)
                    return;
                const dx = mouse.x - pressPos.x;
                const dy = mouse.y - pressPos.y;
                if (dx * dx + dy * dy >= Qt.styleHints.startDragDistance * Qt.styleHints.startDragDistance) {
                    dragSent = true;
                    root.dragRequested(pressPos.x + card.x, pressPos.y + card.y);
                }
            }
            onClicked: mouse => {
                if (dragSent)
                    return;
                if (mouse.button === Qt.RightButton)
                    root.contextMenuRequested(mouse.x + card.x, mouse.y + card.y);
                else
                    root.clicked(mouse);
            }
            onDoubleClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    root.doubleClicked(mouse);
            }
        }

        Loader {
            id: loader

            readonly property string wanted: root.info.source

            function load(): void {
                if (wanted !== "")
                    setSource(Qt.resolvedUrl(wanted), {
                        frame: root,
                        controller: root.controller
                    });
                else
                    source = "";
            }

            anchors.fill: parent
            anchors.margins: root.frameless ? 0 : (root.isGroup ? Tokens.padding.small : Tokens.padding.large)
            asynchronous: true

            onWantedChanged: load()
            Component.onCompleted: load()
        }
    }

    // Centred in the gap down to the next row's card (its top gap included), so
    // names in different scripts line up.
    StyledRect {
        visible: !root.frameless
        anchors.horizontalCenter: card.horizontalCenter
        anchors.verticalCenter: card.bottom
        anchors.verticalCenterOffset: (root.labelHeight + root.topGap) / 2 - 1
        width: title.width + Tokens.padding.medium * 2
        height: title.height + Tokens.padding.small
        radius: Tokens.rounding.small
        color: root.selected && !title.renaming ? Qt.alpha(Colours.palette.m3primary, 0.24) : "transparent"

        GroupTitle {
            id: title

            anchors.centerIn: parent
            width: Math.min(implicitWidth, card.width)
            desktopStyle: true
            text: root.label
            onRenameRequested: root.controller.startRename(root.key)
            onRenameCommitted: text => {
                root.controller.finishRename(root);
                root.controller.renameGroup(root.itemId, text);
            }
            onRenameCancelled: root.controller.finishRename(root)
        }
    }

    // Move handle (widgets only): drag the corner to move the widget freely.
    MouseArea {
        id: moveHandle

        property point origin
        property real startX
        property real startY

        anchors.left: card.left
        anchors.top: card.top
        z: 2
        width: Tokens.padding.large * 2
        height: width
        hoverEnabled: true
        cursorShape: Qt.SizeAllCursor
        visible: !root.isGroup && opacity > 0
        opacity: root.hovered || root.selected || pressed ? 1 : 0
        preventStealing: true
        onPressed: mouse => {
            origin = mapToItem(root.controller, mouse.x, mouse.y);
            startX = root.naturalX;
            startY = root.naturalY;
            const p = mapToItem(root, mouse.x, mouse.y);
            root.pressed({
                x: p.x,
                y: p.y,
                button: Qt.LeftButton,
                modifiers: Qt.NoModifier
            });
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(root.controller, mouse.x, mouse.y);
            root.dragOffsetX = p.x - origin.x;
            root.dragOffsetY = p.y - origin.y;
        }
        onReleased: {
            root.controller.commitWidgetMove(root.key, root.naturalX + root.dragOffsetX, root.naturalY + root.dragOffsetY);
            root.dragOffsetX = 0;
            root.dragOffsetY = 0;
        }
        onCanceled: {
            root.dragOffsetX = 0;
            root.dragOffsetY = 0;
        }

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "drag_indicator"
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // Drag the corner to resize. Folders resize in whole cells; widgets follow
    // the placement snap and their own min/max.
    MouseArea {
        id: grip

        property point origin
        property var startSpan
        property real startW
        property real startH

        anchors.right: card.right
        anchors.bottom: card.bottom
        z: 2
        width: Tokens.padding.large * 2
        height: width
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor
        visible: opacity > 0
        opacity: root.hovered || root.selected || pressed ? 1 : 0
        preventStealing: true
        onPressed: mouse => {
            origin = mapToItem(root.controller, mouse.x, mouse.y);
            startSpan = root.span;
            startW = root.naturalW;
            startH = root.naturalH;
            const p = mapToItem(root, mouse.x, mouse.y);
            root.pressed({
                x: p.x,
                y: p.y,
                button: Qt.LeftButton,
                modifiers: Qt.NoModifier
            });
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(root.controller, mouse.x, mouse.y);
            if (root.isGroup) {
                const w = Math.max(root.info.min.w, Math.min(root.info.max.w, Math.round(startSpan.w + (p.x - origin.x) / root.controller.cellWidth)));
                const h = Math.max(root.info.min.h, Math.min(root.info.max.h, Math.round(startSpan.h + (p.y - origin.y) / root.controller.cellHeight)));
                root.controller.previewResize(root.key, w, h);
            } else {
                const minW = (root.info.min?.w ?? 1) * root.controller.cellWidth;
                const minH = (root.info.min?.h ?? 1) * root.controller.cellHeight;
                const maxW = (root.info.max?.w ?? 8) * root.controller.cellWidth;
                const maxH = (root.info.max?.h ?? 8) * root.controller.cellHeight;
                root.resizeOffsetW = Math.max(minW, Math.min(maxW, startW + (p.x - origin.x))) - startW;
                root.resizeOffsetH = Math.max(minH, Math.min(maxH, startH + (p.y - origin.y))) - startH;
            }
        }
        onReleased: {
            if (root.isGroup) {
                const s = root.controller.displaySpans[root.key] ?? startSpan;
                root.controller.resizeItem(root.key, s.w, s.h);
            } else {
                root.controller.commitWidgetResize(root.key, root.naturalW + root.resizeOffsetW, root.naturalH + root.resizeOffsetH);
                root.resizeOffsetW = 0;
                root.resizeOffsetH = 0;
            }
        }
        onCanceled: {
            if (root.isGroup)
                root.controller.endResizePreview();
            else {
                root.resizeOffsetW = 0;
                root.resizeOffsetH = 0;
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "drag_handle"
            rotation: -45
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
