#include "keyringprompter.hpp"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QDebug>
#include <QFile>
#include <QTimer>
#include <QVariant>

#include <openssl/crypto.h>
#include <signal.h>
#include <sys/types.h>

#include <csignal>
#include <optional>
#include <string>
#include <utility>

namespace caelestia::services {

namespace {

const QString kSystemService = QStringLiteral("org.gnome.keyring.SystemPrompter");
const QString kPrivateService = QStringLiteral("org.gnome.keyring.PrivatePrompter");
const QString kObjectPath = QStringLiteral("/org/gnome/keyring/Prompter");
const QString kPrompterInterface = QStringLiteral("org.gnome.keyring.internal.Prompter");
const QString kCallbackInterface = QStringLiteral("org.gnome.keyring.internal.Prompter.Callback");
const QString kFailedError = QStringLiteral("org.gnome.keyring.Prompter.Failed");

constexpr int kUiReadyTimeoutMs = 4000;

QString propertyString(const QVariantMap& properties, const char* key) {
    return properties.value(QString::fromLatin1(key)).toString();
}

bool propertyBool(const QVariantMap& properties, const char* key) {
    return properties.value(QString::fromLatin1(key)).toBool();
}

} // namespace

KeyringPrompter::KeyringPrompter(QObject* parent)
    : QObject(parent)
    , m_uiFallbackTimer(new QTimer(this)) {
    m_uiFallbackTimer->setSingleShot(true);
    m_uiFallbackTimer->setInterval(kUiReadyTimeoutMs);
    connect(m_uiFallbackTimer, &QTimer::timeout, this, &KeyringPrompter::onUiFallbackTimeout);

    // Watch only our two names instead of subscribing to every ownership
    // change on the bus, which QDBusConnectionInterface::serviceOwnerChanged
    // would otherwise force on us.
    auto* watcher = new QDBusServiceWatcher(this);
    watcher->setConnection(QDBusConnection::sessionBus());
    watcher->setWatchMode(QDBusServiceWatcher::WatchForOwnerChange);
    watcher->addWatchedService(kSystemService);
    watcher->addWatchedService(kPrivateService);
    connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, &KeyringPrompter::onServiceOwnerChanged);
}

KeyringPrompter::~KeyringPrompter() {
    stop();

    if (m_objectRegistered) {
        QDBusConnection::sessionBus().unregisterObject(kObjectPath);
        m_objectRegistered = false;
    }
}

bool KeyringPrompter::enabled() const {
    return m_enabled;
}

void KeyringPrompter::setEnabled(bool enabled) {
    if (m_enabled == enabled)
        return;

    m_enabled = enabled;
    emit enabledChanged();

    if (m_enabled) {
        start();
        if (m_takeover)
            tryTakeover();
    } else {
        stop();
    }
}

bool KeyringPrompter::takeover() const {
    return m_takeover;
}

void KeyringPrompter::setTakeover(bool takeover) {
    if (m_takeover == takeover)
        return;

    m_takeover = takeover;
    emit takeoverChanged();

    if (m_takeover && m_enabled)
        tryTakeover();
}

bool KeyringPrompter::ready() const {
    return m_ready;
}

void KeyringPrompter::setReady(bool ready) {
    if (m_ready == ready)
        return;

    m_ready = ready;
    emit readyChanged();

    if (m_ready) {
        m_uiFallbackTimer->stop();
        emit promptChanged();
    } else if (m_active) {
        armUiFallbackTimer();
    }
}

bool KeyringPrompter::ownsName() const {
    return m_ownsSystem || m_ownsPrivate;
}

bool KeyringPrompter::hasPrompt() const {
    return m_active.has_value();
}

QVariantMap KeyringPrompter::prompt() const {
    return m_active.has_value() ? m_active->properties : QVariantMap {};
}

int KeyringPrompter::pendingCount() const {
    return static_cast<int>(m_queue.size()) + (m_active.has_value() ? 1 : 0);
}

QString KeyringPrompter::lastError() const {
    return m_lastError;
}

void KeyringPrompter::start() {
    if (m_started || !m_enabled)
        return;

    auto connection = QDBusConnection::sessionBus();
    if (!connection.isConnected()) {
        setLastError(QStringLiteral("Session bus is not available"));
        return;
    }

    if (!m_objectRegistered) {
        if (!connection.registerObject(kObjectPath, this, QDBusConnection::ExportAllSlots)) {
            setLastError(QStringLiteral("Could not export the keyring prompter object"));
            return;
        }
        m_objectRegistered = true;
    }

    m_started = true;
    claimService(kSystemService);
    claimService(kPrivateService);
}

void KeyringPrompter::stop() {
    cancelAll();
    releaseNames();
    m_sessions.clear();
    m_uiFallbackTimer->stop();
    m_started = false;
}

void KeyringPrompter::claimService(const QString& service) {
    if (!m_started || !m_enabled)
        return;
    if ((service == kSystemService && m_ownsSystem) || (service == kPrivateService && m_ownsPrivate))
        return;

    auto* interface = QDBusConnection::sessionBus().interface();
    if (interface == nullptr)
        return;

    // Without takeover, queue behind the current owner instead of trying to
    // replace it: an in-flight gcr-prompter prompt must be allowed to finish,
    // and a permanent owner such as GNOME Shell must never be disturbed. With
    // takeover enabled, ask to replace it and kill it in tryTakeover() if it
    // refuses.
    const auto queueOption = m_takeover ? QDBusConnectionInterface::ReplaceExistingService : QDBusConnectionInterface::QueueService;
    const auto reply = interface->registerService(service, queueOption, QDBusConnectionInterface::DontAllowReplacement);
    if (!reply.isValid()) {
        setLastError(QStringLiteral("Could not request the keyring prompter name %1").arg(service));
        return;
    }

    switch (reply.value()) {
        case QDBusConnectionInterface::ServiceRegistered:
            if (service == kSystemService)
                m_ownsSystem = true;
            else
                m_ownsPrivate = true;
            break;
        case QDBusConnectionInterface::ServiceQueued:
            // The current owner (usually gcr-prompter) keeps handling prompts
            // until it releases the name; our request stays queued.
            break;
        case QDBusConnectionInterface::ServiceNotRegistered:
            setLastError(QStringLiteral("Could not register the keyring prompter name %1").arg(service));
            break;
        default:
            break;
    }

    emit ownsNameChanged();
}

void KeyringPrompter::releaseNames() {
    auto* interface = QDBusConnection::sessionBus().interface();
    if (interface == nullptr)
        return;

    // Release unconditionally: unregisterService also gives up a queue
    // position, which ReleaseName on a name we do not own harmlessly ignores.
    interface->unregisterService(kSystemService);
    interface->unregisterService(kPrivateService);

    const bool wasOwner = m_ownsSystem || m_ownsPrivate;
    m_ownsSystem = false;
    m_ownsPrivate = false;

    if (wasOwner)
        emit ownsNameChanged();
}

void KeyringPrompter::tryTakeover() {
    if (!m_enabled || !m_started || !m_takeover)
        return;

    auto* interface = QDBusConnection::sessionBus().interface();
    if (interface == nullptr)
        return;

    const auto ownerReply = interface->serviceOwner(kSystemService);
    if (!ownerReply.isValid())
        return;

    const QString owner = ownerReply.value();
    if (owner.isEmpty() || owner == QDBusConnection::sessionBus().baseService())
        return;

    const auto pidReply = interface->servicePid(owner);
    if (!pidReply.isValid())
        return;

    const qint64 pid = pidReply.value();
    if (pid <= 0 || pid == QCoreApplication::applicationPid())
        return;

    QFile comm(QStringLiteral("/proc/%1/comm").arg(pid));
    if (!comm.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const QString commName = QString::fromUtf8(comm.readAll()).trimmed();
    if (commName != QStringLiteral("gcr-prompter"))
        return;

    qInfo() << "keyring prompter: taking over from gcr-prompter (pid" << pid << ")";
    ::kill(static_cast<pid_t>(pid), SIGTERM);

    QTimer::singleShot(250, this, [this] {
        if (m_enabled && m_started) {
            claimService(kSystemService);
            claimService(kPrivateService);
        }
    });
}

void KeyringPrompter::onServiceOwnerChanged(const QString& service, const QString& oldOwner, const QString& newOwner) {
    Q_UNUSED(oldOwner);

    if (service != kSystemService && service != kPrivateService)
        return;

    const bool isSystem = service == kSystemService;
    const bool isBaseOwner = newOwner == QDBusConnection::sessionBus().baseService();

    if (isSystem)
        m_ownsSystem = isBaseOwner;
    else
        m_ownsPrivate = isBaseOwner;

    if (isBaseOwner && (!m_started || !m_enabled)) {
        // We disabled the prompter while the name request was still queued.
        if (auto* interface = QDBusConnection::sessionBus().interface())
            interface->unregisterService(service);
        if (isSystem)
            m_ownsSystem = false;
        else
            m_ownsPrivate = false;
    } else if (newOwner.isEmpty() && m_started && m_enabled) {
        // If the previous owner released the name but our request was not
        // queued (for example it lost a replacement race), retry shortly.
        QTimer::singleShot(50, this, [this, service] {
            if (m_enabled && m_started)
                claimService(service);
        });
    }

    emit ownsNameChanged();
}

void KeyringPrompter::showNext() {
    if (m_active.has_value() || m_queue.isEmpty() || !m_enabled)
        return;

    m_active = m_queue.dequeue();
    emit promptChanged();
    emit pendingCountChanged();

    if (!m_ready)
        armUiFallbackTimer();
}

void KeyringPrompter::cancelAll() {
    while (!m_queue.isEmpty())
        cancelRequest(m_queue.dequeue());

    if (m_active.has_value()) {
        cancelRequest(*m_active);
        m_active.reset();
    }

    emit promptChanged();
    emit pendingCountChanged();
}

void KeyringPrompter::cancelRequestsForSession(const QString& key) {
    bool changed = false;
    QQueue<Request> remaining;
    while (!m_queue.isEmpty()) {
        const Request request = m_queue.dequeue();
        if (request.sessionKey == key)
            changed = true;
        else
            remaining.enqueue(request);
    }
    m_queue = remaining;

    if (m_active.has_value() && m_active->sessionKey == key) {
        m_active.reset();
        changed = true;
    }

    if (changed) {
        emit promptChanged();
        emit pendingCountChanged();
    }
}

void KeyringPrompter::armUiFallbackTimer() {
    if (!m_ready && m_active.has_value() && !m_uiFallbackTimer->isActive())
        m_uiFallbackTimer->start();
}

void KeyringPrompter::onUiFallbackTimeout() {
    if (m_ready || !m_active.has_value())
        return;

    qWarning() << "keyring prompter: prompt UI is not ready; releasing the service so gcr-prompter can handle new prompts";
    setLastError(QStringLiteral("Shell keyring prompt UI is not available"));
    cancelAll();
    releaseNames();
    m_sessions.clear();
    m_started = false;
}

void KeyringPrompter::sendPromptReady(const Session& session, const QString& reply, const QVariantMap& properties, const std::string& exchange) {
    if (session.sender.isEmpty() || session.callback.isEmpty())
        return;

    QDBusMessage message = QDBusMessage::createMethodCall(session.sender, session.callback, kCallbackInterface, QStringLiteral("PromptReady"));
    message << reply << properties << QString::fromUtf8(exchange.data(), static_cast<qsizetype>(exchange.size()));
    QDBusConnection::sessionBus().send(message);
}

void KeyringPrompter::sendPromptDone(const Session& session) {
    if (session.sender.isEmpty() || session.callback.isEmpty())
        return;

    const QDBusMessage message = QDBusMessage::createMethodCall(session.sender, session.callback, kCallbackInterface, QStringLiteral("PromptDone"));
    QDBusConnection::sessionBus().send(message);
}

void KeyringPrompter::cancelRequest(const Request& request) {
    auto* session = findSession(request.sessionKey);
    if (session == nullptr)
        return;

    std::string error;
    const auto exchange = session->exchange.send(std::nullopt, &error);
    if (!exchange.has_value()) {
        setLastError(QString::fromStdString(error));
        return;
    }

    sendPromptReady(*session, QStringLiteral("no"), QVariantMap {}, *exchange);
}

QVariantMap KeyringPrompter::normalizeProperties(quint64 id, const QString& type, const QVariantMap& properties) const {
    QVariantMap out;
    out.insert(QStringLiteral("id"), QVariant::fromValue<qulonglong>(id));
    out.insert(QStringLiteral("type"), type);
    out.insert(QStringLiteral("title"), propertyString(properties, "title"));
    out.insert(QStringLiteral("message"), propertyString(properties, "message"));
    out.insert(QStringLiteral("description"), propertyString(properties, "description"));
    out.insert(QStringLiteral("warning"), propertyString(properties, "warning"));
    out.insert(QStringLiteral("choiceLabel"), propertyString(properties, "choice-label"));
    out.insert(QStringLiteral("choiceChosen"), propertyBool(properties, "choice-chosen"));
    out.insert(QStringLiteral("passwordNew"), propertyBool(properties, "password-new"));
    out.insert(QStringLiteral("continueLabel"), propertyString(properties, "continue-label"));
    out.insert(QStringLiteral("cancelLabel"), propertyString(properties, "cancel-label"));
    return out;
}

QString KeyringPrompter::sessionKey(const QString& sender, const QDBusObjectPath& callback) const {
    return sender + QLatin1Char(':') + callback.path();
}

KeyringPrompter::Session* KeyringPrompter::findSession(const QString& key) {
    const auto it = m_sessions.find(key);
    return it == m_sessions.end() ? nullptr : it.value().get();
}

void KeyringPrompter::setLastError(const QString& error) {
    if (m_lastError == error)
        return;
    m_lastError = error;
    emit lastErrorChanged();
}

void KeyringPrompter::BeginPrompting(const QDBusObjectPath& callback) {
    const QString sender = calledFromDBus() ? message().service() : QString();
    if (sender.isEmpty()) {
        if (calledFromDBus())
            sendErrorReply(kFailedError, QStringLiteral("A keyring prompt must come from D-Bus"));
        return;
    }

    const QString key = sessionKey(sender, callback);

    if (m_sessions.contains(key)) {
        cancelRequestsForSession(key);
        m_sessions.remove(key);
    }

    auto session = std::make_shared<Session>();
    session->sender = sender;
    session->callback = callback.path();

    const auto beginExchange = session->exchange.begin();
    if (!beginExchange.has_value()) {
        sendErrorReply(kFailedError, QStringLiteral("Could not start the keyring secret exchange"));
        return;
    }
    session->beginExchange = QByteArray::fromStdString(*beginExchange);

    m_sessions.insert(key, session);

    // BeginPrompting returns immediately; the callback is seeded once we have
    // replied, exactly like gcr-prompter does. Holding the session keeps a
    // superseded one from seeding the callback after it was replaced.
    QTimer::singleShot(50, this, [this, key, session] {
        if (findSession(key) != session.get())
            return;
        sendPromptReady(*session, QString {}, QVariantMap {}, session->beginExchange.toStdString());
    });
}

void KeyringPrompter::PerformPrompt(const QDBusObjectPath& callback, const QString& type, const QVariantMap& properties, const QString& exchange) {
    const QString sender = calledFromDBus() ? message().service() : QString();
    if (sender.isEmpty()) {
        if (calledFromDBus())
            sendErrorReply(kFailedError, QStringLiteral("A keyring prompt must come from D-Bus"));
        return;
    }

    const QString key = sessionKey(sender, callback);
    auto* session = findSession(key);
    if (session == nullptr) {
        if (calledFromDBus())
            sendErrorReply(kFailedError, QStringLiteral("No keyring prompt is in progress for this caller"));
        return;
    }

    std::string peerSecret;
    std::string error;
    if (!session->exchange.receive(exchange.toStdString(), &peerSecret, &error)) {
        if (calledFromDBus())
            sendErrorReply(kFailedError, QString::fromStdString(error));
        return;
    }

    for (auto it = properties.constBegin(); it != properties.constEnd(); ++it)
        session->properties.insert(it.key(), it.value());

    Request request;
    request.id = m_nextId++;
    request.sessionKey = key;
    request.type = type;
    request.properties = normalizeProperties(request.id, type, session->properties);

    m_queue.enqueue(request);
    emit pendingCountChanged();
    showNext();
}

void KeyringPrompter::StopPrompting(const QDBusObjectPath& callback) {
    const QString sender = calledFromDBus() ? message().service() : QString();
    if (sender.isEmpty())
        return;

    const QString key = sessionKey(sender, callback);
    auto it = m_sessions.find(key);
    if (it != m_sessions.end()) {
        const auto session = it.value();
        cancelRequestsForSession(key);
        m_sessions.erase(it);
        sendPromptDone(*session);
    } else {
        Session session;
        session.sender = sender;
        session.callback = callback.path();
        sendPromptDone(session);
    }

    showNext();
}

void KeyringPrompter::respond(quint64 id, const QString& secret, bool choice) {
    if (!m_active.has_value() || m_active->id != id)
        return;

    const Request request = *m_active;
    m_active.reset();
    emit promptChanged();
    emit pendingCountChanged();

    auto* session = findSession(request.sessionKey);
    if (session == nullptr) {
        showNext();
        return;
    }

    QVariantMap properties;
    if (!propertyString(session->properties, "choice-label").isEmpty())
        properties.insert(QStringLiteral("choice-chosen"), choice);

    QByteArray secretBytes = secret.toUtf8();
    std::optional<std::string> payload(std::string(secretBytes.constData(), static_cast<std::size_t>(secretBytes.size())));
    OPENSSL_cleanse(secretBytes.data(), static_cast<std::size_t>(secretBytes.size()));

    std::string error;
    const auto exchange = session->exchange.send(payload, &error);
    if (payload.has_value())
        OPENSSL_cleanse(payload->data(), payload->size());

    if (!exchange.has_value()) {
        setLastError(QString::fromStdString(error));
        const auto cancelExchange = session->exchange.send(std::nullopt);
        if (cancelExchange.has_value())
            sendPromptReady(*session, QStringLiteral("no"), QVariantMap {}, *cancelExchange);
        showNext();
        return;
    }

    sendPromptReady(*session, QStringLiteral("yes"), properties, *exchange);
    showNext();
}

void KeyringPrompter::cancel(quint64 id) {
    if (!m_active.has_value() || m_active->id != id)
        return;

    const Request request = *m_active;
    m_active.reset();
    emit promptChanged();
    emit pendingCountChanged();

    auto* session = findSession(request.sessionKey);
    if (session != nullptr) {
        std::string error;
        const auto exchange = session->exchange.send(std::nullopt, &error);
        if (exchange.has_value())
            sendPromptReady(*session, QStringLiteral("no"), QVariantMap {}, *exchange);
        else
            setLastError(QString::fromStdString(error));
    }

    showNext();
}

} // namespace caelestia::services