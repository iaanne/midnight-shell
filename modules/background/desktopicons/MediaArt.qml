pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Album art clipped to a rounded rect, with a placeholder when there is none.
StyledClippingRect {
    id: root

    property string url: ""
    property bool rounded: true

    radius: root.rounded ? Tokens.rounding.large : 0
    color: Colours.palette.m3surfaceContainerHigh

    MaterialIcon {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        text: "music_note"
        color: Colours.palette.m3outline
        fontStyle: Tokens.font.icon.size(Math.max(16, root.height * 0.4)).build()
    }

    Image {
        id: art

        anchors.fill: parent
        source: root.url
        visible: root.url !== ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        retainWhileLoading: true
        sourceSize.width: Math.max(48, Math.round(width))
        sourceSize.height: Math.max(48, Math.round(height))
    }
}
