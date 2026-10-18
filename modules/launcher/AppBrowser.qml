pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property real maxWidth

    readonly property var browser: loader.item
    readonly property var currentItem: root.browser?.currentItem ?? null
    readonly property int count: root.browser?.count ?? 0

    function refresh(): void {
        root.browser?.refresh();
    }

    function launch(app): void {
        root.browser?.launch(app);
    }

    function selectTile(index: int): void {
        root.browser?.selectTile(index);
    }

    function incrementCurrentIndex(): void {
        root.browser?.incrementCurrentIndex();
    }

    function decrementCurrentIndex(): void {
        root.browser?.decrementCurrentIndex();
    }

    function moveLeft(wrap): void {
        root.browser?.moveLeft(wrap);
    }

    function moveRight(wrap): void {
        root.browser?.moveRight(wrap);
    }

    function nextCategory(): void {
        if (typeof root.browser?.nextCategory === "function")
            root.browser.nextCategory();
    }

    function prevCategory(): void {
        if (typeof root.browser?.prevCategory === "function")
            root.browser.prevCategory();
    }

    function toggleFocus(): void {
        root.browser?.toggleFocus();
    }

    function activateCurrent(): void {
        root.browser?.activateCurrent();
    }

    implicitWidth: root.browser?.implicitWidth ?? 0
    implicitHeight: root.browser?.implicitHeight ?? 0

    Loader {
        id: loader

        anchors.fill: parent
        sourceComponent: {
            switch (Config.launcher.browseLayout) {
            case LauncherBrowseLayout.Simple:
                return simpleBrowser;
            case LauncherBrowseLayout.Compact:
                return compactBrowser;
            default:
                return gridBrowser;
            }
        }
    }

    Component {
        id: gridBrowser

        AppBrowserGrid {
            screenState: root.screenState
            maxWidth: root.maxWidth
        }
    }

    Component {
        id: simpleBrowser

        AppBrowserSimple {
            screenState: root.screenState
            maxWidth: root.maxWidth
        }
    }

    Component {
        id: compactBrowser

        AppBrowserCompact {
            screenState: root.screenState
            maxWidth: root.maxWidth
        }
    }
}
