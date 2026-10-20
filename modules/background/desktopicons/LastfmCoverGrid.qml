pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// A size-adaptive grid of Last.fm cover art. The widget decides the entity and
// range; this component only lays the result out and asks for the release-year
// metadata of the tiles that are actually visible.
Item {
    id: root

    property var items: []
    property string entity: "album"
    property bool showArtist: true
    property bool showAlbum: true
    property bool showYear: false

    readonly property real gap: Math.max(3, Tokens.spacing.small)
    readonly property real minTile: 88
    readonly property int maxColumns: 8
    readonly property int columns: Math.max(1, Math.min(maxColumns, Math.floor((width + gap) / (minTile + gap))))
    readonly property real widthTile: (width - (columns - 1) * gap) / columns
    // Start with the rows that fit at the width-derived tile size, then take an
    // extra row when shrinking the tiles only slightly fills the height better.
    readonly property int baseRows: Math.max(1, Math.floor((height + gap) / (widthTile + gap)))
    readonly property int rows: {
        const maxRows = Math.max(1, Math.floor((height + gap) / (minTile + gap)));
        let count = root.baseRows;
        while (count < maxRows) {
            const candidate = (height - count * gap) / (count + 1);
            if (candidate < root.minTile || candidate < root.widthTile * 0.9)
                break;
            count++;
        }
        return count;
    }
    readonly property real tileSize: Math.max(1, Math.min(widthTile, (height - (rows - 1) * gap) / rows))
    readonly property int visibleLimit: Math.max(1, columns * rows)
    readonly property var shownItems: (items ?? []).slice(0, visibleLimit)
    readonly property bool showSecondary: tileSize >= 88
    readonly property bool showYearLine: tileSize >= 96

    function syncDetails(): void {
        if (!items || shownItems.length === 0)
            return;
        Lastfm.ensureTileDetails(entity, shownItems, showAlbum, showYear);
    }

    onShownItemsChanged: syncDetails()
    onShowAlbumChanged: syncDetails()
    onShowYearChanged: syncDetails()
    onEntityChanged: syncDetails()
    Component.onCompleted: syncDetails()

    Grid {
        anchors.centerIn: parent
        columns: root.columns
        spacing: root.gap

        Repeater {
            model: root.shownItems

            delegate: Item {
                id: tile

                required property var modelData

                readonly property string albumText: root.entity === "track" ? Lastfm.tileAlbum(tile.modelData) : ""
                readonly property string yearText: root.entity !== "artist" ? Lastfm.tileYear(tile.modelData) : ""

                width: root.tileSize
                height: root.tileSize

                MediaArt {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    url: tile.modelData.image ?? ""

                    Rectangle {
                        anchors.fill: parent
                        z: 1
                        gradient: Gradient {
                            GradientStop {
                                position: 0.42
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: Qt.rgba(0, 0, 0, 0.86)
                            }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Math.max(4, Math.round(root.tileSize * 0.055))
                        z: 2
                        spacing: 0

                        StyledText {
                            width: parent.width
                            visible: root.tileSize >= 48
                            text: tile.modelData.name ?? ""
                            color: "white"
                            font: root.tileSize >= 140 ? Tokens.font.body.medium : Tokens.font.body.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            width: parent.width
                            visible: root.showArtist && root.entity !== "artist" && root.showSecondary && text !== ""
                            text: tile.modelData.artist ?? ""
                            color: Qt.rgba(1, 1, 1, 0.84)
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            width: parent.width
                            visible: root.showAlbum && root.entity === "track" && root.showSecondary && text !== ""
                            text: tile.albumText
                            color: Qt.rgba(1, 1, 1, 0.76)
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            width: parent.width
                            visible: root.showYear && root.entity !== "artist" && root.showYearLine && text !== ""
                            text: tile.yearText
                            color: Qt.rgba(1, 1, 1, 0.68)
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }
            }
        }
    }
}
