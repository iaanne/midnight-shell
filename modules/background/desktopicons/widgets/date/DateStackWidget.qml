pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// Weekday, day and month stacked in a tall column.
Item {
    id: root

    property var frame
    property var controller

    DateInfo {
        id: info
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: info.weekday.toUpperCase()
            color: Colours.palette.m3primary
            font: Tokens.font.label.medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: info.day
            font: Tokens.font.clock.size(Math.max(24, root.height * 0.3)).weight(Font.Black).build()
            fontSizeMode: Text.Fit
            minimumPointSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            Layout.fillWidth: true
            text: info.month
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.title.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
