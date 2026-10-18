pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A photo with just the current temperature laid over the right edge.
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

    StyledRect {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * 0.42
        topRightRadius: Tokens.rounding.extraLarge
        bottomRightRadius: Tokens.rounding.extraLarge
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha("#000000", 0.6)
            }
        }
    }

    StyledText {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Tokens.padding.medium
        text: Weather.temp
        color: "white"
        font: Tokens.font.headline.builders.medium.scale(Math.max(1, root.height / 70)).weight(Font.Bold).build()
    }
}
