import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily

        IdleInhibitor;
        GameMode;
        Notifs;
        Players;
        Brightness;
        Weather.reload();
        // Runs the desktop-widget migration before anything lays out the grid.
        ConfigMigrations;

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;

        if (GlobalConfig.services.lastfmEnabled)
            Lastfm;
    }
}
