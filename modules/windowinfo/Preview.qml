pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property var client

    Layout.preferredWidth: preview.implicitWidth + Tokens.padding.extraLargeIncreased
    Layout.fillHeight: true

    StyledClippingRect {
        id: preview

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: label.top
        anchors.topMargin: Tokens.padding.large
        anchors.bottomMargin: Tokens.spacing.medium

        implicitWidth: view.implicitWidth

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            active: !root.client

            sourceComponent: ColumnLayout {
                spacing: 0

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "web_asset_off"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(3).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("No active client")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.builders.large.size(28).weight(Font.Medium).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("Try switching to a window")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.large
                }
            }
        }

        SafeScreencopy {
            id: view

            anchors.fill: parent

            captureSource: {
                const client = root.client;
                if (!client || !client.wayland) return null; // no wayland surface handle in neutral schema
                if (client.width <= 0 || client.height <= 0) return null;
                return client.wayland;
            }
            live: visible

            constraintSize.width: (root.client && root.client.height > 0) ? parent.height * Math.min(root.screen.width / root.screen.height, root.client.width / root.client.height) : parent.height
            constraintSize.height: parent.height
        }
    }

    StyledText {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.large

        animate: true
        text: {
            const client = root.client;
            if (!client)
                return Tr.tr("No active client");

            const output = Compositor.getOutput(client.output);
            const pos = client.grid;
            // TRANSLATORS: %1 = window title, %2 = monitor name, %3/%4 = column/row position
            return Tr.tr("%1 on monitor %2 at %3, %4").arg(client.title).arg(output?.name ?? "unknown").arg(pos?.col ?? -1).arg(pos?.row ?? -1);
        }
    }
}
