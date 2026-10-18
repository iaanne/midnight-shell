pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Android's now-playing card: cover on the left, text and transport on the right.
Item {
    id: root

    property var frame
    property var controller

    WidgetPlayback {
        id: playback
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.large

        MediaArt {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            Layout.maximumWidth: root.width * 0.42
            radius: Tokens.rounding.large
            url: playback.artUrl
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.extraSmall

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                Layout.fillWidth: true
                text: playback.title
                font: Tokens.font.title.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: playback.artist
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            MediaButtons {
                Layout.topMargin: Tokens.spacing.extraSmall
                playback: playback
                iconFont: Tokens.font.icon.medium
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
