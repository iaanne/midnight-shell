pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A single compact row: art, title/artist, one play button.
Item {
    id: root

    property var frame
    property var controller

    WidgetPlayback {
        id: playback
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        MediaArt {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            Layout.maximumWidth: root.width * 0.38
            radius: Tokens.rounding.medium
            url: playback.artUrl
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: playback.title
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: playback.artist
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            type: IconButton.Tonal
            isRound: true
            icon: playback.isPlaying ? "pause" : "play_arrow"
            disabled: !playback.player?.canTogglePlaying
            onClicked: playback.toggle()
        }
    }
}
