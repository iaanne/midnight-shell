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
        // Wallpaper only. The interactive desktop (file icons, large folders and
        // free-placed widgets) lives in DesktopSurface.qml, on its own surface,
        // because compositors back the stationary desktop wallpaper with a
        // "backdrop" placement (Niri's place-within-backdrop) and backdrop
        // surfaces deliberately receive no input. Splitting them keeps the
        // wallpaper stationary *and* the icons clickable. See DesktopSurface.qml.
        //
        // The namespace stays "caelestia-background" (i.e. no isDesktopWidget),
        // which is what backdrop layer rules are expected to match.
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (contentItem.Config.background.wallpaperEnabled && !(wallpaper.item && wallpaper.item.weActive)) ? WlrLayer.Background : WlrLayer.Bottom
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

        // Empty-desktop interaction (the right/middle-click handler and the
        // keyboard-focus policy) moved to DesktopSurface.qml, which owns the
        // icon and widget surface this handler used to sit above.

        Item {
            id: wallpaperLayer

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
    }
}
