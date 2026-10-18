pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// Three cards: today and the next two days.
Item {
    id: root

    property var frame
    property var controller

    readonly property DateInfo info: DateInfo {}

    readonly property var days: [0, 1, 2].map(offset => new Date(info.today.getFullYear(), info.today.getMonth(), info.today.getDate() + offset))

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: root.days

            StyledRect {
                id: card

                required property var modelData
                required property int index

                readonly property bool isToday: index === 0

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.large
                color: card.isToday ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.locale().dayName(card.modelData.getDay(), Locale.NarrowFormat)
                        color: card.isToday ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: card.modelData.getDate()
                        color: card.isToday ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        font: Tokens.font.clock.size(Math.max(20, root.height * 0.35)).weight(Font.Bold).build()
                        fontSizeMode: Text.Fit
                        minimumPointSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
