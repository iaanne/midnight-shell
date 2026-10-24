import QtQuick

// Karaoke line renderer. Word-synced lines are drawn as a single wrapping text
// so long lines wrap and centre like ordinary text; each word is coloured on its
// own and the active word fades from the base colour to the accent as it is sung.
// Providers without word timings fall back to a normal text line.
Item {
    id: root

    property var line
    property real position: 0
    // Seconds. Positive offset delays the lyrics (the value shown by the UI is ms).
    property real offset: 0
    property color baseColor
    property color activeColor
    property font font
    property int horizontalAlignment: Text.AlignLeft
    // Only the current line fills; earlier lines stay in the base colour.
    property bool active: false

    readonly property bool hasWords: (line?.w?.length ?? 0) > 0
    readonly property real sampleTime: root.position - root.offset
    // Index of the word being sung, or -1 before the line starts / when inactive.
    readonly property int currentWord: {
        if (!root.active || !root.hasWords)
            return -1;
        const words = root.line.w;
        let index = -1;
        for (let i = 0; i < words.length; ++i) {
            if (root.sampleTime >= root.wordStart(words[i]))
                index = i;
        }
        return index;
    }
    readonly property var activeWord: root.currentWord >= 0 && root.currentWord < (root.line?.w?.length ?? 0) ? root.line.w[root.currentWord] : null
    // Fully faded in when there is no active word (invalid index or inactive line).
    readonly property real activeProgress: root.activeWord ? root.wordProgress(root.activeWord) : 1

    function wordStart(word: var): real {
        return word.t ?? root.line?.t ?? 0;
    }

    function wordEnd(word: var): real {
        const start = root.wordStart(word);
        return (word.e ?? 0) > start ? word.e : Math.max(start + 0.25, root.line?.e ?? 0);
    }

    function wordProgress(word: var): real {
        return Math.max(0, Math.min(1, (root.sampleTime - root.wordStart(word)) / Math.max(0.01, root.wordEnd(word) - root.wordStart(word))));
    }

    function escaped(text: var): string {
        return String(text ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n/g, "<br>");
    }

    // The whole line, one font tag per word. The active word is left transparent
    // so the overlay below can fade it in on top without moving any glyph.
    function baseText(): string {
        const words = root.line.w;
        let out = "";
        for (let i = 0; i < words.length; ++i) {
            let color = root.baseColor;
            if (root.active && i < root.currentWord)
                color = root.activeColor;
            else if (root.active && i === root.currentWord)
                color = "transparent";
            out += '<font color="' + color.toString() + '">' + root.escaped(words[i].x) + "</font>";
        }
        return out;
    }

    // Only the active word; everything else transparent so the layout matches baseText().
    function activeText(): string {
        const words = root.line.w;
        const active = root.currentWord;
        let out = "";
        for (let i = 0; i < words.length; ++i) {
            const color = i === active ? root.activeColor : "transparent";
            out += '<font color="' + color.toString() + '">' + root.escaped(words[i].x) + "</font>";
        }
        return out;
    }

    implicitWidth: base.implicitWidth
    implicitHeight: base.implicitHeight

    Text {
        id: base

        width: root.width
        text: root.hasWords ? root.baseText() : (root.line?.x || ". . .")
        textFormat: root.hasWords ? Text.StyledText : Text.PlainText
        color: root.active && (root.line?.t ?? -1) >= 0 && root.sampleTime >= root.line.t ? root.activeColor : root.baseColor
        font: root.font
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        horizontalAlignment: root.horizontalAlignment

        Text {
            id: activeLayer

            anchors.fill: parent
            visible: root.hasWords && root.active && root.currentWord >= 0
            text: root.hasWords ? root.activeText() : ""
            textFormat: Text.StyledText
            color: Qt.tint(root.baseColor, Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, root.activeProgress))
            font: base.font
            wrapMode: base.wrapMode
            horizontalAlignment: base.horizontalAlignment
        }
    }
}
