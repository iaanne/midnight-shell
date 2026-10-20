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

    // Last.fm widgets share a few settings: the cover grid has chart options,
    // while every variant gets its own refresh interval and manual refresh.
    readonly property bool isLastfm: root.widget?.type === "lastfm"
    readonly property string lastfmMode: {
        if (!root.isLastfm)
            return "";
        const id = root.widget?.variant || root.widget?.config?.mode || "recent";
        return id === "hero" || id === "profile" || id === "grid" ? id : "recent";
    }
    readonly property bool isLastfmGrid: root.isLastfm && root.lastfmMode === "grid"
    readonly property var lastfmConfig: root.widget?.config ?? ({})
    readonly property string chartEntity: Lastfm.normalizeChartEntity(root.lastfmConfig.chartEntity ?? "album")
    readonly property string chartUnit: Lastfm.normalizeChartUnit(root.lastfmConfig.chartUnit ?? "month")
    readonly property int chartValue: Lastfm.normalizeChartValue(root.chartUnit, root.lastfmConfig.chartValue ?? 3)
    readonly property int chartMaxValue: root.chartUnit === "week" ? 520 : root.chartUnit === "year" ? 50 : 120
    readonly property bool exactRange: root.isLastfmGrid && root.chartUnit !== "overall" && (root.chartEntity === "track" || Lastfm.nativePeriod(root.chartUnit, root.chartValue) === "")
    readonly property string refreshUnit: Lastfm.normalizeRefreshUnit(root.lastfmConfig.refreshUnit ?? Lastfm.defaultRefreshUnit(root.lastfmMode))
    readonly property int refreshMin: root.refreshUnit === "second" ? 10 : 1
    readonly property int refreshMax: Lastfm.maxRefreshValue(root.refreshUnit)
    readonly property int refreshValue: {
        const fallback = Lastfm.defaultRefreshValue(root.lastfmMode);
        const value = Number(root.lastfmConfig.refreshValue ?? fallback);
        return Math.max(root.refreshMin, Math.min(root.refreshMax, Math.round(value) || fallback));
    }
    readonly property int refreshMs: Lastfm.refreshIntervalMs(root.refreshUnit, root.refreshValue)
    readonly property string gridChartKey: root.isLastfmGrid ? Lastfm.chartKey(root.chartEntity, root.chartUnit, root.chartValue) : ""
    readonly property var gridChart: root.isLastfmGrid ? (Lastfm.charts[root.gridChartKey] ?? null) : null
    readonly property bool lastfmLoading: root.isLastfmGrid ? (root.gridChart?.loading ?? false) : (root.lastfmMode === "profile" ? (Lastfm.loadingProfile || Lastfm.loadingRecent) : Lastfm.loadingRecent)

    property string refreshInput: ""
    property string refreshError: ""

    readonly property list<MenuItem> chartEntityItems: [
        MenuItem {
            text: Tr.tr("Artists")
            icon: "person"
            value: "artist"
        },
        MenuItem {
            text: Tr.tr("Albums")
            icon: "album"
            value: "album"
        },
        MenuItem {
            text: Tr.tr("Songs")
            icon: "music_note"
            value: "track"
        }
    ]

    readonly property list<MenuItem> chartUnitItems: [
        MenuItem {
            text: Tr.tr("Weeks")
            icon: "date_range"
            value: "week"
        },
        MenuItem {
            text: Tr.tr("Months")
            icon: "calendar_month"
            value: "month"
        },
        MenuItem {
            text: Tr.tr("Years")
            icon: "calendar_today"
            value: "year"
        },
        MenuItem {
            text: Tr.tr("Overall")
            icon: "all_inclusive"
            value: "overall"
        }
    ]

    readonly property list<MenuItem> refreshUnitItems: [
        MenuItem {
            text: Tr.tr("Seconds")
            icon: "timer"
            value: "second"
        },
        MenuItem {
            text: Tr.tr("Minutes")
            icon: "schedule"
            value: "minute"
        },
        MenuItem {
            text: Tr.tr("Hours")
            icon: "hourglass"
            value: "hour"
        }
    ]
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

    function setLastfmConfig(patch: var): void {
        if (root.widget)
            DesktopLayout.setWidgetConfig(root.widgetId, patch);
    }

    function syncRefreshInput(): void {
        root.refreshInput = String(root.refreshValue);
    }

    function validRefreshText(text: string): bool {
        const value = String(text ?? "").trim();
        if (!/^\d+$/.test(value))
            return false;
        const number = Number(value);
        return number >= root.refreshMin && number <= root.refreshMax;
    }

    function applyRefreshInput(text: string): void {
        if (!root.validRefreshText(text)) {
            root.refreshError = Tr.tr("Enter a whole number between %1 and %2").arg(root.refreshMin).arg(root.refreshMax);
            return;
        }
        root.refreshError = "";
        root.refreshInput = String(Number(String(text).trim()));
        root.setLastfmConfig({ refreshValue: Number(root.refreshInput) });
    }

    function setRefreshUnit(unit: string): void {
        const max = Lastfm.maxRefreshValue(unit);
        const min = unit === "second" ? 10 : 1;
        const value = Math.max(min, Math.min(max, root.refreshValue));
        root.refreshError = "";
        root.setLastfmConfig({ refreshUnit: unit, refreshValue: value });
        root.syncRefreshInput();
    }

    function setChartUnit(unit: string): void {
        const max = unit === "week" ? 520 : unit === "year" ? 50 : unit === "overall" ? 0 : 120;
        const value = unit === "overall" ? 0 : Math.max(1, Math.min(max, root.chartValue || 1));
        root.setLastfmConfig({ chartUnit: unit, chartValue: value });
    }

    function refreshLastfmNow(): void {
        if (!root.isLastfm)
            return;
        if (root.isLastfmGrid) {
            Lastfm.refreshChart(root.chartEntity, root.chartUnit, root.chartValue, true, root.refreshMs);
            return;
        }
        Lastfm.refreshFeed(root.lastfmMode, root.refreshMs, true);
    }

    onLastfmModeChanged: root.syncRefreshInput()
    onRefreshUnitChanged: root.syncRefreshInput()
    onRefreshValueChanged: root.syncRefreshInput()

    Component.onCompleted: {
        root.rebuildVariantItems();
        root.syncRefreshInput();
    }

    title: root.baseInfo.name || Tr.tr("Widget")
    isSubPage: true

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
        // y, span, variant and config off their frame, so the stub exposes all
        // of them.
        QtObject {
            id: previewFrame

            readonly property real width: preview.width
            readonly property real height: preview.height
            readonly property real x: 0
            readonly property real y: 0
            readonly property var span: ({ w: root.info.size?.w ?? 2, h: root.info.size?.h ?? 2 })
            readonly property string variant: root.widget?.variant ?? ""
            readonly property var config: root.widget?.config ?? ({})
            // The preview gets the real desktop controller for size/icon data,
            // but it is not the placed widget and must stay live while Nexus
            // covers the desktop.
            readonly property bool isPreview: true

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
            last: !root.isLastfm
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
            text: Tr.tr("Cover grid")
            visible: root.isLastfmGrid
        }

        SelectRow {
            Layout.fillWidth: true
            visible: root.isLastfmGrid
            first: true
            label: Tr.tr("Show")
            subtext: Tr.tr("Artists, albums or songs")
            menuItems: root.chartEntityItems
            active: root.chartEntityItems.find(i => i.value === root.chartEntity) ?? root.chartEntityItems[1]
            onSelected: item => root.setLastfmConfig({ chartEntity: item.value })
        }

        SelectRow {
            Layout.fillWidth: true
            visible: root.isLastfmGrid
            label: Tr.tr("Range")
            subtext: Tr.tr("A rolling Last.fm chart period")
            menuItems: root.chartUnitItems
            active: root.chartUnitItems.find(i => i.value === root.chartUnit) ?? root.chartUnitItems[1]
            onSelected: item => root.setChartUnit(item.value)
        }

        StepperRow {
            Layout.fillWidth: true
            visible: root.isLastfmGrid && root.chartUnit !== "overall"
            label: Tr.tr("Amount")
            subtext: Tr.tr("How many weeks, months or years to include")
            value: root.chartValue
            from: 1
            to: root.chartMaxValue
            stepSize: 1
            onMoved: value => root.setLastfmConfig({ chartValue: value })
        }

        ToggleRow {
            Layout.fillWidth: true
            visible: root.isLastfmGrid && root.chartEntity !== "artist"
            text: Tr.tr("Show artist")
            subtext: Tr.tr("Overlay the artist name on each cover")
            checked: root.lastfmConfig.showArtist ?? true
            onToggled: root.setLastfmConfig({ showArtist: checked })
        }

        ToggleRow {
            Layout.fillWidth: true
            visible: root.isLastfmGrid && root.chartEntity === "track"
            text: Tr.tr("Show album")
            subtext: Tr.tr("Overlay the album name on each song cover")
            checked: root.lastfmConfig.showAlbum ?? true
            onToggled: root.setLastfmConfig({ showAlbum: checked })
        }

        ToggleRow {
            Layout.fillWidth: true
            visible: root.isLastfmGrid && root.chartEntity !== "artist"
            text: Tr.tr("Show release year")
            subtext: Tr.tr("Album release year, when Last.fm has it")
            checked: root.lastfmConfig.showYear ?? false
            onToggled: root.setLastfmConfig({ showYear: checked })
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            visible: root.isLastfmGrid && root.chartEntity === "artist"
            text: Tr.tr("Artist covers use the artist name as the title; there is no release year to show.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            visible: root.exactRange
            text: Tr.tr("Custom ranges are loaded exactly from your scrobbles and can take a while.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.Wrap
        }

        SectionHeader {
            text: Tr.tr("Refresh")
            visible: root.isLastfm
        }

        SelectRow {
            Layout.fillWidth: true
            visible: root.isLastfm
            first: !root.isLastfmGrid
            label: Tr.tr("Unit")
            subtext: Tr.tr("Seconds, minutes or hours")
            menuItems: root.refreshUnitItems
            active: root.refreshUnitItems.find(i => i.value === root.refreshUnit) ?? root.refreshUnitItems[0]
            onSelected: item => root.setRefreshUnit(item.value)
        }

        TextFieldRow {
            Layout.fillWidth: true
            visible: root.isLastfm
            label: Tr.tr("Refresh every")
            subtext: Tr.tr("Whole number; minimum 10 seconds, maximum about 24 days")
            errorText: root.refreshError
            value: root.refreshInput
            placeholderText: String(root.refreshValue)
            maximumLength: 7
            validate: text => root.validRefreshText(text)
            field.inputMethodHints: Qt.ImhDigitsOnly
            onEditingFinished: value => root.applyRefreshInput(value)
        }

        RowButton {
            Layout.fillWidth: true
            visible: root.isLastfm
            last: true
            icon: "refresh"
            text: Tr.tr("Refresh now")
            subtext: root.lastfmLoading ? (root.isLastfmGrid ? Tr.tr("Loading covers…") : Tr.tr("Refreshing scrobbles…")) : (root.isLastfmGrid ? Tr.tr("Reload this cover grid immediately") : Tr.tr("Refresh this widget immediately"))
            disabled: root.isLastfm && !root.isLastfmGrid && root.lastfmLoading
            onClicked: root.refreshLastfmNow()
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            visible: root.isLastfm
            text: Tr.tr("Widgets that display the same Last.fm data share it, so the shortest active refresh interval wins. The dashboard has its own interval.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.Wrap
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
            onClicked: root.setSize(root.info.size.w, root.info.size.h)
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
