pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

// One hand of an analog face. Sized to the face it is added to (anchors.fill)
// and rotated about the face centre.
Item {
    id: root

    property real angle: 0
    property real length: 0
    property real tail: 0
    property real thickness: 4
    property color colour: Colours.palette.m3onSurface

    rotation: root.angle

    StyledRect {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 - root.length
        width: root.thickness
        height: root.length
        radius: root.thickness / 2
        color: root.colour
    }

    StyledRect {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2
        width: root.thickness
        height: root.tail
        radius: root.thickness / 2
        color: root.colour
    }
}
