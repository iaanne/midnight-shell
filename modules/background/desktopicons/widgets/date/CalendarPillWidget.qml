pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// A month grid with a pill underneath carrying the month and day.
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

        MonthGrid {
            Layout.fillWidth: true
            Layout.fillHeight: true
            showHeader: false
            showWeekdays: true
            interactive: true
        }

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: pill.implicitWidth + Tokens.padding.large
            implicitHeight: pill.implicitHeight + Tokens.padding.extraSmall
            radius: height / 2
            color: Qt.alpha(Colours.palette.m3primary, 0.18)

            StyledText {
                id: pill

                anchors.centerIn: parent
                text: info.month + " " + info.day
                color: Colours.palette.m3primary
                font: Tokens.font.label.medium
            }
        }
    }
}
