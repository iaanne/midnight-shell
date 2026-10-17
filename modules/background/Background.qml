pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData
        readonly property alias wallpaperLoader: wallpaper

        screen: modelData
        name: "background"
        isDesktopWidget: true
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (contentItem.Config.background.wallpaperEnabled && !(wallpaper.item && wallpaper.item.weActive)) ? WlrLayer.Background : WlrLayer.Bottom
        // Keyboard focus follows the inline rename editor. Exclusive while it is
        // open; OnDemand otherwise so a click lands on the desktop as it would
        // on any other surface. Niri does not hand an *unfocused* layer surface
        // the exclusive grab, so the first click only focuses the surface — which
        // is harmless here because every rename is already started by interacting
        // with it (context menu, F2, or a click on the tile).
        WlrLayershell.keyboardFocus: desktopIcons.renameActive ? WlrKeyboardFocus.Exclusive : desktopIcons.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: contentItem.Config.background.wallpaperEnabled && !(wallpaper.item && wallpaper.item.weActive) ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        ShellState.ComponentRef {
            screen: win.screen
            slot: "background"
            component: win
        }

        // Empty-desktop interaction. Declared before the wallpaper/icons so the
        // icon and widget handlers sit above it and win when they are hit.
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

        Item {
            id: behindClock

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled
                opacity: (item && item.weActive) ? 0 : 1

                sourceComponent: Wallpaper {
                    screen: win.modelData
                }
            }

            Process {
                id: weProc
                property string weDir: wallpaper.item ? wallpaper.item.weDir : ""
                property bool weActive: wallpaper.item ? wallpaper.item.weActive : false
                
                command: {
                    let cmd = ["linux-wallpaperengine", "--screen-root", win.modelData.name, "--layer", "background"];
                    if (Wallpapers.weSilent) {
                        cmd.push("--silent");
                    } else {
                        cmd.push("--volume", Math.round(Wallpapers.weVolume * 100).toString());
                    }
                    cmd.push(weDir);
                    return cmd;
                }
                running: weActive && weDir !== "" && contentItem.Config.background.wallpaperEnabled
            }


            Loader {
                anchors.fill: parent
                z: 2
                active: !Config.background.visualiser.aboveWindows

                sourceComponent: Visualiser {
                    screen: win.modelData
                    wallpaper: wallpaper
                }
            }
        }

        // Desktop icons and free-placed widgets. Supersedes the fixed-position
        // clock/lyrics loaders that used to live here; those are widgets now,
        // seeded from the retired config keys by ConfigMigrations.
        DesktopIcons {
            id: desktopIcons

            screenData: win.modelData
            wallpaper: behindClock
            z: 3
        }
    }
}
