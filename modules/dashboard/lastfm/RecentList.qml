pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Recent scrobbles")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.small
            elide: Text.ElideRight
        }

        StyledText {
            text: Lastfm.formatCount(Lastfm.recentTracks.length)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true

        clip: true
        spacing: Tokens.spacing.extraSmall
        model: Lastfm.recentTracks

        ScrollBar.vertical: StyledScrollBar {
            flickable: list
        }

        delegate: StyledRect {
            id: row

            required property int index
            required property var modelData

            readonly property bool selected: row.index === Lastfm.selectedIndex

            width: ListView.view.width
            implicitHeight: 48
            radius: Tokens.rounding.medium
            color: row.selected ? Qt.alpha(Colours.palette.m3primary, 0.14) : "transparent"

            StateLayer {
                radius: Tokens.rounding.medium
                onClicked: Lastfm.selectTrack(row.index)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.small
                anchors.rightMargin: Tokens.padding.small
                spacing: Tokens.spacing.small

                Art {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    url: row.modelData.image
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: row.selected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            visible: row.modelData.nowPlaying
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: Colours.palette.m3primary
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.artist
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: row.modelData.nowPlaying ? Tr.tr("Now") : Lastfm.relativeTime(row.modelData.timestamp)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
