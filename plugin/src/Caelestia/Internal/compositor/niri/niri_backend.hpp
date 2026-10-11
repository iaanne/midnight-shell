#pragma once

#include "../backend.hpp"

#include "nirisocket.hpp"

#include <qhash.h>
#include <qjsonobject.h>
#include <qvariant.h>

namespace caelestia {

/// NiriBackend — CompositorBackend implementation for the niri compositor.
///
/// Absorbs the former NiriIpc engine: owns the niri IPC sockets, normalizes
/// raw niri state into the neutral schema (backend.hpp) on every event and
/// caches the result, and translates the neutral verbs into niri actions.
/// Add a new backend = copy this seam: compositor/<name>/<name>_backend.{hpp,cpp}
/// plus one case in platform.cpp and one env var in detect.cpp.
class NiriBackend : public CompositorBackend {
    Q_OBJECT

public:
    explicit NiriBackend(QObject* parent = nullptr);
    ~NiriBackend() override = default;

    [[nodiscard]] CompositorCapabilities capabilities() const override;
    [[nodiscard]] bool available() const override;
    [[nodiscard]] QString keybindConfigPath() const override;

    [[nodiscard]] QVariantList workspaces() const override;
    [[nodiscard]] int focusedWorkspaceIndex() const override;
    [[nodiscard]] QString focusedWorkspaceId() const override;
    [[nodiscard]] QString focusedMonitorName() const override;

    [[nodiscard]] QVariantList windows() const override;
    [[nodiscard]] int focusedWindowIndex() const override;
    [[nodiscard]] QString focusedWindowId() const override;
    [[nodiscard]] QString focusedWindowTitle() const override;
    [[nodiscard]] QString focusedWindowClass() const override;
    [[nodiscard]] QVariantMap focusedWindow() const override;
    [[nodiscard]] QVariantMap lastFocusedWindow() const override;
    [[nodiscard]] bool inOverview() const override;
    [[nodiscard]] QString scrollDirection() const override;

    [[nodiscard]] QVariantMap outputs() const override;

    [[nodiscard]] QVariantList kbLayoutsArray() const override;
    [[nodiscard]] int kbLayoutIndex() const override;
    [[nodiscard]] QString kbLayouts() const override;
    [[nodiscard]] QString defaultKbLayout() const override;
    [[nodiscard]] QString kbLayout() const override;

    [[nodiscard]] int getWorkspaceIdxById(const QString& id) const override;
    [[nodiscard]] QVariantList getWindowsByWorkspaceId(const QString& id) const override;
    [[nodiscard]] QVariantList getWindowsByWorkspaceIndex(int index) const override;
    [[nodiscard]] QVariantList getActiveWorkspaceWindows() const override;

    bool focusWorkspace(const QString& id) override;
    bool focusWorkspaceRelative(int delta) override;
    bool moveWindowToWorkspace(const QString& id) override;
    bool moveWindowToIndex(int index) override;
    bool focusWindow(const QString& id) override;
    bool closeWindow(const QString& id = {}) override;
    bool toggleFloating(const QString& id = {}) override;
    bool toggleFullscreen() override;
    bool toggleMaximize() override;
    bool toggleOverview() override;
    bool centerWindow() override;
    bool expandWindow() override;
    bool focusDirection(const QString& dir) override;
    bool moveDirection(const QString& dir) override;
    bool switchKbLayout(int index) override;
    bool setDisplayPower(bool on) override;
    bool screenshotWindow() override;
    bool dispatch(const QString& command) override;

private slots:
    void onEventStreamConnected();
    void onEventStreamDisconnected();
    void onEvent(const QJsonObject& event);

private:
    void fetchInitialState();
    void handleWorkspacesChanged(const QJsonObject& data);
    void handleWindowsChanged(const QJsonObject& data);
    void handleWindowOpenedOrChanged(const QJsonObject& data);
    void handleWindowClosed(const QJsonObject& data);
    void handleWindowFocusChanged(const QJsonObject& data);
    void handleWindowLayoutsChanged(const QJsonObject& data);
    void handleOutputsChanged(const QJsonObject& data);
    void handleKeyboardLayoutsChanged(const QJsonObject& data);
    void handleOverviewOpenedOrClosed(const QJsonObject& data);

    void updateFocusedWindowFields();
    void updateWorkspaceOccupancy();
    void sortWindowsList();
    void rebuildWindowIndex();
    [[nodiscard]] int findWindowIndexById(qint64 id) const;
    [[nodiscard]] qint64 workspaceNiriIdxById(const QString& id) const;

    /// Send a raw niri action (internal only — not exposed to QML).
    bool niriAction(const QString& pascalName, const QJsonValue& inner = QJsonObject());

    NiriEventSocket m_eventSocket;
    NiriRequestSocket m_requestSocket;

    bool m_available = false;

    // Workspace state (neutral schema, cached)
    QVariantList m_workspaces;
    int m_focusedWorkspaceIndex = -1;
    QString m_focusedWorkspaceId;
    QString m_focusedMonitorName;

    // Window state (neutral schema, cached)
    QVariantList m_windows;
    QHash<qint64, int> m_windowIndex;
    int m_focusedWindowIndex = -1;
    QString m_focusedWindowId;
    QString m_focusedWindowTitle;
    QString m_focusedWindowClass;
    QVariantMap m_focusedWindow;
    QVariantMap m_lastFocusedWindow;
    int m_lastFocusedColumn = -1;
    QString m_scrollDirection = QStringLiteral("none");
    bool m_inOverview = false;

    // Output state (neutral schema, cached)
    QVariantMap m_outputs;

    // Keyboard state
    QVariantList m_kbLayoutsArray;
    int m_kbLayoutIndex = 0;
    QString m_kbLayouts = QStringLiteral("?");
};

} // namespace caelestia
