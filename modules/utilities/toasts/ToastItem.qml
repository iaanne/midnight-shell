import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.effects
import qs.components.images
import qs.services

StyledRect {
    id: root

    required property Toast modelData

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: layout.implicitHeight + Tokens.padding.large

    radius: Tokens.rounding.large
    color: {
        let baseColor = Colours.palette.m3surface;
        if (root.modelData.type === Toast.Success)
            baseColor = Colours.palette.m3successContainer;
        else if (root.modelData.type === Toast.Warning)
            baseColor = Colours.palette.m3secondary;
        else if (root.modelData.type === Toast.Error)
            baseColor = Colours.palette.m3errorContainer;

        if (GlobalConfig.utilities.toasts.transparency && !(GameMode.enabled && GlobalConfig.utilities.gameMode.disableToastTransparency)) {
            return Qt.alpha(baseColor, Math.max(0.1, GlobalConfig.utilities.toasts.transparencyBase));
        }
        return baseColor;
    }

    border.width: 1
    border.color: {
        let colour = Colours.palette.m3outlineVariant;
        if (root.modelData.type === Toast.Success)
            colour = Colours.palette.m3success;
        if (root.modelData.type === Toast.Warning)
            colour = Colours.palette.m3secondaryContainer;
        if (root.modelData.type === Toast.Error)
            colour = Colours.palette.m3error;
        return Qt.alpha(colour, 0.3);
    }

    Elevation {
        anchors.fill: parent
        radius: parent.radius
        opacity: parent.opacity
        z: -1
        level: 3
        visible: !GlobalConfig.utilities.toasts.transparency || (GameMode.enabled && GlobalConfig.utilities.gameMode.disableToastTransparency)
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        StyledClippingRect {
            id: iconTile

            // The now-playing toast is the only one that uses the "music_note"
            // icon, so use it to swap the icon tile for the current album art.
            readonly property bool isNowPlaying: root.modelData.icon === "music_note"
            readonly property string artUrl: iconTile.isNowPlaying ? Players.getArtUrl(Players.active) : ""

            radius: Tokens.rounding.large
            color: {
                if (root.modelData.type === Toast.Success)
                    return Colours.palette.m3success;
                if (root.modelData.type === Toast.Warning)
                    return Colours.palette.m3secondaryContainer;
                if (root.modelData.type === Toast.Error)
                    return Colours.palette.m3error;
                return Colours.palette.m3surfaceContainerHigh;
            }

            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Tokens.padding.large

            FadeImage {
                id: art

                anchors.fill: parent
                source: iconTile.artUrl
                visible: source != ""
            }

            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                visible: !art.visible
                text: root.modelData.icon
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Colours.palette.m3onSuccess;
                    if (root.modelData.type === Toast.Warning)
                        return Colours.palette.m3onSecondaryContainer;
                    if (root.modelData.type === Toast.Error)
                        return Colours.palette.m3onError;
                    return Colours.palette.m3onSurfaceVariant;
                }
                fontStyle: Tokens.font.icon.builders.large.scale(1.2).build()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: title

                Layout.fillWidth: true
                text: Tr.trMarked(root.modelData.title)
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Colours.palette.m3onSuccessContainer;
                    if (root.modelData.type === Toast.Warning)
                        return Colours.palette.m3onSecondary;
                    if (root.modelData.type === Toast.Error)
                        return Colours.palette.m3onErrorContainer;
                    return Colours.palette.m3onSurface;
                }
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                textFormat: Text.StyledText
                text: Tr.trMarked(root.modelData.message)
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Colours.palette.m3onSuccessContainer;
                    if (root.modelData.type === Toast.Warning)
                        return Colours.palette.m3onSecondary;
                    if (root.modelData.type === Toast.Error)
                        return Colours.palette.m3onErrorContainer;
                    return Colours.palette.m3onSurface;
                }
                opacity: 0.8
                elide: Text.ElideRight
            }
        }
    }

    Behavior on border.color {
        CAnim {}
    }
}
