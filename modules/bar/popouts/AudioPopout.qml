pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal && popouts.currentSection === "end"

    implicitWidth: Math.max(Tokens.sizes.bar.audioWidth, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)
    implicitHeight: layout.implicitHeight

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.topMargin: Tokens.padding.medium
            Layout.leftMargin: Tokens.padding.small
            text: Tr.tr("Audio")
            font.weight: 500
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            TextButton {
                Layout.fillWidth: true
                type: TextButton.Tonal
                text: Tr.tr("Device")
                checked: root.popouts.audioTab === 0
                onClicked: root.popouts.audioTab = 0
            }

            TextButton {
                Layout.fillWidth: true
                type: TextButton.Tonal
                text: Tr.tr("Streams")
                checked: root.popouts.audioTab === 1
                onClicked: root.popouts.audioTab = 1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.popouts.audioTab === 0
            spacing: layout.spacing

            StyledRect {
                Layout.fillWidth: true
                implicitWidth: outputLayout.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: outputLayout.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer
                clip: true

                ColumnLayout {
                    id: outputLayout

                    width: parent.width - Tokens.padding.medium * 2
                    x: Tokens.padding.medium
                    y: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: Tr.tr("Output device")
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                    }

                    Repeater {
                        model: Audio.sinks

                        StyledRadioButton {
                            id: outputControl

                            required property PwNode modelData

                            Layout.fillWidth: true
                            ButtonGroup.group: sinks
                            checked: Audio.sink?.id === modelData.id
                            onClicked: Audio.setAudioSink(modelData)
                            text: modelData.description
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitWidth: inputLayout.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: inputLayout.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer
                clip: true

                ColumnLayout {
                    id: inputLayout

                    width: parent.width - Tokens.padding.medium * 2
                    x: Tokens.padding.medium
                    y: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: Tr.tr("Input device")
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                    }

                    Repeater {
                        model: Audio.sources

                        StyledRadioButton {
                            id: inputControl

                            required property PwNode modelData

                            Layout.fillWidth: true
                            ButtonGroup.group: sources
                            checked: Audio.source?.id === modelData.id
                            onClicked: Audio.setAudioSource(modelData)
                            text: modelData.description
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.popouts.audioTab === 1
            spacing: layout.spacing

            ColumnLayout {
                Layout.fillWidth: true
                visible: Audio.streams.length === 0
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.padding.large
                    text: "music_off"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: Tokens.padding.large
                    text: Tr.tr("No apps playing audio")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }

            ListView {
                id: streamList

                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 320)
                visible: Audio.streams.length > 0
                clip: true
                spacing: Tokens.spacing.medium
                model: [...Audio.streams]

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: streamList
                }

                delegate: ColumnLayout {
                    id: stream

                    required property PwNode modelData
                    readonly property bool muted: modelData?.audio?.muted ?? false

                    width: ListView.view.width
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        IconButton {
                            type: IconButton.Text
                            icon: Icons.getVolumeIcon(stream.modelData?.audio?.volume ?? 0, stream.muted)
                            onClicked: Audio.setStreamMuted(stream.modelData, !stream.muted)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Audio.getStreamName(stream.modelData)
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                            color: stream.muted ? Colours.palette.m3outline : Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: Strings.percentOne(stream.modelData?.audio?.volume ?? 0)
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                        }
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        value: stream.modelData?.audio?.volume ?? 0
                        enabled: !stream.muted
                        onInteraction: v => Audio.setStreamVolume(stream.modelData, v)
                    }
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: Audio.muted ? Tr.tr("Volume (Muted)") : Tr.tr("Volume (%1%)").arg(Math.round(Audio.volume * 100))
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 3

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: Audio.volume
                onInteraction: v => Audio.setVolume(v)
                onReleased: v => Audio.playEffectTick()
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.small
            text: Tr.tr("Open settings")
            icon: "settings"

            onClicked: root.popouts.detachRequested("audio")
        }
    }
}
