pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import qs.components

// A photo filling the whole widget.
Item {
    id: root

    property var frame
    property var controller

    readonly property string path: root.frame?.config?.path ?? ""

    PhotoImage {
        anchors.fill: parent
        frame: root.frame
        path: root.path
        rounded: true
    }
}
