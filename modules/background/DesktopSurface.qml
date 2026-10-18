pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components.containers
import qs.services

// The interactive desktop: file icons, large folders and free-placed widgets.
//
// It deliberately gets a surface of its own, separate from the wallpaper in
// Background.qml, and it sits on the Bottom layer. Compositors render the
// stationary desktop wallpaper through a "backdrop" placement (Niri's
// `place-within-backdrop` layer rule), and backdrop surfaces are input
// transparent by design — so a surface that has to be hovered, clicked and
// dragged must not share one with the wallpaper. Bottom is immune to backdrop
// placement (it only applies to background-layer surfaces) while still drawing
// above the wallpaper surface. iNiR and end-4's shells split them the same way.
Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        // Keyboard focus follows the inline rename editor. Exclusive while it is
        // open; OnDemand otherwise so a click lands on the desktop as it would
        // on any other surface. Niri does not hand an *unfocused* layer surface
        // the exclusive grab, so the first click only focuses the surface — which
        // is harmless here because every rename is already started by interacting
        // with it (context menu, F2, or a click on the tile).
        //
        // Niri can also focus a *freshly mapped* OnDemand layer surface, which
        // would steal the keyboard from whichever app had it when the shell
        // starts or restarts. So the surface maps keyboard-inert and arms
        // OnDemand only once it has settled (same workaround as iNiR).
        property bool keyboardFocusArmed: false

        screen: modelData
        name: "desktop"
        isDesktopWidget: true
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: desktopIcons.renameActive ? WlrKeyboardFocus.Exclusive : (keyboardFocusArmed && desktopIcons.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

        color: "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Timer {
            interval: 500
            running: true
            repeat: false

            onTriggered: win.keyboardFocusArmed = true
        }

        // Empty-desktop interaction. A full-window item below the icons, so the
        // icon and widget handlers (which sit on children and are therefore hit
        // first) win whenever they are hit.
        Item {
            id: emptyDesktop

            anchors.fill: parent

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onTapped: (eventPoint, button) => {
                    // A click anywhere cancels an in-flight rename first.
                    if (desktopIcons.renameActive)
                        desktopIcons.renamingDelegate?.commitRename();
                    // Only the empty desktop reacts: a hit on an icon or widget is
                    // that item's own. The wallpaper gate matches DesktopIcons'
                    // own visibility, which is also off without a wallpaper.
                    const onEmptyDesktop = Config.background.wallpaperEnabled && !desktopIcons.iconAt(eventPoint.position.x, eventPoint.position.y);
                    if (button === Qt.RightButton && onEmptyDesktop)
                        ContextMenuStore.openDesktopContextMenu(eventPoint.position.x, eventPoint.position.y, win.modelData.name);
                    else if (button === Qt.MiddleButton && onEmptyDesktop)
                        ContextMenuStore.toggleIcons(win.modelData.name);
                    // A left click on the empty desktop only has to focus the
                    // surface, which WlrKeyboardFocus.OnDemand does on the click.
                }
            }
        }

        // Desktop icons and free-placed widgets. Supersedes the fixed-position
        // clock/lyrics loaders that used to live in the wallpaper window; those
        // are widgets now, seeded from the retired config keys by
        // ConfigMigrations.
        DesktopIcons {
            id: desktopIcons

            screenData: win.modelData
            // The frosted cards of large items sample the wallpaper with an
            // in-scene ShaderEffectSource, which cannot span surfaces. With null
            // that loader stays inactive and the cards render unfrosted; a
            // compositor blur gives them a backdrop instead, e.g. for Niri:
            //   layer-rule { match namespace="caelestia-desktop"; background-effect { blur true } }
            wallpaper: null
            z: 3
        }
    }
}
