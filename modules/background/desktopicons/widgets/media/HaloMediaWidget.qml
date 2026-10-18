pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Art inside a soft halo that pulses (wavy) while playing.
Item {
    id: root

    property var frame
    property var controller

    readonly property WidgetPlayback playback: WidgetPlayback {}

    readonly property real size: Math.min(width, height)

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size
        strokeWidth: Math.max(3, root.size * 0.05)
        value: 1
        fgColour: Qt.alpha(Colours.palette.m3primary, playback.isPlaying ? 0.9 : 0.4)
        bgColour: "transparent"
        wavy: true
        wavePaused: !playback.isPlaying
        hasEndIndicator: false
    }

    MediaArt {
        anchors.centerIn: parent
        width: root.size * 0.66
        height: width
        radius: width / 2
        url: playback.artUrl
    }

    IconButton {
        anchors.centerIn: parent
        type: IconButton.Filled
        isRound: true
        icon: playback.isPlaying ? "pause" : "play_arrow"
        opacity: hover.hovered ? 1 : 0
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
}
