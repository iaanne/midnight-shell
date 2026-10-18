pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The time stretched to fill whatever box it is given, plus the date.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    Column {
        anchors.fill: parent
        spacing: 0

        StyledText {
            width: parent.width
            height: parent.height - (root.height > 80 ? Tokens.font.body.medium.pointSize * 2 : 0)
            text: time.hm
            font: Tokens.font.clock.size(96).weight(Font.Bold).build()
            color: Colours.palette.m3onSurface
            fontSizeMode: Text.Fit
            minimumPointSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            width: parent.width
            visible: root.height > 80
            text: time.dateShort
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
