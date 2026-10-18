pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Nothing's wheel: each digit sits in its own rounded slot, with a red accent.
Item {
    id: root

    property var frame
    property var controller

    readonly property ClockTime time: ClockTime {}

    readonly property string digits: time.hourStr + time.minuteStr

    RowLayout {
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: root.digits.split("")

            Item {
                id: slot

                required property string modelData

                Layout.preferredWidth: Math.max(24, root.height * 0.5)
                Layout.preferredHeight: Math.max(36, root.height * 0.8)

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.7)

                    StyledText {
                        anchors.centerIn: parent
                        text: slot.modelData
                        font: Tokens.font.mono.builders.large.scale(Math.max(1, root.height / 100)).build()
                        color: Colours.palette.m3onSurface
                    }
                }
            }
        }

        StyledRect {
            Layout.preferredWidth: Math.max(6, root.height * 0.08)
            Layout.preferredHeight: width
            radius: width / 2
            color: Colours.palette.m3error
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
