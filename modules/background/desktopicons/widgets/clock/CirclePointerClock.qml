pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components

// A minimal dial: no ticks, hands ending in round pointers, accent seconds.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    AnalogFace {
        anchors.fill: parent
        time: time
        showTicks: false
        showNumbers: false
        faceOpacity: 0.35

        // Pointer caps at the tip of each hand.
        Item {
            anchors.fill: parent
            rotation: time.hourAngle

            StyledRect {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - parent.width * 0.24
                width: parent.width * 0.09
                height: width
                radius: width / 2
                color: Colours.palette.m3onSurface
            }
        }

        Item {
            anchors.fill: parent
            rotation: time.minuteAngle

            StyledRect {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - parent.width * 0.35
                width: parent.width * 0.07
                height: width
                radius: width / 2
                color: Colours.palette.m3onSurface
            }
        }
    }
}
