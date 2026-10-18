pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls as Controls
import qs.components.filedialog
import qs.services
import qs.utils

// A photo from the widget's own `path`, clipped to a rounded rect. With no
// path yet it shows a choose-photo prompt; picking a file writes it back to
// the widget's config through `frame.setConfig`.
StyledClippingRect {
    id: root

    property var frame
    property string path: ""
    property bool rounded: true

    readonly property string chosen: root.path || (root.frame?.config?.path ?? "")
    readonly property string resolved: {
        if (!root.chosen)
            return "";
        return /^(file|https?):\/\//.test(root.chosen) ? root.chosen : "file://" + root.chosen;
    }
    readonly property var pickerCwd: {
        const clean = root.chosen.replace(/^file:\/\//, "");
        const dir = clean.substring(0, clean.lastIndexOf("/"));
        if (dir.startsWith(Paths.home))
            return ["Home", ...dir.substring(Paths.home.length).split("/").filter(s => s.length > 0)];
        return ["Home"];
    }

    function choosePhoto(): void {
        picker.open();
    }

    radius: root.rounded ? Tokens.rounding.extraLarge : 0
    color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.55)

    Image {
        id: image

        anchors.fill: parent
        visible: root.resolved !== "" && status !== Image.Error
        source: root.resolved
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Math.max(96, Math.round(width))
        sourceSize.height: Math.max(96, Math.round(height))
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.resolved === "" || image.status === Image.Error
        cursorShape: Qt.PointingHandCursor
        onClicked: root.choosePhoto()
    }

    Column {
        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall
        visible: root.resolved === "" || image.status === Image.Error

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "add_photo_alternate"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.builders.large.build()
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Choose photo")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    HoverHandler {
        id: hover
    }

    Controls.IconButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.small
        type: Controls.IconButton.Filled
        icon: "add_photo_alternate"
        visible: root.resolved !== "" && hover.hovered
        opacity: visible ? 1 : 0
        onClicked: root.choosePhoto()

        Behavior on opacity {
            CAnim {}
        }
    }

    FileDialog {
        id: picker

        title: qsTr("Choose a photo")
        filterLabel: qsTr("Images")
        filters: Images.validImageExtensions
        cwd: root.pickerCwd
        onAccepted: selected => {
            if (root.frame?.setConfig)
                root.frame.setConfig({ path: selected.replace(/^file:\/\//, "") });
        }
    }
}
