pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A reusable analog dial: tick marks, optional numbers and the three hands.
// Variants style it through properties rather than redrawing the face.
Item {
    id: root

    property var time: null
    property bool showTicks: true
    property bool showNumbers: false
    property bool showSecond: true
    property bool showMinute: true
    property color tickColour: Colours.palette.m3onSurfaceVariant
    property color handColour: Colours.palette.m3onSurface
    property color secondColour: Colours.palette.m3primary
    property real faceOpacity: 1

    readonly property real radius: Math.min(width, height) / 2
    readonly property real tickLength: Math.max(4, radius * 0.1)

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.55)
        opacity: root.faceOpacity

        Repeater {
            model: 12

            StyledRect {
                required property int index

                readonly property real angle: index * 30 * Math.PI / 180

                width: index % 3 === 0 ? 3 : 1.5
                height: root.tickLength * (index % 3 === 0 ? 1 : 0.6)
                radius: width / 2
                color: root.tickColour
                visible: root.showTicks
                x: parent.width / 2 + Math.sin(angle) * (root.radius - height * 0.8) - width / 2
                y: parent.height / 2 - Math.cos(angle) * (root.radius - height * 0.8) - height / 2
            }
        }

        Repeater {
            model: root.showNumbers ? 12 : 0

            StyledText {
                required property int index

                readonly property real angle: index * 30 * Math.PI / 180
                readonly property int num: index === 0 ? 12 : index

                text: num
                color: root.tickColour
                font: Tokens.font.title.small
                x: parent.width / 2 + Math.sin(angle) * (root.radius * 0.78) - width / 2
                y: parent.height / 2 - Math.cos(angle) * (root.radius * 0.78) - height / 2
            }
        }
    }

    ClockHand {
        anchors.fill: parent
        angle: root.time?.hourAngle ?? 0
        length: root.radius * 0.5
        tail: root.radius * 0.1
        thickness: Math.max(4, root.radius * 0.07)
        colour: root.handColour
    }

    ClockHand {
        anchors.fill: parent
        angle: root.time?.minuteAngle ?? 0
        length: root.radius * 0.72
        tail: root.radius * 0.12
        thickness: Math.max(3, root.radius * 0.05)
        colour: root.handColour
    }

    ClockHand {
        anchors.fill: parent
        visible: root.showSecond
        angle: root.time?.secondAngle ?? 0
        length: root.radius * 0.8
        tail: root.radius * 0.16
        thickness: Math.max(2, root.radius * 0.025)
        colour: root.secondColour
    }

    StyledRect {
        anchors.centerIn: parent
        width: Math.max(8, root.radius * 0.12)
        height: width
        radius: width / 2
        color: root.secondColour
    }
}
