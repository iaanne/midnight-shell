#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

class LockConfig : public settings::ObjectNode {
    CONFIG_NODE(LockConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, useWallpaper, false)
    CONFIG_PROPERTY(bool, recolourLogo, true)
    CONFIG_PROPERTY(bool, uppercaseAmPm, true)
    CONFIG_GLOBAL_PROPERTY(bool, enableFprint, true)
    CONFIG_GLOBAL_PROPERTY(int, maxFprintTries, 3)
    CONFIG_GLOBAL_PROPERTY(int, profilePicShape, 12)
    CONFIG_GLOBAL_PROPERTY(bool, enableHowdy, true)
    CONFIG_GLOBAL_PROPERTY(int, maxHowdyTries, 3)
    CONFIG_GLOBAL_PROPERTY(bool, triggerHowdyOnWake, true)
    CONFIG_PROPERTY(bool, hideNotifs, false)
    CONFIG_GLOBAL_PROPERTY(bool, lockOnStartup, false)
    // Unlock the login keyring with the password entered on the lock screen.
    CONFIG_GLOBAL_PROPERTY(bool, unlockKeyring, true)
    // Render GNOME keyring / GPG prompts in the shell instead of gcr-prompter.
    CONFIG_GLOBAL_PROPERTY(bool, keyringPrompter, true)
    // Ask the shell to replace a running gcr-prompter. Left off by default so
    // another prompter (for example GNOME Shell's) is never disturbed.
    CONFIG_GLOBAL_PROPERTY(bool, keyringPrompterTakeover, false)
    // Fork default: session buttons were always available on hover before
    // this option existed upstream
    CONFIG_GLOBAL_PROPERTY(bool, enableSessionControls, true)
};

} // namespace caelestia::config
