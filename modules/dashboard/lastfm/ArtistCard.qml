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

    readonly property var artist: Lastfm.artist

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
                url: root.artist?.image ?? ""
                circular: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.artist?.name ?? Tr.tr("Artist")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.artist !== null
                    text: root.artist ? Tr.tr("%1 listeners · %2 scrobbles").arg(Lastfm.formatCount(root.artist.listeners)).arg(Lastfm.formatCount(root.artist.playcount)) : ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            LoadingIndicator {
                visible: root.artist === null && Lastfm.loadingDetails
                implicitSize: 22
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: root.artist !== null && root.artist.tags.length > 0
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.artist?.tags ?? []

                delegate: StyledRect {
                    required property var modelData

                    implicitWidth: tag.implicitWidth + Tokens.padding.small * 2
                    implicitHeight: tag.implicitHeight + Tokens.padding.extraSmall
                    radius: height / 2
                    color: Qt.alpha(Colours.palette.m3secondary, 0.14)

                    StyledText {
                        id: tag

                        anchors.centerIn: parent
                        text: modelData
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.artist?.bio ?? ""
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.artist && root.artist.similar.length > 0 ? Tr.tr("Similar: %1").arg(root.artist.similar.map(similar => similar.name).join(", ")) : ""
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.artist === null && !Lastfm.loadingDetails
            text: Tr.tr("No artist info")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
