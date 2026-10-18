pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// The month as a headline with the day number under it.
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
            text: time.month.toUpperCase()
            color: Colours.palette.m3primary
            font: Tokens.font.title.medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: time.day
            color: Colours.palette.m3onSurface
            font: Tokens.font.headline.builders.medium.scale(Math.max(1, root.height / 120)).weight(Font.Bold).build()
            fontSizeMode: Text.Fit
            minimumPointSize: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            Layout.fillWidth: true
            text: time.weekday
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
