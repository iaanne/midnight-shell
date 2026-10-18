import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Desktop clock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        // The clock is a widget now: where it sits and how big it is comes from
        // the widget grid, so this page only styles it.
        NavRow {
            first: true
            last: true
            icon: "widgets"
            text: qsTr("Add or move the clock")
            subtext: qsTr("The clock lives in the desktop widget grid")
            onClicked: root.nState.currentPageIdx = PageRegistry.indexForKey("desktop")
        }

        SectionHeader {
            text: qsTr("Appearance")
        }

        ToggleRow {
            first: true
            last: true
            Layout.fillWidth: true
            text: qsTr("Invert colors")
            subtext: qsTr("Invert the clock color when using light wallpaper")
            configNode: root.targetConfig.background.desktopClock
            propertyName: "invertColors"
            checked: root.targetConfig.background.desktopClock.invertColors
            onToggled: {
                root.targetConfig.background.desktopClock.invertColors = checked;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Background")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable background")
            configNode: root.targetConfig.background.desktopClock.background
            propertyName: "enabled"
            checked: root.targetConfig.background.desktopClock.background.enabled
            onToggled: {
                root.targetConfig.background.desktopClock.background.enabled = checked;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.targetConfig.background.desktopClock.background
            propertyName: "opacity"
            value: root.targetConfig.background.desktopClock.background.opacity
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => {
                root.targetConfig.background.desktopClock.background.opacity = v;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopClock.background.enabled
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Blur")
            configNode: root.targetConfig.background.desktopClock.background
            propertyName: "blur"
            checked: root.targetConfig.background.desktopClock.background.blur
            onToggled: {
                root.targetConfig.background.desktopClock.background.blur = checked;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopClock.background.enabled
        }

        SectionHeader {
            text: qsTr("Shadow")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable shadow")
            configNode: root.targetConfig.background.desktopClock.shadow
            propertyName: "enabled"
            checked: root.targetConfig.background.desktopClock.shadow.enabled
            onToggled: {
                root.targetConfig.background.desktopClock.shadow.enabled = checked;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.targetConfig.background.desktopClock.shadow
            propertyName: "opacity"
            value: root.targetConfig.background.desktopClock.shadow.opacity
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => {
                root.targetConfig.background.desktopClock.shadow.opacity = v;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopClock.shadow.enabled
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Blur strength")
            configNode: root.targetConfig.background.desktopClock.shadow
            propertyName: "blur"
            value: root.targetConfig.background.desktopClock.shadow.blur / 2.0
            valueLabel: (value * 2.0).toFixed(1)
            onMoved: v => {
                root.targetConfig.background.desktopClock.shadow.blur = v * 2.0;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopClock.shadow.enabled
        }
    }
}
