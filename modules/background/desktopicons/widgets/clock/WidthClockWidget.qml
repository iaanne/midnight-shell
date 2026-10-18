pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A wide, widely-tracked time over a rule.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    Column {
        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: time.hm
            font: Tokens.font.clock.size(Math.max(20, root.height * 0.45)).letterSpacing(Math.max(4, root.width * 0.02) / Math.max(20, root.height * 0.45)).weight(Font.Light).build()
            color: Colours.palette.m3onSurface
        }

        StyledRect {
            width: parent.width
            height: 2
            radius: 1
            color: Qt.alpha(Colours.palette.m3onSurface, 0.25)
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: time.dateLong
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }
}
