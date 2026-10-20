pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

StyledRect {
    id: root

    // Follow the selected scrobble so the song, artist and album cards all
    // describe the same track. With nothing selected this is the newest one.
    readonly property var track: Lastfm.selectedTrack ?? Lastfm.nowPlaying ?? Lastfm.recentTracks[0] ?? null
    readonly property bool playing: root.track?.nowPlaying === true

    implicitHeight: 126
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer

    StateLayer {
        onClicked: {
            if (root.track?.url)
                Qt.openUrlExternally(root.track.url);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        Art {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            url: root.track?.image ?? ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledRect {
                    visible: root.playing
                    implicitWidth: playingBadge.implicitWidth + Tokens.padding.small * 2
                    implicitHeight: playingBadge.implicitHeight + Tokens.padding.extraSmall
                    radius: height / 2
                    color: Qt.alpha(Colours.palette.m3primary, 0.16)

                    RowLayout {
                        id: playingBadge

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall

                        StyledRect {
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            text: Tr.tr("Now playing")
                            color: Colours.palette.m3primary
                            font: Tokens.font.label.small
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !root.playing
                    text: root.track && root.track.timestamp > 0 ? Tr.tr("Last scrobbled %1").arg(Lastfm.relativeTime(root.track.timestamp)) : Tr.tr("Last scrobble")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    visible: root.track?.loved === true
                    text: "favorite"
                    color: Colours.palette.m3error
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.track?.name ?? Tr.tr("Nothing scrobbled yet")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.track?.artist ?? ""
                color: Colours.palette.m3primary
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.track?.album ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
