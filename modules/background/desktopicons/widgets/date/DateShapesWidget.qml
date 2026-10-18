pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import M3Shapes
import Caelestia.Config
import qs.components

// The day number set inside a Material shape.
Item {
    id: root

    property var frame
    property var controller

    readonly property DateInfo info: DateInfo {}

    readonly property real size: Math.min(width, height)

    MaterialShape {
        anchors.centerIn: parent
        implicitSize: root.size
        shape: MaterialShape.Cookie12Sided
        color: Colours.palette.m3primaryContainer
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: info.day
            color: Colours.palette.m3onPrimaryContainer
            font: Tokens.font.clock.size(Math.max(20, root.size * 0.3)).weight(Font.Bold).build()
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: info.monthShort.toUpperCase()
            color: Colours.palette.m3onPrimaryContainer
            font: Tokens.font.label.small
        }
    }
}
