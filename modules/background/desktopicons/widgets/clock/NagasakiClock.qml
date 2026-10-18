pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Slim time in a thin face, with a small-caps date over a hairline rule.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: time.hm
            font: Tokens.font.clock.size(Math.max(18, root.height * 0.5)).weight(Font.ExtraLight).letterSpacing(2).build()
            fontSizeMode: Text.Fit
            minimumPointSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            implicitHeight: 2
            radius: 1
            color: Colours.palette.m3primary
        }

        StyledText {
            Layout.fillWidth: true
            text: time.weekday.toUpperCase() + " · " + time.monthShort.toUpperCase() + " " + time.day
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
