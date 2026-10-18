pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components

// A wide banner: the weekday large on the left, the full date on the right.
Item {
    id: root

    property var frame
    property var controller

    DateInfo {
        id: info
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: info.weekday.toUpperCase()
            color: Colours.palette.m3primary
            font: Tokens.font.title.medium
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: info.monthShort + " " + info.day
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.small
        }
    }
}
