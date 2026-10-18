pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Nothing's dot-matrix digital: a monospaced time with a wide dot grid behind it.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    Grid {
        anchors.centerIn: parent
        columns: Math.max(1, Math.floor(root.width / 18))
        spacing: 6

        Repeater {
            model: Math.max(0, Math.floor(root.width / 18) * Math.floor(root.height / 18))

            StyledRect {
                width: 2
                height: 2
                radius: 1
                color: Qt.alpha(Colours.palette.m3onSurface, 0.12)
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: time.hm
            font: Tokens.font.mono.builders.large.scale(Math.max(1, root.height / 90)).weight(Font.Medium).build()
            color: Colours.palette.m3onSurface
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.height > 80
            text: time.dateShort.toUpperCase()
            color: Colours.palette.m3tertiary
            font: Tokens.font.mono.builders.small.scale(1.1).letterSpacing(2).build()
        }
    }
}
