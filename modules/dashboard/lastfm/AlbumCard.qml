pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    readonly property var album: Lastfm.album

    implicitHeight: content.implicitHeight + Tokens.padding.medium * 2
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            Art {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                url: root.album?.image ?? ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.album?.name ?? Lastfm.selectedTrack?.album ?? Tr.tr("Album")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.album?.artist ?? Lastfm.selectedTrack?.artist ?? ""
                    color: Colours.palette.m3primary
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.album !== null && (root.album.releaseDate !== "" || root.album.listeners > 0)
                    text: root.album ? [root.album.releaseDate, Tr.tr("%1 listeners").arg(Lastfm.formatCount(root.album.listeners))].filter(part => part !== "").join(" · ") : ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            LoadingIndicator {
                visible: root.album === null && Lastfm.loadingDetails
                implicitSize: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.album !== null && root.album.tracks.length > 0
            spacing: 0

            Repeater {
                model: root.album?.tracks.slice(0, 8) ?? []

                delegate: RowLayout {
                    id: trackRow

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: (trackRow.index + 1).toString().padStart(2, "0")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: trackRow.modelData.name
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: Lastfm.formatDuration(trackRow.modelData.duration)
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.album?.wiki ?? ""
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.Wrap
            maximumLineCount: 5
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.album === null && !Lastfm.loadingDetails
            text: Tr.tr("No album info")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
