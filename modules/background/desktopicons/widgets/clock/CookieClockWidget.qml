pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Effects
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

// The Material "cookie" face: a scalloped shape behind a clean analog dial.
Item {
    id: root

    property var frame
    property var controller

    readonly property ClockTime time: ClockTime {}

    readonly property real size: Math.min(width, height)

    Item {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        layer.enabled: true
        opacity: Qt.alpha(Colours.palette.m3primaryContainer, 1)

        MaterialShape {
            id: shape

            implicitSize: root.size
            shape: MaterialShape.Cookie12Sided
            color: Colours.palette.m3primaryContainer
            rotation: time.secondAngle * 0.05

            Behavior on rotation {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
    }

    AnalogFace {
        anchors.centerIn: parent
        width: root.size * 0.7
        height: root.size * 0.7
        time: time
        showTicks: true
        showNumbers: false
        faceOpacity: 0
        handColour: Colours.palette.m3onPrimaryContainer
        secondColour: Colours.palette.m3onPrimaryContainer
        tickColour: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.6)
    }
}
