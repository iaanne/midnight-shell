pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A round watch face with a seconds arc and the time in the middle.
Item {
    id: root

    property var frame
    property var controller

    readonly property ClockTime time: ClockTime {}

    readonly property real size: Math.min(width, height)

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)
    }

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size * 0.92
        strokeWidth: Math.max(3, root.size * 0.05)
        value: time.seconds / 60
        fgColour: Colours.palette.m3primary
        bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.12)
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: time.hourStr + ":" + time.minuteStr
            font: Tokens.font.title.small
            color: Colours.palette.m3onSurface
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: time.weekdayShort + " " + time.day
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
