pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// State and transport shared by every media widget variant, so each look only
// has to draw. Wraps Midnight's Players service.
QtObject {
    id: root

    readonly property var player: Players.active
    readonly property bool hasPlayer: root.player !== null
    readonly property bool isPlaying: root.player?.isPlaying ?? false
    readonly property string title: root.hasPlayer ? (root.player.trackTitle || qsTr("Unknown title")) : qsTr("Nothing playing")
    readonly property string artist: root.hasPlayer ? (root.player.trackArtist || qsTr("Unknown artist")) : ""
    readonly property string playerName: root.player?.identity ?? ""
    readonly property string artUrl: Players.getArtUrl(root.player)

    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0
    readonly property real progress: root.length > 0 ? Math.min(1, (root.position % root.length) / root.length) : 0
    readonly property string positionText: fmt(root.position)
    readonly property string lengthText: root.length > 0 ? fmt(root.length) : "--:--"

    function fmt(seconds: real): string {
        if (!(seconds > 0))
            return "0:00";
        const total = Math.floor(seconds);
        const s = total % 60;
        const m = Math.floor(total / 60) % 60;
        const h = Math.floor(total / 3600);
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(s).padStart(2, "0");
    }

    function toggle(): void {
        root.player?.togglePlaying();
    }

    function next(): void {
        root.player?.next();
    }

    function previous(): void {
        root.player?.previous();
    }
}
