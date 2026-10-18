pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// A strip of the seven days of the current week, today highlighted.
Item {
    id: root

    property var frame
    property var controller

    readonly property DateInfo info: DateInfo {}

    readonly property var days: info.weekDates(info.today)

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.days

            Item {
                id: chip

                required property var modelData

                readonly property bool isToday: modelData.toDateString() === info.today.toDateString()

                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledRect {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    radius: width / 2
                    color: chip.isToday ? Colours.palette.m3primary : "transparent"
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.locale().dayName(chip.modelData.getDay(), Locale.NarrowFormat)
                        color: chip.isToday ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: chip.modelData.getDate()
                        color: chip.isToday ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        font: Tokens.font.label.medium
                    }
                }
            }
        }
    }
}
