pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.services

// Single playback clock for every lyrics surface. Widgets subscribe instead of
// spawning their own polling timers, so idle CPU stays at one timer no matter
// how many lyrics views are open.
Singleton {
    id: root

    property var subscribers: []
    property real position: 0
    property int currentIndex: -1
    // QML does not notify on in-place array mutation, so keep the count explicit;
    // the playback timer depends on it.
    property int subscriptionCount: 0
    readonly property bool hasSubscribers: subscriptionCount > 0
    readonly property var currentLine: currentIndex >= 0 && currentIndex < Lyrics.lyricLines.length ? Lyrics.lyricLines[currentIndex] : null

    function subscribe(object: var): void {
        if (!object || subscribers.indexOf(object) >= 0)
            return;
        subscribers.push(object);
        subscriptionCount = subscribers.length;
        update();
    }

    function unsubscribe(object: var): void {
        const index = subscribers.indexOf(object);
        if (index >= 0) {
            subscribers.splice(index, 1);
            subscriptionCount = subscribers.length;
        }
    }

    function reloadTrack(): void {
        const player = Players.active;
        if (!player) {
            Lyrics.clearTrack();
            position = 0;
            currentIndex = -1;
            return;
        }
        Lyrics.setTrack(player.trackArtist ?? "", player.trackTitle ?? "", player.trackAlbum ?? "",
            player.length ?? 0, player.metadata ? (player.metadata["xesam:url"] ?? "") : "");
        update();
    }

    function update(): void {
        const player = Players.active;
        if (!player) {
            position = 0;
            currentIndex = -1;
            return;
        }
        position = player.position ?? 0;
        currentIndex = Lyrics.hasLyrics ? Lyrics.indexForTime(position) : -1;
    }

    function lineAt(offset: int): var {
        const index = currentIndex + offset;
        const lines = Lyrics.lyricLines;
        return index >= 0 && index < lines.length ? lines[index] : null;
    }

    function seek(line: var): void {
        const player = Players.active;
        if (player && line && (line.t ?? -1) >= 0) {
            player.position = line.t + Lyrics.offset / 1000 + 0.01;
            update();
        }
    }

    Timer {
        running: root.subscriptionCount > 0 && !!Players.active?.isPlaying
        // Word/syllable fills need a much finer clock than line transitions.
        interval: Lyrics.wordSynced ? 50 : GlobalConfig.dashboard.mediaUpdateInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            Players.active?.positionChanged();
            root.update();
        }
    }

    Connections {
        target: Players

        function onActiveChanged(): void {
            root.reloadTrack();
        }
    }

    Connections {
        target: Players.active
        ignoreUnknownSignals: true

        function onPostTrackChanged(): void {
            root.reloadTrack();
        }

        function onTrackTitleChanged(): void {
            root.reloadTrack();
        }

        function onTrackArtistChanged(): void {
            root.reloadTrack();
        }

        // Keep the active line correct for paused seeks and external position changes.
        function onPositionChanged(): void {
            root.update();
        }
    }

    Connections {
        target: Lyrics

        function onLyricsChanged(): void {
            root.update();
        }

        function onLyricLinesChanged(): void {
            root.update();
        }

        function onOffsetChanged(): void {
            root.update();
        }
    }

    Component.onCompleted: reloadTrack()
}
