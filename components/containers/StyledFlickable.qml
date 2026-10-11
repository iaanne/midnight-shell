import QtQuick
import Caelestia.Config
import qs.components

Flickable {
    id: root

    property bool doneFakeFlick
    readonly property real scrollMultiplier: Config.general.scrollMultiplier

    maximumFlickVelocity: 3000

    rebound: Transition {
        onRunningChanged: {
            if (!running && !root.doneFakeFlick) {
                root.doneFakeFlick = true;
                root.flick(1, 1);
                root.flick(-1, -1);
                Qt.callLater(() => root.cancelFlick());
            }
        }

        Anim {
            properties: "x,y"
        }
    }

    WheelHandler {
        id: wheelHandler

        acceptedModifiers: Qt.NoModifier
        blocking: true

        property real lastDeltaY: 0
        property real lastTimestamp: 0

        onWheel: event => {
            const mult = root.scrollMultiplier;
            let dx = 0;
            let dy = 0;
            if (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0) {
                dx = event.pixelDelta.x * mult;
                dy = event.pixelDelta.y * mult;
            } else {
                dx = event.angleDelta.x / 120 * 72 * mult;
                dy = event.angleDelta.y / 120 * 72 * mult;
            }

            if ((root.flickableDirection & Flickable.VerticalFlick) && dy !== 0) {
                const minY = -root.topMargin;
                const maxY = Math.max(minY, root.contentHeight - root.height + root.bottomMargin);
                root.contentY = Math.min(maxY, Math.max(minY, root.contentY - dy));
            }
            if ((root.flickableDirection & Flickable.HorizontalFlick) && dx !== 0) {
                const minX = -root.leftMargin;
                const maxX = Math.max(minX, root.contentWidth - root.width + root.rightMargin);
                root.contentX = Math.min(maxX, Math.max(minX, root.contentX - dx));
            }

            if (event.phase === Qt.ScrollEnd) {
                const dt = (event.timestamp - wheelHandler.lastTimestamp) / 1000;
                if (dt > 0 && dt < 0.5)
                    root.flick(0, wheelHandler.lastDeltaY / dt);
            } else if (dy !== 0) {
                wheelHandler.lastDeltaY = dy;
                wheelHandler.lastTimestamp = event.timestamp;
            }

            event.accepted = true;
        }
    }

    Timer {
        running: root.doneFakeFlick
        interval: 10
        onTriggered: root.doneFakeFlick = false
    }
}
