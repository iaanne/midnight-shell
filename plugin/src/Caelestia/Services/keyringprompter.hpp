#pragma once

#include <QByteArray>
#include <QDBusContext>
#include <QDBusObjectPath>
#include <QHash>
#include <QObject>
#include <QQueue>
#include <QVariantMap>
#include <qqmlintegration.h>

#include <memory>
#include <optional>
#include <string>

#include "secretexchange.hpp"

class QTimer;

namespace caelestia::services {

// Owns the GNOME keyring (GCR) prompter D-Bus service and renders its prompts
// through the shell instead of gcr-prompter's GTK dialog.
//
// The service is opt-in from QML via `enabled`; when the shell cannot own the
// name (another prompter such as gnome-shell has it and does not allow
// replacement) a queued D-Bus registration leaves the request with that
// prompter, so the fallback path stays intact.
class KeyringPrompter : public QObject, protected QDBusContext {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.gnome.keyring.internal.Prompter")

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool takeover READ takeover WRITE setTakeover NOTIFY takeoverChanged)
    // Set by the shell once the prompt window exists and can render.
    Q_PROPERTY(bool ready READ ready WRITE setReady NOTIFY readyChanged)
    Q_PROPERTY(bool ownsName READ ownsName NOTIFY ownsNameChanged)
    Q_PROPERTY(bool hasPrompt READ hasPrompt NOTIFY promptChanged)
    Q_PROPERTY(QVariantMap prompt READ prompt NOTIFY promptChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingCountChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit KeyringPrompter(QObject* parent = nullptr);
    ~KeyringPrompter() override;

    [[nodiscard]] bool enabled() const;
    void setEnabled(bool enabled);

    [[nodiscard]] bool takeover() const;
    void setTakeover(bool takeover);

    [[nodiscard]] bool ready() const;
    void setReady(bool ready);

    [[nodiscard]] bool ownsName() const;
    [[nodiscard]] bool hasPrompt() const;
    [[nodiscard]] QVariantMap prompt() const;
    [[nodiscard]] int pendingCount() const;
    [[nodiscard]] QString lastError() const;

    // Called by the prompt UI with the answer for the currently shown prompt.
    Q_INVOKABLE void respond(quint64 id, const QString& secret, bool choice);
    Q_INVOKABLE void cancel(quint64 id);

public slots:
    void BeginPrompting(const QDBusObjectPath& callback);
    void PerformPrompt(const QDBusObjectPath& callback, const QString& type, const QVariantMap& properties, const QString& exchange);
    void StopPrompting(const QDBusObjectPath& callback);

signals:
    void enabledChanged();
    void takeoverChanged();
    void readyChanged();
    void ownsNameChanged();
    void promptChanged();
    void pendingCountChanged();
    void lastErrorChanged();

private:
    struct Session {
        QString sender;
        QString callback;
        QByteArray beginExchange;
        SecretExchange exchange;
        QVariantMap properties;
    };

    struct Request {
        quint64 id = 0;
        QString sessionKey;
        QString type;
        QVariantMap properties;
    };

    void start();
    void stop();
    void claimService(const QString& service);
    void releaseNames();
    void tryTakeover();
    void onServiceOwnerChanged(const QString& service, const QString& oldOwner, const QString& newOwner);

    void showNext();
    void cancelAll();
    void cancelRequestsForSession(const QString& key);
    void armUiFallbackTimer();
    void onUiFallbackTimeout();

    void sendPromptReady(const Session& session, const QString& reply, const QVariantMap& properties, const std::string& exchange);
    void sendPromptDone(const Session& session);
    void cancelRequest(const Request& request);
    [[nodiscard]] QVariantMap normalizeProperties(quint64 id, const QString& type, const QVariantMap& properties) const;
    [[nodiscard]] QString sessionKey(const QString& sender, const QDBusObjectPath& callback) const;
    [[nodiscard]] Session* findSession(const QString& key);
    void setLastError(const QString& error);

    bool m_enabled = false;
    bool m_takeover = false;
    bool m_ready = false;
    bool m_started = false;
    bool m_objectRegistered = false;
    bool m_ownsSystem = false;
    bool m_ownsPrivate = false;
    QString m_lastError;
    QHash<QString, std::shared_ptr<Session>> m_sessions;
    QQueue<Request> m_queue;
    std::optional<Request> m_active;
    quint64 m_nextId = 1;
    QTimer* m_uiFallbackTimer = nullptr;
};

} // namespace caelestia::services