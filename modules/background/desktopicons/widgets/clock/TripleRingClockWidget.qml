pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Three thick concentric rings for hours, minutes and seconds.
Item {
    id: root

    property var frame
    property var controller

    readonly property ClockTime time: ClockTime {}

    readonly property real size: Math.min(width, height)

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size
        strokeWidth: Math.max(4, root.size * 0.07)
        value: (time.hours % 12) / 12
        fgColour: Colours.palette.m3primary
        bgColour: Qt.alpha(Colours.palette.m3primary, 0.15)
        hasEndIndicator: true
    }

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size * 0.72
        strokeWidth: Math.max(4, root.size * 0.06)
        value: time.minutes / 60
        fgColour: Colours.palette.m3secondary
        bgColour: Qt.alpha(Colours.palette.m3secondary, 0.15)
        hasEndIndicator: true
    }

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size * 0.46
        strokeWidth: Math.max(3, root.size * 0.05)
        value: time.seconds / 60
        fgColour: Colours.palette.m3tertiary
        bgColour: Qt.alpha(Colours.palette.m3tertiary, 0.15)
    }

    StyledText {
        anchors.centerIn: parent
        text: time.hourStr + ":" + time.minuteStr
        font: Tokens.font.title.small
        color: Colours.palette.m3onSurface
    }
}
