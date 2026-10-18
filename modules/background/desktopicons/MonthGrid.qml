pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A month grid: a header with the month name and arrows, then the days. Shared
// by the calendar variants so they only differ in framing.
Item {
    id: root

    property bool showHeader: true
    property bool showWeekdays: true
    property bool interactive: true
    property bool accentToday: true

    readonly property date today: Time.date
    property int year: today.getFullYear()
    property int month: today.getMonth()
    readonly property int firstDay: Qt.locale().firstDayOfWeek
    readonly property int lead: (new Date(year, month, 1).getDay() - firstDay + 7) % 7
    // How many week rows the month needs (5 or 6).
    readonly property int rows: Math.ceil((lead + new Date(year, month + 1, 0).getDate()) / 7)

    function shift(delta: int): void {
        const d = new Date(year, month + delta, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }

    function cellDate(index: int): date {
        return new Date(year, month, index - lead + 1);
    }

    WheelHandler {
        enabled: root.interactive
        acceptedModifiers: Qt.NoModifier
        onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true
            visible: root.showHeader

            StyledText {
                Layout.fillWidth: true
                text: Qt.locale().standaloneMonthName(root.month) + " " + root.year
                font: Tokens.font.title.small
                color: Colours.palette.m3primary
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.year = root.today.getFullYear();
                        root.month = root.today.getMonth();
                    }
                }
            }

            IconButton {
                type: IconButton.Text
                icon: "chevron_left"
                visible: root.interactive
                onClicked: root.shift(-1)
            }

            IconButton {
                type: IconButton.Text
                icon: "chevron_right"
                visible: root.interactive
                onClicked: root.shift(1)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: root.showWeekdays ? 7 : 0

                StyledText {
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(parent.height / 8, Tokens.font.label.small.pointSize * 2)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }

            Repeater {
                model: root.rows * 7

                Item {
                    required property int index

                    readonly property date date: root.cellDate(index)
                    readonly property bool inMonth: date.getMonth() === root.month
                    readonly property bool isToday: date.toDateString() === root.today.toDateString()

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StyledRect {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2
                        height: width
                        radius: width / 2
                        color: parent.isToday && root.accentToday ? Colours.palette.m3primary : "transparent"
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: parent.date.getDate()
                        font: Tokens.font.label.medium
                        color: parent.isToday && root.accentToday ? Colours.palette.m3onPrimary : parent.inMonth ? Colours.palette.m3onSurface : Colours.palette.m3outlineVariant
                    }
                }
            }
        }
    }
}
