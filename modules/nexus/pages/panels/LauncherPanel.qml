pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Launcher")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            configNode: root.targetConfig.launcher
            propertyName: "enabled"
            checked: root.targetConfig.launcher.enabled
            onToggled: {
                root.targetConfig.launcher.enabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            configNode: root.targetConfig.launcher
            propertyName: "showOnHover"
            checked: root.targetConfig.launcher.showOnHover
            onToggled: {
                root.targetConfig.launcher.showOnHover = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Keep content alive")
            subtext: qsTr("Keep content loaded after closing for instant reopening")
            configNode: root.targetConfig.launcher
            propertyName: "keepAlive"
            checked: root.targetConfig.launcher.keepAlive
            onToggled: {
                root.targetConfig.launcher.keepAlive = checked;
                root.targetConfig.save();
            }
        }

        TextFieldRow {
            id: prefixRow

            last: true
            label: qsTr("Action prefix")
            subtext: qsTr("Prefix used to run actions in the launcher")
            configNode: root.targetConfig.launcher
            propertyName: "actionPrefix"
            errorText: qsTr("Prefix must not be alphanumeric")
            value: root.targetConfig.launcher.actionPrefix === ">" ? "" : root.targetConfig.launcher.actionPrefix
            placeholderText: ">"
            maximumLength: 1
            smallField: true
            validate: /^[^a-zA-Z0-9\s]$/
            onEditingFinished: value => {
                if (!field.valid)
                    return;
                root.targetConfig.launcher.actionPrefix = value || ">";
                if (root.targetConfig.launcher.actionPrefix === ">")
                    clear();
                root.targetConfig.save();
            }
        }

        // Display
        SectionHeader {
            text: Tr.tr("Display")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Animate size")
            subtext: Tr.tr("Smoothly resize the launcher while searching")
            configNode: root.targetConfig.launcher
            propertyName: "animateSize"
            checked: root.targetConfig.launcher.animateSize
            onToggled: {
                root.targetConfig.launcher.animateSize = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: Tr.tr("Browse apps when search is empty")
            subtext: Tr.tr("Show the categorized app browser when the search field is empty")
            configNode: root.targetConfig.launcher
            propertyName: "showBrowseOnEmpty"
            checked: root.targetConfig.launcher.showBrowseOnEmpty
            onToggled: {
                root.targetConfig.launcher.showBrowseOnEmpty = checked;
                root.targetConfig.save();
            }
        }

        SelectRow {
            Layout.fillWidth: true
            label: Tr.tr("App browser layout")
            subtext: Tr.tr("Default: a sidebar of categories next to the apps. Simple: a full-width grid with favourites on top. Compact: a vertical list like search results")
            configNode: root.targetConfig.launcher
            propertyName: "browseLayout"
            menuItems: [
                MenuItem {
                    text: qsTr("Default")
                },
                MenuItem {
                    text: qsTr("Simple")
                },
                MenuItem {
                    text: qsTr("Compact")
                }
            ]
            active: {
                switch (root.targetConfig.launcher.browseLayout) {
                case LauncherBrowseLayout.Simple:
                    return menuItems[1];
                case LauncherBrowseLayout.Compact:
                    return menuItems[2];
                default:
                    return menuItems[0];
                }
            }
            onSelected: item => {
                root.targetConfig.launcher.browseLayout = item === menuItems[1] ? LauncherBrowseLayout.Simple : (item === menuItems[2] ? LauncherBrowseLayout.Compact : LauncherBrowseLayout.Default);
                root.targetConfig.save();
            }
        }

        SelectRow {
            Layout.fillWidth: true
            label: Tr.tr("Truncated app names")
            subtext: Tr.tr("How to show app names too long for a tile: a hover tooltip, shrinking the icon for a second line, or flipping the icon away to show the full name")
            configNode: root.targetConfig.launcher
            propertyName: "nameOverflow"
            menuItems: [
                MenuItem {
                    text: qsTr("Tooltip")
                },
                MenuItem {
                    text: qsTr("Shrink icon")
                },
                MenuItem {
                    text: qsTr("Flip icon")
                }
            ]
            active: {
                switch (root.targetConfig.launcher.nameOverflow) {
                case LauncherNameOverflow.Shrink:
                    return menuItems[1];
                case LauncherNameOverflow.Flip:
                    return menuItems[2];
                default:
                    return menuItems[0];
                }
            }
            onSelected: item => {
                root.targetConfig.launcher.nameOverflow = item === menuItems[1] ? LauncherNameOverflow.Shrink : (item === menuItems[2] ? LauncherNameOverflow.Flip : LauncherNameOverflow.Tooltip);
                root.targetConfig.save();
            }
        }

        StepperRow {
            label: qsTr("Max items shown")
            configNode: root.targetConfig.launcher
            propertyName: "maxShown"
            value: root.targetConfig.launcher.maxShown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => {
                root.targetConfig.launcher.maxShown = v;
                root.targetConfig.save();
            }
        }

        StepperRow {
            label: qsTr("Max wallpapers")
            configNode: root.targetConfig.launcher
            propertyName: "maxWallpapers"
            value: root.targetConfig.launcher.maxWallpapers
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => {
                root.targetConfig.launcher.maxWallpapers = v;
                root.targetConfig.save();
            }
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the launcher opens")
            configNode: root.targetConfig.launcher
            propertyName: "dragThreshold"
            value: root.targetConfig.launcher.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => {
                root.targetConfig.launcher.dragThreshold = v;
                root.targetConfig.save();
            }
        }

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        ToggleRow {
            first: true
            text: qsTr("Vim keybinds")
            subtext: qsTr("Navigate results with Ctrl+hjkl")
            configNode: root.targetConfig.launcher
            propertyName: "vimKeybinds"
            checked: root.targetConfig.launcher.vimKeybinds
            onToggled: {
                root.targetConfig.launcher.vimKeybinds = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Enable dangerous actions")
            subtext: qsTr("Allow actions that shut down or log out")
            configNode: root.targetConfig.launcher
            propertyName: "enableDangerousActions"
            checked: root.targetConfig.launcher.enableDangerousActions
            onToggled: {
                root.targetConfig.launcher.enableDangerousActions = checked;
                root.targetConfig.save();
            }
        }

        // Fuzzy search
        SectionHeader {
            text: Tr.tr("Fuzzy search")
        }

        ToggleRow {
            first: true
            text: qsTr("Apps")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "apps"
            checked: root.targetConfig.launcher.useFuzzy.apps
            onToggled: {
                root.targetConfig.launcher.useFuzzy.apps = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Actions")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "actions"
            checked: root.targetConfig.launcher.useFuzzy.actions
            onToggled: {
                root.targetConfig.launcher.useFuzzy.actions = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Schemes")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "schemes"
            checked: root.targetConfig.launcher.useFuzzy.schemes
            onToggled: {
                root.targetConfig.launcher.useFuzzy.schemes = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Variants")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "variants"
            checked: root.targetConfig.launcher.useFuzzy.variants
            onToggled: {
                root.targetConfig.launcher.useFuzzy.variants = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Wallpapers")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "wallpapers"
            checked: root.targetConfig.launcher.useFuzzy.wallpapers
            onToggled: {
                root.targetConfig.launcher.useFuzzy.wallpapers = checked;
                root.targetConfig.save();
            }
        }
    }
}
