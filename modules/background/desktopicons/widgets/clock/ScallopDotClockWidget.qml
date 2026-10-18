pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A dial ringed with dots marking each hour, hands in the middle.
Item {
    id: root

    property var frame
    property var controller

    readonly property ClockTime time: ClockTime {}

    readonly property real radius: Math.min(width, height) / 2

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.5)
    }

    Repeater {
        model: 24

        StyledRect {
            required property int index

            readonly property real angle: index * 15 * Math.PI / 180
            readonly property bool major: index % 2 === 0
            readonly property bool lit: time.hours % 12 * 2 + (time.minutes >= 30 ? 1 : 0) === index

            width: major ? 5 : 3
            height: width
            radius: width / 2
            color: lit ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.5)
            x: root.width / 2 + Math.sin(angle) * (root.radius * 0.86) - width / 2
            y: root.height / 2 - Math.cos(angle) * (root.radius * 0.86) - height / 2
        }
    }

    AnalogFace {
        anchors.fill: parent
        time: time
        showTicks: false
        showNumbers: false
        faceOpacity: 0
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.radius * 0.16
        text: time.dateShort
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }
}
