pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A dial with the hours printed around the rim.
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
        showNumbers: true
        faceOpacity: 1
    }
}
