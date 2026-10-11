#pragma once

#include "detect.hpp"

#include <qobject.h>
#include <qtimer.h>
#include <qvariant.h>

#include <QtQmlIntegration>

#include <memory>

namespace caelestia {

class CompositorBackend;

/// CompositorIpc — QML singleton facade over the detected compositor backend.
/// The only QML-visible window-management surface (contract in backend.hpp;
/// shell policy helpers live in services/Compositor.qml).
/// Neutral properties/signals/actions regardless of backend; capability-gated
/// features read `capabilities`. Also owns the compositor-agnostic sysfs
/// caps/num lock LED polling (moved out of the old NiriIpc).
/// Adding a backend = implement CompositorBackend in compositor/<name>/,
/// one case in createBackend(), one env var in detect().
class CompositorIpc : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    /// Stable lowercase kind id, e.g. "niri". Constant per process.
    Q_PROPERTY(QString kind READ kind CONSTANT)
    /// Human-readable compositor name, e.g. "Niri". Constant per process.
    Q_PROPERTY(QString name READ name CONSTANT)
    /// Feature/action support matrix (see CompositorCapabilities).
    Q_PROPERTY(QVariantMap capabilities READ capabilities CONSTANT)
    /// True when a real backend exists and its IPC connection is up.
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    /// Path to the compositor's keybind config file for the keybind-source
    /// parser (see capabilities.keybindSource); empty when unsupported.
    Q_PROPERTY(QString keybindConfigPath READ keybindConfigPath CONSTANT)

    // ── Workspaces ──
    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(int focusedWorkspaceIndex READ focusedWorkspaceIndex NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QString focusedWorkspaceId READ focusedWorkspaceId NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QString focusedMonitorName READ focusedMonitorName NOTIFY focusedWorkspaceChanged)

    // ── Windows ──
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(int focusedWindowIndex READ focusedWindowIndex NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowId READ focusedWindowId NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowTitle READ focusedWindowTitle NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowClass READ focusedWindowClass NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap lastFocusedWindow READ lastFocusedWindow NOTIFY lastFocusedWindowChanged)
    Q_PROPERTY(QString scrollDirection READ scrollDirection NOTIFY scrollDirectionChanged)
    Q_PROPERTY(bool inOverview READ inOverview NOTIFY inOverviewChanged)

    // ── Outputs ──
    Q_PROPERTY(QVariantMap outputs READ outputs NOTIFY outputsChanged)

    // ── Keyboard ──
    Q_PROPERTY(QVariantList kbLayoutsArray READ kbLayoutsArray NOTIFY keyboardChanged)
    Q_PROPERTY(int kbLayoutIndex READ kbLayoutIndex NOTIFY keyboardChanged)
    Q_PROPERTY(QString kbLayouts READ kbLayouts NOTIFY keyboardChanged)
    Q_PROPERTY(QString defaultKbLayout READ defaultKbLayout NOTIFY keyboardChanged)
    Q_PROPERTY(QString kbLayout READ kbLayout NOTIFY keyboardChanged)
    Q_PROPERTY(bool capsLock READ capsLock NOTIFY capsLockChanged)
    Q_PROPERTY(bool numLock READ numLock NOTIFY numLockChanged)

public:
    explicit CompositorIpc(QObject* parent = nullptr);
    ~CompositorIpc() override;

    [[nodiscard]] QString kind() const;
    [[nodiscard]] QString name() const;
    [[nodiscard]] QVariantMap capabilities() const;
    [[nodiscard]] bool available() const;
    [[nodiscard]] QString keybindConfigPath() const;

    [[nodiscard]] QVariantList workspaces() const;
    [[nodiscard]] int focusedWorkspaceIndex() const;
    [[nodiscard]] QString focusedWorkspaceId() const;
    [[nodiscard]] QString focusedMonitorName() const;

    [[nodiscard]] QVariantList windows() const;
    [[nodiscard]] int focusedWindowIndex() const;
    [[nodiscard]] QString focusedWindowId() const;
    [[nodiscard]] QString focusedWindowTitle() const;
    [[nodiscard]] QString focusedWindowClass() const;
    [[nodiscard]] QVariantMap focusedWindow() const;
    [[nodiscard]] QVariantMap lastFocusedWindow() const;
    [[nodiscard]] QString scrollDirection() const;
    [[nodiscard]] bool inOverview() const;

    [[nodiscard]] QVariantMap outputs() const;

    [[nodiscard]] QVariantList kbLayoutsArray() const;
    [[nodiscard]] int kbLayoutIndex() const;
    [[nodiscard]] QString kbLayouts() const;
    [[nodiscard]] QString defaultKbLayout() const;
    [[nodiscard]] QString kbLayout() const;
    [[nodiscard]] bool capsLock() const;
    [[nodiscard]] bool numLock() const;

    // ── Helpers ──
    Q_INVOKABLE int getWorkspaceIdxById(const QString& id) const;
    Q_INVOKABLE QVariantList getWindowsByWorkspaceId(const QString& id) const;
    Q_INVOKABLE QVariantList getWindowsByWorkspaceIndex(int index) const;
    Q_INVOKABLE QVariantList getActiveWorkspaceWindows() const;

    // ── Neutral action verbs ──
    Q_INVOKABLE bool focusWorkspace(const QString& id);
    Q_INVOKABLE bool focusWorkspaceRelative(int delta);
    Q_INVOKABLE bool moveWindowToWorkspace(const QString& id);
    Q_INVOKABLE bool moveWindowToIndex(int index);
    Q_INVOKABLE bool focusWindow(const QString& id);
    Q_INVOKABLE bool closeWindow(const QString& id = {});
    Q_INVOKABLE bool toggleFloating(const QString& id = {});
    Q_INVOKABLE bool toggleFullscreen();
    Q_INVOKABLE bool toggleMaximize();
    Q_INVOKABLE bool toggleOverview();
    Q_INVOKABLE bool centerWindow();
    Q_INVOKABLE bool expandWindow();
    Q_INVOKABLE bool focusDirection(const QString& dir);
    Q_INVOKABLE bool moveDirection(const QString& dir);
    Q_INVOKABLE bool switchKbLayout(int index);
    Q_INVOKABLE bool setDisplayPower(bool on);
    Q_INVOKABLE bool screenshotWindow();
    /// Config-compat translator ("dpms off", "dpms on", …).
    Q_INVOKABLE bool dispatch(const QString& command);

    /// Escape hatch for tests/diagnostics; not exposed to QML.
    [[nodiscard]] CompositorBackend* backend() const;

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
    void capsLockChanged();
    void numLockChanged();
    void windowOpenedOrChanged(const QVariantMap& windowData);
    void windowClosed(const QString& id);

private:
    /// The compositor seam: detect() -> per-compositor backend (noctalia-style).
    static std::unique_ptr<CompositorBackend> createBackend();

    void setupLedWatchers();
    void readLedState();
    void updateLedPolling();

    std::unique_ptr<CompositorBackend> m_backend;

    // Compositor-agnostic sysfs LED state (caps/num lock)
    bool m_capsLock = false;
    bool m_numLock = false;
    QTimer m_ledPollTimer;
    QString m_capsLockPath;
    QString m_numLockPath;
};

} // namespace caelestia
