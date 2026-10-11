#pragma once

#include <QString>

namespace caelestia {

/// Compositor kinds the shell can recognize. Values and detection order
/// mirror noctalia's CompositorKind so both projects detect identically.
enum class CompositorKind {
    Unknown = 0,
    Niri,
    Hyprland,
    Sway,
    Mango,
    Labwc,
    Dwl,
    Kde,
    Umbriel,
};

/// Detect the running compositor. Cached for process lifetime. This is the
/// ONLY place in the shell allowed to sniff compositor env vars.
[[nodiscard]] CompositorKind detect();

/// Stable lowercase id ("niri", "hyprland", …, "unknown"); mirrored by
/// midnight-cli's compositor package.
[[nodiscard]] QString kindId(CompositorKind kind);

/// Human-readable name ("Niri", "Hyprland", …, "Unknown").
[[nodiscard]] QString name(CompositorKind kind);

/// Concatenated XDG_CURRENT_DESKTOP:XDG_SESSION_DESKTOP:DESKTOP_SESSION for diagnostics.
[[nodiscard]] QString envHint();

[[nodiscard]] inline bool isNiri() { return detect() == CompositorKind::Niri; }
[[nodiscard]] inline bool isHyprland() { return detect() == CompositorKind::Hyprland; }
[[nodiscard]] inline bool isSway() { return detect() == CompositorKind::Sway; }
[[nodiscard]] inline bool isMango() { return detect() == CompositorKind::Mango; }
[[nodiscard]] inline bool isLabwc() { return detect() == CompositorKind::Labwc; }
[[nodiscard]] inline bool isDwl() { return detect() == CompositorKind::Dwl; }
[[nodiscard]] inline bool isKde() { return detect() == CompositorKind::Kde; }
[[nodiscard]] inline bool isUmbriel() { return detect() == CompositorKind::Umbriel; }

} // namespace caelestia
