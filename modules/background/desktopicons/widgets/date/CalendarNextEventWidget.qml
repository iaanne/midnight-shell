pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// Today's date, large, with a line reserved for the next event. Without a
// calendar source the line stays quiet.
Item {
    id: root

    property var frame
    property var controller

    DateInfo {
        id: info
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            text: qsTr("TODAY")
            color: Colours.palette.m3primary
            font: Tokens.font.label.small
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: info.day
                color: Colours.palette.m3onSurface
                font: Tokens.font.clock.size(Math.max(24, root.height * 0.3)).weight(Font.Bold).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                text: info.weekday + "\n" + info.month
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("No upcoming events")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }
}
