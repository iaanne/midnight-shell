pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Bold numerals with a hairline date, on a soft tinted panel.
Item {
    id: root

    property var frame
    property var controller

    // The digits shrink to fit their columns, so the colon has to follow the
    // size they actually land on rather than a fraction of the widget height.
    readonly property real digitSize: {
        const sizes = [hourText.fontInfo.pointSize, minuteText.fontInfo.pointSize].filter(s => s > 0);
        return sizes.length > 0 ? Math.min(...sizes) : Math.max(20, root.height * 0.6);
    }

    ClockTime {
        id: time
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    id: hourText

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: time.hourStr
                    font: Tokens.font.clock.size(Math.max(20, root.height * 0.6)).weight(Font.Black).build()
                    fontSizeMode: Text.Fit
                    minimumPointSize: 12
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }

                StyledText {
                    Layout.fillHeight: true
                    text: ":"
                    font: Tokens.font.clock.size(root.digitSize).weight(Font.Light).build()
                    color: Colours.palette.m3primary
                    verticalAlignment: Text.AlignVCenter
                }

                StyledText {
                    id: minuteText

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: time.minuteStr
                    font: Tokens.font.clock.size(Math.max(20, root.height * 0.6)).weight(Font.Black).build()
                    fontSizeMode: Text.Fit
                    minimumPointSize: 12
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.height > 90
                text: time.dateLong.toUpperCase()
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
