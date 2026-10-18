pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Date state and helpers shared by the date and calendar variants.
QtObject {
    id: root

    readonly property date today: Time.date
    readonly property string weekday: Time.format("dddd")
    readonly property string weekdayShort: Time.format("ddd")
    readonly property string weekdayNarrow: Qt.locale().dayName(Time.date.getDay(), Locale.NarrowFormat)
    readonly property string month: Time.format("MMMM")
    readonly property string monthShort: Time.format("MMM")
    readonly property string day: Time.format("d")
    readonly property string dayPadded: Time.format("dd")
    readonly property string dateLong: Time.format("dddd, MMMM d")
    readonly property string dateShort: Time.format("ddd, MMM d")

    // Monday- or Sunday-based, following the locale.
    function startOfWeek(base: date): date {
        const first = Qt.locale().firstDayOfWeek;
        const d = new Date(base.getFullYear(), base.getMonth(), base.getDate());
        d.setDate(d.getDate() - ((d.getDay() - first + 7) % 7));
        return d;
    }

    function weekDates(base: date): var {
        const start = startOfWeek(base);
        const out = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push(d);
        }
        return out;
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
}
