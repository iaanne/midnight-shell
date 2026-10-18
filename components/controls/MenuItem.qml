import QtQuick

QtObject {
    required property string text
    property string icon
    property string trailingIcon
    property string activeIcon: icon
    property string activeText: text
    property var value
    // Entries that do not apply to the current selection are left out of the
    // menu entirely; Menu filters on this. A MenuItem is a plain QtObject, so
    // it has nothing to hide itself with.
    property bool visible: true

    signal clicked
}
