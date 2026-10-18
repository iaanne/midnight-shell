pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Full-bleed cover with the title over a bottom scrim and a seek line.
Item {
    id: root

    property var frame
    property var controller

    WidgetPlayback {
        id: playback
    }

    MediaArt {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        url: playback.artUrl
    }

    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.55
        bottomLeftRadius: Tokens.rounding.extraLarge
        bottomRightRadius: Tokens.rounding.extraLarge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha("#000000", 0.78)
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: playback.title
                color: "white"
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: playback.artist
                color: Qt.alpha("#ffffff", 0.75)
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        IconButton {
            type: IconButton.Filled
            isRound: true
            icon: playback.isPlaying ? "pause" : "play_arrow"
            disabled: !playback.player?.canTogglePlaying
            onClicked: playback.toggle()
        }
    }

    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0
        height: 3
        color: Qt.alpha("#ffffff", 0.25)

        StyledRect {
            width: parent.width * playback.progress
            height: parent.height
            color: "white"

            Behavior on width {
                Anim {
                    type: Anim.StandardSmall
                }
            }
        }
    }
}
