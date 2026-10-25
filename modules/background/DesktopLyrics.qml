pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    // Frame/controller come from the widget host (BigItem); they keep their
    // null defaults so the same component still serves the lyrics overlay
    // window, which supplies screen/wallpaper/absX/absY directly.
    property var frame: null
    property var controller: null
    property ShellScreen screen: controller?.screenData ?? null
    property Item wallpaper: controller?.wallpaper ?? null
    property real absX: (controller?.gridOrigin.x ?? 0) + (frame?.x ?? 0)
    property real absY: (controller?.gridOrigin.y ?? 0) + (frame?.y ?? 0)

    // Scale to the frame it was given, times the user's own scale, which stays
    // a multiplier on top of the automatic fit.
    readonly property real gridScale: frame ? Math.min(frame.width / 350, frame.height / 180) : 1
    property real lyricsScale: Math.max(0.5, gridScale) * Config.background.desktopLyrics.scale
    readonly property bool bgEnabled: Config.background.desktopLyrics.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopLyrics.background.blur && !GameMode.enabled
    readonly property bool invertColors: Config.background.desktopLyrics.invertColors
    // Was a gate on the fixed-position loader in Background.qml; it has to live
    // here now that the lyrics are a widget.
    readonly property bool gameModeBlocked: GameMode.enabled && GlobalConfig.utilities.gameMode.disableDesktopLyrics
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    readonly property int alignment: Config.background.desktopLyrics.alignment
    readonly property bool autoHideFullscreen: Config.background.desktopLyrics.autoHideFullscreen
    readonly property bool autoHideTiled: Config.background.desktopLyrics.autoHideTiled
    
    readonly property bool hasFullscreen: {
        const wins = Compositor.getActiveWorkspaceWindows();
        return wins ? wins.some(t => t.fullscreen) : false;
    }
    readonly property bool hasTiled: {
        const wins = Compositor.getActiveWorkspaceWindows();
        return wins ? wins.some(t => !t.floating && !t.fullscreen) : false;
    }

    readonly property bool shouldHide: (autoHideFullscreen && hasFullscreen) || (autoHideTiled && hasTiled)
    readonly property bool appFilterActive: Players.appFilterPasses(Config.background.desktopLyrics.appFilter, Config.background.desktopLyrics.filteredApps, Players.active)

    property bool hasLyrics: Lyrics.hasLyrics
    // Plain and instrumental results still have text but no timing; show the
    // first lines without treating any of them as the active karaoke line.
    property int currentLyricIndex: Lyrics.hasLyrics
        ? (Lyrics.timedLyrics ? LyricsController.currentIndex : 0)
        : -1
    readonly property bool isCurrentActive: currentLyricIndex >= 0 && Lyrics.timedLyrics
    readonly property var currentLineObj: currentLyricIndex >= 0 ? (Lyrics.lyricLines[currentLyricIndex] ?? null) : null

    property var player: Players.active
    readonly property int contextLines: Config.background.desktopLyrics.contextLines
    readonly property int centerSlot: contextLines
    readonly property int slotCount: contextLines * 2 + 1
    readonly property bool hasText: {
        const lines = Lyrics.lyrics;
        for (let d = -contextLines; d <= contextLines; d++) {
            const i = currentLyricIndex + d;
            if (i >= 0 && i < lines.length && (lines[i] ?? "").trim() !== "")
                return true;
        }
        return false;
    }

    property real lyricSpacing: Tokens.spacing.large * root.lyricsScale
    property int slideDir: 1
    property int lastSlideIndex: -1
    readonly property int textAlignment: {
        switch (root.alignment) {
        case 0:
            return Text.AlignLeft;
        case 2:
            return Text.AlignRight;
        default:
            return Text.AlignHCenter;
        }
    }

    function reloadTrack() {
        const p = Players.active;
        if (p) {
            LyricsService.setTrack(p.trackArtist ?? "", p.trackTitle ?? "", p.trackAlbum ?? "", p.length ?? 0,
                p.metadata ? (p.metadata["xesam:url"] ?? "") : "");
        } else {
            LyricsService.clearTrack();
        }
    }

    function lineText(d) {
        const i = currentLyricIndex + d;
        const lines = Lyrics.lyrics;
        if (i < 0 || i >= lines.length)
            return "";
        return (lines[i] ?? "").replace(/\u00A0/g, " ");
    }

    onCurrentLyricIndexChanged: {
        slideDir = currentLyricIndex > lastSlideIndex ? 1 : -1;
        lastSlideIndex = currentLyricIndex;
    }

    Component.onCompleted: {
        root.reloadTrack();
    }

    implicitWidth: 350 * root.lyricsScale
    implicitHeight: Config.background.desktopLyrics.height * root.lyricsScale

    opacity: (((root.hasLyrics && root.hasText) || Lyrics.loading) && !root.shouldHide && !root.gameModeBlocked && root.appFilterActive) ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        Anim {}
    }

    Behavior on lyricsScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.StandardSmall
        }
    }

    Connections {
        function onActiveChanged() {
            root.reloadTrack();
        }

        target: Players
    }

    Connections {
        function onPostTrackChanged() {
            root.reloadTrack();
        }

        ignoreUnknownSignals: true

        target: Players.active
    }

    Item {
        id: lyricsContainer

        anchors.fill: parent
        // Removed clip: true from here so the shadow doesn't get cut off

        layer.enabled: Config.background.desktopLyrics.shadow.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background.desktopLyrics.shadow.opacity
            shadowBlur: Config.background.desktopLyrics.shadow.blur
        }

        Loader {
            id: blurLoader

            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled && root.wallpaper !== null

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Tokens.rounding.large * root.lyricsScale
            opacity: Config.background.desktopLyrics.background.opacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        Loader {
            id: loadingIndicator

            anchors.centerIn: parent
            asynchronous: true
            active: opacity > 0
            opacity: Lyrics.loading && !root.hasLyrics ? 1 : 0

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.large * root.lyricsScale

                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: shape.implicitSize + Tokens.padding.medium * 2 * root.lyricsScale
                    implicitHeight: shape.implicitSize + Tokens.padding.medium * 2 * root.lyricsScale
                    color: Colours.palette.m3primaryContainer
                    radius: Tokens.rounding.full

                    LoadingIndicator {
                        id: shape

                        anchors.centerIn: parent
                        implicitSize: Math.round(Tokens.sizes.dashboard.mediaSectionWidth / 5 * root.lyricsScale)
                        containsIcon: true
                        color: Colours.palette.m3primary
                    }
                }

                StyledText {
                    text: qsTr("Loading lyrics...")
                    color: root.safeSecondary
                    // Built from the token builder so it keeps the font's
                    // variable axes (ROND/opsz/wght) instead of a bare family.
                    font: Tokens.font.title.builders.medium.size(Math.round(Tokens.font.title.medium.pointSize * root.lyricsScale)).build()
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // --- NEW INNER CONTAINER FOR FADE MASK ---
        Item {
            id: fadeContainer

            anchors.fill: parent
            clip: true
            opacity: root.hasLyrics ? 1 : 0

            layer.enabled: true
            layer.effect: Mask {
                maskSource: fadeMask
            }

            Behavior on opacity {
                Anim {
                    type: Anim.SlowEffects
                }
            }

            Rectangle {
                id: fadeMask

                layer.enabled: true
                visible: false
                implicitWidth: fadeContainer.width
                implicitHeight: fadeContainer.height

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        color: Qt.alpha("black", 0)
                        position: 0
                    }
                    GradientStop {
                        color: Qt.alpha("black", 1)
                        position: 0.25 // fadeMargin
                    }
                    GradientStop {
                        color: Qt.alpha("black", 1)
                        position: 0.75 // 1 - fadeMargin
                    }
                    GradientStop {
                        color: Qt.alpha("black", 0)
                        position: 1
                    }
                }
            }

            Column {
                id: lyricsColumn

                anchors.centerIn: parent
                spacing: root.lyricSpacing

                Repeater {
                    model: root.slotCount

                    delegate: Item {
                        id: slot

                        required property int index

                        readonly property int distance: index - root.centerSlot
                        readonly property bool isCenter: distance === 0
                        readonly property string line: root.lineText(distance)
                        readonly property real bigPointSize: Tokens.font.title.medium.pointSize * 1.3 * root.lyricsScale
                        readonly property real smallPointSize: Tokens.font.body.medium.pointSize * root.lyricsScale
                        // Word/syllable karaoke only applies to the centre line; the
                        // surrounding context lines stay plain.
                        readonly property bool karaoke: slot.isCenter && root.isCurrentActive && Lyrics.wordSynced && ((root.currentLineObj?.w?.length ?? 0) > 0)

                        width: lyricsContainer.width
                        height: slot.karaoke ? (karaoke.item?.implicitHeight ?? 0) : label.implicitHeight
                        // Untimed results have no active line, but they should still
                        // show the first context lines instead of an empty overlay.
                        visible: (root.isCurrentActive || (Lyrics.hasLyrics && !Lyrics.timedLyrics)) && line !== ""

                        transform: Translate {
                            id: slideOffset

                            y: 0
                        }

                        Connections {
                            function onCurrentLyricIndexChanged() {
                                if (root.isCurrentActive)
                                    slide.restart();
                            }

                            target: root
                        }

                        SequentialAnimation {
                            id: slide

                            PropertyAction {
                                target: slideOffset
                                property: "y"
                                value: (root.slideDir > 0 ? 1 : -1) * (slot.height + root.lyricSpacing)
                            }

                            NumberAnimation {
                                target: slideOffset
                                property: "y"
                                to: 0
                                duration: Tokens.anim.durations.expressiveDefaultEffects
                                easing.type: Easing.OutCubic
                            }
                        }

                        Loader {
                            id: karaoke

                            anchors.left: parent.left
                            anchors.right: parent.right
                            active: slot.karaoke
                            visible: active

                            sourceComponent: LyricsVocal {
                                width: slot.width
                                line: root.currentLineObj
                                active: true
                                position: LyricsController.position
                                offset: Lyrics.offset / 1000
                                baseColor: root.safeSecondary
                                activeColor: Colours.palette.m3primary
                                horizontalAlignment: root.textAlignment
                                font: Tokens.font.body.builders.medium.size(Math.round(slot.bigPointSize)).weight(Font.Bold).build()
                            }
                        }

                        MultiEffect {
                            anchors.fill: slot.karaoke ? karaoke : label
                            source: slot.karaoke ? karaoke.item : label
                            enabled: slot.isCenter && root.isCurrentActive

                            blurEnabled: true
                            blur: 0.4

                            shadowEnabled: true
                            shadowColor: Colours.palette.m3primary
                            shadowOpacity: 0.5
                            shadowBlur: 0.6
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0

                            autoPaddingEnabled: true
                        }

                        StyledText {
                            id: label

                            anchors.fill: parent
                            visible: !slot.karaoke
                            text: slot.line
                            font: Tokens.font.body.builders.medium.size(Math.round(slot.isCenter ? slot.bigPointSize : slot.smallPointSize)).weight(slot.isCenter ? Font.Bold : Tokens.font.body.small.weight).build()
                            color: slot.isCenter ? Colours.palette.m3primary : root.safeSecondary
                            opacity: slot.isCenter ? 1 : Math.max(0.3, 0.6 - (Math.abs(slot.distance) - 1) * 0.15)
                            wrapMode: Text.WordWrap
                            horizontalAlignment: root.textAlignment
                        }
                    }
                }
            }
        }
    }

    LyricsSubscription {
        active: root.visible
    }
}
