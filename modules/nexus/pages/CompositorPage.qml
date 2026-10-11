pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Compositor")

    readonly property var caps: Compositor.capabilities
    readonly property var capKeys: caps ? Object.keys(caps).filter(k => k !== "keybindSource") : []

    function capLabel(key: string): string {
        return key.replace(/([A-Z])/g, " $1").toLowerCase();
    }

    function capValue(key: string): string {
        return caps[key] ? Tr.tr("Supported") : Tr.tr("Not supported");
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall

        SectionHeader {
            first: true
            text: Tr.tr("Status")
        }

        InfoRow {
            first: true
            label: Tr.tr("Compositor")
            value: Compositor.compositorName
        }

        InfoRow {
            label: Tr.tr("Kind")
            value: Compositor.kind
        }

        InfoRow {
            last: true
            label: Tr.tr("Available")
            value: Compositor.available ? Tr.tr("Yes") : Tr.tr("No")
        }

        SectionHeader {
            text: Tr.tr("Capabilities")
        }

        Repeater {
            model: root.capKeys

            InfoRow {
                required property string modelData
                required property int index

                first: index === 0
                last: index === root.capKeys.length - 1
                label: root.capLabel(modelData)
                value: root.capValue(modelData)
            }
        }

        SectionHeader {
            text: Tr.tr("Keybinds")
        }

        InfoRow {
            first: true
            label: Tr.tr("Source")
            value: Compositor.capabilities.keybindSource ?? Tr.tr("None")
        }

        InfoRow {
            last: true
            label: Tr.tr("Config path")
            value: Compositor.keybindConfigPath || Tr.tr("—")
        }
    }
}
