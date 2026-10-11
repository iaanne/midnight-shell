#include "niri_backend.hpp"

#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qdebug.h>
#include <qstandardpaths.h>

#include <algorithm>
#include <utility>

namespace caelestia {

namespace {

    // ── Normalization helpers (raw niri → neutral schema) ────────────────

    /// niri window object → neutral window map. `output` resolved by caller
    /// via the workspace-output map. No absolute geometry: x/y omitted
    /// (capabilities.absoluteGeometry == false); width/height from the
    /// scrolling-layout window_size.
    QVariantMap normalizeWindow(const QJsonObject& raw, const QString& output) {
        QVariantMap win;
        const QString id = QString::number(raw.value(QStringLiteral("id")).toInteger());
        win.insert(QStringLiteral("id"), id);
        win.insert(QStringLiteral("appId"), raw.value(QStringLiteral("app_id")).toString());
        win.insert(QStringLiteral("title"), raw.value(QStringLiteral("title")).toString());
        win.insert(QStringLiteral("workspaceId"),
            QString::number(raw.value(QStringLiteral("workspace_id")).toInteger()));
        win.insert(QStringLiteral("output"), output);
        win.insert(QStringLiteral("focused"), raw.value(QStringLiteral("is_focused")).toBool());
        win.insert(QStringLiteral("floating"), raw.value(QStringLiteral("is_floating")).toBool());
        win.insert(QStringLiteral("fullscreen"), false);
        win.insert(QStringLiteral("maximized"), false);
        win.insert(QStringLiteral("urgent"), raw.value(QStringLiteral("is_urgent")).toBool());
        win.insert(QStringLiteral("pid"), raw.value(QStringLiteral("pid")).toInt());

        const auto layout = raw.value(QStringLiteral("layout")).toObject();
        const auto size = layout.value(QStringLiteral("window_size")).toArray();
        if (size.size() >= 2) {
            win.insert(QStringLiteral("width"), size.at(0).toDouble());
            win.insert(QStringLiteral("height"), size.at(1).toDouble());
        }
        const auto pos = layout.value(QStringLiteral("pos_in_scrolling_layout")).toArray();
        if (pos.size() >= 2) {
            QVariantMap grid;
            grid.insert(QStringLiteral("col"), pos.at(0).toInt());
            grid.insert(QStringLiteral("row"), pos.at(1).toInt());
            win.insert(QStringLiteral("grid"), grid);
        }
        return win;
    }

    /// niri workspace object → neutral workspace map. occupied/windowCount
    /// are filled by the caller once the window list is known.
    QVariantMap normalizeWorkspace(const QJsonObject& raw) {
        QVariantMap ws;
        ws.insert(QStringLiteral("id"), QString::number(raw.value(QStringLiteral("id")).toInteger()));
        ws.insert(QStringLiteral("name"), raw.value(QStringLiteral("name")).toString());
        ws.insert(QStringLiteral("index"), raw.value(QStringLiteral("idx")).toInt());
        ws.insert(QStringLiteral("output"), raw.value(QStringLiteral("output")).toString());
        ws.insert(QStringLiteral("active"), raw.value(QStringLiteral("is_active")).toBool());
        ws.insert(QStringLiteral("focused"), raw.value(QStringLiteral("is_focused")).toBool());
        ws.insert(QStringLiteral("urgent"), raw.value(QStringLiteral("is_urgent")).toBool());
        ws.insert(QStringLiteral("occupied"), false);
        ws.insert(QStringLiteral("windowCount"), 0);
        ws.insert(QStringLiteral("isSpecial"), false);
        return ws;
    }

    /// Raw niri outputs map (from IPC "Outputs") → neutral outputs map.
    /// Mirrors the CLI normalization (midnight-cli utils/niri.py).
    QVariantMap normalizeOutputs(const QJsonObject& rawOutputs) {
        QVariantMap outputs;
        for (auto it = rawOutputs.begin(); it != rawOutputs.end(); ++it) {
            const auto raw = it.value().toObject();
            QVariantMap out;
            const QString name = it.key();
            out.insert(QStringLiteral("name"), name);

            const auto modes = raw.value(QStringLiteral("modes")).toArray();
            const int current = raw.value(QStringLiteral("current_mode")).toInt(-1);
            QJsonObject mode;
            if (current >= 0 && current < modes.size()) {
                mode = modes.at(current).toObject();
            } else if (!modes.isEmpty()) {
                mode = modes.first().toObject();
                for (const auto& m : modes) {
                    if (m.toObject().value(QStringLiteral("is_preferred")).toBool()) {
                        mode = m.toObject();
                        break;
                    }
                }
            }
            QVariantMap modeMap;
            modeMap.insert(QStringLiteral("width"), mode.value(QStringLiteral("width")).toInt());
            modeMap.insert(QStringLiteral("height"), mode.value(QStringLiteral("height")).toInt());
            modeMap.insert(QStringLiteral("refreshRate"), mode.value(QStringLiteral("refresh_rate")).toInt());
            out.insert(QStringLiteral("mode"), modeMap);

            const auto logical = raw.value(QStringLiteral("logical")).toObject();
            QVariantMap location;
            location.insert(QStringLiteral("x"), logical.value(QStringLiteral("x")).toInt());
            location.insert(QStringLiteral("y"), logical.value(QStringLiteral("y")).toInt());
            out.insert(QStringLiteral("location"), location);
            out.insert(QStringLiteral("scale"), logical.value(QStringLiteral("scale")).toDouble(1.0));
            out.insert(QStringLiteral("transform"), logical.value(QStringLiteral("transform")).toInt(0));
            out.insert(QStringLiteral("enabled"), current >= 0 && !logical.isEmpty());
            outputs.insert(name, out);
        }
        return outputs;
    }

} // namespace

// ── Construction ─────────────────────────────────────────────────────────

NiriBackend::NiriBackend(QObject* parent)
    : CompositorBackend(parent)
    , m_eventSocket(this)
    , m_requestSocket(this) {

    connect(&m_eventSocket, &NiriEventSocket::connected, this, &NiriBackend::onEventStreamConnected);
    connect(&m_eventSocket, &NiriEventSocket::disconnected, this, &NiriBackend::onEventStreamDisconnected);
    connect(&m_eventSocket, &NiriEventSocket::eventReceived, this, &NiriBackend::onEvent);

    m_eventSocket.connectToNiri();
}

// ── Capabilities ─────────────────────────────────────────────────────────

CompositorCapabilities NiriBackend::capabilities() const {
    CompositorCapabilities caps;
    caps.workspaces = true;
    caps.windows = true;
    caps.outputs = true;
    caps.kbLayout = true;
    caps.focusWindow = true;
    caps.closeWindow = true;
    caps.focusWorkspace = true;
    caps.moveWindowToWorkspace = true;
    caps.moveWindowToIndex = true;
    caps.toggleFloating = true;
    caps.toggleFullscreen = true;
    caps.toggleMaximize = true;
    caps.toggleOverview = true;
    caps.centerWindow = true;
    caps.expandWindow = true;
    caps.focusDirection = true;
    caps.moveDirection = true;
    caps.switchKbLayout = true;
    caps.displayPower = true;
    caps.screenshotWindow = true;
    caps.windowGrid = true;
    caps.absoluteGeometry = false;
    caps.scrollDirection = true;
    caps.specialWorkspaces = false;
    caps.keybindSource = QStringLiteral("niri-kdl");
    return caps;
}

bool NiriBackend::available() const { return m_available; }

QString NiriBackend::keybindConfigPath() const {
    // QStandardPaths::GenericConfigLocation honours XDG_CONFIG_HOME.
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/niri/config.kdl");
}

// ── Property getters ─────────────────────────────────────────────────────

QVariantList NiriBackend::workspaces() const { return m_workspaces; }
int NiriBackend::focusedWorkspaceIndex() const { return m_focusedWorkspaceIndex; }
QString NiriBackend::focusedWorkspaceId() const { return m_focusedWorkspaceId; }
QString NiriBackend::focusedMonitorName() const { return m_focusedMonitorName; }

QVariantList NiriBackend::windows() const { return m_windows; }
int NiriBackend::focusedWindowIndex() const { return m_focusedWindowIndex; }
QString NiriBackend::focusedWindowId() const { return m_focusedWindowId; }
QString NiriBackend::focusedWindowTitle() const { return m_focusedWindowTitle; }
QString NiriBackend::focusedWindowClass() const { return m_focusedWindowClass; }
QVariantMap NiriBackend::focusedWindow() const { return m_focusedWindow; }
QVariantMap NiriBackend::lastFocusedWindow() const { return m_lastFocusedWindow; }
bool NiriBackend::inOverview() const { return m_inOverview; }
QString NiriBackend::scrollDirection() const { return m_scrollDirection; }

QVariantMap NiriBackend::outputs() const { return m_outputs; }

QVariantList NiriBackend::kbLayoutsArray() const { return m_kbLayoutsArray; }
int NiriBackend::kbLayoutIndex() const { return m_kbLayoutIndex; }
QString NiriBackend::kbLayouts() const { return m_kbLayouts; }

QString NiriBackend::defaultKbLayout() const {
    if (!m_kbLayoutsArray.isEmpty()) {
        return m_kbLayoutsArray.first().toString();
    }
    return QStringLiteral("?");
}

QString NiriBackend::kbLayout() const {
    if (m_kbLayoutIndex >= 0 && m_kbLayoutIndex < m_kbLayoutsArray.size()) {
        const QString name = m_kbLayoutsArray.at(m_kbLayoutIndex).toString();
        if (name.size() >= 2) {
            return name.left(2).toLower();
        }
    }
    return QStringLiteral("?");
}

// ── Workspace/window helpers ─────────────────────────────────────────────

int NiriBackend::getWorkspaceIdxById(const QString& id) const {
    for (const auto& v : m_workspaces) {
        const auto ws = v.toMap();
        if (ws.value(QStringLiteral("id")).toString() == id) {
            return ws.value(QStringLiteral("index")).toInt();
        }
    }
    return -1;
}

QVariantList NiriBackend::getWindowsByWorkspaceId(const QString& id) const {
    QVariantList res;
    for (const auto& w : m_windows) {
        if (w.toMap().value(QStringLiteral("workspaceId")).toString() == id) {
            res.append(w);
        }
    }
    return res;
}

QVariantList NiriBackend::getWindowsByWorkspaceIndex(int index) const {
    if (index < 0 || index >= m_workspaces.size()) return {};
    const QString wsId = m_workspaces.at(index).toMap().value(QStringLiteral("id")).toString();
    return getWindowsByWorkspaceId(wsId);
}

QVariantList NiriBackend::getActiveWorkspaceWindows() const {
    if (m_focusedWorkspaceId.isEmpty()) return {};
    return getWindowsByWorkspaceId(m_focusedWorkspaceId);
}

qint64 NiriBackend::workspaceNiriIdxById(const QString& id) const {
    for (const auto& v : m_workspaces) {
        const auto ws = v.toMap();
        if (ws.value(QStringLiteral("id")).toString() == id) {
            return ws.value(QStringLiteral("index")).toLongLong();
        }
    }
    return -1;
}

// ── Neutral verbs → niri actions ─────────────────────────────────────────

bool NiriBackend::niriAction(const QString& pascalName, const QJsonValue& inner) {
    if (!m_available) {
        warnUnsupported(QStringLiteral("niri IPC (not connected)"));
        return false;
    }
    QJsonObject actionObj;
    actionObj.insert(pascalName, inner);
    QJsonObject wrapper;
    wrapper.insert(QStringLiteral("Action"), actionObj);
    m_requestSocket.action(QJsonDocument(wrapper).toJson(QJsonDocument::Compact));
    return true;
}

bool NiriBackend::focusWorkspace(const QString& id) {
    const qint64 idx = workspaceNiriIdxById(id);
    if (idx < 0) return false;
    QJsonObject ref;
    ref.insert(QStringLiteral("Index"), idx);
    QJsonObject inner;
    inner.insert(QStringLiteral("reference"), ref);
    return niriAction(QStringLiteral("FocusWorkspace"), inner);
}

bool NiriBackend::focusWorkspaceRelative(int delta) {
    if (delta == 0) return false;
    return niriAction(delta > 0 ? QStringLiteral("FocusWorkspaceDown") : QStringLiteral("FocusWorkspaceUp"));
}

bool NiriBackend::moveWindowToWorkspace(const QString& id) {
    const qint64 idx = workspaceNiriIdxById(id);
    if (idx < 0) return false;
    QJsonObject ref;
    ref.insert(QStringLiteral("Index"), idx);
    QJsonObject inner;
    inner.insert(QStringLiteral("window_id"), QJsonValue::Null);
    inner.insert(QStringLiteral("reference"), ref);
    inner.insert(QStringLiteral("focus"), true);
    return niriAction(QStringLiteral("MoveWindowToWorkspace"), inner);
}

bool NiriBackend::moveWindowToIndex(int index) {
    QJsonObject inner;
    inner.insert(QStringLiteral("index"), index);
    return niriAction(QStringLiteral("MoveColumnToIndex"), inner);
}

bool NiriBackend::focusWindow(const QString& id) {
    QJsonObject inner;
    inner.insert(QStringLiteral("id"), id.toLongLong());
    return niriAction(QStringLiteral("FocusWindow"), inner);
}

bool NiriBackend::closeWindow(const QString& id) {
    QJsonObject inner;
    inner.insert(QStringLiteral("id"), id.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(id.toLongLong()));
    return niriAction(QStringLiteral("CloseWindow"), inner);
}

bool NiriBackend::toggleFloating(const QString& id) {
    QJsonObject inner;
    inner.insert(QStringLiteral("id"), id.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(id.toLongLong()));
    return niriAction(QStringLiteral("ToggleWindowFloating"), inner);
}

bool NiriBackend::toggleFullscreen() { return niriAction(QStringLiteral("FullscreenWindow")); }
bool NiriBackend::toggleMaximize() { return niriAction(QStringLiteral("MaximizeColumn")); }
bool NiriBackend::toggleOverview() { return niriAction(QStringLiteral("ToggleOverview")); }
bool NiriBackend::centerWindow() { return niriAction(QStringLiteral("CenterWindow")); }
bool NiriBackend::expandWindow() { return niriAction(QStringLiteral("ExpandColumnToAvailableWidth")); }

bool NiriBackend::focusDirection(const QString& dir) {
    if (dir == QStringLiteral("left")) return niriAction(QStringLiteral("FocusColumnLeft"));
    if (dir == QStringLiteral("right")) return niriAction(QStringLiteral("FocusColumnRight"));
    if (dir == QStringLiteral("up")) return niriAction(QStringLiteral("FocusWindowUp"));
    if (dir == QStringLiteral("down")) return niriAction(QStringLiteral("FocusWindowDown"));
    warnUnsupported(QStringLiteral("focusDirection(") + dir + u')');
    return false;
}

bool NiriBackend::moveDirection(const QString& dir) {
    if (dir == QStringLiteral("left")) return niriAction(QStringLiteral("MoveColumnLeft"));
    if (dir == QStringLiteral("right")) return niriAction(QStringLiteral("MoveColumnRight"));
    if (dir == QStringLiteral("up")) return niriAction(QStringLiteral("MoveWindowUp"));
    if (dir == QStringLiteral("down")) return niriAction(QStringLiteral("MoveWindowDown"));
    warnUnsupported(QStringLiteral("moveDirection(") + dir + u')');
    return false;
}

bool NiriBackend::switchKbLayout(int index) {
    // niri: SwitchLayout { layout: Next | Prev | Index(u8) }
    QJsonObject layout;
    layout.insert(QStringLiteral("Index"), index);
    QJsonObject inner;
    inner.insert(QStringLiteral("layout"), layout);
    return niriAction(QStringLiteral("SwitchLayout"), inner);
}

bool NiriBackend::setDisplayPower(bool on) {
    return niriAction(on ? QStringLiteral("PowerOnMonitors") : QStringLiteral("PowerOffMonitors"));
}

bool NiriBackend::screenshotWindow() {
    QJsonObject inner;
    inner.insert(QStringLiteral("id"), QJsonValue::Null);
    inner.insert(QStringLiteral("write_to_disk"), true);
    inner.insert(QStringLiteral("show_pointer"), false);
    inner.insert(QStringLiteral("path"), QJsonValue::Null);
    return niriAction(QStringLiteral("ScreenshotWindow"), inner);
}

bool NiriBackend::dispatch(const QString& command) {
    const QString cmd = command.trimmed().toLower();
    if (cmd == QStringLiteral("dpms off")) return setDisplayPower(false);
    if (cmd == QStringLiteral("dpms on")) return setDisplayPower(true);
    warnUnsupported(QStringLiteral("dispatch(") + command + u')');
    return false;
}

// ── Event stream ─────────────────────────────────────────────────────────

void NiriBackend::onEventStreamConnected() {
    qDebug() << "NiriBackend: Event stream connected";
    m_available = true;
    emit availableChanged();
    fetchInitialState();
}

void NiriBackend::onEventStreamDisconnected() {
    qDebug() << "NiriBackend: Event stream disconnected";
    m_available = false;
    emit availableChanged();
}

void NiriBackend::onEvent(const QJsonObject& event) {
    if (event.contains(QStringLiteral("WorkspacesChanged"))) {
        handleWorkspacesChanged(event.value(QStringLiteral("WorkspacesChanged")).toObject());
    } else if (event.contains(QStringLiteral("WorkspaceActivated"))) {
        const auto data = event.value(QStringLiteral("WorkspaceActivated")).toObject();
        const QString id = QString::number(data.value(QStringLiteral("id")).toInteger());
        for (int i = 0; i < m_workspaces.size(); ++i) {
            auto ws = m_workspaces.at(i).toMap();
            if (ws.value(QStringLiteral("id")).toString() == id) {
                m_focusedWorkspaceIndex = i;
                m_focusedWorkspaceId = id;
                m_focusedMonitorName = ws.value(QStringLiteral("output")).toString();
                for (int j = 0; j < m_workspaces.size(); ++j) {
                    auto w = m_workspaces.at(j).toMap();
                    if (w.value(QStringLiteral("output")).toString() == m_focusedMonitorName) {
                        w[QStringLiteral("active")] = (j == i);
                        w[QStringLiteral("focused")] = (j == i);
                        m_workspaces[j] = w;
                    }
                }
                emit workspacesChanged();
                break;
            }
        }
        emit focusedWorkspaceChanged();
    } else if (event.contains(QStringLiteral("WindowsChanged"))) {
        handleWindowsChanged(event.value(QStringLiteral("WindowsChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowOpenedOrChanged"))) {
        handleWindowOpenedOrChanged(event.value(QStringLiteral("WindowOpenedOrChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowClosed"))) {
        handleWindowClosed(event.value(QStringLiteral("WindowClosed")).toObject());
    } else if (event.contains(QStringLiteral("WindowFocusChanged"))) {
        handleWindowFocusChanged(event.value(QStringLiteral("WindowFocusChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowLayoutsChanged"))) {
        handleWindowLayoutsChanged(event.value(QStringLiteral("WindowLayoutsChanged")).toObject());
    } else if (event.contains(QStringLiteral("KeyboardLayoutsChanged"))) {
        handleKeyboardLayoutsChanged(event.value(QStringLiteral("KeyboardLayoutsChanged")).toObject());
    } else if (event.contains(QStringLiteral("OverviewOpenedOrClosed"))) {
        handleOverviewOpenedOrClosed(event.value(QStringLiteral("OverviewOpenedOrClosed")).toObject());
    } else if (event.contains(QStringLiteral("OutputsChanged"))) {
        handleOutputsChanged(event.value(QStringLiteral("OutputsChanged")).toObject());
    }
}

// ── Initial state ────────────────────────────────────────────────────────

void NiriBackend::fetchInitialState() {
    m_requestSocket.request("\"Workspaces\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        QJsonObject data;
        data.insert(QStringLiteral("workspaces"), result.value(QStringLiteral("Workspaces")));
        handleWorkspacesChanged(data);
    });

    m_requestSocket.request("\"Windows\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        QJsonObject data;
        data.insert(QStringLiteral("windows"), result.value(QStringLiteral("Windows")));
        handleWindowsChanged(data);
    });

    m_requestSocket.request("\"FocusedWindow\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        const auto win = result.value(QStringLiteral("FocusedWindow"));
        if (win.isObject()) {
            QJsonObject d;
            d.insert(QStringLiteral("id"), win.toObject().value(QStringLiteral("id")));
            handleWindowFocusChanged(d);
        }
    });

    m_requestSocket.request("\"Outputs\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        m_outputs = normalizeOutputs(result.value(QStringLiteral("Outputs")).toObject());
        emit outputsChanged();
    });

    m_requestSocket.request("\"KeyboardLayouts\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        QJsonObject data;
        data.insert(QStringLiteral("keyboard_layouts"), result.value(QStringLiteral("KeyboardLayouts")));
        handleKeyboardLayoutsChanged(data);
    });
}

// ── Event handlers (normalize + cache) ───────────────────────────────────

void NiriBackend::handleWorkspacesChanged(const QJsonObject& data) {
    const QJsonArray wsArray = data.value(QStringLiteral("workspaces")).toArray();

    QVariantList wsList;
    wsList.reserve(wsArray.size());
    for (const auto& v : wsArray) {
        wsList.append(normalizeWorkspace(v.toObject()));
    }
    std::sort(wsList.begin(), wsList.end(), [](const QVariant& a, const QVariant& b) {
        const auto am = a.toMap();
        const auto bm = b.toMap();
        const QString ao = am.value(QStringLiteral("output")).toString();
        const QString bo = bm.value(QStringLiteral("output")).toString();
        if (ao != bo) return ao < bo;
        return am.value(QStringLiteral("index")).toInt() < bm.value(QStringLiteral("index")).toInt();
    });

    m_workspaces = wsList;

    m_focusedWorkspaceIndex = -1;
    m_focusedWorkspaceId.clear();
    for (int i = 0; i < wsList.size(); ++i) {
        const auto ws = wsList.at(i).toMap();
        if (ws.value(QStringLiteral("focused")).toBool()) {
            m_focusedWorkspaceIndex = i;
            m_focusedWorkspaceId = ws.value(QStringLiteral("id")).toString();
            m_focusedMonitorName = ws.value(QStringLiteral("output")).toString();
            break;
        }
    }
    if (m_focusedWorkspaceIndex < 0 && !wsList.isEmpty()) {
        m_focusedWorkspaceIndex = 0;
    }

    // occupied/windowCount depend on the window list — refresh both.
    updateWorkspaceOccupancy();
    emit workspacesChanged();
    emit focusedWorkspaceChanged();
}

void NiriBackend::handleWindowsChanged(const QJsonObject& data) {
    if (data.contains(QStringLiteral("windows"))) {
        const QJsonArray winArray = data.value(QStringLiteral("windows")).toArray();

        // Workspace id → output map for neutral `output` on windows.
        QHash<QString, QString> wsOutput;
        for (const auto& v : std::as_const(m_workspaces)) {
            const auto ws = v.toMap();
            wsOutput.insert(ws.value(QStringLiteral("id")).toString(), ws.value(QStringLiteral("output")).toString());
        }

        QVariantList winList;
        winList.reserve(winArray.size());
        for (const auto& v : winArray) {
            const auto raw = v.toObject();
            const QString wsId = QString::number(raw.value(QStringLiteral("workspace_id")).toInteger());
            winList.append(normalizeWindow(raw, wsOutput.value(wsId)));
        }
        m_windows = winList;
        sortWindowsList();
        rebuildWindowIndex();
    }

    updateWorkspaceOccupancy();
    updateFocusedWindowFields();
    emit windowsChanged();
}

void NiriBackend::updateWorkspaceOccupancy() {
    QHash<QString, int> counts;
    for (const auto& w : std::as_const(m_windows)) {
        counts[w.toMap().value(QStringLiteral("workspaceId")).toString()]++;
    }
    bool occChanged = false;
    for (int i = 0; i < m_workspaces.size(); ++i) {
        auto ws = m_workspaces.at(i).toMap();
        const int count = counts.value(ws.value(QStringLiteral("id")).toString(), 0);
        if (ws.value(QStringLiteral("windowCount")).toInt() != count) {
            ws[QStringLiteral("windowCount")] = count;
            ws[QStringLiteral("occupied")] = count > 0;
            m_workspaces[i] = ws;
            occChanged = true;
        }
    }
    if (occChanged) {
        emit workspacesChanged();
    }
}

void NiriBackend::handleWindowOpenedOrChanged(const QJsonObject& data) {
    const QJsonObject winObj = data.value(QStringLiteral("window")).toObject();
    if (winObj.isEmpty()) return;

    const QString wsId = QString::number(winObj.value(QStringLiteral("workspace_id")).toInteger());
    QString output;
    for (const auto& v : std::as_const(m_workspaces)) {
        const auto ws = v.toMap();
        if (ws.value(QStringLiteral("id")).toString() == wsId) {
            output = ws.value(QStringLiteral("output")).toString();
            break;
        }
    }
    const QVariantMap window = normalizeWindow(winObj, output);
    const qint64 winId = window.value(QStringLiteral("id")).toString().toLongLong();

    const int existingIdx = findWindowIndexById(winId);
    if (existingIdx >= 0) {
        auto existing = m_windows.at(existingIdx).toMap();
        for (auto it = window.begin(); it != window.end(); ++it) {
            existing[it.key()] = it.value();
        }
        m_windows[existingIdx] = existing;
    } else {
        m_windows.append(window);
    }

    sortWindowsList();
    rebuildWindowIndex();

    if (window.value(QStringLiteral("focused")).toBool()) {
        m_focusedWindowId = window.value(QStringLiteral("id")).toString();
        m_focusedWindowIndex = findWindowIndexById(winId);
    }

    updateWorkspaceOccupancy();
    updateFocusedWindowFields();
    emit windowsChanged();
    emit windowOpenedOrChanged(window);
}

void NiriBackend::handleWindowClosed(const QJsonObject& data) {
    const qint64 closedId = data.value(QStringLiteral("id")).toInteger();
    const QString closedIdStr = QString::number(closedId);

    const int idx = findWindowIndexById(closedId);
    if (idx >= 0) {
        m_windows.removeAt(idx);
        rebuildWindowIndex();
    }

    updateWorkspaceOccupancy();
    updateFocusedWindowFields();
    emit windowsChanged();
    emit windowClosed(closedIdStr);
}

void NiriBackend::handleWindowFocusChanged(const QJsonObject& data) {
    if (data.contains(QStringLiteral("id")) && !data.value(QStringLiteral("id")).isNull()) {
        const qint64 id = data.value(QStringLiteral("id")).toInteger();
        m_focusedWindowId = QString::number(id);
        m_focusedWindowIndex = findWindowIndexById(id);
    } else {
        m_focusedWindowId.clear();
        m_focusedWindowIndex = -1;
    }

    updateFocusedWindowFields();
    emit focusedWindowChanged();
}

void NiriBackend::handleWindowLayoutsChanged(const QJsonObject& data) {
    const QJsonArray changes = data.value(QStringLiteral("changes")).toArray();
    if (changes.isEmpty()) return;

    for (const auto& change : changes) {
        const QJsonArray pair = change.toArray();
        if (pair.size() != 2) continue;

        const qint64 id = pair.at(0).toInteger();
        const auto layout = pair.at(1).toObject();

        const int idx = findWindowIndexById(id);
        if (idx >= 0) {
            auto w = m_windows.at(idx).toMap();
            const auto size = layout.value(QStringLiteral("window_size")).toArray();
            if (size.size() >= 2) {
                w[QStringLiteral("width")] = size.at(0).toDouble();
                w[QStringLiteral("height")] = size.at(1).toDouble();
            }
            const auto pos = layout.value(QStringLiteral("pos_in_scrolling_layout")).toArray();
            if (pos.size() >= 2) {
                QVariantMap grid;
                grid.insert(QStringLiteral("col"), pos.at(0).toInt());
                grid.insert(QStringLiteral("row"), pos.at(1).toInt());
                w[QStringLiteral("grid")] = grid;
            }
            m_windows[idx] = w;
        }
    }

    sortWindowsList();
    rebuildWindowIndex();

    if (!m_focusedWindowId.isEmpty()) {
        m_focusedWindowIndex = findWindowIndexById(m_focusedWindowId.toLongLong());
    }

    updateFocusedWindowFields();
    emit windowsChanged();
}

void NiriBackend::handleOutputsChanged(const QJsonObject& data) {
    const auto outputs = data.value(QStringLiteral("outputs"));
    if (outputs.isObject()) {
        m_outputs = normalizeOutputs(outputs.toObject());
    } else {
        m_outputs = normalizeOutputs(data);
    }
    emit outputsChanged();
}

void NiriBackend::handleKeyboardLayoutsChanged(const QJsonObject& data) {
    const QJsonObject kb = data.value(QStringLiteral("keyboard_layouts")).toObject();
    QJsonObject src = kb.isEmpty() ? data : kb;

    const QJsonArray names = src.value(QStringLiteral("names")).toArray();
    m_kbLayoutsArray = names.toVariantList();

    QStringList namesList;
    for (const auto& v : std::as_const(m_kbLayoutsArray)) {
        namesList.append(v.toString());
    }
    m_kbLayouts = namesList.isEmpty() ? QStringLiteral("?") : namesList.join(QStringLiteral(","));

    const int idx = src.value(QStringLiteral("current_idx")).toInt(0);
    m_kbLayoutIndex = (idx >= 0 && idx < m_kbLayoutsArray.size()) ? idx : 0;

    emit keyboardChanged();
}

void NiriBackend::handleOverviewOpenedOrClosed(const QJsonObject& data) {
    const bool isOpen = data.value(QStringLiteral("is_open")).toBool();
    if (m_inOverview != isOpen) {
        m_inOverview = isOpen;
        emit inOverviewChanged();
    }
}

// ── Internal helpers ─────────────────────────────────────────────────────

void NiriBackend::updateFocusedWindowFields() {
    if (m_focusedWindowIndex >= 0 && m_focusedWindowIndex < m_windows.size()) {
        const auto win = m_windows.at(m_focusedWindowIndex).toMap();
        QString title = win.value(QStringLiteral("title")).toString();
        while (!title.isEmpty() && title.at(0).unicode() < 0x20) {
            title.remove(0, 1);
        }
        m_focusedWindowTitle = title.isEmpty() ? QStringLiteral("(Unnamed window)") : title;
        m_focusedWindowClass = win.value(QStringLiteral("appId")).toString();
        m_focusedWindow = win;

        const auto grid = win.value(QStringLiteral("grid")).toMap();
        if (grid.contains(QStringLiteral("col"))) {
            const int currentCol = grid.value(QStringLiteral("col")).toInt();
            if (m_lastFocusedColumn >= 0) {
                const QString newDir = currentCol > m_lastFocusedColumn ? QStringLiteral("right")
                                     : currentCol < m_lastFocusedColumn ? QStringLiteral("left")
                                     : QStringLiteral("none");
                if (m_scrollDirection != newDir) {
                    m_scrollDirection = newDir;
                    emit scrollDirectionChanged();
                }
            }
            m_lastFocusedColumn = currentCol;
        }

        m_lastFocusedWindow = win;
        emit lastFocusedWindowChanged();
    } else {
        m_focusedWindowTitle.clear();
        m_focusedWindowClass = QStringLiteral("Desktop");
        m_focusedWindow.clear();
    }
    emit focusedWindowChanged();
}

void NiriBackend::sortWindowsList() {
    std::sort(m_windows.begin(), m_windows.end(), [](const QVariant& a, const QVariant& b) {
        const auto aGrid = a.toMap().value(QStringLiteral("grid")).toMap();
        const auto bGrid = b.toMap().value(QStringLiteral("grid")).toMap();
        const int ax = aGrid.value(QStringLiteral("col")).toInt();
        const int ay = aGrid.value(QStringLiteral("row")).toInt();
        const int bx = bGrid.value(QStringLiteral("col")).toInt();
        const int by = bGrid.value(QStringLiteral("row")).toInt();
        if (ax != bx) return ax < bx;
        return ay < by;
    });
}

void NiriBackend::rebuildWindowIndex() {
    m_windowIndex.clear();
    m_windowIndex.reserve(m_windows.size());
    for (int i = 0; i < m_windows.size(); ++i) {
        const qint64 id = m_windows.at(i).toMap().value(QStringLiteral("id")).toString().toLongLong();
        m_windowIndex.insert(id, i);
    }
}

int NiriBackend::findWindowIndexById(qint64 id) const {
    auto it = m_windowIndex.find(id);
    return (it != m_windowIndex.end()) ? it.value() : -1;
}

} // namespace caelestia
