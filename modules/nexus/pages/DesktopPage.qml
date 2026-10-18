pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.background.desktopicons

// Desktop icons and the widgets placed on the wallpaper. Everything here is
// backed by DesktopLayout, which is shared by every screen, except the icon
// switches, which live in the per-screen background config.
PageBase {
    id: root

    // The controller owns the icon grid of one screen and is only registered
    // while its background surface exists, so adding and removing widgets is
    // the one thing here that needs it. Falling back to the Nexus window's own
    // screen covers the "all screens" target of the monitor selector.
    readonly property string screenName: root.nState.targetScreen || root.nState.screen?.name || ""
    readonly property var controller: DesktopLayout.controllerFor(root.screenName)

    readonly property WidgetCatalog catalog: WidgetCatalog {}
    readonly property var widgetList: {
        const out = [];
        for (const id in DesktopLayout.widgets) {
            const widget = DesktopLayout.widgets[id];
            const info = root.catalog.info(widget.type);
            out.push({
                id,
                key: DesktopLayout.widgetKey(id),
                type: widget.type,
                label: info.name,
                icon: info.icon
            });
        }
        return out;
    }

    // Keep in sync with WidgetCatalog.types; the gallery on the desktop is the
    // picker for everything that needs placing by hand.
    readonly property list<MenuItem> widgetItems: [
        MenuItem {
            text: Tr.tr("Clock & Weather")
            icon: "partly_cloudy_day"
            value: "clock"
        },
        MenuItem {
            text: Tr.tr("Desktop Clock")
            icon: "schedule"
            value: "desktopClock"
        },
        MenuItem {
            text: Tr.tr("Media")
            icon: "music_note"
            value: "media"
        },
        MenuItem {
            text: Tr.tr("Media Shapes")
            icon: "graphic_eq"
            value: "shapes"
        },
        MenuItem {
            text: Tr.tr("Desktop Lyrics")
            icon: "lyrics"
            value: "lyrics"
        },
        MenuItem {
            text: Tr.tr("System Monitor")
            icon: "monitoring"
            value: "system"
        },
        MenuItem {
            text: Tr.tr("Calendar")
            icon: "calendar_month"
            value: "calendar"
        },
        MenuItem {
            text: Tr.tr("Note")
            icon: "sticky_note_2"
            value: "note"
        },
        MenuItem {
            text: Tr.tr("Folder View")
            icon: "folder_open"
            value: "folder"
        }
    ]

    readonly property list<MenuItem> iconSizeItems: [
        MenuItem {
            text: Tr.tr("Small")
            value: 48
        },
        MenuItem {
            text: Tr.tr("Medium")
            value: 64
        },
        MenuItem {
            text: Tr.tr("Large")
            value: 80
        },
        MenuItem {
            text: Tr.tr("Huge")
            value: 96
        }
    ]

    readonly property list<MenuItem> sortItems: [
        MenuItem {
            text: Tr.tr("Name")
            value: "name"
        },
        MenuItem {
            text: Tr.tr("Type")
            value: "type"
        },
        MenuItem {
            text: Tr.tr("Date modified")
            value: "modified"
        },
        MenuItem {
            text: Tr.tr("Size")
            value: "size"
        }
    ]

    function addWidget(type: string): void {
        root.controller?.addWidget(type, null);
    }

    function removeWidget(key: string): void {
        root.controller?.removeWidgets([key]);
    }

    // Back to the catalog's default size; the grid then refits it.
    function resetWidget(widget: var): void {
        const info = root.catalog.info(widget.type);
        root.controller?.resizeItem(widget.key, info.size.w, info.size.h);
    }

    title: Tr.tr("Desktop")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Desktop icons")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: Tr.tr("Show desktop icons")
            subtext: Tr.tr("Files and folders from ~/Desktop, shown on the wallpaper")
            configNode: root.targetConfig.background
            propertyName: "desktopIconsEnabled"
            checked: root.targetConfig.background.desktopIconsEnabled
            onToggled: {
                root.targetConfig.background.desktopIconsEnabled = checked;
                root.targetConfig.save();
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: Tr.tr("Icon size")
            subtext: Tr.tr("Ctrl+scroll on the desktop also resizes icons")
            menuItems: root.iconSizeItems
            active: root.iconSizeItems.find(i => i.value === DesktopLayout.iconSize) ?? root.iconSizeItems[1]
            onSelected: item => DesktopLayout.setIconSize(item.value)
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: Tr.tr("Round icon corners")
            subtext: Tr.tr("Clip full-colour icons to a rounded square")
            checked: DesktopLayout.roundIcons
            onToggled: DesktopLayout.setRoundIcons(checked)
        }

        // This switches the bundled monochrome set on, tinted with the theme
        // colour; icons the set does not have fall back to the system theme.
        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: Tr.tr("Monochrome icons")
            subtext: Tr.tr("Draw icons from the bundled monochrome set using the theme colour")
            configNode: root.targetConfig.background
            propertyName: "materialYouIconsEnabled"
            checked: root.targetConfig.background.materialYouIconsEnabled
            onToggled: {
                root.targetConfig.background.materialYouIconsEnabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: Tr.tr("Vibrant tint")
            subtext: Tr.tr("Use a more saturated tint for monochrome icons")
            configNode: root.targetConfig.background
            propertyName: "materialYouIconsVibrant"
            checked: root.targetConfig.background.materialYouIconsVibrant
            enabled: root.targetConfig.background.materialYouIconsEnabled
            onToggled: {
                root.targetConfig.background.materialYouIconsVibrant = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: Tr.tr("Single click to open")
            subtext: Tr.tr("Without it one click selects and a second one opens")
            checked: DesktopLayout.singleClick
            onToggled: DesktopLayout.singleClick = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: Tr.tr("Arrange icons automatically")
            subtext: Tr.tr("Keep icons packed; dragging one reorders the rest")
            checked: DesktopLayout.autoArrange
            onToggled: DesktopLayout.setAutoArrange(checked)
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: Tr.tr("Sort by")
            subtext: Tr.tr("Sorts once unless icons are arranged automatically")
            menuItems: root.sortItems
            active: root.sortItems.find(i => i.value === DesktopLayout.sortKey) ?? null
            fallbackText: Tr.tr("Manual")
            fallbackIcon: "sort"
            onSelected: item => root.controller?.sortBy(item.value)
        }

        SectionHeader {
            text: Tr.tr("Widgets")
        }

        ItemList {
            id: widgetList

            showList: true
            first: true
            placeholderIcon: "widgets"
            placeholderText: Tr.tr("No desktop widgets")
            model: ScriptModel {
                values: root.widgetList
            }

            delegate: StateLayer {
                id: widgetRow

                required property int index
                required property var modelData

                anchors.left: widgetList.list.contentItem.left
                anchors.right: widgetList.list.contentItem.right
                anchors.fill: undefined
                implicitHeight: widgetRowLayout.implicitHeight + widgetRowLayout.anchors.margins * 2
                // No row action, so no pointing hand; only the buttons answer.
                cursorShape: Qt.ArrowCursor
                radius: Tokens.rounding.extraSmall
                topLeftRadius: index === 0 ? Tokens.rounding.extraLarge : radius
                topRightRadius: index === 0 ? Tokens.rounding.extraLarge : radius

                RowLayout {
                    id: widgetRowLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.small
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: widgetRow.modelData.icon
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: widgetRow.modelData.label
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "restart_alt"
                        type: IconButton.Text
                        isRound: true
                        font: Tokens.font.icon.small
                        label.fill: 0
                        onClicked: root.resetWidget(widgetRow.modelData)
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        isRound: true
                        font: Tokens.font.icon.small
                        inactiveOnColour: Colours.palette.m3error
                        label.fill: 0
                        onClicked: root.removeWidget(widgetRow.modelData.key)
                    }
                }
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: Tr.tr("Add widget")
            subtext: Tr.tr("Placed in the first free spot; drag it on the desktop to move it")
            menuItems: root.widgetItems
            fallbackText: Tr.tr("Add")
            fallbackIcon: "add"
            onSelected: item => root.addWidget(item.value)
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: Tr.tr("Auto-hide media shapes")
            subtext: Tr.tr("Hide media shapes while a window covers the screen")
            configNode: root.targetConfig.background.desktopShapes
            propertyName: "autoHide"
            checked: root.targetConfig.background.desktopShapes.autoHide
            onToggled: {
                root.targetConfig.background.desktopShapes.autoHide = checked;
                root.targetConfig.save();
            }
        }
    }
}
