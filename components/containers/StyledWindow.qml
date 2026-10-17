import Quickshell
import Quickshell.Wayland
import Caelestia.Config

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    required property string name
    // Marks a surface as part of the desktop widget layer (the wallpaper,
    // desktop icons and desktop widgets). Those get a namespace of their own so
    // compositor layer rules can target the desktop without catching panels.
    property bool isDesktopWidget: false

    WlrLayershell.namespace: isDesktopWidget ? "caelestia-desktop" : `caelestia-${name}`
    color: "transparent"

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name
}
