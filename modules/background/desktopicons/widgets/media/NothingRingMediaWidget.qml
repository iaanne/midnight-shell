pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Nothing's glyph ring: art in the centre, a ring of dots and the track below.
Item {
    id: root

    property var frame
    property var controller

    readonly property WidgetPlayback playback: WidgetPlayback {}

    readonly property real size: Math.min(width, height * 0.82)

    readonly property int dotCount: 24

    Item {
        id: ring

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.size
        height: root.size

        Repeater {
            model: root.dotCount

            StyledRect {
                required property int index

                readonly property real angle: index / root.dotCount * Math.PI * 2 - Math.PI / 2
                readonly property bool active: index / root.dotCount <= playback.progress

                width: Tokens.spacing.extraSmall
                height: width
                radius: width / 2
                color: active ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.18)
                x: ring.width / 2 + Math.cos(angle) * (ring.width / 2 - width) - width / 2
                y: ring.height / 2 + Math.sin(angle) * (ring.height / 2 - height) - height / 2

                Behavior on color {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }
        }

        MediaArt {
            anchors.centerIn: parent
            width: parent.width * 0.58
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

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: ring.bottom
        anchors.topMargin: Tokens.spacing.small
        width: root.width
        text: playback.title
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font: Tokens.font.title.small
    }
}
