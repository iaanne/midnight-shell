pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    function create(parent: Item, props: var): void {
        nexusComp.createObject(parent ?? dummy, props);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win

            // Page to open on, set through the props of create() so callers can
            // deep link (the desktop context menu does).
            property int initialPageIdx: 0

            readonly property bool shellBlurActive: GlobalConfig.appearance.blur.enabled
                && !GlobalConfig.appearance.pitchBlack
                && win.color.a < 1.0

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            BackgroundEffect.blurRegion: win.shellBlurActive ? blurRegion : null

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
            minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: Tr.tr("Nexus — %1").arg(PageRegistry.pages[nexus.nState.currentPageIdx].label)

            Region {
                id: blurRegion

                x: 0
                y: 0
                width: win.width
                height: win.height
                radius: Tokens.rounding.large
            }

            Nexus {
                id: nexus

                anchors.fill: parent
                nState.screen: win.screen
                nState.isWindow: true
                // Navigating breaks this binding, which is what we want: the
                // deep link only decides the page the window opens on.
                nState.currentPageIdx: Math.max(0, Math.min(PageRegistry.pages.length - 1, win.initialPageIdx))
                onClose: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
