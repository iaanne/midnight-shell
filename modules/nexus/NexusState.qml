import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    property ShellScreen screen
    property bool isWindow
    property bool animatingContainer
    property int currentPageIdx
    property list<int> subPageIdxStack
    property string searchQuery: ""
    readonly property bool searchOpen: searchQuery.trim().length > 0
    property bool justUnlockedDevMode: false
    property string targetScreen: ""

    property string selectedWallpaperCategory
    property string wallpaperFilterType: "all"
    property BluetoothDevice selectedBtDevice
    property DesktopEntry selectedApp
    property string selectedWidgetKey: ""
    property int editingVpnIndex: -1
    property string selectedNetworkSsid
    property string selectedEthernetInterface
    property bool networkDetailsFromSaved
    // Target of the add/edit network configuration sub-page. The SSID is
    // pre-filled and, when editing, the saved profile is loaded into the form.
    property string networkConfigSsid
    property bool networkConfigEditing

    signal close
    signal subPageOpened(idx: int)
    signal subPageClosed

    function openSubPage(idx: int): void {
        subPageIdxStack.push(idx);
        subPageOpened(idx);
    }

    function closeSubPage(): void {
        subPageClosed();
        subPageIdxStack.pop();
    }

    onCurrentPageIdxChanged: subPageIdxStack.length = 0
}
