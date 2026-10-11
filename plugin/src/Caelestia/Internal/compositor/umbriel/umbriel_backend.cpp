#include "umbriel_backend.hpp"

#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qdebug.h>

#include <algorithm>
#include <climits>
#include <utility>

namespace caelestia {

namespace {

    // ── Normalization helpers (raw Umbriel → neutral schema) ──────────────

    /// Umbriel transform name → wl_output_transform ordinal (neutral schema
    /// stores transform as an int, matching niri).
    int transformToInt(const QString& name) {
        if (name == QStringLiteral("90")) return 1;
        if (name == QStringLiteral("180")) return 2;
        if (name == QStringLiteral("270")) return 3;
        if (name == QStringLiteral("flipped")) return 4;
        if (name == QStringLiteral("flipped-90")) return 5;
        if (name == QStringLiteral("flipped-180")) return 6;
        if (name == QStringLiteral("flipped-270")) return 7;
        return 0; // "normal" and unknown
    }

    /// Umbriel window object → neutral window map. Umbriel windows carry
    /// their output and geometry directly, so no workspace join is needed.
    QVariantMap normalizeWindow(const QJsonObject& raw) {
        QVariantMap win;
        win.insert(QStringLiteral("id"), raw.value(QStringLiteral("id")).toString());
        win.insert(QStringLiteral("appId"), raw.value(QStringLiteral("app_id")).toString());
        win.insert(QStringLiteral("title"), raw.value(QStringLiteral("title")).toString());
        win.insert(QStringLiteral("workspaceId"), raw.value(QStringLiteral("workspace")).toString());
        win.insert(QStringLiteral("output"), raw.value(QStringLiteral("output")).toString());
        // `active` is Umbriel's seat-global activation flag — the focused window.
        win.insert(QStringLiteral("focused"), raw.value(QStringLiteral("active")).toBool());
        win.insert(QStringLiteral("floating"), raw.value(QStringLiteral("floating")).toBool());
        win.insert(QStringLiteral("fullscreen"), raw.value(QStringLiteral("fullscreen")).toBool());
        win.insert(QStringLiteral("maximized"), raw.value(QStringLiteral("maximized")).toBool());
        win.insert(QStringLiteral("urgent"), raw.value(QStringLiteral("urgent")).toBool());
        win.insert(QStringLiteral("pid"), raw.value(QStringLiteral("pid")).toInt(-1));

        win.insert(QStringLiteral("x"), raw.value(QStringLiteral("x")).toDouble());
        win.insert(QStringLiteral("y"), raw.value(QStringLiteral("y")).toDouble());
        win.insert(QStringLiteral("width"), raw.value(QStringLiteral("w")).toDouble());
        win.insert(QStringLiteral("height"), raw.value(QStringLiteral("h")).toDouble());

        // column/row are -1 for floating windows and non-scrolling layouts.
        const int col = raw.value(QStringLiteral("column")).toInt(-1);
        const int row = raw.value(QStringLiteral("row")).toInt(-1);
        if (col >= 0 || row >= 0) {
            QVariantMap grid;
            grid.insert(QStringLiteral("col"), col);
            grid.insert(QStringLiteral("row"), row);
            win.insert(QStringLiteral("grid"), grid);
        }
        return win;
    }

    /// Umbriel workspace object → neutral workspace map. Umbriel's `index`
    /// is already 1-based (workspace->index() + 1), matching the neutral
    /// schema and the workspace-switch selector's digit form.
    QVariantMap normalizeWorkspace(const QJsonObject& raw) {
        QVariantMap ws;
        ws.insert(QStringLiteral("id"), raw.value(QStringLiteral("id")).toString());
        ws.insert(QStringLiteral("name"), raw.value(QStringLiteral("name")).toString());
        ws.insert(QStringLiteral("index"), raw.value(QStringLiteral("index")).toInt());
        ws.insert(QStringLiteral("output"), raw.value(QStringLiteral("output")).toString());
        ws.insert(QStringLiteral("active"), raw.value(QStringLiteral("active")).toBool());
        ws.insert(QStringLiteral("focused"), raw.value(QStringLiteral("focused")).toBool());
        ws.insert(QStringLiteral("urgent"), raw.value(QStringLiteral("urgent")).toBool());
        ws.insert(QStringLiteral("occupied"), raw.value(QStringLiteral("occupied")).toBool());
        ws.insert(QStringLiteral("windowCount"), raw.value(QStringLiteral("window_count")).toInt());
        ws.insert(QStringLiteral("isSpecial"), false);
        // Umbriel-only extra: layout mode, used to derive scrollDirection.
        ws.insert(QStringLiteral("layout"), raw.value(QStringLiteral("layout")).toString());
        return ws;
    }

    /// Raw Umbriel outputs array → neutral outputs map.
    QVariantMap normalizeOutputs(const QJsonArray& rawOutputs) {
        QVariantMap outputs;
        for (const auto& v : rawOutputs) {
            const auto raw = v.toObject();
            const QString name = raw.value(QStringLiteral("name")).toString();
            if (name.isEmpty()) continue;

            QVariantMap out;
            out.insert(QStringLiteral("name"), name);

            // Prefer the current mode, else the preferred one, else the first.
            const auto modes = raw.value(QStringLiteral("modes")).toArray();
            QJsonObject mode;
            for (const auto& m : modes) {
                const auto mo = m.toObject();
                if (mo.value(QStringLiteral("current")).toBool()) {
                    mode = mo;
                    break;
                }
            }
            if (mode.isEmpty()) {
                for (const auto& m : modes) {
                    const auto mo = m.toObject();
                    if (mo.value(QStringLiteral("preferred")).toBool()) {
                        mode = mo;
                        break;
                    }
                }
            }
            if (mode.isEmpty() && !modes.isEmpty()) {
                mode = modes.first().toObject();
            }
            QVariantMap modeMap;
            modeMap.insert(QStringLiteral("width"), mode.value(QStringLiteral("width")).toInt());
            modeMap.insert(QStringLiteral("height"), mode.value(QStringLiteral("height")).toInt());
            modeMap.insert(QStringLiteral("refreshRate"), mode.value(QStringLiteral("refresh_mhz")).toInt());
            out.insert(QStringLiteral("mode"), modeMap);

            const auto position = raw.value(QStringLiteral("position")).toObject();
            QVariantMap location;
            location.insert(QStringLiteral("x"), position.value(QStringLiteral("x")).toInt());
            location.insert(QStringLiteral("y"), position.value(QStringLiteral("y")).toInt());
            out.insert(QStringLiteral("location"), location);
            out.insert(QStringLiteral("scale"), raw.value(QStringLiteral("scale")).toDouble(1.0));
            out.insert(QStringLiteral("transform"), transformToInt(raw.value(QStringLiteral("transform")).toString()));
            out.insert(QStringLiteral("enabled"), raw.value(QStringLiteral("enabled")).toBool());
            outputs.insert(name, out);
        }
        return outputs;
    }

} // namespace

// ── Construction ─────────────────────────────────────────────────────────

UmbrielBackend::UmbrielBackend(QObject* parent)
    : CompositorBackend(parent)
    , m_eventSocket(this)
    , m_requestSocket(this) {

    connect(&m_eventSocket, &UmbrielEventSocket::connected, this, &UmbrielBackend::onEventStreamConnected);
    connect(&m_eventSocket, &UmbrielEventSocket::disconnected, this, &UmbrielBackend::onEventStreamDisconnected);
    connect(&m_eventSocket, &UmbrielEventSocket::eventReceived, this, &UmbrielBackend::onEvent);

    m_eventSocket.connectToUmbriel();
}

// ── Capabilities ─────────────────────────────────────────────────────────

CompositorCapabilities UmbrielBackend::capabilities() const {
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
    caps.screenshotWindow = false; // Umbriel has no screenshot-window action
    caps.windowGrid = true;
    caps.absoluteGeometry = true;
    caps.scrollDirection = true;
    caps.specialWorkspaces = false;
    caps.keybindSource = QString(); // no keybind-config parser source for Umbriel
    return caps;
}

bool UmbrielBackend::available() const { return m_available; }

// ── Property getters ─────────────────────────────────────────────────────

QVariantList UmbrielBackend::workspaces() const { return m_workspaces; }
int UmbrielBackend::focusedWorkspaceIndex() const { return m_focusedWorkspaceIndex; }
QString UmbrielBackend::focusedWorkspaceId() const { return m_focusedWorkspaceId; }
QString UmbrielBackend::focusedMonitorName() const { return m_focusedMonitorName; }

QVariantList UmbrielBackend::windows() const { return m_windows; }
int UmbrielBackend::focusedWindowIndex() const { return m_focusedWindowIndex; }
QString UmbrielBackend::focusedWindowId() const { return m_focusedWindowId; }
QString UmbrielBackend::focusedWindowTitle() const { return m_focusedWindowTitle; }
QString UmbrielBackend::focusedWindowClass() const { return m_focusedWindowClass; }
QVariantMap UmbrielBackend::focusedWindow() const { return m_focusedWindow; }
QVariantMap UmbrielBackend::lastFocusedWindow() const { return m_lastFocusedWindow; }
bool UmbrielBackend::inOverview() const { return m_inOverview; }
QString UmbrielBackend::scrollDirection() const { return m_scrollDirection; }

QVariantMap UmbrielBackend::outputs() const { return m_outputs; }

QVariantList UmbrielBackend::kbLayoutsArray() const { return m_kbLayoutsArray; }
int UmbrielBackend::kbLayoutIndex() const { return m_kbLayoutIndex; }
QString UmbrielBackend::kbLayouts() const { return m_kbLayouts; }

QString UmbrielBackend::defaultKbLayout() const {
    if (!m_kbLayoutsArray.isEmpty()) {
        return m_kbLayoutsArray.first().toString();
    }
    return QStringLiteral("?");
}

QString UmbrielBackend::kbLayout() const {
    if (m_kbLayoutIndex >= 0 && m_kbLayoutIndex < m_kbLayoutsArray.size()) {
        const QString name = m_kbLayoutsArray.at(m_kbLayoutIndex).toString();
        if (name.size() >= 2) {
            return name.left(2).toLower();
        }
    }
    return QStringLiteral("?");
}

// ── Workspace/window helpers ─────────────────────────────────────────────

int UmbrielBackend::getWorkspaceIdxById(const QString& id) const {
    for (const auto& v : m_workspaces) {
        const auto ws = v.toMap();
        if (ws.value(QStringLiteral("id")).toString() == id) {
            return ws.value(QStringLiteral("index")).toInt();
        }
    }
    return -1;
}

QVariantList UmbrielBackend::getWindowsByWorkspaceId(const QString& id) const {
    QVariantList res;
    for (const auto& w : m_windows) {
        if (w.toMap().value(QStringLiteral("workspaceId")).toString() == id) {
            res.append(w);
        }
    }
    return res;
}

QVariantList UmbrielBackend::getWindowsByWorkspaceIndex(int index) const {
    // `index` is a position into the sorted workspace list (mirrors niri and
    // the QML wrapper in services/Compositor.qml).
    if (index < 0 || index >= m_workspaces.size()) return {};
    const QString wsId = m_workspaces.at(index).toMap().value(QStringLiteral("id")).toString();
    return getWindowsByWorkspaceId(wsId);
}

QVariantList UmbrielBackend::getActiveWorkspaceWindows() const {
    if (m_focusedWorkspaceId.isEmpty()) return {};
    return getWindowsByWorkspaceId(m_focusedWorkspaceId);
}

bool UmbrielBackend::workspaceSelectorById(const QString& id, QString& selector) const {
    for (const auto& v : m_workspaces) {
        const auto ws = v.toMap();
        if (ws.value(QStringLiteral("id")).toString() != id) continue;
        const int index = ws.value(QStringLiteral("index")).toInt();
        const QString output = ws.value(QStringLiteral("output")).toString();
        if (index <= 0) return false;
        // Bare digits select the 1-based position, scoped to the output so
        // per-output workspace lists can't collide.
        selector = output.isEmpty() ? QString::number(index)
                                    : QString::number(index) + u'/' + output;
        return true;
    }
    return false;
}

// ── Neutral verbs → Umbriel actions ──────────────────────────────────────

bool UmbrielBackend::umbrielAction(const QString& action) {
    if (!m_available) {
        warnUnsupported(QStringLiteral("Umbriel IPC (not connected)"));
        return false;
    }
    QJsonObject req;
    req.insert(QStringLiteral("cmd"), QStringLiteral("msg"));
    req.insert(QStringLiteral("arg"), action);
    m_requestSocket.action(QJsonDocument(req).toJson(QJsonDocument::Compact));
    return true;
}

bool UmbrielBackend::focusWorkspace(const QString& id) {
    QString selector;
    if (!workspaceSelectorById(id, selector)) return false;
    return umbrielAction(QStringLiteral("workspace-switch:") + selector);
}

bool UmbrielBackend::focusWorkspaceRelative(int delta) {
    if (delta == 0) return false;
    const QString action = delta > 0 ? QStringLiteral("workspace-next") : QStringLiteral("workspace-previous");
    bool ok = true;
    for (int i = 0; i < qAbs(delta); ++i) {
        ok = umbrielAction(action) && ok;
    }
    return ok;
}

bool UmbrielBackend::moveWindowToWorkspace(const QString& id) {
    QString selector;
    if (!workspaceSelectorById(id, selector)) return false;
    return umbrielAction(QStringLiteral("window-move-to-workspace:") + selector);
}

bool UmbrielBackend::moveWindowToIndex(int index) {
    if (index < 0) return false;
    // Umbriel has no direct move-to-index; walk the column order from the
    // focused window's current column using the scrolling layout's moves.
    if (m_focusedWindowIndex < 0 || m_focusedWindowIndex >= m_windows.size()) return false;
    const auto grid = m_windows.at(m_focusedWindowIndex).toMap().value(QStringLiteral("grid")).toMap();
    const int current = grid.value(QStringLiteral("col"), -1).toInt();
    if (current < 0) {
        warnUnsupported(QStringLiteral("moveWindowToIndex (non-scrolling layout)"));
        return false;
    }
    const int delta = index - current;
    if (delta == 0) return true;
    const QString action = delta > 0 ? QStringLiteral("column-move-right") : QStringLiteral("column-move-left");
    bool ok = true;
    for (int i = 0; i < qAbs(delta); ++i) {
        ok = umbrielAction(action) && ok;
    }
    return ok;
}

bool UmbrielBackend::focusWindow(const QString& id) {
    if (id.isEmpty()) return false;
    return umbrielAction(QStringLiteral("window-focus:") + id);
}

bool UmbrielBackend::closeWindow(const QString& id) {
    return umbrielAction(id.isEmpty() ? QStringLiteral("window-close")
                                      : QStringLiteral("window-close:") + id);
}

bool UmbrielBackend::toggleFloating(const QString& id) {
    return umbrielAction(id.isEmpty() ? QStringLiteral("window-toggle-floating")
                                      : QStringLiteral("window-toggle-floating:") + id);
}

bool UmbrielBackend::toggleFullscreen() { return umbrielAction(QStringLiteral("window-toggle-fullscreen")); }
bool UmbrielBackend::toggleMaximize() { return umbrielAction(QStringLiteral("window-toggle-maximize")); }
bool UmbrielBackend::toggleOverview() { return umbrielAction(QStringLiteral("overview-toggle")); }

bool UmbrielBackend::centerWindow() {
    // column-center for tiled windows, window-center for floats.
    if (m_focusedWindowIndex >= 0 && m_focusedWindowIndex < m_windows.size()) {
        const auto win = m_windows.at(m_focusedWindowIndex).toMap();
        if (win.value(QStringLiteral("floating")).toBool()) {
            return umbrielAction(QStringLiteral("window-center"));
        }
    }
    return umbrielAction(QStringLiteral("column-center"));
}

bool UmbrielBackend::expandWindow() { return umbrielAction(QStringLiteral("window-cycle-primary-extent")); }

bool UmbrielBackend::focusDirection(const QString& dir) {
    if (dir == QStringLiteral("left")) return umbrielAction(QStringLiteral("window-focus-left"));
    if (dir == QStringLiteral("right")) return umbrielAction(QStringLiteral("window-focus-right"));
    if (dir == QStringLiteral("up")) return umbrielAction(QStringLiteral("window-focus-up"));
    if (dir == QStringLiteral("down")) return umbrielAction(QStringLiteral("window-focus-down"));
    warnUnsupported(QStringLiteral("focusDirection(") + dir + u')');
    return false;
}

bool UmbrielBackend::moveDirection(const QString& dir) {
    if (dir == QStringLiteral("left")) return umbrielAction(QStringLiteral("window-move-left"));
    if (dir == QStringLiteral("right")) return umbrielAction(QStringLiteral("window-move-right"));
    if (dir == QStringLiteral("up")) return umbrielAction(QStringLiteral("window-move-up"));
    if (dir == QStringLiteral("down")) return umbrielAction(QStringLiteral("window-move-down"));
    warnUnsupported(QStringLiteral("moveDirection(") + dir + u')');
    return false;
}

bool UmbrielBackend::switchKbLayout(int index) {
    // Umbriel cycles with keyboard-layout-next; walk the delta from current.
    if (m_kbLayoutsArray.isEmpty()) return false;
    const int count = static_cast<int>(m_kbLayoutsArray.size());
    const int target = ((index % count) + count) % count;
    int delta = target - m_kbLayoutIndex;
    if (delta < 0) delta += count;
    if (delta == 0) return true;
    bool ok = true;
    for (int i = 0; i < delta; ++i) {
        ok = umbrielAction(QStringLiteral("keyboard-layout-next")) && ok;
    }
    return ok;
}

bool UmbrielBackend::setDisplayPower(bool on) {
    return umbrielAction(on ? QStringLiteral("dpms-on") : QStringLiteral("dpms-off"));
}

bool UmbrielBackend::screenshotWindow() {
    warnUnsupported(QStringLiteral("screenshotWindow"));
    return false;
}

bool UmbrielBackend::dispatch(const QString& command) {
    const QString cmd = command.trimmed().toLower();
    if (cmd == QStringLiteral("dpms off")) return setDisplayPower(false);
    if (cmd == QStringLiteral("dpms on")) return setDisplayPower(true);
    warnUnsupported(QStringLiteral("dispatch(") + command + u')');
    return false;
}

// ── Event stream ─────────────────────────────────────────────────────────

void UmbrielBackend::onEventStreamConnected() {
    qDebug() << "UmbrielBackend: Event stream connected";
    m_available = true;
    emit availableChanged();
    // Workspaces/windows/outputs/overview state arrives as the first
    // snapshot of each subscribed family; only keyboard layouts need an
    // explicit query.
    fetchKeyboardLayouts();
}

void UmbrielBackend::onEventStreamDisconnected() {
    qDebug() << "UmbrielBackend: Event stream disconnected";
    m_available = false;
    emit availableChanged();
}

void UmbrielBackend::onEvent(const QJsonObject& event) {
    const QString name = event.value(QStringLiteral("event")).toString();
    const QJsonValue data = event.value(QStringLiteral("data"));

    if (name == QStringLiteral("workspaces")) {
        handleWorkspacesSnapshot(data.toArray());
    } else if (name == QStringLiteral("windows")) {
        handleWindowsSnapshot(data.toArray());
    } else if (name == QStringLiteral("outputs")) {
        handleOutputsSnapshot(data.toArray());
    } else if (name == QStringLiteral("overview")) {
        handleOverview(data);
    } else if (name == QStringLiteral("keyboard_layout")) {
        // Payload is a change signal only — re-query the layout list.
        fetchKeyboardLayouts();
    }
}

// ── Initial state ────────────────────────────────────────────────────────

void UmbrielBackend::fetchKeyboardLayouts() {
    m_requestSocket.request(QByteArrayLiteral(R"({"cmd":"keyboard-layouts"})"),
        [this](bool ok, const QJsonObject& resp) {
            if (!ok) return;
            handleKeyboardLayouts(resp.value(QStringLiteral("result")).toObject());
        });
}

// ── Event handlers (normalize + cache) ───────────────────────────────────

void UmbrielBackend::handleWorkspacesSnapshot(const QJsonArray& data) {
    QVariantList wsList;
    wsList.reserve(data.size());
    for (const auto& v : data) {
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
    m_focusedMonitorName.clear();
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

    updateWorkspaceOccupancy();
    emit workspacesChanged();
    emit focusedWorkspaceChanged();
}

void UmbrielBackend::handleWindowsSnapshot(const QJsonArray& data) {
    QVariantList winList;
    winList.reserve(data.size());
    for (const auto& v : data) {
        const auto raw = v.toObject();
        // Windows without an ext-foreign-toplevel identifier can't be
        // targeted by focus/close, so skip them (matches noctalia).
        if (raw.value(QStringLiteral("id")).toString().isEmpty()) continue;
        winList.append(normalizeWindow(raw));
    }
    m_windows = winList;
    sortWindowsList();

    m_focusedWindowId.clear();
    m_focusedWindowIndex = -1;
    for (int i = 0; i < m_windows.size(); ++i) {
        if (m_windows.at(i).toMap().value(QStringLiteral("focused")).toBool()) {
            m_focusedWindowIndex = i;
            m_focusedWindowId = m_windows.at(i).toMap().value(QStringLiteral("id")).toString();
            break;
        }
    }

    updateWorkspaceOccupancy();
    updateFocusedWindowFields();
    emit windowsChanged();
}

void UmbrielBackend::handleOutputsSnapshot(const QJsonArray& data) {
    m_outputs = normalizeOutputs(data);
    emit outputsChanged();
}

void UmbrielBackend::handleOverview(const QJsonValue& data) {
    bool open = false;
    if (data.isObject()) {
        open = data.toObject().value(QStringLiteral("open")).toBool();
    } else if (data.isBool()) {
        open = data.toBool();
    }
    if (m_inOverview != open) {
        m_inOverview = open;
        emit inOverviewChanged();
    }
}

void UmbrielBackend::handleKeyboardLayouts(const QJsonObject& payload) {
    const QJsonArray names = payload.value(QStringLiteral("names")).toArray();
    m_kbLayoutsArray = names.toVariantList();

    QStringList namesList;
    for (const auto& v : std::as_const(m_kbLayoutsArray)) {
        namesList.append(v.toString());
    }
    m_kbLayouts = namesList.isEmpty() ? QStringLiteral("?") : namesList.join(QStringLiteral(","));

    const int idx = payload.value(QStringLiteral("current_index")).toInt(0);
    m_kbLayoutIndex = (idx >= 0 && idx < m_kbLayoutsArray.size()) ? idx : 0;

    emit keyboardChanged();
}

// ── Internal helpers ─────────────────────────────────────────────────────

void UmbrielBackend::updateWorkspaceOccupancy() {
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

void UmbrielBackend::updateFocusedWindowFields() {
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

void UmbrielBackend::sortWindowsList() {
    std::sort(m_windows.begin(), m_windows.end(), [](const QVariant& a, const QVariant& b) {
        const auto aGrid = a.toMap().value(QStringLiteral("grid")).toMap();
        const auto bGrid = b.toMap().value(QStringLiteral("grid")).toMap();
        // -1 (floating / non-scrolling) sorts after tiled windows.
        const int ax = aGrid.contains(QStringLiteral("col")) ? aGrid.value(QStringLiteral("col")).toInt() : INT_MAX;
        const int ay = aGrid.contains(QStringLiteral("row")) ? aGrid.value(QStringLiteral("row")).toInt() : INT_MAX;
        const int bx = bGrid.contains(QStringLiteral("col")) ? bGrid.value(QStringLiteral("col")).toInt() : INT_MAX;
        const int by = bGrid.contains(QStringLiteral("row")) ? bGrid.value(QStringLiteral("row")).toInt() : INT_MAX;
        if (ax != bx) return ax < bx;
        if (ay != by) return ay < by;
        // Fall back to position for windows without grid info.
        const auto aPos = a.toMap();
        const auto bPos = b.toMap();
        const auto aX = aPos.value(QStringLiteral("x")).toDouble();
        const auto bX = bPos.value(QStringLiteral("x")).toDouble();
        if (aX < bX || bX < aX) {
            return aX < bX;
        }
        return aPos.value(QStringLiteral("y")).toDouble() < bPos.value(QStringLiteral("y")).toDouble();
    });
}

} // namespace caelestia
