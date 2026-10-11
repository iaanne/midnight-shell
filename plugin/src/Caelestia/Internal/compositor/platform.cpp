#include "platform.hpp"

#include "backend.hpp"
#include "niri/niri_backend.hpp"
#include "umbriel/umbriel_backend.hpp"

#include "config/rootnodes.hpp"
#include "config/serviceconfig.hpp"

#include <qdebug.h>
#include <qdir.h>
#include <qfile.h>

namespace caelestia {

    namespace {

        /// NullBackend — stand-in for detected-but-unimplemented compositors
        /// (and Unknown). All capabilities false, all getters empty, verbs
        /// return false with a single construction warning.
        class NullBackend : public CompositorBackend {
        public:
            explicit NullBackend(CompositorKind kind, QObject* parent = nullptr)
                : CompositorBackend(parent) {
                qWarning() << "CompositorBackend: compositor" << caelestia::name(kind)
                           << "detected, backend not implemented yet — capability-gated features stay disabled";
            }

            [[nodiscard]] CompositorCapabilities capabilities() const override { return {}; }
            [[nodiscard]] bool available() const override { return false; }

            [[nodiscard]] QVariantList workspaces() const override { return {}; }
            [[nodiscard]] int focusedWorkspaceIndex() const override { return -1; }
            [[nodiscard]] QString focusedWorkspaceId() const override { return {}; }
            [[nodiscard]] QString focusedMonitorName() const override { return {}; }

            [[nodiscard]] QVariantList windows() const override { return {}; }
            [[nodiscard]] int focusedWindowIndex() const override { return -1; }
            [[nodiscard]] QString focusedWindowId() const override { return {}; }
            [[nodiscard]] QString focusedWindowTitle() const override { return {}; }
            [[nodiscard]] QString focusedWindowClass() const override { return {}; }
            [[nodiscard]] QVariantMap focusedWindow() const override { return {}; }
            [[nodiscard]] QVariantMap lastFocusedWindow() const override { return {}; }
            [[nodiscard]] bool inOverview() const override { return false; }
            [[nodiscard]] QString scrollDirection() const override { return {}; }

            [[nodiscard]] QVariantMap outputs() const override { return {}; }

            [[nodiscard]] QVariantList kbLayoutsArray() const override { return {}; }
            [[nodiscard]] int kbLayoutIndex() const override { return 0; }
            [[nodiscard]] QString kbLayouts() const override { return {}; }
            [[nodiscard]] QString defaultKbLayout() const override { return {}; }
            [[nodiscard]] QString kbLayout() const override { return {}; }

            [[nodiscard]] int getWorkspaceIdxById(const QString&) const override { return -1; }
            [[nodiscard]] QVariantList getWindowsByWorkspaceId(const QString&) const override { return {}; }
            [[nodiscard]] QVariantList getWindowsByWorkspaceIndex(int) const override { return {}; }
            [[nodiscard]] QVariantList getActiveWorkspaceWindows() const override { return {}; }

            bool focusWorkspace(const QString&) override { return false; }
            bool focusWorkspaceRelative(int) override { return false; }
            bool moveWindowToWorkspace(const QString&) override { return false; }
            bool moveWindowToIndex(int) override { return false; }
            bool focusWindow(const QString&) override { return false; }
            bool closeWindow(const QString&) override { return false; }
            bool toggleFloating(const QString&) override { return false; }
            bool toggleFullscreen() override { return false; }
            bool toggleMaximize() override { return false; }
            bool toggleOverview() override { return false; }
            bool centerWindow() override { return false; }
            bool expandWindow() override { return false; }
            bool focusDirection(const QString&) override { return false; }
            bool moveDirection(const QString&) override { return false; }
            bool switchKbLayout(int) override { return false; }
            bool setDisplayPower(bool) override { return false; }
            bool screenshotWindow() override { return false; }
            bool dispatch(const QString&) override { return false; }
        };

    } // namespace

    CompositorIpc::CompositorIpc(QObject* parent) : QObject(parent), m_backend(createBackend()) {
        if (m_backend) {
            // Signal fan-in: every backend signal re-emitted on the facade.
            connect(m_backend.get(), &CompositorBackend::availableChanged, this, &CompositorIpc::availableChanged);
            connect(m_backend.get(), &CompositorBackend::workspacesChanged, this, &CompositorIpc::workspacesChanged);
            connect(m_backend.get(), &CompositorBackend::focusedWorkspaceChanged, this, &CompositorIpc::focusedWorkspaceChanged);
            connect(m_backend.get(), &CompositorBackend::windowsChanged, this, &CompositorIpc::windowsChanged);
            connect(m_backend.get(), &CompositorBackend::focusedWindowChanged, this, &CompositorIpc::focusedWindowChanged);
            connect(m_backend.get(), &CompositorBackend::lastFocusedWindowChanged, this, &CompositorIpc::lastFocusedWindowChanged);
            connect(m_backend.get(), &CompositorBackend::scrollDirectionChanged, this, &CompositorIpc::scrollDirectionChanged);
            connect(m_backend.get(), &CompositorBackend::inOverviewChanged, this, &CompositorIpc::inOverviewChanged);
            connect(m_backend.get(), &CompositorBackend::outputsChanged, this, &CompositorIpc::outputsChanged);
            connect(m_backend.get(), &CompositorBackend::keyboardChanged, this, &CompositorIpc::keyboardChanged);
            connect(m_backend.get(), &CompositorBackend::windowOpenedOrChanged, this, &CompositorIpc::windowOpenedOrChanged);
            connect(m_backend.get(), &CompositorBackend::windowClosed, this, &CompositorIpc::windowClosed);
        }
        setupLedWatchers();
    }

    CompositorIpc::~CompositorIpc() = default;

    QString CompositorIpc::kind() const { return kindId(detect()); }
    QString CompositorIpc::name() const { return caelestia::name(detect()); }

    QVariantMap CompositorIpc::capabilities() const {
        // Capabilities never change at runtime; the map is rebuilt per call
        // only until first use — cache it on first invocation.
        static QVariantMap cached;
        if (!cached.isEmpty()) return cached;
        if (!m_backend) return {};
        const auto caps = m_backend->capabilities();
        QVariantMap m;
        m.insert(QStringLiteral("workspaces"), caps.workspaces);
        m.insert(QStringLiteral("windows"), caps.windows);
        m.insert(QStringLiteral("outputs"), caps.outputs);
        m.insert(QStringLiteral("kbLayout"), caps.kbLayout);
        m.insert(QStringLiteral("focusWindow"), caps.focusWindow);
        m.insert(QStringLiteral("closeWindow"), caps.closeWindow);
        m.insert(QStringLiteral("focusWorkspace"), caps.focusWorkspace);
        m.insert(QStringLiteral("moveWindowToWorkspace"), caps.moveWindowToWorkspace);
        m.insert(QStringLiteral("moveWindowToIndex"), caps.moveWindowToIndex);
        m.insert(QStringLiteral("toggleFloating"), caps.toggleFloating);
        m.insert(QStringLiteral("toggleFullscreen"), caps.toggleFullscreen);
        m.insert(QStringLiteral("toggleMaximize"), caps.toggleMaximize);
        m.insert(QStringLiteral("toggleOverview"), caps.toggleOverview);
        m.insert(QStringLiteral("centerWindow"), caps.centerWindow);
        m.insert(QStringLiteral("expandWindow"), caps.expandWindow);
        m.insert(QStringLiteral("focusDirection"), caps.focusDirection);
        m.insert(QStringLiteral("moveDirection"), caps.moveDirection);
        m.insert(QStringLiteral("switchKbLayout"), caps.switchKbLayout);
        m.insert(QStringLiteral("displayPower"), caps.displayPower);
        m.insert(QStringLiteral("screenshotWindow"), caps.screenshotWindow);
        m.insert(QStringLiteral("windowGrid"), caps.windowGrid);
        m.insert(QStringLiteral("absoluteGeometry"), caps.absoluteGeometry);
        m.insert(QStringLiteral("scrollDirection"), caps.scrollDirection);
        m.insert(QStringLiteral("specialWorkspaces"), caps.specialWorkspaces);
        m.insert(QStringLiteral("keybindSource"),
            caps.keybindSource.isEmpty() ? QVariant() : QVariant(caps.keybindSource));
        cached = m;
        return cached;
    }

    bool CompositorIpc::available() const { return m_backend && m_backend->available(); }

    QString CompositorIpc::keybindConfigPath() const { return m_backend ? m_backend->keybindConfigPath() : QString(); }

    QVariantList CompositorIpc::workspaces() const { return m_backend ? m_backend->workspaces() : QVariantList(); }
    int CompositorIpc::focusedWorkspaceIndex() const { return m_backend ? m_backend->focusedWorkspaceIndex() : -1; }
    QString CompositorIpc::focusedWorkspaceId() const { return m_backend ? m_backend->focusedWorkspaceId() : QString(); }
    QString CompositorIpc::focusedMonitorName() const { return m_backend ? m_backend->focusedMonitorName() : QString(); }

    QVariantList CompositorIpc::windows() const { return m_backend ? m_backend->windows() : QVariantList(); }
    int CompositorIpc::focusedWindowIndex() const { return m_backend ? m_backend->focusedWindowIndex() : -1; }
    QString CompositorIpc::focusedWindowId() const { return m_backend ? m_backend->focusedWindowId() : QString(); }
    QString CompositorIpc::focusedWindowTitle() const { return m_backend ? m_backend->focusedWindowTitle() : QString(); }
    QString CompositorIpc::focusedWindowClass() const { return m_backend ? m_backend->focusedWindowClass() : QString(); }
    QVariantMap CompositorIpc::focusedWindow() const { return m_backend ? m_backend->focusedWindow() : QVariantMap(); }
    QVariantMap CompositorIpc::lastFocusedWindow() const { return m_backend ? m_backend->lastFocusedWindow() : QVariantMap(); }
    QString CompositorIpc::scrollDirection() const { return m_backend ? m_backend->scrollDirection() : QString(); }
    bool CompositorIpc::inOverview() const { return m_backend && m_backend->inOverview(); }

    QVariantMap CompositorIpc::outputs() const { return m_backend ? m_backend->outputs() : QVariantMap(); }

    QVariantList CompositorIpc::kbLayoutsArray() const { return m_backend ? m_backend->kbLayoutsArray() : QVariantList(); }
    int CompositorIpc::kbLayoutIndex() const { return m_backend ? m_backend->kbLayoutIndex() : 0; }
    QString CompositorIpc::kbLayouts() const { return m_backend ? m_backend->kbLayouts() : QString(); }
    QString CompositorIpc::defaultKbLayout() const { return m_backend ? m_backend->defaultKbLayout() : QString(); }
    QString CompositorIpc::kbLayout() const { return m_backend ? m_backend->kbLayout() : QString(); }
    bool CompositorIpc::capsLock() const { return m_capsLock; }
    bool CompositorIpc::numLock() const { return m_numLock; }

    // ── Helpers ──

    int CompositorIpc::getWorkspaceIdxById(const QString& id) const { return m_backend ? m_backend->getWorkspaceIdxById(id) : -1; }
    QVariantList CompositorIpc::getWindowsByWorkspaceId(const QString& id) const {
        return m_backend ? m_backend->getWindowsByWorkspaceId(id) : QVariantList();
    }
    QVariantList CompositorIpc::getWindowsByWorkspaceIndex(int index) const {
        return m_backend ? m_backend->getWindowsByWorkspaceIndex(index) : QVariantList();
    }
    QVariantList CompositorIpc::getActiveWorkspaceWindows() const {
        return m_backend ? m_backend->getActiveWorkspaceWindows() : QVariantList();
    }

    // ── Neutral action verbs ──

    bool CompositorIpc::focusWorkspace(const QString& id) { return m_backend && m_backend->focusWorkspace(id); }
    bool CompositorIpc::focusWorkspaceRelative(int delta) { return m_backend && m_backend->focusWorkspaceRelative(delta); }
    bool CompositorIpc::moveWindowToWorkspace(const QString& id) { return m_backend && m_backend->moveWindowToWorkspace(id); }
    bool CompositorIpc::moveWindowToIndex(int index) { return m_backend && m_backend->moveWindowToIndex(index); }
    bool CompositorIpc::focusWindow(const QString& id) { return m_backend && m_backend->focusWindow(id); }
    bool CompositorIpc::closeWindow(const QString& id) { return m_backend && m_backend->closeWindow(id); }
    bool CompositorIpc::toggleFloating(const QString& id) { return m_backend && m_backend->toggleFloating(id); }
    bool CompositorIpc::toggleFullscreen() { return m_backend && m_backend->toggleFullscreen(); }
    bool CompositorIpc::toggleMaximize() { return m_backend && m_backend->toggleMaximize(); }
    bool CompositorIpc::toggleOverview() { return m_backend && m_backend->toggleOverview(); }
    bool CompositorIpc::centerWindow() { return m_backend && m_backend->centerWindow(); }
    bool CompositorIpc::expandWindow() { return m_backend && m_backend->expandWindow(); }
    bool CompositorIpc::focusDirection(const QString& dir) { return m_backend && m_backend->focusDirection(dir); }
    bool CompositorIpc::moveDirection(const QString& dir) { return m_backend && m_backend->moveDirection(dir); }
    bool CompositorIpc::switchKbLayout(int index) { return m_backend && m_backend->switchKbLayout(index); }
    bool CompositorIpc::setDisplayPower(bool on) { return m_backend && m_backend->setDisplayPower(on); }
    bool CompositorIpc::screenshotWindow() { return m_backend && m_backend->screenshotWindow(); }
    bool CompositorIpc::dispatch(const QString& command) { return m_backend && m_backend->dispatch(command); }

    CompositorBackend* CompositorIpc::backend() const { return m_backend.get(); }

    std::unique_ptr<CompositorBackend> CompositorIpc::createBackend() {
        switch (detect()) {
        case CompositorKind::Niri:
            return std::make_unique<NiriBackend>();
        case CompositorKind::Umbriel:
            return std::make_unique<UmbrielBackend>();
        case CompositorKind::Unknown:
        case CompositorKind::Hyprland:
        case CompositorKind::Sway:
        case CompositorKind::Mango:
        case CompositorKind::Labwc:
        case CompositorKind::Dwl:
        case CompositorKind::Kde:
            return std::make_unique<NullBackend>(detect());
        }
        return std::make_unique<NullBackend>(CompositorKind::Unknown);
    }

    // ── LED Watchers (capslock/numlock via /sys/class/leds) ──────────────
    // Compositor-agnostic: keyboard LED state comes from sysfs, not IPC.
    // Moved here from the old NiriIpc (was niriipc.cpp setupLedWatchers).

    void CompositorIpc::setupLedWatchers() {
        QDir ledsDir(QStringLiteral("/sys/class/leds"));
        if (!ledsDir.exists()) return;

        const auto entries = ledsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const auto& entry : entries) {
            const QString brightnessPath = ledsDir.filePath(entry) + QStringLiteral("/brightness");
            if (!QFile::exists(brightnessPath)) continue;

            if (entry.contains(QStringLiteral("capslock"), Qt::CaseInsensitive)) {
                m_capsLockPath = brightnessPath;
            } else if (entry.contains(QStringLiteral("numlock"), Qt::CaseInsensitive)) {
                m_numLockPath = brightnessPath;
            }
        }

        readLedState();

        // Poll sysfs since inotify doesn't work on virtual files
        if (!m_capsLockPath.isEmpty() || !m_numLockPath.isEmpty()) {
            auto* svc = config::ConfigSingleton::instance()->services();
            connect(svc, &config::ServiceConfig::ledPollEnabledChanged, this, &CompositorIpc::updateLedPolling);
            if (svc->ledPollEnabled()) {
                m_ledPollTimer.setInterval(1000);
                connect(&m_ledPollTimer, &QTimer::timeout, this, &CompositorIpc::readLedState);
                m_ledPollTimer.start();
            }
        }
    }

    void CompositorIpc::readLedState() {
        auto readBrightness = [](const QString& path) -> bool {
            if (path.isEmpty()) return false;
            QFile file(path);
            if (!file.open(QIODevice::ReadOnly)) return false;
            const QByteArray data = file.readAll().trimmed();
            return data.toInt() > 0;
        };

        const bool newCaps = readBrightness(m_capsLockPath);
        const bool newNum = readBrightness(m_numLockPath);

        if (m_capsLock != newCaps) {
            m_capsLock = newCaps;
            emit capsLockChanged();
        }
        if (m_numLock != newNum) {
            m_numLock = newNum;
            emit numLockChanged();
        }
    }

    void CompositorIpc::updateLedPolling() {
        const bool enabled = config::ConfigSingleton::instance()->services()->ledPollEnabled();
        if (enabled) {
            if (!m_ledPollTimer.isActive()) {
                m_ledPollTimer.start();
            }
        } else {
            m_ledPollTimer.stop();
        }
    }

} // namespace caelestia
