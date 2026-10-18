pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A spinning CD: art inside a disc with a centre spindle, transport below.
Item {
    id: root

    property var frame
    property var controller

    readonly property WidgetPlayback playback: WidgetPlayback {}

    readonly property real size: Math.min(width, height)

    Item {
        id: disc

        anchors.centerIn: parent
        width: root.size * 0.82
        height: width
        rotation: 0

        RotationAnimation on rotation {
            running: playback.isPlaying
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 12000
        }

        StyledRect {
            anchors.fill: parent
            radius: width / 2
            color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)
        }

        MediaArt {
            anchors.fill: parent
            anchors.margins: parent.width * 0.06
            radius: width / 2
            url: playback.artUrl
        }

        StyledRect {
            anchors.centerIn: parent
            width: parent.width * 0.16
            height: width
            radius: width / 2
            color: Colours.palette.m3surface
        }
    }

    MediaButtons {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: disc.bottom
        anchors.topMargin: Tokens.spacing.small
        playback: playback
        iconFont: Tokens.font.icon.medium
    }
}
