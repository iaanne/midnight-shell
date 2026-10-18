import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> alignmentItems: [
        MenuItem {
            text: qsTr("Left")
            value: 0
        },
        MenuItem {
            text: qsTr("Center")
            value: 1
        },
        MenuItem {
            text: qsTr("Right")
            value: 2
        }
    ]

    readonly property list<string> positionValues: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]
    readonly property list<MenuItem> positionItems: [
        MenuItem { text: qsTr("Top Left") },
        MenuItem { text: qsTr("Top Center") },
        MenuItem { text: qsTr("Top Right") },
        MenuItem { text: qsTr("Middle Left") },
        MenuItem { text: qsTr("Middle Center") },
        MenuItem { text: qsTr("Middle Right") },
        MenuItem { text: qsTr("Bottom Left") },
        MenuItem { text: qsTr("Bottom Center") },
        MenuItem { text: qsTr("Bottom Right") }
    ]

    title: qsTr("Desktop lyrics")
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

        // "enabled" is the overlay's master switch now: the wallpaper lyrics are
        // a widget, shown as long as one is placed on the grid.
        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Overlay lyrics")
            subtext: qsTr("Draw lyrics over every window, instead of on the wallpaper")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "overlay"
            checked: root.targetConfig.background.desktopLyrics.enabled && root.targetConfig.background.desktopLyrics.overlay
            onToggled: {
                root.targetConfig.background.desktopLyrics.enabled = checked;
                root.targetConfig.background.desktopLyrics.overlay = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Auto-hide for fullscreen windows")
            subtext: qsTr("Hide wallpaper lyrics when a window is fullscreen")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "autoHideFullscreen"
            checked: root.targetConfig.background.desktopLyrics.autoHideFullscreen
            onToggled: {
                root.targetConfig.background.desktopLyrics.autoHideFullscreen = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Auto-hide for tiled windows")
            subtext: qsTr("Hide wallpaper lyrics when tiled windows are open")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "autoHideTiled"
            checked: root.targetConfig.background.desktopLyrics.autoHideTiled
            onToggled: {
                root.targetConfig.background.desktopLyrics.autoHideTiled = checked;
                root.targetConfig.save();
            }
        }

        // The wallpaper lyrics are a widget now: where they sit and how big they
        // are comes from the widget grid.
        NavRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            icon: "widgets"
            text: qsTr("Add or move the lyrics")
            subtext: qsTr("Wallpaper lyrics live in the desktop widget grid")
            onClicked: root.nState.currentPageIdx = PageRegistry.indexForKey("desktop")
        }

        SectionHeader {
            text: qsTr("App filter")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Filter mode")
            subtext: qsTr("Only show lyrics for specific apps")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "appFilter"
            menuItems: [
                MenuItem { text: qsTr("Disabled") },
                MenuItem { text: qsTr("Whitelist") },
                MenuItem { text: qsTr("Blacklist") }
            ]
            active: {
                switch (root.targetConfig.background.desktopLyrics.appFilter) {
                case AppFilter.Whitelist: return menuItems[1];
                case AppFilter.Blacklist: return menuItems[2];
                default: return menuItems[0];
                }
            }
            onSelected: item => {
                if (item === menuItems[1])
                    root.targetConfig.background.desktopLyrics.appFilter = AppFilter.Whitelist;
                else if (item === menuItems[2])
                    root.targetConfig.background.desktopLyrics.appFilter = AppFilter.Blacklist;
                else
                    root.targetConfig.background.desktopLyrics.appFilter = AppFilter.Disabled;
                root.targetConfig.save();
            }
        }

        TagRow {
            last: true
            label: qsTr("Filtered apps")
            subtext: qsTr("App names to include or exclude (case-insensitive)")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "filteredApps"
            values: root.targetConfig.background.desktopLyrics.filteredApps
            onValueAdded: value => {
                const apps = root.targetConfig.background.desktopLyrics.filteredApps;
                apps.push(value);
                root.targetConfig.background.desktopLyrics.filteredApps = apps;
                root.targetConfig.save();
            }
            onValueRemoved: index => {
                const apps = root.targetConfig.background.desktopLyrics.filteredApps;
                apps.splice(index, 1);
                root.targetConfig.background.desktopLyrics.filteredApps = apps;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopLyrics.appFilter !== AppFilter.Disabled
        }

        SectionHeader {
            text: qsTr("Appearance")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Alignment")
            subtext: qsTr("Text alignment on the wallpaper and in the overlay")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "alignment"
            menuItems: root.alignmentItems
            active: root.alignmentItems.find(i => i.value === root.targetConfig.background.desktopLyrics.alignment) ?? root.alignmentItems[1]
            onSelected: item => {
                root.targetConfig.background.desktopLyrics.alignment = item.value;
                root.targetConfig.save();
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Overlay position")
            subtext: qsTr("Where the overlay sits; the wallpaper widget is moved on the Desktop page")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "position"
            menuItems: root.positionItems
            active: root.positionItems[root.positionValues.indexOf(root.targetConfig.background.desktopLyrics.position)] ?? root.positionItems[4]
            onSelected: item => {
                let idx = root.positionItems.indexOf(item);
                if (idx !== -1) {
                    root.targetConfig.background.desktopLyrics.position = root.positionValues[idx];
                    root.targetConfig.save();
                }
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Scale")
            subtext: qsTr("Multiplies the size on the wallpaper and in the overlay")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "scale"
            value: (root.targetConfig.background.desktopLyrics.scale - 0.5) / 2.5
            valueLabel: (0.5 + value * 2.5).toFixed(1) + "x"
            onMoved: v => {
                root.targetConfig.background.desktopLyrics.scale = 0.5 + v * 2.5;
                root.targetConfig.save();
            }
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: Tr.tr("Height")
            subtext: Tr.tr("Box height in pixels, shows more lines when taller")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "height"
            value: root.targetConfig.background.desktopLyrics.height
            from: 80
            to: 600
            stepSize: 10
            showReset: true
            onMoved: v => {
                root.targetConfig.background.desktopLyrics.height = v;
                root.targetConfig.save();
            }
            onReset: {
                root.targetConfig.background.desktopLyrics.resetOption("height");
            }
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: Tr.tr("Surrounding lines")
            subtext: Tr.tr("Lines shown above and below the current line")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "contextLines"
            value: root.targetConfig.background.desktopLyrics.contextLines
            from: 0
            to: 3
            stepSize: 1
            showReset: true
            onMoved: v => {
                root.targetConfig.background.desktopLyrics.contextLines = v;
                root.targetConfig.save();
            }
            onReset: {
                root.targetConfig.background.desktopLyrics.resetOption("contextLines");
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Invert colors")
            subtext: qsTr("Invert the lyrics color when using light wallpaper")
            configNode: root.targetConfig.background.desktopLyrics
            propertyName: "invertColors"
            checked: root.targetConfig.background.desktopLyrics.invertColors
            onToggled: {
                root.targetConfig.background.desktopLyrics.invertColors = checked;
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
            configNode: root.targetConfig.background.desktopLyrics.background
            propertyName: "enabled"
            checked: root.targetConfig.background.desktopLyrics.background.enabled
            onToggled: {
                root.targetConfig.background.desktopLyrics.background.enabled = checked;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.targetConfig.background.desktopLyrics.background
            propertyName: "opacity"
            value: root.targetConfig.background.desktopLyrics.background.opacity
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => {
                root.targetConfig.background.desktopLyrics.background.opacity = v;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopLyrics.background.enabled
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Blur")
            configNode: root.targetConfig.background.desktopLyrics.background
            propertyName: "blur"
            checked: root.targetConfig.background.desktopLyrics.background.blur
            onToggled: {
                root.targetConfig.background.desktopLyrics.background.blur = checked;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopLyrics.background.enabled
        }

        SectionHeader {
            text: qsTr("Shadow")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable shadow")
            configNode: root.targetConfig.background.desktopLyrics.shadow
            propertyName: "enabled"
            checked: root.targetConfig.background.desktopLyrics.shadow.enabled
            onToggled: {
                root.targetConfig.background.desktopLyrics.shadow.enabled = checked;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.targetConfig.background.desktopLyrics.shadow
            propertyName: "opacity"
            value: root.targetConfig.background.desktopLyrics.shadow.opacity
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => {
                root.targetConfig.background.desktopLyrics.shadow.opacity = v;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopLyrics.shadow.enabled
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Blur strength")
            configNode: root.targetConfig.background.desktopLyrics.shadow
            propertyName: "blur"
            value: root.targetConfig.background.desktopLyrics.shadow.blur / 2.0
            valueLabel: (value * 2.0).toFixed(1)
            onMoved: v => {
                root.targetConfig.background.desktopLyrics.shadow.blur = v * 2.0;
                root.targetConfig.save();
            }
            enabled: root.targetConfig.background.desktopLyrics.shadow.enabled
        }
    }
}
