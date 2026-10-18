pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Plain digital time with the date underneath.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: time.hm
            font: Tokens.font.clock.size(Math.max(20, root.height * 0.5)).weight(Font.DemiBold).build()
            color: Colours.palette.m3onSurface
            fontSizeMode: Text.Fit
            minimumPointSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.height > 90
            text: time.dateShort
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
