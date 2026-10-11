#pragma once

#include "detect.hpp"

#include <qdebug.h>
#include <qobject.h>
#include <qset.h>
#include <qvariant.h>

#include <QtQmlIntegration>

namespace caelestia {

/// Feature/action support matrix for a compositor backend. QML gates
/// features on these flags instead of branching on the compositor kind.
struct CompositorCapabilities {
    // State the backend publishes.
    bool workspaces = false;
    bool windows = false;
    bool outputs = false;
    bool kbLayout = false;

    // Neutral action verbs (below).
    bool focusWindow = false;
    bool closeWindow = false;
    bool focusWorkspace = false;
    bool moveWindowToWorkspace = false;
    bool moveWindowToIndex = false;
    bool toggleFloating = false;
    bool toggleFullscreen = false;
    bool toggleMaximize = false;
    bool toggleOverview = false;
    bool centerWindow = false;
    bool expandWindow = false;
    bool focusDirection = false;
    bool moveDirection = false;
    bool switchKbLayout = false;
    bool displayPower = false;
    bool screenshotWindow = false;

    // Feature extras.
    bool windowGrid = false;
    bool absoluteGeometry = false;
    bool scrollDirection = false;
    bool specialWorkspaces = false;

    /// "niri-kdl" when a keybind-config parser source exists, else empty.
    QString keybindSource;
};

/// Neutral window-manager interface, one implementation per compositor.
/// Neutral schema (COMPOSITOR_AGNOSTIC_PLAN.md §3.1):
///   workspace: { id: string, name: string, index: int, output: string,
///                active, focused, urgent, occupied: bool, windowCount: int, isSpecial: bool }
///   window:    { id: string, appId: string, title: string, workspaceId: string, output: string,
///                x, y, width, height: number, focused, floating, fullscreen, maximized,
///                urgent: bool, pid: int, grid?: { col, row } }
///   outputs:   { [name]: { name, mode: {width, height, refreshRate(mHz)},
///                location: {x, y}, scale, transform: int, enabled: bool } }
/// Backends normalize raw state on every mutation; CompositorIpc re-emits unchanged.
class CompositorBackend : public QObject {
    Q_OBJECT

public:
    explicit CompositorBackend(QObject* parent = nullptr) : QObject(parent) { }

    [[nodiscard]] virtual CompositorCapabilities capabilities() const = 0;
    [[nodiscard]] virtual bool available() const = 0;

    /// Path to the compositor's keybind config file, consumed by the parser
    /// named in CompositorCapabilities::keybindSource (niri: config.kdl).
    /// Empty when the compositor has no keybind-config parser source.
    [[nodiscard]] virtual QString keybindConfigPath() const { return {}; }

    [[nodiscard]] virtual QVariantList workspaces() const = 0;
    [[nodiscard]] virtual int focusedWorkspaceIndex() const = 0;
    [[nodiscard]] virtual QString focusedWorkspaceId() const = 0;
    [[nodiscard]] virtual QString focusedMonitorName() const = 0;

    [[nodiscard]] virtual QVariantList windows() const = 0;
    [[nodiscard]] virtual int focusedWindowIndex() const = 0;
    [[nodiscard]] virtual QString focusedWindowId() const = 0;
    [[nodiscard]] virtual QString focusedWindowTitle() const = 0;
    [[nodiscard]] virtual QString focusedWindowClass() const = 0;
    [[nodiscard]] virtual QVariantMap focusedWindow() const = 0;
    [[nodiscard]] virtual QVariantMap lastFocusedWindow() const = 0;
    [[nodiscard]] virtual bool inOverview() const = 0;
    [[nodiscard]] virtual QString scrollDirection() const = 0;

    [[nodiscard]] virtual QVariantMap outputs() const = 0;

    [[nodiscard]] virtual QVariantList kbLayoutsArray() const = 0;
    [[nodiscard]] virtual int kbLayoutIndex() const = 0;
    [[nodiscard]] virtual QString kbLayouts() const = 0;
    [[nodiscard]] virtual QString defaultKbLayout() const = 0;
    [[nodiscard]] virtual QString kbLayout() const = 0;

    Q_INVOKABLE virtual int getWorkspaceIdxById(const QString& id) const = 0;
    Q_INVOKABLE virtual QVariantList getWindowsByWorkspaceId(const QString& id) const = 0;
    Q_INVOKABLE virtual QVariantList getWindowsByWorkspaceIndex(int index) const = 0;
    Q_INVOKABLE virtual QVariantList getActiveWorkspaceWindows() const = 0;

    // ── Neutral action verbs ──
    Q_INVOKABLE virtual bool focusWorkspace(const QString& id) = 0;
    Q_INVOKABLE virtual bool focusWorkspaceRelative(int delta) = 0;
    Q_INVOKABLE virtual bool moveWindowToWorkspace(const QString& id) = 0;
    /// Move the focused window to position `index` within its workspace's column order.
    Q_INVOKABLE virtual bool moveWindowToIndex(int index) = 0;
    Q_INVOKABLE virtual bool focusWindow(const QString& id) = 0;
    Q_INVOKABLE virtual bool closeWindow(const QString& id = {}) = 0;
    Q_INVOKABLE virtual bool toggleFloating(const QString& id = {}) = 0;
    Q_INVOKABLE virtual bool toggleFullscreen() = 0;
    Q_INVOKABLE virtual bool toggleMaximize() = 0;
    Q_INVOKABLE virtual bool toggleOverview() = 0;
    Q_INVOKABLE virtual bool centerWindow() = 0;
    Q_INVOKABLE virtual bool expandWindow() = 0;
    Q_INVOKABLE virtual bool focusDirection(const QString& dir) = 0;
    Q_INVOKABLE virtual bool moveDirection(const QString& dir) = 0;
    Q_INVOKABLE virtual bool switchKbLayout(int index) = 0;
    Q_INVOKABLE virtual bool setDisplayPower(bool on) = 0;
    Q_INVOKABLE virtual bool screenshotWindow() = 0;
    /// Config-compat translator ("dpms off", "dpms on", …).
    Q_INVOKABLE virtual bool dispatch(const QString& command) = 0;

signals:
    void availableChanged();
    void workspacesChanged();
    void focusedWorkspaceChanged();
    void windowsChanged();
    void focusedWindowChanged();
    void lastFocusedWindowChanged();
    void scrollDirectionChanged();
    void inOverviewChanged();
    void outputsChanged();
    void keyboardChanged();
    void windowOpenedOrChanged(const QVariantMap& windowData);
    /// Fixes the latent Niri.windowClosed bug (was never declared on the QML facade).
    void windowClosed(const QString& id);

protected:
    /// Warn once per feature when the capability is unsupported.
    void warnUnsupported(const QString& feature) const {
        if (m_warnedFeatures.contains(feature)) {
            return;
        }
        m_warnedFeatures.insert(feature);
        qWarning() << "CompositorBackend: unsupported" << feature << "on" << name(detect());
    }

private:
    mutable QSet<QString> m_warnedFeatures;
};

} // namespace caelestia
