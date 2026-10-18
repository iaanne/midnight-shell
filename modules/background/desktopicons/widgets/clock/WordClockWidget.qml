pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The time written out: "twenty five past ten".
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    StyledText {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        text: time.wordHours()
        color: Colours.palette.m3onSurface
        font: Tokens.font.headline.builders.medium.scale(Math.max(1, root.height / 130)).weight(Font.Medium).build()
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        fontSizeMode: Text.Fit
        minimumPointSize: 12
    }
}
