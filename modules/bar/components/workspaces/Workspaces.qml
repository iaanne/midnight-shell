pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    // TODO: no special workspaces in neutral schema — always false
    readonly property bool onSpecial: false

    readonly property var outputWorkspaces: Compositor.allWorkspaces.filter(w => w.output === root.screen.name)
    readonly property int activeWsIndex: {
        const focused = outputWorkspaces.find(w => w.focused);
        return focused ? focused.index : 1;
    }

    readonly property var occupied: {
        const occ = {};
        for (const ws of outputWorkspaces) {
            occ[ws.index] = ws.occupied ?? false;
        }
        return occ;
    }
    readonly property int groupOffset: Math.floor((activeWsIndex - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    property real blur: onSpecial ? 1 : 0

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    implicitWidth: isHorizontal ? (layout.implicitWidth + Tokens.padding.small) : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : (layout.implicitHeight + Tokens.padding.small)

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            asynchronous: true
            active: Config.bar.workspaces.occupiedBg

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: OccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: root.groupOffset
            }
        }

        GridLayout {
            id: layout

            anchors.centerIn: parent
            columns: isHorizontal ? -1 : 1
            rows: isHorizontal ? 1 : -1
            flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            columnSpacing: Math.floor(Tokens.spacing.small)
            rowSpacing: Math.floor(Tokens.spacing.small)

            Repeater {
                id: workspaces

                model: Config.bar.workspaces.shown

                Workspace {
                    activeWsId: root.activeWsIndex
                    occupied: root.occupied
                    groupOffset: root.groupOffset
                    outputWorkspaces: root.outputWorkspaces
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.horizontalCenter: isHorizontal ? undefined : parent.horizontalCenter
            anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: ActiveIndicator {
                activeWsId: root.activeWsIndex
                workspaces: workspaces
                mask: layout
                fullscreen: root.fullscreen
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const ws = (layout.childAt(event.x, event.y) as Workspace)?.ws;
                if (!ws)
                    return;
                if (root.activeWsIndex !== ws)
                    Compositor.switchToWorkspaceByNumber(ws, root.screen.name);
                // TODO: no special workspace toggle in neutral schema
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // TODO: no special workspaces in neutral schema — loader commented out
    // Loader {
    //     id: specialWs
    //     ...
    // }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
