#include "detect.hpp"

#include <qglobal.h>
#include <qstringlist.h>

namespace caelestia {

    namespace {

        [[nodiscard]] bool envNonEmpty(const char* name) { return !qEnvironmentVariable(name).isEmpty(); }

        [[nodiscard]] QString buildEnvHint() {
            constexpr const char* vars[] = {"XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "DESKTOP_SESSION"};
            QStringList parts;
            for (const char* var : vars) {
                const QString value = qEnvironmentVariable(var);
                if (!value.isEmpty()) {
                    parts.append(value);
                }
            }
            return parts.join(u':');
        }

        [[nodiscard]] CompositorKind detectImpl() {
            // Compositor-set env vars are the most reliable signal.
            if (envNonEmpty("UMBRIEL_SOCKET")) {
                return CompositorKind::Umbriel;
            }
            if (envNonEmpty("LABWC_PID")) {
                return CompositorKind::Labwc;
            }
            if (envNonEmpty("NIRI_SOCKET")) {
                return CompositorKind::Niri;
            }
            if (envNonEmpty("HYPRLAND_INSTANCE_SIGNATURE")) {
                return CompositorKind::Hyprland;
            }
            if (envNonEmpty("SWAYSOCK")) {
                return CompositorKind::Sway;
            }
            if (envNonEmpty("MANGO_INSTANCE_SIGNATURE")) {
                return CompositorKind::Mango;
            }

            // Fall back to the desktop env hint (covers compositors without a socket var).
            const QString hint = buildEnvHint();
            if (hint.contains(QStringLiteral("umbriel"), Qt::CaseInsensitive)) {
                return CompositorKind::Umbriel;
            }
            if (hint.contains(QStringLiteral("niri"), Qt::CaseInsensitive)) {
                return CompositorKind::Niri;
            }
            if (hint.contains(QStringLiteral("hypr"), Qt::CaseInsensitive)) {
                return CompositorKind::Hyprland;
            }
            if (hint.contains(QStringLiteral("sway"), Qt::CaseInsensitive)) {
                return CompositorKind::Sway;
            }
            if (hint.contains(QStringLiteral("mango"), Qt::CaseInsensitive)) {
                return CompositorKind::Mango;
            }
            if (hint.contains(QStringLiteral("dwl"), Qt::CaseInsensitive)) {
                return CompositorKind::Dwl;
            }
            if (hint.contains(QStringLiteral("labwc"), Qt::CaseInsensitive)) {
                return CompositorKind::Labwc;
            }
            if (hint.contains(QStringLiteral("kde"), Qt::CaseInsensitive) || hint.contains(QStringLiteral("plasma"), Qt::CaseInsensitive)) {
                return CompositorKind::Kde;
            }
            return CompositorKind::Unknown;
        }

    } // namespace

    CompositorKind detect() {
        static const CompositorKind cached = detectImpl();
        return cached;
    }

    QString kindId(CompositorKind kind) {
        switch (kind) {
        case CompositorKind::Niri:
            return QStringLiteral("niri");
        case CompositorKind::Hyprland:
            return QStringLiteral("hyprland");
        case CompositorKind::Sway:
            return QStringLiteral("sway");
        case CompositorKind::Mango:
            return QStringLiteral("mango");
        case CompositorKind::Dwl:
            return QStringLiteral("dwl");
        case CompositorKind::Labwc:
            return QStringLiteral("labwc");
        case CompositorKind::Kde:
            return QStringLiteral("kde");
        case CompositorKind::Umbriel:
            return QStringLiteral("umbriel");
        case CompositorKind::Unknown:
            return QStringLiteral("unknown");
        }
        return QStringLiteral("unknown");
    }

    QString name(CompositorKind kind) {
        switch (kind) {
        case CompositorKind::Niri:
            return QStringLiteral("Niri");
        case CompositorKind::Hyprland:
            return QStringLiteral("Hyprland");
        case CompositorKind::Sway:
            return QStringLiteral("Sway");
        case CompositorKind::Mango:
            return QStringLiteral("Mango");
        case CompositorKind::Dwl:
            return QStringLiteral("dwl");
        case CompositorKind::Labwc:
            return QStringLiteral("Labwc");
        case CompositorKind::Kde:
            return QStringLiteral("KDE");
        case CompositorKind::Umbriel:
            return QStringLiteral("Umbriel");
        case CompositorKind::Unknown:
            return QStringLiteral("Unknown");
        }
        return QStringLiteral("Unknown");
    }

    QString envHint() {
        static const QString cached = buildEnvHint();
        return cached;
    }

} // namespace caelestia
