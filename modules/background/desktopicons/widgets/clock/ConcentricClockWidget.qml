pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Three nested rings: hours, minutes, seconds.
Item {
    id: root

    property var frame
    property var controller

    readonly property ClockTime time: ClockTime {}

    readonly property real size: Math.min(width, height)

    readonly property real hourValue: (time.hours % 12) / 12 + time.minutes / 720

    readonly property real minuteValue: time.minutes / 60 + time.seconds / 3600

    readonly property real secondValue: time.seconds / 60

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size
        strokeWidth: Math.max(3, root.size * 0.05)
        value: root.hourValue
        fgColour: Colours.palette.m3primary
        bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.1)
    }

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size * 0.78
        strokeWidth: Math.max(3, root.size * 0.045)
        value: root.minuteValue
        fgColour: Colours.palette.m3secondary
        bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.08)
    }

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size * 0.56
        strokeWidth: Math.max(2, root.size * 0.035)
        value: root.secondValue
        fgColour: Colours.palette.m3tertiary
        bgColour: "transparent"
    }

    StyledText {
        anchors.centerIn: parent
        text: time.hm
        font: Tokens.font.title.small
        color: Colours.palette.m3onSurface
    }
}
