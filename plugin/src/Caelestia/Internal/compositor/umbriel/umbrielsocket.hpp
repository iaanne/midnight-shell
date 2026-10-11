#pragma once

#include <qbytearray.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <qobject.h>
#include <qtimer.h>

#include <deque>
#include <functional>

namespace caelestia {

/// Persistent subscription connection to Umbriel's IPC socket.
/// Connects, sends the subscribe request, then emits newline-delimited
/// {"event":…,"data":…} messages continuously. Umbriel pushes the current
/// state of each subscribed family first, so no separate initial fetch is
/// needed for window/workspace/output state.
class UmbrielEventSocket : public QObject {
    Q_OBJECT

public:
    explicit UmbrielEventSocket(QObject* parent = nullptr);

    void connectToUmbriel();
    void disconnectFromUmbriel();
    [[nodiscard]] bool isConnected() const;

signals:
    void connected();
    void disconnected();
    void eventReceived(const QJsonObject& event);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onError(QLocalSocket::LocalSocketError error);

private:
    void processLine(const QByteArray& line);
    void scheduleReconnect();

    QLocalSocket* m_socket = nullptr;
    QTimer m_reconnectTimer;
    QByteArray m_readBuffer;
    int m_reconnectDelay = 1000;
};

/// One-shot request/action connection to Umbriel's IPC socket.
/// Each request opens a fresh connection, sends one JSON line, reads one
/// reply line, then closes — matching Umbriel's request model and avoiding
/// conflicts with the subscription socket.
class UmbrielRequestSocket : public QObject {
    Q_OBJECT

public:
    using Callback = std::function<void(bool ok, const QJsonObject& response)>;

    explicit UmbrielRequestSocket(QObject* parent = nullptr);

    /// Send a request and receive the parsed reply via callback. On success
    /// the payload under "ok" is passed as {"result": …}; on error the raw
    /// reply object is passed and ok is false.
    void request(const QByteArray& payload, Callback callback);

    /// Send an action (fire-and-forget, reply discarded).
    void action(const QByteArray& payload);

private:
    struct PendingRequest {
        QByteArray payload;
        Callback callback; // nullptr for fire-and-forget
    };

    void processQueue();
    void startRequest(const PendingRequest& req);

    std::deque<PendingRequest> m_queue;
    bool m_busy = false;
};

} // namespace caelestia
