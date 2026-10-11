#pragma once

#include "../backend.hpp"

#include "umbrielsocket.hpp"

#include <qhash.h>
#include <qjsonarray.h>
#include <qjsonobject.h>
#include <qjsonvalue.h>
#include <qvariant.h>

namespace caelestia {

/// UmbrielBackend — CompositorBackend implementation for the Umbriel compositor.
///
/// Umbriel speaks the same JSON-lines IPC shape as niri: a persistent
/// subscription socket streaming full-snapshot events, plus one-shot
/// request sockets. Workspaces, windows, outputs and overview state all
/// arrive over the subscription; keyboard layouts are re-queried on change.
/// Window and workspace ids are opaque strings (ext-foreign-toplevel
/// identifiers and Umbriel workspace ids respectively).
class UmbrielBackend : public CompositorBackend {
    Q_OBJECT

public:
    explicit UmbrielBackend(QObject* parent = nullptr);
    ~UmbrielBackend() override = default;

    [[nodiscard]] CompositorCapabilities capabilities() const override;
    [[nodiscard]] bool available() const override;

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
    void fetchKeyboardLayouts();
    void handleWorkspacesSnapshot(const QJsonArray& data);
    void handleWindowsSnapshot(const QJsonArray& data);
    void handleOutputsSnapshot(const QJsonArray& data);
    void handleOverview(const QJsonValue& data);
    void handleKeyboardLayouts(const QJsonObject& payload);

    void updateFocusedWindowFields();
    void updateWorkspaceOccupancy();
    void sortWindowsList();
    /// Resolve a neutral workspace id to the 1-based Umbriel index + output
    /// for the workspace-switch selector.
    [[nodiscard]] bool workspaceSelectorById(const QString& id, QString& selector) const;

    /// Send a raw Umbriel msg action (internal only — not exposed to QML).
    bool umbrielAction(const QString& action);

    UmbrielEventSocket m_eventSocket;
    UmbrielRequestSocket m_requestSocket;

    bool m_available = false;

    // Workspace state (neutral schema, cached)
    QVariantList m_workspaces;
    int m_focusedWorkspaceIndex = -1;
    QString m_focusedWorkspaceId;
    QString m_focusedMonitorName;

    // Window state (neutral schema, cached)
    QVariantList m_windows;
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
