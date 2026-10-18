pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// The week as a vertical list: weekday and day, today called out.
Item {
    id: root

    property var frame
    property var controller

    readonly property DateInfo info: DateInfo {}

    readonly property var days: info.weekDates(info.today)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.days

            StyledRect {
                id: row

                required property var modelData

                readonly property bool isToday: modelData.toDateString() === info.today.toDateString()

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.small
                color: row.isToday ? Qt.alpha(Colours.palette.m3primary, 0.2) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small
                    anchors.rightMargin: Tokens.padding.small

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.locale().dayName(row.modelData.getDay(), Locale.LongFormat)
                        color: row.isToday ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: row.modelData.getDate()
                        color: row.isToday ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.title.small
                    }
                }
            }
        }
    }
}
