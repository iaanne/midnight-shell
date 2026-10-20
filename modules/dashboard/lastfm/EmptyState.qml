pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    property string icon: "music_note"
    property string title
    property string subtitle
    property string actionText
    property bool loading: false
    property bool active: true

    signal action()

    spacing: Tokens.spacing.small

    LoadingIndicator {
        visible: root.loading
        animated: root.active
        Layout.alignment: Qt.AlignHCenter
        implicitSize: 34
    }

    MaterialIcon {
        visible: !root.loading
        Layout.alignment: Qt.AlignHCenter
        text: root.icon
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).build()
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.medium
        wrapMode: Text.Wrap
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.subtitle !== ""
        horizontalAlignment: Text.AlignHCenter
        text: root.subtitle
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        wrapMode: Text.Wrap
    }

    TextButton {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.small
        visible: root.actionText !== ""
        text: root.actionText
        onClicked: root.action()
    }
}
