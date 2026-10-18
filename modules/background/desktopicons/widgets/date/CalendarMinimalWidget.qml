pragma ComponentBehavior: Bound

import "../.."
import QtQuick

// A bare month grid: no header, no weekday row, just the days.
Item {
    id: root

    property var frame
    property var controller

    MonthGrid {
        anchors.fill: parent
        showHeader: false
        showWeekdays: false
        interactive: true
    }
}
