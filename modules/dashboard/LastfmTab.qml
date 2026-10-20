pragma ComponentBehavior: Bound

import "lastfm"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ScreenState screenState

    readonly property string emptyState: {
        if (!Lastfm.hasCredentials)
            return "setup";
        if (!Lastfm.enabled)
            return "disabled";
        if (Lastfm.recentTracks.length > 0)
            return "";
        if (Lastfm.error !== "")
            return "error";
        if (Lastfm.loadingRecent || Lastfm.loadingProfile)
            return "loading";
        return "empty";
    }

    property bool acquired: false

    function syncActive(): void {
        const active = root.screenState.dashboard;
        if (active && !acquired) {
            acquired = true;
            Lastfm.acquire();
        } else if (!active && acquired) {
            acquired = false;
            Lastfm.release();
        }
    }

    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth
    implicitHeight: 380

    Component.onCompleted: syncActive()
    Component.onDestruction: {
        if (acquired)
            Lastfm.release();
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraLarge
        visible: root.emptyState === ""

        ProfileCard {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
        }

        ColumnLayout {
            Layout.preferredWidth: 350
            Layout.fillHeight: true
            spacing: Tokens.spacing.medium

            HeroCard {
                Layout.fillWidth: true
            }

            RecentList {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        Flickable {
            id: detailsFlick

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentWidth: width
            contentHeight: details.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: StyledScrollBar {
                flickable: detailsFlick
            }

            ColumnLayout {
                id: details

                width: detailsFlick.width
                spacing: Tokens.spacing.medium

                ArtistCard {
                    Layout.fillWidth: true
                }

                AlbumCard {
                    Layout.fillWidth: true
                    visible: Lastfm.selectedTrack !== null && Lastfm.selectedTrack.album !== ""
                }
            }
        }
    }

    EmptyState {
        anchors.centerIn: parent
        width: Math.max(220, Math.min(parent.width - Tokens.padding.extraLarge * 2, 440))
        visible: root.emptyState !== ""
        loading: root.emptyState === "loading"
        icon: {
            switch (root.emptyState) {
            case "setup":
                return "settings";
            case "disabled":
                return "music_off";
            case "error":
                return "cloud_off";
            default:
                return "music_off";
            }
        }
        title: {
            switch (root.emptyState) {
            case "setup":
                return Tr.tr("Set up Last.fm");
            case "disabled":
                return Tr.tr("Last.fm is off");
            case "error":
                return Tr.tr("Could not reach Last.fm");
            case "loading":
                return Tr.tr("Loading your scrobbles…");
            default:
                return Tr.tr("No scrobbles yet");
            }
        }
        subtitle: {
            switch (root.emptyState) {
            case "setup":
                return Tr.tr("Add your username and API key in Settings → Services → Last.fm.");
            case "disabled":
                return Tr.tr("Enable it in Settings → Services → Last.fm.");
            case "error":
                return Lastfm.error;
            case "loading":
                return "";
            default:
                return Tr.tr("Scrobbles will show up here once you listen to something.");
            }
        }
        actionText: root.emptyState === "error" ? Tr.tr("Retry") : ""
        onAction: Lastfm.reload(true)
    }

    Connections {
        function onDashboardChanged(): void {
            root.syncActive();
        }

        target: root.screenState
    }
}
