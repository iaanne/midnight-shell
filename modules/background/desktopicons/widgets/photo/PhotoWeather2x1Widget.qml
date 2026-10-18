pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A photo with the current conditions along the bottom.
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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.5
        bottomLeftRadius: Tokens.rounding.extraLarge
        bottomRightRadius: Tokens.rounding.extraLarge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha("#000000", 0.66)
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: Weather.icon
            color: "white"
            fontStyle: Tokens.font.icon.builders.medium.build()
        }

        StyledText {
            Layout.fillWidth: true
            text: Weather.description || Weather.city
            color: "white"
            font: Tokens.font.title.small
            elide: Text.ElideRight
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Weather.temp
            color: "white"
            font: Tokens.font.title.medium
        }
    }
}
