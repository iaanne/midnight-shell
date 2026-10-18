pragma ComponentBehavior: Bound

import "../.."
import QtQuick

// The month grid turned wide: a header and the weekday row, no arrows.
Item {
    id: root

    property var frame
    property var controller

    MonthGrid {
        anchors.fill: parent
        showHeader: true
        showWeekdays: true
        interactive: false
    }
}
