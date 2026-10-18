pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.controls as Controls
import qs.utils

Controls.Menu {
    id: root

    property DesktopEntry app: null

    property real _menuW: root.backgroundItem && root.backgroundItem.implicitWidth > 0 ? root.backgroundItem.implicitWidth : 220
    property real _menuH: root.backgroundItem && root.backgroundItem.implicitHeight > 0 ? root.backgroundItem.implicitHeight : 200
    property bool _flipX: {
        if (!attachTo || !parent)
            return false;
        const mapped = attachTo.mapToItem(parent, 0, 0);
        return mapped.x + attachTo.width / 2 > parent.width / 2;
    }
    property bool _flipY: {
        if (!attachTo || !parent)
            return false;
        const mapped = attachTo.mapToItem(parent, 0, attachTo.height);
        return mapped.y + _menuH > parent.height;
    }

    // The Midnight dock pins whatever is in launcher.favouriteApps.
    readonly property bool isPinnedToDock: app ? Strings.testRegexList(GlobalConfig.launcher.favouriteApps, app.id) : false
    readonly property bool isHidden: app ? Strings.testRegexList(GlobalConfig.launcher.hiddenApps, app.id) : false

    function openFor(targetApp: DesktopEntry, targetItem: Item): void {
        app = targetApp;
        attachTo = targetItem;
        expanded = true;
    }

    attachSideX: _flipX ? Controls.Menu.Right : Controls.Menu.Left
    attachSideY: _flipY ? Controls.Menu.Top : Controls.Menu.Bottom
    thisSideX: _flipX ? Controls.Menu.Right : Controls.Menu.Left
    thisSideY: _flipY ? Controls.Menu.Bottom : Controls.Menu.Top

    items: [
        Controls.MenuItem {
            text: root.isPinnedToDock ? qsTr("Unpin from dock") : qsTr("Pin to dock")
            icon: "push_pin"
            onClicked: {
                if (!root.app?.id)
                    return;
                const current = GlobalConfig.launcher.favouriteApps ? [...GlobalConfig.launcher.favouriteApps] : [];
                const id = root.app.id;
                if (Strings.testRegexList(current, id)) {
                    const idx = current.indexOf(id);
                    if (idx !== -1)
                        current.splice(idx, 1);
                } else {
                    current.push(id);
                }
                GlobalConfig.launcher.favouriteApps = current;
            }
        },
        Controls.MenuItem {
            text: root.isHidden ? qsTr("Show in launcher") : qsTr("Hide app")
            icon: root.isHidden ? "visibility" : "visibility_off"
            onClicked: {
                const appId = root.app?.id;
                if (!appId)
                    return;
                const hiddenApps = GlobalConfig.launcher.hiddenApps ? [...GlobalConfig.launcher.hiddenApps] : [];
                if (Strings.testRegexList(hiddenApps, appId)) {
                    const idx = hiddenApps.indexOf(appId);
                    if (idx !== -1)
                        hiddenApps.splice(idx, 1);
                } else {
                    hiddenApps.push(appId);
                }
                GlobalConfig.launcher.hiddenApps = hiddenApps;
            }
        }
    ]
}
