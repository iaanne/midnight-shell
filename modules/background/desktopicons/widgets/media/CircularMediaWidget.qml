pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Art in a circle, wrapped by a progress ring that ripples while playing.
Item {
    id: root

    property var frame
    property var controller

    readonly property WidgetPlayback playback: WidgetPlayback {}

    readonly property real size: Math.min(width, height)

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size
        strokeWidth: Math.max(3, root.size * 0.045)
        value: playback.progress
        fgColour: Colours.palette.m3primary
        bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.12)
        wavy: playback.isPlaying
        wavePaused: !playback.isPlaying
        hasEndIndicator: playback.hasPlayer
    }

    MediaArt {
        anchors.centerIn: parent
        width: root.size * 0.7
        height: width
        radius: width / 2
        url: playback.artUrl
    }

    IconButton {
        anchors.centerIn: parent
        type: IconButton.Filled
        isRound: true
        icon: playback.isPlaying ? "pause" : "play_arrow"
        opacity: hover.hovered || !playback.isPlaying ? 1 : 0
        onClicked: playback.toggle()

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    HoverHandler {
        id: hover
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        visible: height < Tokens.padding.small
        text: qsTr("Nothing playing")
        color: Colours.palette.m3outline
    }
}
