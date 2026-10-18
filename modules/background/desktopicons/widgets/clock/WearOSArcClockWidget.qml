pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A watch face with open arcs: hours on the outer ring, minutes inside.
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
        implicitSize: root.size * 0.94
        strokeWidth: Math.max(3, root.size * 0.06)
        startAngle: -90
        sweepAngle: 360
        value: (time.hours % 12) / 12
        fgColour: Colours.palette.m3primary
        bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.1)
        hasEndIndicator: true
    }

    CircularProgress {
        anchors.centerIn: parent
        implicitSize: root.size * 0.72
        strokeWidth: Math.max(3, root.size * 0.05)
        value: time.minutes / 60
        fgColour: Colours.palette.m3secondary
        bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.08)
        hasEndIndicator: true
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: time.hm
            font: Tokens.font.title.medium
            color: Colours.palette.m3onSurface
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: time.monthShort + " " + time.day
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
