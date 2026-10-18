pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Hour, minute and second stacked in aligned columns.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: 0

        Repeater {
            model: [{
                value: time.hourStr,
                label: qsTr("HOUR")
            }, {
                value: time.minuteStr,
                label: qsTr("MIN")
            }, {
                value: time.seconds < 10 ? "0" + time.seconds : String(time.seconds),
                label: qsTr("SEC")
            }]

            RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: modelData.value
                    font: Tokens.font.clock.size(Math.max(16, root.height / 6)).weight(Font.Bold).build()
                    horizontalAlignment: Text.AlignRight
                }

                StyledText {
                    text: modelData.label
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
