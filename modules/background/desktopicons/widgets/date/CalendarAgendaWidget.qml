pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// A week agenda. Midnight has no calendar backend, so this lists the days of
// the coming week; hook a source in later and the rows are already here.
Item {
    id: root

    property var frame
    property var controller

    readonly property DateInfo info: DateInfo {}

    readonly property var days: {
        const out = [];
        for (let i = 0; i < 7; i++)
            out.push(new Date(info.today.getFullYear(), info.today.getMonth(), info.today.getDate() + i));
        return out;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.extraSmall
            text: info.month.toUpperCase() + " " + info.today.getFullYear()
            color: Colours.palette.m3primary
            font: Tokens.font.label.medium
            elide: Text.ElideRight
        }

        Repeater {
            model: root.days

            RowLayout {
                id: row

                required property var modelData

                readonly property bool isToday: modelData.toDateString() === info.today.toDateString()

                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledRect {
                    Layout.preferredWidth: Math.min(row.height, 34)
                    Layout.preferredHeight: width
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: row.isToday ? Colours.palette.m3primary : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: row.modelData.getDate()
                        color: row.isToday ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Qt.locale().dayName(row.modelData.getDay(), Locale.LongFormat)
                    color: row.isToday ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
