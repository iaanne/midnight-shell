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

    readonly property string mode: {
        const id = frame?.variant || frame?.widget?.variant || frame?.config?.mode || "recent";
        return id === "hero" || id === "profile" || id === "grid" ? id : "recent";
    }
    readonly property bool isGrid: root.mode === "grid"
    readonly property int limit: Math.max(1, Math.min(20, frame?.config?.limit ?? 10))
    readonly property var track: Lastfm.nowPlaying ?? Lastfm.recentTracks[0] ?? null

    // Rows that fit in the current height, so a resized widget never clips.
    readonly property int visibleCount: Math.max(1, Math.min(limit, Math.floor((height - 22) / 34)))

    // Cover grid configuration.
    readonly property string chartEntity: Lastfm.normalizeChartEntity(frame?.config?.chartEntity ?? "album")
    readonly property string chartUnit: Lastfm.normalizeChartUnit(frame?.config?.chartUnit ?? "month")
    readonly property int chartValue: Lastfm.normalizeChartValue(chartUnit, frame?.config?.chartValue ?? 3)
    readonly property string chartKey: Lastfm.chartKey(chartEntity, chartUnit, chartValue)
    readonly property var chart: Lastfm.charts[chartKey] ?? null
    readonly property var chartItems: chart?.items ?? []
    readonly property bool chartLoading: chart?.loading ?? false
    readonly property string chartError: chart?.error ?? ""
    readonly property real chartProgress: chart?.progress ?? 0

    // Per-widget refresh. Feed widgets share the service cache; the grid has
    // its own chart data.
    readonly property string refreshUnit: Lastfm.normalizeRefreshUnit(frame?.config?.refreshUnit ?? Lastfm.defaultRefreshUnit(mode))
    readonly property int refreshValue: {
        const fallback = Lastfm.defaultRefreshValue(root.mode);
        const value = Number(frame?.config?.refreshValue ?? fallback);
        return Math.max(1, Math.min(Lastfm.maxRefreshValue(root.refreshUnit), Math.round(value) || fallback));
    }
    readonly property int refreshMs: Lastfm.refreshIntervalMs(refreshUnit, refreshValue)
    // Coarse QML timers may wake slightly early; leave enough headroom that the
    // service's strict interval check still accepts the tick.
    readonly property int refreshTimerMs: Math.min(Lastfm.maxTimerMs, root.refreshMs + Math.max(1000, Math.round(root.refreshMs * 0.06)))

    readonly property bool needsSetup: !Lastfm.hasCredentials || !Lastfm.enabled
    readonly property bool disabled: Lastfm.hasCredentials && !Lastfm.enabled
    readonly property bool feedFailed: Lastfm.configured && Lastfm.recentTracks.length === 0 && Lastfm.error !== "" && !Lastfm.loadingRecent
    readonly property bool gridFailed: root.isGrid && Lastfm.configured && root.chart !== null && root.chartError !== "" && !root.chartLoading && root.chartItems.length === 0
    readonly property bool failed: root.isGrid ? root.gridFailed : root.feedFailed
    readonly property string failureText: root.isGrid ? root.chartError : Lastfm.error
    readonly property string failureTitle: root.needsSetup ? (root.disabled ? Tr.tr("Last.fm is off") : Tr.tr("Set up Last.fm")) : (root.isGrid ? Tr.tr("Could not load this chart") : Tr.tr("Could not reach Last.fm"))
    readonly property bool gridEmpty: root.isGrid && Lastfm.configured && root.chart !== null && !root.chartLoading && root.chartError === "" && root.chartItems.length === 0
    readonly property bool gridLoading: root.isGrid && Lastfm.configured && (root.chart === null || (root.chartLoading && root.chartItems.length === 0))
    readonly property bool refreshLoading: root.isGrid ? root.chartLoading : (root.mode === "profile" ? (Lastfm.loadingProfile || Lastfm.loadingRecent) : Lastfm.loadingRecent)

    property bool hovered: false
    property bool feedAcquired: false
    property string activeChartKey: ""

    function syncFeed(): void {
        const needFeed = !root.isGrid && root.frame !== undefined;
        if (needFeed && !root.feedAcquired) {
            Lastfm.acquireWidget();
            root.feedAcquired = true;
        } else if (!needFeed && root.feedAcquired) {
            Lastfm.releaseWidget();
            root.feedAcquired = false;
        }
    }

    function syncChart(): void {
        const key = root.isGrid && root.frame !== undefined ? root.chartKey : "";
        if (key === root.activeChartKey)
            return;
        if (root.activeChartKey !== "")
            Lastfm.releaseChart(root.activeChartKey);
        root.activeChartKey = key;
        if (key !== "")
            Lastfm.acquireChart(root.chartEntity, root.chartUnit, root.chartValue);
    }

    function syncAll(): void {
        root.syncFeed();
        root.syncChart();
    }

    function refreshNow(manual: bool): void {
        if (!Lastfm.configured)
            return;
        if (root.isGrid) {
            Lastfm.refreshChart(root.chartEntity, root.chartUnit, root.chartValue, manual === true, root.refreshMs);
            return;
        }
        Lastfm.refreshFeed(root.mode, root.refreshMs, manual === true);
    }

    function emptyText(): string {
        if (root.chartEntity === "artist")
            return Tr.tr("No top artists for this range");
        if (root.chartEntity === "track")
            return Tr.tr("No top songs for this range");
        return Tr.tr("No top albums for this range");
    }

    clip: true

    Component.onCompleted: root.syncAll()
    Component.onDestruction: {
        if (root.feedAcquired)
            Lastfm.releaseWidget();
        if (root.activeChartKey !== "")
            Lastfm.releaseChart(root.activeChartKey);
    }

    onModeChanged: root.syncAll()
    onFrameChanged: root.syncAll()
    onChartKeyChanged: root.syncAll()

    Connections {
        function onConfiguredChanged(): void {
            root.syncAll();
            if (!Lastfm.configured)
                return;
            if (root.isGrid && root.activeChartKey !== "")
                Lastfm.ensureChart(root.chartEntity, root.chartUnit, root.chartValue);
        }

        target: Lastfm
    }

    Timer {
        interval: root.refreshTimerMs
        repeat: true
        running: root.frame !== undefined && Lastfm.configured
        onTriggered: root.refreshNow(false)
    }

    HoverHandler {
        id: hover

        onHoveredChanged: root.hovered = hovered
    }


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

    // Cover grid: adaptive tiles for top artists, albums or songs.
    LastfmCoverGrid {
        anchors.fill: parent
        visible: root.isGrid && !root.needsSetup && !root.failed && !root.gridLoading && !root.gridEmpty
        items: root.chartItems
        entity: root.chartEntity
        showArtist: root.frame?.config?.showArtist ?? true
        showAlbum: root.frame?.config?.showAlbum ?? true
        showYear: root.frame?.config?.showYear ?? false
    }

    // Initial exact-range load. Refreshes with existing covers stay visible.
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.padding.large * 2, 260)
        spacing: Tokens.spacing.small
        visible: root.gridLoading

        LoadingIndicator {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: 34
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Tr.tr("Loading covers…")
            font: Tokens.font.body.small
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: root.chartProgress > 0
            text: Tr.tr("%1%").arg(Math.round(root.chartProgress * 100))
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }

    StyledText {
        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.padding.large * 2, 240)
        horizontalAlignment: Text.AlignHCenter
        visible: root.gridEmpty && !root.needsSetup && !root.failed
        text: root.emptyText()
        color: Colours.palette.m3outline
        font: Tokens.font.body.small
        wrapMode: Text.Wrap
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
                text: root.failureTitle
                font: Tokens.font.title.small
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.needsSetup ? (root.disabled ? Tr.tr("Enable it in Settings → Services → Last.fm.") : Tr.tr("Add your username and API key in Settings → Services → Last.fm.")) : root.failureText
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
                onClicked: {
                    if (root.isGrid)
                        root.refreshNow(true);
                    else
                        Lastfm.reload(true);
                }
            }
        }
    }

    // Refresh is available on every Last.fm widget. It stays out of the way
    // until the widget is hovered, except while a request is running.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.small
        width: 30
        height: 30
        radius: 15
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.85)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
        z: 20
        visible: !root.needsSetup && (root.hovered || root.refreshLoading)
        opacity: root.hovered ? 1 : 0.82

        IconButton {
            anchors.centerIn: parent
            type: IconButton.Text
            icon: "refresh"
            font: Tokens.font.icon.small
            visible: !root.refreshLoading
            onClicked: root.refreshNow(true)
        }

        LoadingIndicator {
            anchors.centerIn: parent
            implicitSize: 16
            visible: root.refreshLoading
        }

        Behavior on opacity {
            Anim {}
        }
    }
}
