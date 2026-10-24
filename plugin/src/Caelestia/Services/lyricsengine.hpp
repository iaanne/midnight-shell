#pragma once

#include <qbytearray.h>
#include <qhash.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkreply.h>
#include <qobject.h>
#include <qpointer.h>
#include <qstringlist.h>
#include <qprocess.h>
#include <qset.h>
#include <qtimer.h>
#include <qurl.h>
#include <qvector.h>

#include <functional>

#include "lyricstypes.hpp"

namespace caelestia::services {

struct LyricsQuery {
    QString artist;
    QString title;
    QString album;
    QString fileUrl;
    QString lyricsDir;
    qreal duration = 0.0;
    bool refresh = false;
};

struct LyricsProviderInfo {
    QString id;
    QString name;
    QString url;
    QString command;
    QStringList commandArgs;
    QString workDir;
    bool wordSync = false;
    bool plugin = false;
};

// Concurrent provider lookup. Providers are started together and selected by sync
// quality first and configured priority second, matching the DMS engine. A result
// that has no timing is only used when every better tier has failed.
class LyricsEngine : public QObject {
    Q_OBJECT

public:
    explicit LyricsEngine(QNetworkAccessManager* nam, QObject* parent = nullptr);
    ~LyricsEngine() override;

    using Callback = std::function<void(const LyricsResult&)>;

    void lookup(const LyricsQuery& query, const QStringList& providers, Callback callback);
    void cancel();

    [[nodiscard]] static QVector<LyricsProviderInfo> availableProviders();
    [[nodiscard]] static QString providerName(const QString& id);
    [[nodiscard]] static QStringList defaultProviders();

private:
    struct State {
        LyricsProviderInfo info;
        bool finished = false;
        LyricsResult result;
    };

    void start(int generation);
    void checkFinished(int generation);
    void finish(int generation);
    void complete(int generation, int slot, LyricsResult result);
    void miss(int generation, int slot);
    void fetchProvider(int generation, int slot);
    void fetchBetterLyrics(int generation, int slot);
    void fetchUnison(int generation, int slot, bool withDuration = true);
    void fetchLyricsPlus(int generation, int slot);
    void fetchKugou(int generation, int slot);
    void fetchKugouDownload(int generation, int slot, const QStringList& candidates, int index, bool krc);
    void fetchLrclib(int generation, int slot);
    void fetchLrclibSearch(int generation, int slot, const QJsonObject& exact);
    void fetchNetEaseSearch(int generation, int slot);
    void fetchNetEaseLyric(int generation, int slot, const QStringList& ids, int index);
    void fetchQQSearch(int generation, int slot);
    void fetchQQLyric(int generation, int slot, const QStringList& ids, int index);
    void fetchYouTubeSearch(int generation, int slot);
    void fetchYouTubeNext(int generation, int slot, const QString& videoId);
    void fetchYouTubeBrowse(int generation, int slot, const QString& browseId);
    void fetchPlugin(int generation, int slot, const LyricsProviderInfo& info);

    void getJson(int generation, const QUrl& url, const QHash<QByteArray, QByteArray>& headers,
        std::function<void(const QJsonDocument&, const QString&)> callback);
    void postJson(int generation, const QUrl& url, const QHash<QByteArray, QByteArray>& headers,
        const QByteArray& body, std::function<void(const QJsonDocument&, const QString&)> callback);
    void request(int generation, const QByteArray& verb, const QUrl& url,
        const QHash<QByteArray, QByteArray>& headers, const QByteArray& body,
        std::function<void(const QJsonDocument&, const QString&)> callback);

    [[nodiscard]] bool allow(const QString& provider);
    [[nodiscard]] bool readCache(const QString& provider, LyricsResult* result) const;
    void writeCache(const QString& provider, const LyricsResult& result) const;
    [[nodiscard]] QString cachePath(const QString& provider) const;
    [[nodiscard]] QString trackKey() const;

    [[nodiscard]] LyricsResult lookupLocal() const;
    [[nodiscard]] LyricsResult parseLocalFile(const QString& path) const;
    [[nodiscard]] QString findLocalRecursive(const QString& dir) const;

    [[nodiscard]] bool matchesTrack(const QString& title, const QStringList& artists) const;
    [[nodiscard]] int scoreSong(const QJsonObject& song) const;

    struct RateBucket {
        qint64 window = 0;
        int count = 0;
    };

    QPointer<QNetworkAccessManager> m_nam;
    QTimer* m_deadline;
    QTimer* m_grace;
    QSet<QNetworkReply*> m_replies;
    QSet<QProcess*> m_processes;
    QHash<QProcess*, QByteArray> m_processOutput;
    QHash<QString, RateBucket> m_rate;
    QVector<State> m_states;
    LyricsQuery m_query;
    Callback m_callback;
    int m_generation = 0;
    int m_remaining = 0;
    bool m_finished = true;
    bool m_graceStarted = false;
};

} // namespace caelestia::services
