pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Horizontal: the time on the left, the date on the right.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: time.hm
            font: Tokens.font.clock.size(Math.max(18, root.height * 0.5)).weight(Font.DemiBold).build()
            color: Colours.palette.m3onSurface
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                text: time.weekdayShort.toUpperCase()
                color: Colours.palette.m3primary
                font: Tokens.font.label.small
            }

            StyledText {
                text: time.monthShort + " " + time.day
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }
        }
    }
}
