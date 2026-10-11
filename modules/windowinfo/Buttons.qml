pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property var client
    property bool moveToWsExpanded

    anchors.fill: parent
    spacing: Tokens.spacing.small

    RowLayout {
        Layout.topMargin: Tokens.padding.large
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large

        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Move to workspace")
            elide: Text.ElideRight
        }

        StyledRect {
            color: Colours.palette.m3primary
            radius: Tokens.rounding.medium

            implicitWidth: moveToWsIcon.implicitWidth + Tokens.padding.small
            implicitHeight: moveToWsIcon.implicitHeight + Tokens.padding.extraSmall

            StateLayer {
                color: Colours.palette.m3onPrimary
                onClicked: root.moveToWsExpanded = !root.moveToWsExpanded
            }

            MaterialIcon {
                id: moveToWsIcon

                anchors.centerIn: parent

                animate: true
                text: root.moveToWsExpanded ? "expand_more" : "keyboard_arrow_right"
                color: Colours.palette.m3onPrimary
                fontStyle: Tokens.font.icon.large
            }
        }
    }

    GridLayout {
        id: wsGrid

        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.bottomMargin: root.moveToWsExpanded ? Tokens.spacing.medium : 0
        Layout.preferredHeight: root.moveToWsExpanded ? implicitHeight : 0
        opacity: root.moveToWsExpanded ? 1 : 0
        clip: true

        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small
        columns: 5

        Behavior on Layout.bottomMargin {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on Layout.preferredHeight {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Repeater {
            model: {
                const workspaces = Compositor.allWorkspaces;
                if (!workspaces || workspaces.length === 0) return [];
                const focused = Compositor.focusedWorkspaceIndex ?? 0;
                const start = Math.max(0, focused - 4);
                const end = Math.min(workspaces.length, start + 10);
                return workspaces.slice(start, end);
            }

            Button {
                required property var modelData
                readonly property int wsIdx: modelData.index ?? 0
                readonly property bool isCurrent: root.client?.workspaceId === modelData.id

                onClicked: {
                    Compositor.moveWindowToWorkspace(String(modelData.id));
                    Compositor.switchToWorkspace(String(modelData.id));
                }

                color: isCurrent ? Colours.tPalette.m3surfaceContainerHighest : Colours.palette.m3tertiaryContainer
                onColor: isCurrent ? Colours.palette.m3onSurface : Colours.palette.m3onTertiaryContainer
                text: modelData.name ?? (wsIdx + 1)
                disabled: isCurrent
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.padding.large

        spacing: Tokens.spacing.small

        Button {
            color: Colours.palette.m3secondaryContainer
            onColor: Colours.palette.m3onSecondaryContainer
            text: root.client?.floating ? Tr.tr("Tile") : Tr.tr("Float")
            onClicked: Compositor.toggleWindowFloating(root.client?.id ?? "")
        }

        Loader {
            asynchronous: true
            active: false // TODO: no pinned concept in neutral schema
            Layout.fillWidth: active
            Layout.leftMargin: active ? 0 : -parent.spacing
            Layout.rightMargin: active ? 0 : -parent.spacing

            sourceComponent: Button {
                color: Colours.palette.m3secondaryContainer
                onColor: Colours.palette.m3onSecondaryContainer
                text: Tr.tr("Pin")
                onClicked: console.log("Buttons: pin not yet supported")
            }
        }

        Button {
            color: Colours.palette.m3errorContainer
            onColor: Colours.palette.m3onErrorContainer
            text: Tr.tr("Kill")
            onClicked: Compositor.closeWindow(root.client?.id ?? "")
        }
    }

    component Button: StyledRect {
        property color onColor: Colours.palette.m3onSurface
        property alias disabled: stateLayer.disabled
        property alias text: label.text

        signal clicked

        radius: Tokens.rounding.medium

        Layout.fillWidth: true
        implicitHeight: label.implicitHeight + Tokens.padding.small

        StateLayer {
            id: stateLayer

            color: parent.onColor
            onClicked: parent.clicked()
        }

        StyledText {
            id: label

            anchors.centerIn: parent

            animate: true
            color: parent.onColor
            font: Tokens.font.body.medium
        }
    }
}
