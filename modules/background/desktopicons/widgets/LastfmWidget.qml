pragma ComponentBehavior: Bound

import ".."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Last.fm on the desktop: the latest scrobble, a short recent list, or a
// profile card. The variant chosen in the gallery picks the look.
Item {
    id: root

    property var frame
    property var controller
    // Set by the variant wrappers so the look survives the Nexus preview,
    // which has no placed-widget record to read the variant from.
    property string variantMode: ""

    readonly property string mode: {
        const id = variantMode !== "" ? variantMode : (frame?.widget?.variant || frame?.config?.mode || "recent");
        return id === "hero" || id === "profile" ? id : "recent";
    }
    readonly property int limit: Math.max(1, Math.min(20, frame?.config?.limit ?? 10))
    readonly property var track: Lastfm.nowPlaying ?? Lastfm.recentTracks[0] ?? null

    // Rows that fit in the current height, so a resized widget never clips.
    readonly property int visibleCount: Math.max(1, Math.min(limit, Math.floor((height - 22) / 34)))

    readonly property bool needsSetup: !Lastfm.hasCredentials || !Lastfm.enabled
    readonly property bool disabled: Lastfm.hasCredentials && !Lastfm.enabled
    readonly property bool failed: Lastfm.configured && Lastfm.recentTracks.length === 0 && Lastfm.error !== "" && !Lastfm.loadingRecent

    clip: true

    Component.onCompleted: Lastfm.acquire()
    Component.onDestruction: Lastfm.release()

    // Hero: cover, title, artist and the last scrobble time.
    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium
        visible: !root.needsSetup && !root.failed && root.mode === "hero"

        MediaArt {
            Layout.fillHeight: true
            // Cap the art on tall widgets so the text keeps some width.
            Layout.preferredWidth: Math.min(height, root.width * 0.45)
            radius: Tokens.rounding.medium
            url: root.track?.image ?? ""
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
                text: root.track?.nowPlaying ? Tr.tr("Now playing") : (root.track && root.track.timestamp > 0 ? Lastfm.relativeTime(root.track.timestamp) : Tr.tr("Last.fm"))
                color: Colours.palette.m3primary
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.track?.name ?? Tr.tr("Nothing scrobbled yet")
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.track?.artist ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.track?.album ?? ""
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    // Recent: a compact list of the latest scrobbles.
    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall
        visible: !root.needsSetup && !root.failed && root.mode === "recent"

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Last.fm")
                color: Colours.palette.m3primary
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledText {
                text: `@${Lastfm.profile?.name ?? Lastfm.username}`
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: Lastfm.recentTracks.length === 0
            text: Lastfm.loadingRecent ? Tr.tr("Loading…") : Tr.tr("No scrobbles yet")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }

        Repeater {
            model: Lastfm.recentTracks.slice(0, root.visibleCount)

            delegate: RowLayout {
                id: recentRow

                required property int index
                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MediaArt {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Tokens.rounding.small
                    url: recentRow.modelData.image
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: recentRow.modelData.name
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: recentRow.modelData.artist
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: recentRow.modelData.nowPlaying ? Tr.tr("Now") : Lastfm.relativeTime(recentRow.modelData.timestamp)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // Profile: avatar, name and a couple of counters.
    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small
        visible: !root.needsSetup && !root.failed && root.mode === "profile"

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MediaArt {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 26
                url: Lastfm.profile?.image ?? ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Lastfm.profile?.name ?? Lastfm.username
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Lastfm.profile?.realname ?? ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.extraSmall

            StyledText {
                text: Lastfm.formatCount(Lastfm.profile?.playcount ?? 0)
                font: Tokens.font.title.small
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("scrobbles")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            StyledText {
                text: Lastfm.formatCount(Lastfm.profile?.artistCount ?? 0)
                font: Tokens.font.title.small
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("artists")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }

        Item {
            Layout.fillHeight: true
        }

        StyledText {
            Layout.fillWidth: true
            text: root.track ? Tr.tr("Last: %1").arg(root.track.name) : ""
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }
    }

    // Setup / offline card, so the widget is visible before it is configured.
    StyledRect {
        anchors.fill: parent
        visible: root.needsSetup || root.failed
        radius: Tokens.rounding.large
        color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.75)

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Tokens.padding.large * 2
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: root.needsSetup ? (root.disabled ? "music_off" : "music_note") : "cloud_off"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.builders.large.build()
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.needsSetup ? (root.disabled ? Tr.tr("Last.fm is off") : Tr.tr("Set up Last.fm")) : Tr.tr("Could not reach Last.fm")
                font: Tokens.font.title.small
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.needsSetup ? (root.disabled ? Tr.tr("Enable it in Settings → Services → Last.fm.") : Tr.tr("Add your username and API key in Settings → Services → Last.fm.")) : Lastfm.error
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            TextButton {
                Layout.alignment: Qt.AlignHCenter
                visible: root.failed
                text: Tr.tr("Retry")
                onClicked: Lastfm.reload(true)
            }
        }
    }
}
