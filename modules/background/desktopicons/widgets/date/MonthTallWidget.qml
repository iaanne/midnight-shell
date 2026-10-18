pragma ComponentBehavior: Bound

import "../.."
import QtQuick

// A tall month view.
Item {
    id: root

    property var frame
    property var controller

    MonthGrid {
        anchors.fill: parent
        showHeader: true
        showWeekdays: true
        interactive: true
    }
}
