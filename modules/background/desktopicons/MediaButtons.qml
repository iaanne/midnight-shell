pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls

// Prev / play-pause / next transport buttons, sized to the space they get.
RowLayout {
    id: root

    property var playback
    property bool round: true
    property var iconFont: Tokens.font.icon.medium

    spacing: Tokens.spacing.extraSmall

    IconButton {
        type: IconButton.Text
        icon: "skip_previous"
        font: root.iconFont
        disabled: !root.playback?.player?.canGoPrevious
        onClicked: root.playback?.previous()
    }

    IconButton {
        type: IconButton.Tonal
        isRound: root.round
        icon: root.playback?.isPlaying ? "pause" : "play_arrow"
        font: root.iconFont
        disabled: !root.playback?.player?.canTogglePlaying
        onClicked: root.playback?.toggle()
    }

    IconButton {
        type: IconButton.Text
        icon: "skip_next"
        font: root.iconFont
        disabled: !root.playback?.player?.canGoNext
        onClicked: root.playback?.next()
    }
}
