import QtQuick
import qs.utils

// The desktop widgets that can be added. A *type* is what the Nexus "Add
// widget" menu offers and what a placed widget records; a type may also carry
// `variants`, alternate looks of the same widget that share its config. The
// placed widget stores the chosen `variant` id; `variantInfo` resolves the two.
//
// Geometry is in grid cells. `size` is the default, `min`/`max` bound the
// resize grip. A type or variant with `frameless: true` draws no card and no
// label, which is what the ported widgets use: they paint themselves.
QtObject {
    readonly property var types: [
        {
            type: "clock",
            name: qsTr("Clock & Weather"),
            icon: "partly_cloudy_day",
            size: { w: 4, h: 2 },
            min: { w: 2, h: 2 },
            max: { w: 6, h: 3 },
            source: "widgets/ClockWidget.qml"
        },
        {
            type: "desktopClock",
            name: qsTr("Desktop Clock"),
            icon: "schedule",
            size: { w: 4, h: 2 },
            min: { w: 1, h: 1 },
            max: { w: 8, h: 6 },
            frameless: true,
            source: "widgets/DesktopClockWidget.qml",
            variants: [
                { id: "digital", name: qsTr("Digital"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/DigitalClockWidget.qml" },
                { id: "word", name: qsTr("Word"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/WordClockWidget.qml" },
                { id: "numeral", name: qsTr("Numeral"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/NumeralClockWidget.qml" },
                { id: "month", name: qsTr("Month"), icon: "calendar_month", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/MonthClockWidget.qml" },
                { id: "stack", name: qsTr("Stack"), icon: "schedule", size: { w: 2, h: 3 }, min: { w: 1, h: 2 }, max: { w: 5, h: 6 }, frameless: true, source: "widgets/clock/StackClockWidget.qml" },
                { id: "weight", name: qsTr("Weight"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/WeightClockWidget.qml" },
                { id: "width", name: qsTr("Width"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/WidthClockWidget.qml" },
                { id: "hori", name: qsTr("Hori"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/HoriClock.qml" },
                { id: "flex", name: qsTr("Flex"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/FlexClock.qml" },
                { id: "dial", name: qsTr("Dial"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/DialClock.qml" },
                { id: "circlePointer", name: qsTr("Circle Pointer"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/CirclePointerClock.qml" },
                { id: "concentric", name: qsTr("Concentric"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/ConcentricClockWidget.qml" },
                { id: "scallopDot", name: qsTr("Scallop Dot"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/ScallopDotClockWidget.qml" },
                { id: "scallopNumber", name: qsTr("Scallop Number"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/ScallopNumberClockWidget.qml" },
                { id: "tripleRing", name: qsTr("Triple Ring"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/TripleRingClockWidget.qml" },
                { id: "nagasaki", name: qsTr("Nagasaki"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/NagasakiClock.qml" },
                { id: "duo", name: qsTr("Duo"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/DuoClockWidget.qml" },
                { id: "gridCard", name: qsTr("Grid Card"), icon: "schedule", size: { w: 3, h: 2 }, min: { w: 2, h: 2 }, max: { w: 6, h: 4 }, frameless: true, source: "widgets/clock/GridCardClockWidget.qml" },
                { id: "wearos", name: qsTr("WearOS"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/WearOSClockWidget.qml" },
                { id: "wearosArc", name: qsTr("WearOS Arc"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/WearOSArcClockWidget.qml" },
                { id: "iosAnalog", name: qsTr("iOS Analog"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/IosAnalogClockWidget.qml" },
                { id: "iosTile", name: qsTr("iOS Tile"), icon: "schedule", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/IosTileClockWidget.qml" },
                { id: "nothingDigital", name: qsTr("Nothing Digital"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 1 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/NothingDigitalClockWidget.qml" },
                { id: "nothingWheel", name: qsTr("Nothing Wheel"), icon: "schedule", size: { w: 4, h: 2 }, min: { w: 2, h: 2 }, max: { w: 8, h: 4 }, frameless: true, source: "widgets/clock/NothingWheelClockWidget.qml" },
                { id: "cookie", name: qsTr("Cookie"), icon: "cookie", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/clock/CookieClockWidget.qml" }
            ]
        },
        {
            type: "media",
            name: qsTr("Media"),
            icon: "music_note",
            size: { w: 4, h: 2 },
            min: { w: 3, h: 2 },
            max: { w: 6, h: 4 },
            source: "widgets/MediaWidget.qml",
            variants: [
                { id: "circular", name: qsTr("Circular"), icon: "album", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/media/CircularMediaWidget.qml" },
                { id: "compact", name: qsTr("Compact"), icon: "music_note", size: { w: 3, h: 2 }, min: { w: 2, h: 1 }, max: { w: 6, h: 3 }, frameless: true, source: "widgets/media/CompactMediaWidget.qml" },
                { id: "cover", name: qsTr("Cover"), icon: "album", size: { w: 2, h: 3 }, min: { w: 2, h: 2 }, max: { w: 5, h: 6 }, frameless: true, source: "widgets/media/CoverMediaWidget.qml" },
                { id: "deck", name: qsTr("Deck"), icon: "queue_music", size: { w: 4, h: 2 }, min: { w: 3, h: 2 }, max: { w: 7, h: 4 }, frameless: true, source: "widgets/media/DeckMediaWidget.qml" },
                { id: "cd", name: qsTr("CD"), icon: "album", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/media/CdMediaWidget.qml" },
                { id: "halo", name: qsTr("Halo"), icon: "album", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/media/HaloMediaWidget.qml" },
                { id: "poster", name: qsTr("Poster"), icon: "album", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/media/PosterMediaWidget.qml" },
                { id: "nothingRing", name: qsTr("Nothing Ring"), icon: "album", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/media/NothingRingMediaWidget.qml" },
                { id: "android", name: qsTr("Android"), icon: "music_note", size: { w: 4, h: 2 }, min: { w: 3, h: 2 }, max: { w: 7, h: 4 }, frameless: true, source: "widgets/media/AndroidMediaWidget.qml" }
            ]
        },
        {
            type: "photo",
            name: qsTr("Photo"),
            icon: "image",
            size: { w: 2, h: 2 },
            min: { w: 1, h: 1 },
            max: { w: 8, h: 8 },
            frameless: true,
            photo: true,
            source: "widgets/photo/PhotoWidget.qml",
            config: { path: "" },
            variants: [
                { id: "plain1x1", name: qsTr("Plain 1×1"), icon: "image", size: { w: 2, h: 2 }, min: { w: 1, h: 1 }, max: { w: 4, h: 4 }, frameless: true, source: "widgets/photo/PlainPhoto1x1Widget.qml" },
                { id: "plain1x2", name: qsTr("Plain 1×2"), icon: "image", size: { w: 1, h: 2 }, min: { w: 1, h: 1 }, max: { w: 3, h: 4 }, frameless: true, source: "widgets/photo/PlainPhoto1x2Widget.qml" },
                { id: "plain2x1", name: qsTr("Plain 2×1"), icon: "image", size: { w: 2, h: 1 }, min: { w: 1, h: 1 }, max: { w: 4, h: 3 }, frameless: true, source: "widgets/photo/PlainPhoto2x1Widget.qml" },
                { id: "minimal", name: qsTr("Minimal"), icon: "thermostat", size: { w: 2, h: 1 }, min: { w: 2, h: 1 }, max: { w: 4, h: 2 }, frameless: true, source: "widgets/photo/PhotoMinimalTemp2x1Widget.qml" },
                { id: "pill", name: qsTr("Pill"), icon: "image", size: { w: 2, h: 1 }, min: { w: 2, h: 1 }, max: { w: 4, h: 2 }, frameless: true, source: "widgets/photo/PhotoPill2x1Widget.qml" },
                { id: "weather", name: qsTr("Weather"), icon: "partly_cloudy_day", size: { w: 2, h: 1 }, min: { w: 2, h: 1 }, max: { w: 4, h: 2 }, frameless: true, source: "widgets/photo/PhotoWeather2x1Widget.qml" }
            ]
        },
        {
            type: "date",
            name: qsTr("Date & Calendar"),
            icon: "calendar_today",
            size: { w: 2, h: 2 },
            min: { w: 1, h: 1 },
            max: { w: 6, h: 6 },
            frameless: true,
            source: "widgets/date/DateWidget.qml",
            variants: [
                { id: "banner", name: qsTr("Date Banner"), icon: "calendar_today", size: { w: 4, h: 1 }, min: { w: 2, h: 1 }, max: { w: 6, h: 2 }, frameless: true, source: "widgets/date/DateBannerWidget.qml" },
                { id: "shapes", name: qsTr("Date Shapes"), icon: "calendar_today", size: { w: 2, h: 2 }, min: { w: 1, h: 1 }, max: { w: 4, h: 4 }, frameless: true, source: "widgets/date/DateShapesWidget.qml" },
                { id: "stack", name: qsTr("Date Stack"), icon: "calendar_today", size: { w: 1, h: 2 }, min: { w: 1, h: 2 }, max: { w: 3, h: 4 }, frameless: true, source: "widgets/date/DateStackWidget.qml" },
                { id: "type", name: qsTr("Date Type"), icon: "calendar_today", size: { w: 3, h: 1 }, min: { w: 2, h: 1 }, max: { w: 6, h: 2 }, frameless: true, source: "widgets/date/DateTypeWidget.qml" },
                { id: "weekStrip", name: qsTr("Week Strip"), icon: "view_week", size: { w: 4, h: 1 }, min: { w: 3, h: 1 }, max: { w: 6, h: 2 }, frameless: true, source: "widgets/date/WeekStripWidget.qml" },
                { id: "weekAgenda", name: qsTr("Week Agenda"), icon: "event_note", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/date/WeekAgendaWidget.qml" },
                { id: "monthTall", name: qsTr("Month Tall"), icon: "calendar_month", size: { w: 2, h: 3 }, min: { w: 2, h: 3 }, max: { w: 4, h: 6 }, frameless: true, source: "widgets/date/MonthTallWidget.qml" },
                { id: "agenda", name: qsTr("Calendar Agenda"), icon: "event_note", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/date/CalendarAgendaWidget.qml" },
                { id: "minimal", name: qsTr("Calendar Minimal"), icon: "calendar_month", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/date/CalendarMinimalWidget.qml" },
                { id: "nextEvent", name: qsTr("Next Event"), icon: "event", size: { w: 3, h: 2 }, min: { w: 2, h: 2 }, max: { w: 6, h: 4 }, frameless: true, source: "widgets/date/CalendarNextEventWidget.qml" },
                { id: "pill", name: qsTr("Calendar Pill"), icon: "calendar_month", size: { w: 4, h: 2 }, min: { w: 3, h: 2 }, max: { w: 6, h: 4 }, frameless: true, source: "widgets/date/CalendarPillWidget.qml" },
                { id: "upcoming", name: qsTr("Upcoming 3 Days"), icon: "event_upcoming", size: { w: 3, h: 3 }, min: { w: 2, h: 2 }, max: { w: 6, h: 6 }, frameless: true, source: "widgets/date/CalendarUpcoming3DaysWidget.qml" },
                { id: "grid2x1", name: qsTr("Calendar Grid"), icon: "calendar_view_month", size: { w: 4, h: 2 }, min: { w: 3, h: 2 }, max: { w: 6, h: 4 }, frameless: true, source: "widgets/date/CalendarGrid2x1Widget.qml" }
            ]
        },
        {
            type: "shapes",
            name: qsTr("Media Shapes"),
            icon: "graphic_eq",
            size: { w: 3, h: 3 },
            min: { w: 2, h: 2 },
            max: { w: 6, h: 6 },
            frameless: true,
            source: "widgets/ShapesWidget.qml"
        },
        {
            type: "lyrics",
            name: qsTr("Desktop Lyrics"),
            icon: "lyrics",
            size: { w: 4, h: 3 },
            min: { w: 3, h: 2 },
            max: { w: 8, h: 6 },
            frameless: true,
            source: "widgets/LyricsWidget.qml"
        },
        {
            type: "lastfm",
            name: qsTr("Last.fm"),
            icon: "music_note",
            size: { w: 3, h: 2 },
            min: { w: 2, h: 1 },
            max: { w: 6, h: 4 },
            frameless: true,
            source: "widgets/LastfmWidget.qml",
            config: { mode: "recent", limit: 10, chartEntity: "album", chartUnit: "month", chartValue: 3, showArtist: true, showAlbum: true, showYear: false },
            // All looks share one implementation; the chosen id is read from
            // the widget frame so the Nexus preview can switch looks in place.
            variants: [
                { id: "hero", name: qsTr("Now Playing"), icon: "album", size: { w: 3, h: 2 }, min: { w: 2, h: 2 }, max: { w: 6, h: 4 }, frameless: true, source: "widgets/LastfmWidget.qml" },
                { id: "recent", name: qsTr("Recent"), icon: "queue_music", size: { w: 3, h: 2 }, min: { w: 2, h: 2 }, max: { w: 6, h: 4 }, frameless: true, source: "widgets/LastfmWidget.qml" },
                { id: "profile", name: qsTr("Profile"), icon: "person", size: { w: 3, h: 2 }, min: { w: 2, h: 2 }, max: { w: 5, h: 3 }, frameless: true, source: "widgets/LastfmWidget.qml" },
                { id: "grid", name: qsTr("Cover Grid"), icon: "grid_view", size: { w: 4, h: 3 }, min: { w: 2, h: 2 }, max: { w: 8, h: 6 }, frameless: true, source: "widgets/LastfmWidget.qml" }
            ]
        },
        {
            type: "system",
            name: qsTr("System Monitor"),
            icon: "monitoring",
            size: { w: 3, h: 2 },
            min: { w: 2, h: 2 },
            max: { w: 6, h: 4 },
            source: "widgets/SystemWidget.qml"
        },
        {
            type: "calendar",
            name: qsTr("Calendar"),
            icon: "calendar_month",
            size: { w: 3, h: 3 },
            min: { w: 3, h: 3 },
            max: { w: 5, h: 4 },
            source: "widgets/CalendarWidget.qml"
        },
        {
            type: "note",
            name: qsTr("Note"),
            icon: "sticky_note_2",
            size: { w: 2, h: 2 },
            min: { w: 2, h: 1 },
            max: { w: 6, h: 6 },
            source: "widgets/NoteWidget.qml",
            config: { text: "" }
        },
        {
            type: "folder",
            name: qsTr("Folder View"),
            icon: "folder_open",
            size: { w: 3, h: 3 },
            min: { w: 2, h: 2 },
            max: { w: 8, h: 6 },
            source: "widgets/FolderWidget.qml",
            config: { path: Paths.home + "/Downloads" }
        }
    ]

    // Large folders are groups shown at more than one cell.
    readonly property var group: ({ type: "group", name: qsTr("Large Folder"), icon: "folder", size: { w: 3, h: 3 }, min: { w: 3, h: 3 }, max: { w: 8, h: 6 }, source: "BigFolder.qml" })

    function info(type: string): var {
        if (type === "group")
            return group;
        return types.find(t => t.type === type) ?? { type: "", name: "", icon: "widgets", size: { w: 1, h: 1 }, min: { w: 1, h: 1 }, max: { w: 1, h: 1 }, source: "" };
    }

    // The look a placed widget actually uses: the type with its chosen variant
    // merged in. A type without variants (or an unknown id) resolves to itself.
    function variantInfo(type: string, variant: string): var {
        const base = info(type);
        if (type === "group" || !base.variants || base.variants.length === 0 || variant === "")
            return base;
        const v = base.variants.find(x => x.id === variant);
        if (!v)
            return base;
        return Object.assign({}, base, v, { type: base.type, variants: base.variants });
    }

    function sourceFor(type: string, variant: string): string {
        return variantInfo(type, variant).source;
    }

    // Absolute URL of a variant's QML, resolved against this file (which sits
    // beside `widgets/`), so the Nexus preview can load the same source the
    // desktop does.
    function sourceUrl(type: string, variant: string): url {
        const src = sourceFor(type, variant);
        return src === "" ? "" : Qt.resolvedUrl(src);
    }
}
