pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A poster: the cover with the track printed across the bottom and transport.
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
        height: parent.height * 0.5
        bottomLeftRadius: Tokens.rounding.extraLarge
        bottomRightRadius: Tokens.rounding.extraLarge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha("#000000", 0.82)
            }
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            text: playback.title
            color: "white"
            font: Tokens.font.headline.medium
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            text: playback.artist
            color: Qt.alpha("#ffffff", 0.78)
            font: Tokens.font.body.medium
            elide: Text.ElideRight
        }

        MediaButtons {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.extraSmall
            playback: playback
            iconFont: Tokens.font.icon.medium
        }
    }
}
