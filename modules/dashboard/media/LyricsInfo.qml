import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Blobs
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.services
import "../../../components/controls"

Item {
    id: root

    property bool open
    readonly property real padding: Tokens.padding.large

    // Candidate picker: the selected-candidate row expands this list.
    property bool candidatesExpanded: false

    onOpenChanged: {
        if (!open)
            candidatesExpanded = false;
    }

    function backendLabel(candidate: var): string {
        switch (candidate.backend) {
        case LyricsBackend.LRCLIB:
            return "LRCLIB";
        case LyricsBackend.NetEase:
            return "NetEase";
        case LyricsBackend.QQMusic:
            return "QQ Music";
        case LyricsBackend.Local:
            return Tr.tr("Local");
        default:
            return "";
        }
    }

    implicitWidth: btn.implicitWidth * 0.9
    implicitHeight: btn.implicitHeight * 0.9

    BlobGroup {
        id: blobGroup

        color: Colours.palette.m3surfaceContainerHighest
        smoothing: root.Tokens.rounding.medium
        cornerFill: false

        Behavior on color {
            CAnim {}
        }
    }

    BlobRect {
        id: btnRect

        anchors.fill: parent
        anchors.margins: !btn.pressed && btn.containsMouse ? -Tokens.padding.extraSmall : 0
        group: blobGroup
        radius: Tokens.rounding.medium

        Behavior on anchors.margins {
            Anim {}
        }
    }

    BlobRect {
        id: rect

        anchors.right: parent.right
        anchors.top: parent.top

        implicitWidth: parent.width
        implicitHeight: parent.height

        group: blobGroup
        radius: Tokens.rounding.medium
        deformScale: 0.00001

        states: State {
            name: "open"
            when: root.open

            PropertyChanges {
                rect.anchors.rightMargin: root.width - root.Tokens.spacing.small
                rect.anchors.topMargin: -root.Tokens.padding.medium
                rect.implicitWidth: Math.max(layout.implicitWidth, placeholder.implicitWidth) + root.padding * 2
                rect.implicitHeight: Math.max(layout.implicitHeight, placeholder.implicitHeight) + root.padding * 2
                content.opacity: 1
            }
        }

        transitions: Transition {
            Anim {
                properties: "rightMargin,implicitWidth"
            }
            Anim {
                properties: "topMargin,implicitHeight"
                easing: root.Tokens.anim.expressiveFastSpatial
            }
            Anim {
                property: "opacity"
                type: Anim.DefaultEffects
            }
        }

        Behavior on implicitWidth {
            Anim {}
        }

        Behavior on implicitHeight {
            Anim {}
        }

        Item {
            id: content

            anchors.fill: parent
            clip: true
            opacity: 0
            state: Lyrics.loading || !Lyrics.hasLyrics ? "" : "hasLyrics"

            states: State {
                name: "hasLyrics"

                PropertyChanges {
                    layout.opacity: 1
                    placeholder.opacity: 0
                }
            }

            transitions: [
                Transition {
                    from: "hasLyrics"

                    SequentialAnimation {
                        Anim {
                            target: layout
                            property: "opacity"
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: placeholder
                            property: "opacity"
                            type: Anim.DefaultEffects
                        }
                    }
                },
                Transition {
                    to: "hasLyrics"

                    SequentialAnimation {
                        Anim {
                            target: placeholder
                            property: "opacity"
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: layout
                            property: "opacity"
                            type: Anim.DefaultEffects
                        }
                    }
                }
            ]

            ColumnLayout {
                id: layout

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall
                opacity: 0

                StyledText {
                    // TRANSLATORS: %1 = lyrics provider name, e.g. LRCLIB
                    text: Lyrics.instrumental ? Tr.tr("Instrumental") : Tr.tr("Source: %1").arg(Lyrics.sourceName || Tr.tr("Local"))
                    color: Colours.palette.m3onSurfaceVariant
                    animate: true
                }

                StyledText {
                    visible: Lyrics.sourceText !== ""
                    Layout.maximumWidth: Tokens.sizes.dashboard.mediaTabWidth
                    text: Lyrics.sourceText
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    animate: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        visible: Lyrics.selectedCandidate.id !== ""
                        Layout.fillWidth: true
                        Layout.maximumWidth: Tokens.sizes.dashboard.mediaTabWidth / 2
                        text: qsTr("Selected candidate: %1 | %2 | %3").arg(Lyrics.selectedCandidate.title).arg(Lyrics.selectedCandidate.artist).arg(Lyrics.selectedCandidate.album)
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        animate: true
                    }

                    IconButton {
                        visible: Lyrics.lyricCandidates.length > 0
                        icon: root.candidatesExpanded ? "expand_less" : "expand_more"
                        type: IconButton.Text
                        onClicked: root.candidatesExpanded = !root.candidatesExpanded
                    }

                    IconButton {
                        icon: "refresh"
                        type: IconButton.Text
                        onClicked: Lyrics.refresh()
                    }
                }

                StyledFlickable {
                    id: candidateScroller

                    Layout.fillWidth: true
                    // Collapsed height is zero; otherwise show up to 200px and scroll.
                    // The Repeater is not virtualized, so the content height is known
                    // even while the scroller is hidden.
                    Layout.preferredHeight: root.candidatesExpanded ? Math.min(candidateColumn.implicitHeight, 200) : 0
                    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth / 2
                    visible: root.candidatesExpanded && candidateColumn.implicitHeight > 0
                    contentWidth: width
                    contentHeight: candidateColumn.implicitHeight
                    flickableDirection: Flickable.VerticalFlick
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: candidateScroller
                    }

                    ColumnLayout {
                        id: candidateColumn

                        width: candidateScroller.width
                        spacing: Tokens.spacing.extraSmall

                        Repeater {
                            model: Lyrics.lyricCandidates

                            delegate: StyledRect {
                                id: candidateItem

                                required property var modelData

                                readonly property bool current: Lyrics.selectedCandidate.id === modelData.id
                                    && Lyrics.selectedCandidate.backend === modelData.backend
                                readonly property string label: modelData.title
                                    + (modelData.artist !== "" ? " — " + modelData.artist : "")
                                    + (modelData.album !== "" ? " (" + modelData.album + ")" : "")

                                Layout.fillWidth: true
                                implicitHeight: candidateRow.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.small
                                color: current ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)

                                StateLayer {
                                    radius: candidateItem.radius
                                    onClicked: {
                                        Lyrics.selectedCandidate = candidateItem.modelData;
                                        root.candidatesExpanded = false;
                                    }
                                }

                                RowLayout {
                                    id: candidateRow

                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.small
                                    spacing: Tokens.spacing.small

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: candidateItem.label
                                        color: candidateItem.current ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                        animate: true
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: root.backendLabel(candidateItem.modelData)
                                        color: candidateItem.current ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.body.small
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    visible: Lyrics.hasRomanized

                    StyledText {
                        Layout.fillWidth: true
                        text: Lyrics.showRomanized ? Tr.tr("Variant: Romanized") : Tr.tr("Variant: Original")
                        color: Colours.palette.m3onSurfaceVariant
                        animate: true
                    }

                    IconButton {
                        icon: "swap_horiz"
                        type: IconButton.Text
                        onClicked: Lyrics.showRomanized = !Lyrics.showRomanized
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Offset: %1 ms").arg(Math.round(Lyrics.offset))
                        color: Colours.palette.m3onSurfaceVariant
                        animate: true
                    }

                    IconButton {
                        icon: "remove"
                        type: IconButton.Text
                        onClicked: Lyrics.offset -= 100
                    }

                    IconButton {
                        icon: "add"
                        type: IconButton.Text
                        onClicked: Lyrics.offset += 100
                    }
                }
            }

            Item {
                id: placeholder

                anchors.centerIn: parent
                implicitWidth: placeholderText.implicitWidth
                implicitHeight: placeholderText.implicitHeight

                StyledText {
                    id: placeholderText

                    text: Lyrics.loading ? Tr.tr("Loading...") : Tr.tr("No lyrics found")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                    animate: true
                }
            }
        }
    }

    MouseArea {
        id: btn

        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.extraSmall * 2
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.open = !root.open

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            text: "more_vert"
            fontStyle: Tokens.font.icon.medium
        }
    }
}
