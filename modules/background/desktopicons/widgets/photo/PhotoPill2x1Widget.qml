pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A photo with a floating pill carrying the city and temperature.
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
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.medium
        width: pill.implicitWidth + Tokens.padding.large
        height: pill.implicitHeight + Tokens.padding.small
        radius: height / 2
        color: Qt.alpha("#000000", 0.45)

        Row {
            id: pill

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.icon
                color: "white"
                fontStyle: Tokens.font.icon.builders.small.build()
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: (Weather.city ? Weather.city + "  " : "") + Weather.temp
                color: "white"
                font: Tokens.font.label.medium
            }
        }
    }
}
