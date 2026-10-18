pragma ComponentBehavior: Bound

import "../.."
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// An iOS-style rounded tile: a big time with the date and a subtle glyph.
Item {
    id: root

    property var frame
    property var controller

    ClockTime {
        id: time
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.75)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: time.hm
                font: Tokens.font.headline.builders.large.scale(Math.max(1, root.height / 100)).weight(Font.Bold).build()
                color: Colours.palette.m3onSurface
                fontSizeMode: Text.Fit
                minimumPointSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.height > 80
                text: time.dateShort
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
