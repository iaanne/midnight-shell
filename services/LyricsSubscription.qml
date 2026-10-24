import QtQml
import qs.services

// Declares that a component is displaying lyrics. Every surface holds one of
// these so the controller can keep a ref-counted subscriber list.
QtObject {
    id: root

    property bool active: true

    function sync(): void {
        if (active)
            LyricsController.subscribe(root);
        else
            LyricsController.unsubscribe(root);
    }

    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: LyricsController.unsubscribe(root)
}
