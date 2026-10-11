#include "umbrielsocket.hpp"

#include <qdebug.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <QProcessEnvironment>

#include <memory>

namespace caelestia {

namespace {

    QByteArray subscribePayload() {
        // Umbriel pushes the current state of each family on subscribe, then
        // full snapshots on change. Payloads are full snapshots, not deltas.
        return QByteArrayLiteral(
            R"({"cmd":"subscribe","events":["windows","workspaces","outputs","keyboard_layout","overview"]})");
    }

    QString umbrielSocketPath() {
        const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        const QString explicitPath = env.value(QStringLiteral("UMBRIEL_SOCKET"));
        if (!explicitPath.isEmpty()) {
            return explicitPath;
        }
        const QString runtimeDir = env.value(QStringLiteral("XDG_RUNTIME_DIR"));
        const QString waylandDisplay = env.value(QStringLiteral("WAYLAND_DISPLAY"));
        if (!runtimeDir.isEmpty() && !waylandDisplay.isEmpty()) {
            return runtimeDir + QStringLiteral("/umbriel-") + waylandDisplay + QStringLiteral(".sock");
        }
        return {};
    }

} // namespace

// ── UmbrielEventSocket ───────────────────────────────────────────────

UmbrielEventSocket::UmbrielEventSocket(QObject* parent)
    : QObject(parent)
    , m_socket(new QLocalSocket(this)) {

    m_reconnectTimer.setSingleShot(true);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &UmbrielEventSocket::connectToUmbriel);

    connect(m_socket, &QLocalSocket::connected, this, &UmbrielEventSocket::onConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &UmbrielEventSocket::onDisconnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &UmbrielEventSocket::onReadyRead);
    connect(m_socket, &QLocalSocket::errorOccurred, this, &UmbrielEventSocket::onError);
}

void UmbrielEventSocket::connectToUmbriel() {
    const QString path = umbrielSocketPath();
    if (path.isEmpty()) {
        qWarning() << "UmbrielEventSocket: UMBRIEL_SOCKET not set and no fallback socket found";
        return;
    }

    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }

    m_readBuffer.clear();
    m_reconnectDelay = 1000;
    m_socket->connectToServer(path);
}

void UmbrielEventSocket::disconnectFromUmbriel() {
    m_reconnectTimer.stop();
    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }
}

bool UmbrielEventSocket::isConnected() const {
    return m_socket->state() == QLocalSocket::ConnectedState;
}

void UmbrielEventSocket::onConnected() {
    qDebug() << "UmbrielEventSocket: Connected, subscribing to event stream";
    m_socket->write(subscribePayload() + "\n");
    m_socket->flush();
    emit connected();
}

void UmbrielEventSocket::onDisconnected() {
    qDebug() << "UmbrielEventSocket: Disconnected";
    emit disconnected();
    scheduleReconnect();
}

void UmbrielEventSocket::onReadyRead() {
    m_readBuffer.append(m_socket->readAll());

    int pos;
    while ((pos = static_cast<int>(m_readBuffer.indexOf('\n'))) != -1) {
        const QByteArray line = m_readBuffer.left(pos).trimmed();
        m_readBuffer.remove(0, pos + 1);
        if (!line.isEmpty()) {
            processLine(line);
        }
    }
}

void UmbrielEventSocket::processLine(const QByteArray& line) {
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(line, &err);
    if (err.error != QJsonParseError::NoError) {
        qWarning() << "UmbrielEventSocket: JSON parse error:" << err.errorString();
        return;
    }

    const QJsonObject obj = doc.object();
    if (obj.isEmpty()) {
        return;
    }

    // Umbriel replies {"ok":…} to subscribe; that ack has no "event" field
    // and is ignored. An "err" means the server is dropping us — reconnect.
    if (obj.contains(QStringLiteral("err"))) {
        qWarning() << "UmbrielEventSocket: server returned error, reconnecting:" << obj.value(QStringLiteral("err"));
        disconnectFromUmbriel();
        scheduleReconnect();
        return;
    }

    const QJsonValue event = obj.value(QStringLiteral("event"));
    if (!event.isString()) {
        return; // subscribe ack or unrelated message
    }
    emit eventReceived(obj);
}

void UmbrielEventSocket::onError(QLocalSocket::LocalSocketError error) {
    if (error == QLocalSocket::PeerClosedError) return;
    qWarning() << "UmbrielEventSocket: Error:" << m_socket->errorString();
    scheduleReconnect();
}

void UmbrielEventSocket::scheduleReconnect() {
    if (!m_reconnectTimer.isActive()) {
        qDebug() << "UmbrielEventSocket: Reconnecting in" << m_reconnectDelay << "ms";
        m_reconnectTimer.start(m_reconnectDelay);
        m_reconnectDelay = qMin(m_reconnectDelay * 2, 30000);
    }
}

// ── UmbrielRequestSocket ─────────────────────────────────────────────

UmbrielRequestSocket::UmbrielRequestSocket(QObject* parent)
    : QObject(parent) {}

void UmbrielRequestSocket::request(const QByteArray& payload, Callback callback) {
    m_queue.push_back({payload, std::move(callback)});
    if (!m_busy) {
        processQueue();
    }
}

void UmbrielRequestSocket::action(const QByteArray& payload) {
    m_queue.push_back({payload, nullptr});
    if (!m_busy) {
        processQueue();
    }
}

void UmbrielRequestSocket::processQueue() {
    if (m_queue.empty()) {
        m_busy = false;
        return;
    }

    m_busy = true;
    auto req = std::move(m_queue.front());
    m_queue.pop_front();
    startRequest(req);
}

void UmbrielRequestSocket::startRequest(const PendingRequest& req) {
    const QString path = umbrielSocketPath();
    if (path.isEmpty()) {
        qWarning() << "UmbrielRequestSocket: UMBRIEL_SOCKET not set and no fallback socket found";
        if (req.callback) req.callback(false, QJsonObject());
        processQueue();
        return;
    }

    auto* sock = new QLocalSocket(this);
    auto payload = req.payload;
    auto callback = req.callback;

    connect(sock, &QLocalSocket::connected, this, [sock, payload]() {
        sock->write(payload + "\n");
        sock->flush();
    });

    auto buffer = std::make_shared<QByteArray>();

    connect(sock, &QLocalSocket::readyRead, this, [sock, buffer]() {
        buffer->append(sock->readAll());
        if (buffer->contains('\n')) {
            sock->disconnectFromServer();
        }
    });

    connect(sock, &QLocalSocket::disconnected, this, [this, sock, buffer, callback]() {
        if (callback) {
            const QByteArray line = buffer->trimmed();
            QJsonParseError err;
            const QJsonDocument doc = QJsonDocument::fromJson(line, &err);
            if (err.error != QJsonParseError::NoError) {
                qWarning() << "UmbrielRequestSocket: JSON parse error:" << err.errorString();
                callback(false, QJsonObject());
            } else {
                const QJsonObject obj = doc.object();
                if (obj.contains(QStringLiteral("err"))) {
                    qWarning() << "UmbrielRequestSocket: IPC explicitly returned error:" << obj.value(QStringLiteral("err"));
                    callback(false, obj);
                } else if (obj.contains(QStringLiteral("ok"))) {
                    callback(true, QJsonObject{{QStringLiteral("result"), obj.value(QStringLiteral("ok"))}});
                } else {
                    qWarning() << "UmbrielRequestSocket: Unrecognized IPC response schema (missing 'ok' or 'err'):" << doc.toJson(QJsonDocument::Compact);
                    callback(false, obj);
                }
            }
        }
        sock->deleteLater();
        processQueue();
    });

    connect(sock, &QLocalSocket::errorOccurred, this, [this, sock, buffer, callback](QLocalSocket::LocalSocketError) {
        qWarning() << "UmbrielRequestSocket: Error:" << sock->errorString();
        if (callback) callback(false, QJsonObject());
        sock->deleteLater();
        processQueue();
    });

    sock->connectToServer(path);
}

} // namespace caelestia
