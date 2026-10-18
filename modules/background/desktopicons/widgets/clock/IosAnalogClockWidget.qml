pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components

// A clean analog face: no ticks, a slim accent second hand, a date window.
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
        showNumbers: false
        faceOpacity: 0.4
        handColour: Colours.palette.m3onSurface
    }

    StyledRect {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.08
        width: dateText.implicitWidth + Tokens.padding.small * 2
        height: dateText.implicitHeight + Tokens.padding.extraSmall
        radius: Tokens.rounding.small
        color: Qt.alpha(Colours.palette.m3primary, 0.15)

        StyledText {
            id: dateText

            anchors.centerIn: parent
            text: time.monthShort + " " + time.day
            color: Colours.palette.m3primary
            font: Tokens.font.label.small
        }
    }
}
