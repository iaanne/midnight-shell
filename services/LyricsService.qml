pragma Singleton

import QtQml
import Quickshell
import Caelestia.Services

// Public lyrics facade. UI code should use this instead of the C++ singleton
// directly so the backend can grow without touching every widget.
Singleton {
    id: root

    readonly property var backend: Lyrics
    readonly property var lines: Lyrics.lyricLines
    readonly property var providers: Lyrics.providers
    readonly property string sourceName: Lyrics.sourceName
    readonly property string sourceUrl: Lyrics.sourceUrl
    readonly property string sourceText: Lyrics.sourceText
    readonly property bool loading: Lyrics.loading
    readonly property bool hasLyrics: Lyrics.hasLyrics
    readonly property bool wordSynced: Lyrics.wordSynced
    readonly property bool timedLyrics: Lyrics.timedLyrics
    readonly property bool instrumental: Lyrics.instrumental
    readonly property bool hasRomanized: Lyrics.hasRomanized
    readonly property bool showRomanized: Lyrics.showRomanized
    readonly property real offset: Lyrics.offset

    function setTrack(artist: string, title: string, album: string, duration: real, fileUrl: string): void {
        Lyrics.setTrack(artist, title, album, duration, fileUrl);
    }

    function clearTrack(): void {
        Lyrics.clearTrack();
    }

    function refresh(): void {
        Lyrics.refresh();
    }

    function indexForTime(time: real): int {
        return Lyrics.indexForTime(time);
    }

    function timeForIndex(index: int): real {
        return Lyrics.timeForIndex(index);
    }

    function setProviderEnabled(id: string, enabled: bool): void {
        Lyrics.setProviderEnabled(id, enabled);
    }

    function moveProvider(from: int, to: int): void {
        Lyrics.moveProvider(from, to);
    }

    function resetProviders(): void {
        Lyrics.resetProviders();
    }
}
