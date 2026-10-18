pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.background.desktopicons
import qs.modules.nexus.common

// Configure one placed widget: pick its look, size, scale and stacking, or
// remove it. Reached by clicking a widget in the Desktop page's list.
PageBase {
    id: root

    readonly property WidgetCatalog catalog: WidgetCatalog {}
    readonly property string widgetId: root.nState.selectedWidgetKey
    readonly property var widget: DesktopLayout.widgets[root.widgetId] ?? null
    readonly property var baseInfo: root.catalog.info(root.widget?.type ?? "")
    readonly property var info: root.catalog.variantInfo(root.widget?.type ?? "", root.widget?.variant ?? "")
    readonly property var controller: DesktopLayout.controllerFor(root.nState.targetScreen || root.nState.screen?.name || "")
    readonly property bool hasVariants: (root.baseInfo.variants?.length ?? 0) > 0
    // Photo widgets take a picture path in their config.
    readonly property bool hasPhoto: root.baseInfo.photo === true
    readonly property string photoPath: root.widget?.config?.path ?? ""
    readonly property string photoName: root.photoPath ? root.photoPath.substring(root.photoPath.lastIndexOf("/") + 1) : ""
    readonly property var photoCwd: {
        const clean = root.photoPath.replace(/^file:\/\//, "");
        const dir = clean.substring(0, clean.lastIndexOf("/"));
        if (dir.startsWith(Paths.home))
            return ["Home", ...dir.substring(Paths.home.length).split("/").filter(s => s.length > 0)];
        return ["Home"];
    }
    // Preview box: the widget's default cell size, shrunk to fit the column.
    readonly property real cell: 56
    readonly property real previewScale: Math.min(1, (root.cappedWidth - Tokens.padding.extraLarge * 2) / Math.max(1, (root.info.size?.w ?? 2) * root.cell))

    // SelectRow wants a list<MenuItem>; the style menu is rebuilt from the
    // catalog so a type can gain variants without touching this page.
    property var variantItems: []

    readonly property list<MenuItem> overlapItems: [
        MenuItem {
            text: Tr.tr("Use global setting")
            icon: "settings"
            value: "inherit"
        },
        MenuItem {
            text: Tr.tr("Allow")
            icon: "layers"
            value: "allow"
        },
        MenuItem {
            text: Tr.tr("Avoid")
            icon: "block"
            value: "avoid"
        }
    ]

    function rebuildVariantItems(): void {
        const items = [];
        items.push(variantMenuItem.createObject(root, {
            text: Tr.tr("Default"),
            icon: root.baseInfo.icon,
            value: ""
        }));
        for (const v of (root.baseInfo.variants ?? []))
            items.push(variantMenuItem.createObject(root, {
                text: v.name,
                icon: v.icon ?? root.baseInfo.icon,
                value: v.id
            }));
        root.variantItems = items;
    }

    function setSize(widthCells: real, heightCells: real): void {
        if (!root.widget)
            return;
        const min = root.info.min ?? { w: 1, h: 1 };
        const max = root.info.max ?? { w: 8, h: 8 };
        DesktopLayout.setWidgetGeometry(root.widgetId, {
            w: Math.max(min.w, Math.min(max.w, widthCells)),
            h: Math.max(min.h, Math.min(max.h, heightCells))
        });
    }

    title: root.baseInfo.name || Tr.tr("Widget")
    isSubPage: true

    Component.onCompleted: root.rebuildVariantItems()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // MenuItem.text is required, so it has to be set at creation.
        Component {
            id: variantMenuItem

            MenuItem {}
        }

        // Stands in for the widget frame the desktop passes in, so the preview
        // renders exactly like the placed widget. Widgets read width, height, x,
        // y, span and config off their frame, so the stub exposes all of them.
        QtObject {
            id: previewFrame

            readonly property real width: preview.width
            readonly property real height: preview.height
            readonly property real x: 0
            readonly property real y: 0
            readonly property var span: ({ w: root.info.size?.w ?? 2, h: root.info.size?.h ?? 2 })
            readonly property var config: root.widget?.config ?? ({})

            function setConfig(patch: var): void {
                if (root.widget)
                    DesktopLayout.setWidgetConfig(root.widgetId, patch);
            }
        }

        // A live preview of the chosen look.
        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            implicitWidth: Math.max(140, (root.info.size?.w ?? 2) * root.cell * root.previewScale)
            implicitHeight: Math.max(90, (root.info.size?.h ?? 2) * root.cell * root.previewScale + Tokens.padding.large)
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.35)

            Loader {
                id: preview

                anchors.centerIn: parent
                width: Math.max(60, (root.info.size?.w ?? 2) * root.cell * root.previewScale)
                height: Math.max(40, (root.info.size?.h ?? 2) * root.cell * root.previewScale)
                asynchronous: true
                source: root.widget ? root.catalog.sourceUrl(root.widget.type, root.widget.variant ?? "") : ""

                onLoaded: {
                    if (item) {
                        item.frame = previewFrame;
                        item.controller = root.controller;
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.widget === null
                text: Tr.tr("Widget unavailable")
                color: Colours.palette.m3outline
            }
        }

        SectionHeader {
            first: true
            text: Tr.tr("Appearance")
        }

        SelectRow {
            Layout.fillWidth: true
            visible: root.hasVariants
            label: Tr.tr("Style")
            subtext: Tr.tr("How this widget draws itself")
            menuItems: root.variantItems
            active: root.variantItems.find(i => i.value === (root.widget?.variant ?? "")) ?? root.variantItems[0] ?? null
            onSelected: item => {
                if (root.widget)
                    DesktopLayout.setWidgetVariant(root.widgetId, item.value);
            }
        }

        SectionHeader {
            text: Tr.tr("Layout")
        }

        StepperRow {
            Layout.fillWidth: true
            first: true
            label: Tr.tr("Width")
            subtext: Tr.tr("In grid cells")
            value: root.widget?.w ?? 1
            from: root.info.min?.w ?? 1
            to: root.info.max?.w ?? 8
            stepSize: 1
            onMoved: value => root.setSize(value, root.widget?.h ?? 1)
        }

        StepperRow {
            Layout.fillWidth: true
            label: Tr.tr("Height")
            subtext: Tr.tr("In grid cells")
            value: root.widget?.h ?? 1
            from: root.info.min?.h ?? 1
            to: root.info.max?.h ?? 8
            stepSize: 1
            onMoved: value => root.setSize(root.widget?.w ?? 1, value)
        }

        SliderRow {
            Layout.fillWidth: true
            label: Tr.tr("Scale")
            subtext: Tr.tr("Multiplier on top of the global widget size")
            value: root.widget?.scale ?? 1
            from: 0.5
            to: 2
            onMoved: value => {
                if (root.widget)
                    DesktopLayout.setWidgetScale(root.widgetId, value);
            }
        }

        SelectRow {
            Layout.fillWidth: true
            last: true
            label: Tr.tr("Overlap")
            subtext: Tr.tr("Whether this widget may sit on top of icons")
            menuItems: root.overlapItems
            active: root.overlapItems.find(i => i.value === (root.widget?.overlap ?? "inherit")) ?? root.overlapItems[0]
            onSelected: item => {
                if (root.widget)
                    DesktopLayout.setWidgetOverlap(root.widgetId, item.value);
            }
        }

        SectionHeader {
            text: Tr.tr("Photo")
            visible: root.hasPhoto
        }

        RowButton {
            visible: root.hasPhoto
            first: true
            last: root.photoPath === ""
            icon: "image"
            text: Tr.tr("Choose photo…")
            subtext: root.photoName || Tr.tr("No photo selected")
            onClicked: photoDialog.open()

            FileDialog {
                id: photoDialog

                title: Tr.tr("Choose a photo")
                filterLabel: Tr.tr("Images")
                filters: Images.validImageExtensions
                cwd: root.photoCwd
                onAccepted: path => {
                    if (root.widget)
                        DesktopLayout.setWidgetConfig(root.widgetId, { path: path.replace(/^file:\/\//, "") });
                }
            }
        }

        RowButton {
            visible: root.hasPhoto && root.photoPath !== ""
            last: true
            icon: "hide_image"
            text: Tr.tr("Clear photo")
            subtext: Tr.tr("Go back to the choose-photo prompt")
            onClicked: DesktopLayout.setWidgetConfig(root.widgetId, { path: "" })
        }

        SectionHeader {
            text: Tr.tr("Actions")
        }

        RowButton {
            first: true
            icon: "flip_to_front"
            text: Tr.tr("Bring to front")
            subtext: Tr.tr("Move this widget above the others")
            onClicked: DesktopLayout.bringToFront(root.widgetId)
        }

        RowButton {
            icon: "restart_alt"
            text: Tr.tr("Reset size")
            subtext: Tr.tr("Back to the default size for this style")
            onClicked: root.setSize(root.baseInfo.size.w, root.baseInfo.size.h)
        }

        RowButton {
            last: true
            icon: "delete"
            text: Tr.tr("Remove widget")
            subtext: Tr.tr("Take it off the desktop")
            onClicked: {
                DesktopLayout.removeWidget(root.widgetId);
                root.nState.closeSubPage();
            }
        }
    }
}
