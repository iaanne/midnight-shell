pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services

// Album / artist art with a rounded clip and a placeholder.
StyledClippingRect {
    id: root

    property string url: ""
    property bool circular: false

    radius: root.circular ? width / 2 : Tokens.rounding.large
    color: Colours.palette.m3surfaceContainerHigh

    MaterialIcon {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        text: "music_note"
        color: Colours.palette.m3outline
        fontStyle: Tokens.font.icon.size(Math.max(16, root.height * 0.35)).build()
    }

    FadeImage {
        id: art

        anchors.fill: parent
        source: root.url
        visible: root.url !== ""
        fillMode: Image.PreserveAspectCrop
    }
}
