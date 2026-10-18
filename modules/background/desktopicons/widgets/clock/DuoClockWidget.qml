pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Two halves split by a divider: the time and the date.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: time.hm
            font: Tokens.font.clock.size(Math.max(20, root.height * 0.5)).weight(Font.Bold).build()
            fontSizeMode: Text.Fit
            minimumPointSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledRect {
            Layout.fillHeight: true
            Layout.topMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.padding.small
            width: 1
            color: Qt.alpha(Colours.palette.m3onSurface, 0.2)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: time.weekday
                font: Tokens.font.title.small
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: time.monthShort + " " + time.day
                color: Colours.palette.m3onSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
