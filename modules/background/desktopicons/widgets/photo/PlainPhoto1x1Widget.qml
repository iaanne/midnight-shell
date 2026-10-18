pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import qs.components

// The plainest photo: the image, softly rounded, nothing else.
Item {
    id: root

    property var frame
    property var controller

    PhotoImage {
        anchors.fill: parent
        frame: root.frame
        path: root.frame?.config?.path ?? ""
        rounded: true
    }
}
