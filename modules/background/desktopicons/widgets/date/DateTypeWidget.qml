pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components

// A typographic date: the weekday and the day/month in contrasting weights.
Item {
    id: root

    property var frame
    property var controller

    DateInfo {
        id: info
    }

    Row {
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: info.weekdayShort.toUpperCase()
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.title.medium
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: info.day + " " + info.monthShort.toUpperCase()
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.medium
        }
    }
}
