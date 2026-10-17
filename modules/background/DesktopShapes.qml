pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.dashboard.dash as Dash

// Desktop media shapes: a Material shape that breathes with the music, shown
// while something is playing. Lives in a widget frame (BigItem supplies `frame`
// and `controller`); KDE drove the auto-hide from Kwin, which has no Niri
// equivalent, so the check is inlined here.
Item {
    id: root

    property var frame: null
    property var controller: null
    property ShellScreen screen: controller?.screenData ?? null
    property Item wallpaper: controller?.wallpaper ?? null
    property real absX: (controller?.gridOrigin.x ?? 0) + (frame?.x ?? 0)
    property real absY: (controller?.gridOrigin.y ?? 0) + (frame?.y ?? 0)

    property real shapesScale: frame ? Math.min(frame.width / 220, frame.height / 220) : 1
    readonly property bool autoHide: Config.background.desktopShapes.autoHide

    // Hides while a non-floating window covers the screen, mirroring the
    // visualiser's own auto-hide (modules/background/Visualiser.qml). Both the
    // list and its entries are nullable while the compositor reconnects.
    readonly property bool windowHidesShapes: {
        const covers = out => {
            const ws = Compositor.windows?.filter(t => t.output === out);
            return ws?.some(t => !t.floating) ?? false;
        };
        if (Config.background.visualiser.hideOnAllMonitors)
            return Screens.screens.some(s => covers(s.name));
        return root.screen ? covers(root.screen.name) : false;
    }
    readonly property bool shouldHide: autoHide && windowHidesShapes
    readonly property bool isPlaying: Players.active?.isPlaying ?? false

    implicitWidth: 220 * root.shapesScale
    implicitHeight: 220 * root.shapesScale
    width: frame ? frame.width : implicitWidth
    height: frame ? frame.height : implicitHeight

    opacity: (root.isPlaying && !root.shouldHide) ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on shapesScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.StandardSmall
        }
    }

    Dash.MediaShapes {
        id: shapes

        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.92
        height: width
        visible: root.visible
    }
}
