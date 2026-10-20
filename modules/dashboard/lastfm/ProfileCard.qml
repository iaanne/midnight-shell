pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    readonly property var profile: Lastfm.profile

    spacing: Tokens.spacing.medium

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        Art {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            url: root.profile?.image ?? ""
            circular: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.profile?.name ?? Lastfm.username
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.profile?.realname ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.profile?.country ?? ""
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Tokens.spacing.large
        rowSpacing: Tokens.spacing.medium

        Stat {
            label: Tr.tr("Scrobbles")
            value: Lastfm.formatCount(root.profile?.playcount ?? 0)
        }

        Stat {
            label: Tr.tr("Artists")
            value: Lastfm.formatCount(root.profile?.artistCount ?? 0)
        }

        Stat {
            label: Tr.tr("Albums")
            value: Lastfm.formatCount(root.profile?.albumCount ?? 0)
        }

        Stat {
            label: Tr.tr("Tracks")
            value: Lastfm.formatCount(root.profile?.trackCount ?? 0)
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.profile?.registered ? Tr.tr("Member since %1").arg(Lastfm.formatDate(root.profile.registered)) : ""
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
        elide: Text.ElideRight
    }

    Item {
        Layout.fillHeight: true
    }

    TextButton {
        Layout.alignment: Qt.AlignHCenter
        text: Tr.tr("Open Last.fm profile")
        onClicked: Qt.openUrlExternally(root.profile?.url ?? `https://www.last.fm/user/${Lastfm.username}`)
    }

    StyledText {
        Layout.fillWidth: true
        text: Tr.tr("Powered by Last.fm")
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
        horizontalAlignment: Text.AlignHCenter
    }
}
