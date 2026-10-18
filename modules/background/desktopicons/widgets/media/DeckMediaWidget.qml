pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A wide player deck: cover beside the track, transport and seek underneath.
Item {
    id: root

    property var frame
    property var controller

    WidgetPlayback {
        id: playback
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.medium

            MediaArt {
                Layout.fillHeight: true
                Layout.preferredWidth: height
                radius: Tokens.rounding.medium
                url: playback.artUrl
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.fillHeight: true
                }

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
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Qt.alpha(Colours.palette.m3onSurface, 0.15)

            StyledRect {
                width: parent.width * playback.progress
                height: parent.height
                radius: parent.radius
                color: Colours.palette.m3primary

                Behavior on width {
                    Anim {
                        type: Anim.StandardSmall
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: playback.positionText
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            MediaButtons {
                playback: playback
                iconFont: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                text: playback.lengthText
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
