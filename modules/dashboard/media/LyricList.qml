pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    property bool active: true

    readonly property real fadeAmount: 0.1
    property var lyricList: LyricsService.lines

    function reloadTrack() {
        const p = Players.active;
        if (p) {
            LyricsService.setTrack(p.trackArtist ?? "", p.trackTitle ?? "", p.trackAlbum ?? "", p.length ?? 0,
                p.metadata ? (p.metadata["xesam:url"] ?? "") : "");
        } else {
            LyricsService.clearTrack();
        }
    }

    Component.onCompleted: {
        if (root.active)
            root.reloadTrack();
    }

    onActiveChanged: {
        if (root.active)
            root.reloadTrack();
    }

    layer.enabled: true
    layer.effect: Mask {
        maskSource: mask

        Rectangle {
            id: mask

            layer.enabled: true
            visible: false
            implicitWidth: root.width
            implicitHeight: root.height

            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop {
                    color: Qt.alpha("black", 0)
                    position: 0
                }
                GradientStop {
                    color: Qt.alpha("black", 1)
                    position: root.fadeAmount
                }
                GradientStop {
                    color: Qt.alpha("black", 1)
                    position: 1 - root.fadeAmount
                }
                GradientStop {
                    color: Qt.alpha("black", 0)
                    position: 1
                }
            }
        }
    }

    state: {
        if (Lyrics.hasLyrics)
            return "hasLyrics";
        if (Lyrics.loading)
            return "loading";
        return "noLyrics";
    }

    states: [
        State {
            name: "loading"

            PropertyChanges {
                loadingIndicator.opacity: 1
                lyrics.opacity: 0
                noLyrics.opacity: 0
            }
        },
        State {
            name: "hasLyrics"

            PropertyChanges {
                loadingIndicator.opacity: 0
                lyrics.opacity: 1
                noLyrics.opacity: 0
            }
        },
        State {
            name: "noLyrics"

            PropertyChanges {
                loadingIndicator.opacity: 0
                lyrics.opacity: 0
                noLyrics.opacity: 1
            }
        }
    ]

    transitions: [
        Transition {
            from: "loading"

            SequentialAnimation {
                Anim {
                    target: loadingIndicator
                    property: "opacity"
                    type: Anim.DefaultEffects
                }
                Anim {
                    targets: [lyrics, noLyrics]
                    property: "opacity"
                    type: Anim.SlowEffects
                }
            }
        },
        Transition {
            from: "hasLyrics"

            SequentialAnimation {
                Anim {
                    target: lyrics
                    property: "opacity"
                    type: Anim.DefaultEffects
                }
                Anim {
                    targets: [loadingIndicator, noLyrics]
                    property: "opacity"
                    type: Anim.SlowEffects
                }
            }
        },
        Transition {
            from: "noLyrics"

            SequentialAnimation {
                Anim {
                    target: noLyrics
                    property: "opacity"
                    type: Anim.DefaultEffects
                }
                Anim {
                    targets: [loadingIndicator, lyrics]
                    property: "opacity"
                    type: Anim.SlowEffects
                }
            }
        }
    ]

    Connections {
        enabled: root.active

        function onActiveChanged() {
            root.reloadTrack();
        }

        target: Players
    }

    Connections {
        enabled: root.active

        function onPostTrackChanged() {
            root.reloadTrack();
        }

        target: Players.active
        ignoreUnknownSignals: true
    }

    Loader {
        id: loadingIndicator

        anchors.centerIn: parent
        asynchronous: true
        active: opacity > 0
        opacity: 0

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.large

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: shape.implicitSize + Tokens.padding.medium * 2
                implicitHeight: shape.implicitSize + Tokens.padding.medium * 2
                color: Colours.palette.m3primaryContainer
                radius: Tokens.rounding.full

                LoadingIndicator {
                    id: shape

                    anchors.centerIn: parent
                    active: root.active
                    implicitSize: Math.round(Tokens.sizes.dashboard.mediaSectionWidth / 5)
                    containsIcon: true // This removes the pentagon, which is not centered
                }
            }

            StyledText {
                text: Tr.tr("Loading lyrics...")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.title.medium
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: noLyrics

        anchors.centerIn: parent
        asynchronous: true
        active: opacity > 0
        opacity: 0

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "sentiment_sad"
                fontStyle: Tokens.font.icon.builders.large.scale(2).build()
                color: Colours.palette.m3outline
            }

            StyledText {
                text: Tr.tr("No lyrics found")
                color: Colours.palette.m3outline
                font: Tokens.font.title.medium
            }
        }
    }

    StyledListView {
        id: lyrics

        anchors.fill: parent
        anchors.topMargin: parent.height * root.fadeAmount / 2
        anchors.bottomMargin: parent.height * root.fadeAmount / 2

        displayMarginBeginning: anchors.topMargin
        displayMarginEnd: anchors.bottomMargin

        model: root.lyricList
        Component.onCompleted: syncCurrent()
        onModelChanged: Qt.callLater(syncCurrent)

        function syncCurrent(): void {
            currentIndex = LyricsController.currentIndex;
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Center);
        }

        Connections {
            target: LyricsController

            function onCurrentIndexChanged(): void {
                lyrics.syncCurrent();
            }
        }

        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: Tokens.anim.durations.large
        highlightMoveVelocity: -1
        preferredHighlightBegin: (height - (currentItem?.implicitHeight ?? 0)) / 2
        preferredHighlightEnd: (height + (currentItem?.implicitHeight ?? 0)) / 2

        spacing: Tokens.spacing.small
        opacity: 0
        enabled: opacity > 0

        delegate: Item {
            id: lyric

            required property var modelData
            required property int index
            // ListView attached properties only reflect the delegate root, so a
            // child cannot read isCurrentItem; derive it from the shared clock.
            readonly property bool isCurrent: index === LyricsController.currentIndex
            property real effectScale: lyric.isCurrent ? 1 : 0

            anchors.left: lyrics.contentItem.left
            anchors.right: lyrics.contentItem.right
            implicitHeight: vocal.implicitHeight

            LyricsVocal {
                id: vocal

                width: parent.width
                line: lyric.modelData
                active: lyric.isCurrent
                position: LyricsController.position
                offset: Lyrics.offset / 1000
                baseColor: lyric.isCurrent || mouse.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3outline
                activeColor: Colours.palette.m3primary
                font: Tokens.font.body.medium
                horizontalAlignment: Text.AlignLeft

                layer.enabled: lyric.effectScale > 0
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Colours.palette.m3primary
                    shadowOpacity: 0.5 * lyric.effectScale
                    shadowBlur: 0.6 * lyric.effectScale
                    blur: 0.4 * lyric.effectScale
                }
            }

            Behavior on effectScale {
                Anim {
                    type: Anim.SlowEffects
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    LyricsController.seek(lyric.modelData);
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    LyricsSubscription {
        active: root.active
    }
}
