import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    property string label
    property string value

    Layout.fillWidth: true
    spacing: 0

    StyledText {
        Layout.fillWidth: true
        text: root.value
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.medium
        elide: Text.ElideRight
    }

    StyledText {
        Layout.fillWidth: true
        text: root.label
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
        elide: Text.ElideRight
    }
}
