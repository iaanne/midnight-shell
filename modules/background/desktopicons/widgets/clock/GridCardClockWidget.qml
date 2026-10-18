pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Each digit of the time on its own small card.
Item {
    id: root

    property var frame
    property var controller

    readonly property ClockTime time: ClockTime {}

    readonly property string digits: time.hourStr + time.minuteStr

    RowLayout {
        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.digits.split("")

            StyledRect {
                id: cell

                required property string modelData

                Layout.preferredWidth: Math.max(28, root.height * 0.6)
                Layout.preferredHeight: Math.max(40, root.height * 0.85)
                radius: Tokens.rounding.medium
                color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.7)

                StyledText {
                    anchors.centerIn: parent
                    text: cell.modelData
                    font: Tokens.font.clock.size(Math.max(20, root.height * 0.5)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }
}
