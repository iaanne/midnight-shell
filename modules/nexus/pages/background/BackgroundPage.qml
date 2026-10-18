import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // The clock and the wallpaper lyrics are widgets now, so what used to be
    // "Enabled" is whether one is placed on the grid.
    readonly property bool clockPlaced: Object.keys(DesktopLayout.widgets).some(id => DesktopLayout.widgets[id].type === "desktopClock")
    readonly property bool lyricsPlaced: Object.keys(DesktopLayout.widgets).some(id => DesktopLayout.widgets[id].type === "lyrics")
    readonly property bool lyricsOverlay: root.targetConfig.background.desktopLyrics.enabled && root.targetConfig.background.desktopLyrics.overlay

    title: qsTr("Background elements")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        NavRow {
            first: true
            icon: "schedule"
            text: qsTr("Desktop clock")
            subtext: root.clockPlaced ? qsTr("Shown on the desktop") : qsTr("Hidden")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            icon: "lyrics"
            text: qsTr("Desktop lyrics")
            subtext: root.lyricsOverlay ? qsTr("Shown as an overlay") : root.lyricsPlaced ? qsTr("Shown on the desktop") : qsTr("Hidden")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            icon: "equalizer"
            text: qsTr("Background visualiser")
            subtext: root.targetConfig.background.visualiser.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: root.nState.openSubPage(3)
        }

        NavRow {
            last: true
            icon: "pets"
            text: qsTr("Shimeji characters")
            subtext: root.targetConfig.shimeji.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: root.nState.openSubPage(4)
        }
    }
}
