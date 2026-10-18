pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// The date as a headline: the day number over the weekday and month.
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
            Layout.fillHeight: true
            text: info.day
            color: Colours.palette.m3primary
            font: Tokens.font.clock.size(Math.max(24, root.height * 0.45)).weight(Font.Bold).build()
            fontSizeMode: Text.Fit
            minimumPointSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            Layout.fillWidth: true
            text: info.weekday
            font: Tokens.font.title.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            text: info.month
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
