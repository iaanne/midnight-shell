pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Time state and formatting shared by every clock variant.
QtObject {
    id: root

    readonly property date date: Time.date
    readonly property int hours: Time.hours
    readonly property int minutes: Time.minutes
    readonly property int seconds: Time.seconds

    readonly property real hourAngle: (root.hours % 12) * 30 + root.minutes * 0.5
    readonly property real minuteAngle: root.minutes * 6 + root.seconds * 0.1
    readonly property real secondAngle: root.seconds * 6

    readonly property string hourStr: Time.hourStr
    readonly property string minuteStr: Time.minuteStr
    readonly property string amPm: Time.amPmStr
    readonly property string hm: root.hourStr + ":" + root.minuteStr

    readonly property string weekday: Time.format("dddd")
    readonly property string weekdayShort: Time.format("ddd")
    readonly property string month: Time.format("MMMM")
    readonly property string monthShort: Time.format("MMM")
    readonly property string day: Time.format("d")
    readonly property string dayPadded: Time.format("dd")
    readonly property string dateLong: Time.format("dddd, MMMM d")
    readonly property string dateShort: Time.format("ddd, MMM d")

    // Spoken-clock words, for the Word variant. "half past ten"-style.
    // Minutes are rounded to five-minute buckets.
    function wordHours(): string {
        const names = ["twelve", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven"];
        const minuteNames = ["five", "ten", "quarter", "twenty", "twenty five"];
        const h = (((root.hours ?? 0) % 12) + 12) % 12;
        const m = Math.max(0, Math.min(59, Math.floor(root.minutes ?? 0)));
        const next = (h + 1) % 12;

        if (m < 5)
            return names[h] + " o'clock";
        if (m < 30)
            return minuteNames[Math.floor(m / 5) - 1] + " past " + names[h];
        if (m < 35)
            return "half past " + names[h];

        return minuteNames[Math.ceil((60 - m) / 5) - 1] + " to " + names[next];
    }
}
