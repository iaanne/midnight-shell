pragma ComponentBehavior: Bound

import "../.."
import QtQuick

// A conventional dial with hour marks and three hands.
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
        showTicks: true
        showNumbers: false
    }
}
