#include "lyricsengine.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <utility>

#include <qcryptographichash.h>
#include <qdatetime.h>
#include <qdir.h>
#include <qdiriterator.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qjsonvalue.h>
#include <qloggingcategory.h>
#include <qregularexpression.h>
#include <qstandardpaths.h>
#include <qurlquery.h>

#include "qqlyric.hpp"
#include "lyricsparsers.hpp"

namespace caelestia::services {

using Qt::StringLiterals::operator""_s;
using Qt::StringLiterals::operator""_ba;

namespace {

Q_LOGGING_CATEGORY(lcLyricsEngine, "caelestia.lyrics.engine", QtInfoMsg)

constexpr int k_deadlineMs = 12000;
constexpr int k_graceMs = 2000;
constexpr int k_transferTimeoutMs = 9000;
constexpr int k_maxJsonBytes = 1 << 20;
constexpr int k_maxLocalFiles = 5000;
constexpr int k_cacheVersion = 1;
constexpr qint64 k_cacheFoundTtl = 90 * 24 * 3600;
constexpr qint64 k_cacheMissTtl = 14 * 24 * 3600;

const QStringList& localExtensions() {
    static const QStringList k_extensions = {
        u"lrc"_s, u"ttml"_s, u"lyrics"_s, u"lyricsfile"_s, u"yaml"_s, u"yml"_s
    };
    return k_extensions;
}

[[nodiscard]] QString normalized(const QString& text) {
    QString out = text.toLower().trimmed();
    static const QRegularExpression k_bracketed(u"[\\[(（【][^\\])）】]*[\\])）】]"_s);
    out.remove(k_bracketed);
    QString clean;
    clean.reserve(out.size());
    bool space = false;
    for (const QChar c : out) {
        if (c.isLetterOrNumber()) {
            clean.append(c);
            space = false;
        } else if (!space && !clean.isEmpty()) {
            clean.append(u' ');
            space = true;
        }
    }
    return clean.trimmed();
}

[[nodiscard]] bool containsWords(const QString& haystack, const QString& needle) {
    if (needle.isEmpty() || haystack.isEmpty())
        return false;
    return (u" "_s + haystack + u" "_s).contains(u" "_s + needle + u" "_s);
}

[[nodiscard]] bool containsCi(const QString& haystack, const QString& needle) {
    return !needle.isEmpty() && haystack.contains(needle, Qt::CaseInsensitive);
}

[[nodiscard]] QHash<QByteArray, QByteArray> jsonHeaders() {
    return {
        { "User-Agent"_ba, "MidnightShell/1 (+https://github.com/caelestia-dots)"_ba },
        { "Accept"_ba, "application/json"_ba },
    };
}

[[nodiscard]] QHash<QByteArray, QByteArray> netEaseHeaders() {
    auto headers = jsonHeaders();
    headers.insert("Referer"_ba, "https://music.163.com/"_ba);
    headers.insert("User-Agent"_ba,
        "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"_ba);
    return headers;
}

[[nodiscard]] QHash<QByteArray, QByteArray> qqHeaders() {
    auto headers = jsonHeaders();
    headers.insert("Referer"_ba, "https://y.qq.com/"_ba);
    headers.insert("Content-Type"_ba, "application/json"_ba);
    headers.insert("User-Agent"_ba,
        "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"_ba);
    return headers;
}

[[nodiscard]] QHash<QByteArray, QByteArray> youtubeHeaders() {
    auto headers = jsonHeaders();
    headers.insert("Content-Type"_ba, "application/json"_ba);
    headers.insert("Origin"_ba, "https://music.youtube.com"_ba);
    return headers;
}

// Public WEB_REMIX key used by the web player. The innertube endpoints reject
// keyless requests on most deployments.
[[nodiscard]] QUrl youtubeUrl(const QString& method) {
    QUrl url(u"https://music.youtube.com/youtubei/v1/"_s + method);
    QUrlQuery query;
    query.addQueryItem(u"prettyPrint"_s, u"false"_s);
    query.addQueryItem(u"key"_s, u"AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30"_s);
    url.setQuery(query);
    return url;
}

// Some APIs encode numeric ids as JSON numbers and others as strings.
[[nodiscard]] QString jsonScalarText(const QJsonValue& value) {
    if (value.isString())
        return value.toString();
    if (value.isDouble())
        return QString::number(value.toInteger());
    return {};
}

[[nodiscard]] QUrl queryUrl(const QString& base, const QList<QPair<QString, QString>>& items) {
    QUrl url(base);
    QUrlQuery query;
    for (const auto& item : items) {
        if (!item.second.trimmed().isEmpty())
            query.addQueryItem(item.first, item.second);
    }
    url.setQuery(query);
    return url;
}

[[nodiscard]] QString secondsText(qreal duration) {
    if (!std::isfinite(duration) || duration <= 0.0)
        return {};
    return QString::number(qRound(duration));
}

[[nodiscard]] QString textHtmlUnescape(QString text) {
    text.replace(u"\u00A0"_s, u" "_s);
    text.replace(u"&lt;"_s, u"<"_s);
    text.replace(u"&gt;"_s, u">"_s);
    text.replace(u"&quot;"_s, u"\""_s);
    text.replace(u"&apos;"_s, u"'"_s);
    text.replace(u"&#39;"_s, u"'"_s);
    text.replace(u"&amp;"_s, u"&"_s);
    return text;
}

[[nodiscard]] QVector<QJsonValue> jsonItems(const QJsonValue& value) {
    QVector<QJsonValue> items;
    if (value.isArray()) {
        for (const auto& item : value.toArray())
            items.append(item);
    } else if (!value.isUndefined() && !value.isNull()) {
        items.append(value);
    }
    return items;
}

[[nodiscard]] QVector<QJsonValue> dig(const QJsonDocument& document, const QString& path) {
    QVector<QJsonValue> values = { QJsonValue(document.object()) };
    for (const QString& key : path.split(u'.')) {
        QVector<QJsonValue> next;
        for (const auto& value : values) {
            for (const auto& item : jsonItems(value)) {
                if (!item.isObject())
                    continue;
                const QJsonObject object = item.toObject();
                const auto found = object.constFind(key);
                if (found != object.constEnd())
                    next.append(*found);
            }
        }
        values = std::move(next);
    }
    return values;
}

[[nodiscard]] QStringList digStrings(const QJsonDocument& document, const QString& path) {
    QStringList strings;
    for (const auto& value : dig(document, path)) {
        if (value.isString())
            strings.append(value.toString());
        else if (value.isObject())
            strings.append(value.toObject().value(u"text"_s).toString());
    }
    return strings;
}

[[nodiscard]] QString digString(const QJsonDocument& document, const QString& path) {
    const QStringList strings = digStrings(document, path);
    return strings.isEmpty() ? QString{} : strings.first();
}

[[nodiscard]] int clockSeconds(const QString& text) {
    const QStringList parts = text.trimmed().split(u':');
    if (parts.size() < 2 || parts.size() > 3)
        return 0;
    int total = 0;
    for (const QString& part : parts) {
        bool ok = false;
        const int number = part.toInt(&ok);
        if (!ok || number < 0)
            return 0;
        total = total * 60 + number;
    }
    return total;
}

[[nodiscard]] QString youtubeLanguage(const LyricsQuery& query) {
    for (const QChar c : query.artist + query.title) {
        const ushort u = c.unicode();
        if (u >= 0xAC00 && u <= 0xD7A3)
            return u"ko"_s;
        if ((u >= 0x3040 && u <= 0x30FF) || (u >= 0x4E00 && u <= 0x9FFF))
            return u"ja"_s;
    }
    return u"en"_s;
}

using BuiltinList = QVector<LyricsProviderInfo>;

const BuiltinList& builtins() {
    static const BuiltinList k_builtins = {
        { .id = u"betterlyrics"_s,
            .name = u"Better Lyrics"_s,
            .url = u"https://betterlyrics.org"_s,
            .wordSync = true },
        { .id = u"unison"_s,
            .name = u"Unison"_s,
            .url = u"https://unison.betterlyrics.org"_s,
            .wordSync = true },
        { .id = u"lyricsplus"_s,
            .name = u"LyricsPlus"_s,
            .url = u"https://github.com/ibratabian17/lyricsplus"_s,
            .wordSync = true },
        { .id = u"kugou"_s,
            .name = u"KuGou"_s,
            .url = u"https://www.kugou.com"_s,
            .wordSync = true },
        { .id = u"lrclib"_s,
            .name = u"LRCLIB"_s,
            .url = u"https://lrclib.net"_s,
            .wordSync = true },
        { .id = u"youtubemusic"_s,
            .name = u"YouTube Music"_s,
            .url = u"https://music.youtube.com"_s },
        { .id = u"netease"_s, .name = u"NetEase"_s, .url = u"https://music.163.com"_s },
        { .id = u"qqmusic"_s, .name = u"QQ Music"_s, .url = u"https://y.qq.com"_s, .wordSync = true },
    };
    return k_builtins;
}

[[nodiscard]] QString sanitizeId(QString id) {
    id = id.toLower();
    for (qsizetype i = 0; i < id.size(); ++i) {
        const QChar c = id.at(i);
        if (!c.isLetterOrNumber() && c != u'_')
            id[i] = u'_';
    }
    return id;
}

[[nodiscard]] QString manifestDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + u"/caelestia/plugins"_s;
}

} // namespace

LyricsEngine::LyricsEngine(QNetworkAccessManager* nam, QObject* parent)
    : QObject(parent)
    , m_nam(nam)
    , m_deadline(new QTimer(this))
    , m_grace(new QTimer(this)) {
    m_deadline->setSingleShot(true);
    m_grace->setSingleShot(true);
    QObject::connect(m_deadline, &QTimer::timeout, this, [this] { finish(m_generation); });
    QObject::connect(m_grace, &QTimer::timeout, this, [this] { finish(m_generation); });
    // Lyrics owns the manager and destroys it before this engine; drop dangling
    // reply pointers as the manager tears its replies down.
    QObject::connect(nam, &QObject::destroyed, this, [this] { m_replies.clear(); });
}

LyricsEngine::~LyricsEngine() {
    cancel();
}

QStringList LyricsEngine::defaultProviders() {
    QStringList ids;
    for (const auto& info : builtins())
        ids.append(info.id);
    return ids;
}

QString LyricsEngine::providerName(const QString& id) {
    for (const auto& info : builtins()) {
        if (info.id == id)
            return info.name;
    }
    for (const auto& info : availableProviders()) {
        if (info.id == id)
            return info.name;
    }
    return id;
}

QVector<LyricsProviderInfo> LyricsEngine::availableProviders() {
    QVector<LyricsProviderInfo> result = builtins();

    const QDir dir(manifestDir());
    if (!dir.exists())
        return result;

    const QFileInfoList entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const auto& entry : entries) {
        const QString path = entry.absoluteFilePath() + u"/plugin.json"_s;
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly) || file.size() > kMaxLyricsBytes)
            continue;
        const QJsonDocument manifest = QJsonDocument::fromJson(file.readAll());
        if (!manifest.isObject())
            continue;
        const QJsonObject object = manifest.object();
        const QJsonObject lyrics = object.value(u"lyrics"_s).toObject();
        QStringList commandArgs;
        const QJsonValue commandValue = lyrics.value(u"command"_s);
        if (commandValue.isArray()) {
            for (const auto& part : commandValue.toArray()) {
                const QString arg = part.toString();
                if (!arg.isEmpty())
                    commandArgs.append(arg);
            }
        } else {
            commandArgs = QProcess::splitCommand(commandValue.toString());
        }
        if (commandArgs.isEmpty())
            continue;
        const QString command = commandArgs.join(u' ');

        QString id = object.value(u"id"_s).toString();
        if (id.isEmpty())
            id = entry.fileName();
        id = u"plugin_"_s + sanitizeId(id);
        if (id == u"plugin_"_s)
            continue;

        bool duplicate = false;
        for (const auto& existing : result) {
            if (existing.id == id) {
                duplicate = true;
                break;
            }
        }
        if (duplicate)
            continue;

        QString name = lyrics.value(u"name"_s).toString();
        if (name.isEmpty())
            name = object.value(u"name"_s).toString();
        if (name.isEmpty())
            name = entry.fileName();

        result.append(LyricsProviderInfo{ .id = id,
            .name = name,
            .url = lyrics.value(u"url"_s).toString(),
            .command = command,
            .commandArgs = commandArgs,
            .workDir = entry.absoluteFilePath(),
            .wordSync = lyrics.value(u"wordSync"_s).toBool(false),
            .plugin = true });
    }
    return result;
}

QString LyricsEngine::trackKey() const {
    const QString raw = m_query.artist + u"\x1f"_s + m_query.title + u"\x1f"_s + m_query.album + u"\x1f"_s
        + secondsText(m_query.duration);
    return QString::fromLatin1(QCryptographicHash::hash(raw.toUtf8(), QCryptographicHash::Sha256).toHex());
}

QString LyricsEngine::cachePath(const QString& provider) const {
    QString safe = provider;
    safe.replace(u'/', u'_');
    const QString root = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
        + u"/caelestia/lyrics/v2/"_s + safe;
    const QString key = trackKey();
    return root + u'/' + key.left(2) + u'/' + key + u".json"_s;
}

bool LyricsEngine::readCache(const QString& provider, LyricsResult* result) const {
    if (m_query.refresh)
        return false;
    QFile file(cachePath(provider));
    if (!file.open(QIODevice::ReadOnly) || file.size() > k_maxJsonBytes)
        return false;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    if (!document.isObject())
        return false;
    const QJsonObject object = document.object();
    if (object.value(u"v"_s).toInt() != k_cacheVersion)
        return false;
    const qint64 fetched = object.value(u"fetched"_s).toInteger(0);
    const qint64 age = QDateTime::currentSecsSinceEpoch() - fetched;
    const bool found = object.value(u"found"_s).toBool(false);
    if (age < 0 || age > (found ? k_cacheFoundTtl : k_cacheMissTtl))
        return false;
    if (!found)
        return true;
    const LyricsResult cached = LyricsResult::fromJson(object.value(u"result"_s).toObject());
    if (cached.empty())
        return false;
    if (result) {
        *result = cached;
        result->cached = true;
        result->found = true;
    }
    return true;
}

void LyricsEngine::writeCache(const QString& provider, const LyricsResult& result) const {
    if (m_query.title.isEmpty())
        return;
    const QString path = cachePath(provider);
    QDir().mkpath(QFileInfo(path).absolutePath());
    QJsonObject object;
    object.insert(u"v"_s, k_cacheVersion);
    object.insert(u"fetched"_s, QDateTime::currentSecsSinceEpoch());
    object.insert(u"found"_s, result.found);
    if (result.found) {
        LyricsResult copy = result;
        copy.cached = false;
        object.insert(u"result"_s, copy.toJson());
    }
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
}

bool LyricsEngine::allow(const QString& provider) {
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    RateBucket& bucket = m_rate[provider];
    if (now - bucket.window >= 1000) {
        bucket.window = now;
        bucket.count = 0;
    }
    if (bucket.count >= 10)
        return false;
    ++bucket.count;
    return true;
}

void LyricsEngine::lookup(const LyricsQuery& query, const QStringList& providers, Callback callback) {
    cancel();
    m_query = query;
    m_callback = std::move(callback);
    m_finished = false;
    m_graceStarted = false;
    const int generation = m_generation;

    LyricsResult local = lookupLocal();
    if (local.found) {
        QTimer::singleShot(0, this, [this, generation, local = std::move(local)] {
            if (generation != m_generation || m_finished || !m_callback)
                return;
            m_finished = true;
            auto callback = std::move(m_callback);
            m_callback = nullptr;
            callback(local);
        });
        return;
    }

    if (m_query.title.isEmpty()) {
        QTimer::singleShot(0, this, [this, generation] { finish(generation); });
        return;
    }

    const QVector<LyricsProviderInfo> all = availableProviders();
    QStringList seen;
    for (const QString& id : providers) {
        if (id.isEmpty() || seen.contains(id))
            continue;
        seen.append(id);
        const LyricsProviderInfo* info = nullptr;
        for (const auto& candidate : all) {
            if (candidate.id == id) {
                info = &candidate;
                break;
            }
        }
        if (info == nullptr)
            continue;

        State state;
        state.info = *info;
        LyricsResult cached;
        if (readCache(info->id, &cached)) {
            state.finished = true;
            state.result = std::move(cached);
        }
        m_states.append(std::move(state));
    }

    start(generation);
}

void LyricsEngine::start(int generation) {
    if (generation != m_generation || m_finished)
        return;

    m_remaining = 0;
    for (const auto& state : m_states) {
        if (!state.finished)
            ++m_remaining;
    }

    if (m_states.isEmpty() || m_remaining == 0) {
        QTimer::singleShot(0, this, [this, generation] { finish(generation); });
        return;
    }

    m_deadline->start(k_deadlineMs);
    for (int i = 0; i < m_states.size(); ++i) {
        // A synchronous provider failure can finish the lookup while the loop is
        // still starting the remaining providers.
        if (m_finished)
            break;
        if (m_states.at(i).finished)
            continue;
        if (!allow(m_states.at(i).info.id)) {
            miss(generation, i);
            continue;
        }
        fetchProvider(generation, i);
    }

    // A cached result may already be the winner; avoid waiting on providers that
    // cannot improve it (or start the grace timer for one that can).
    checkFinished(generation);
}

void LyricsEngine::cancel() {
    ++m_generation;
    m_finished = true;
    m_callback = nullptr;
    m_deadline->stop();
    m_grace->stop();
    const auto replies = m_replies;
    m_replies.clear();
    for (auto* reply : replies) {
        if (reply) {
            reply->abort();
            reply->deleteLater();
        }
    }
    const auto processes = m_processes;
    m_processes.clear();
    m_processOutput.clear();
    for (auto* process : processes) {
        if (process) {
            process->kill();
            process->deleteLater();
        }
    }
    m_states.clear();
    m_remaining = 0;
}

void LyricsEngine::checkFinished(int generation) {
    if (generation != m_generation || m_finished)
        return;
    if (m_remaining <= 0) {
        finish(generation);
        return;
    }

    int best = -1;
    int bestTier = -1;
    for (int i = 0; i < m_states.size(); ++i) {
        const State& state = m_states.at(i);
        if (!state.finished || !state.result.found || state.result.empty())
            continue;
        const int tier = state.result.tier();
        if (tier > bestTier) {
            best = i;
            bestTier = tier;
        }
    }
    if (best < 0)
        return;

    // A higher-priority provider still out can win at the same tier. Wait for
    // it until the deadline, exactly like the DMS engine.
    for (int i = 0; i < best; ++i) {
        if (!m_states.at(i).finished && (bestTier < 2 || m_states.at(i).info.wordSync))
            return;
    }

    // A lower-priority provider still out can only improve on a non-word result.
    bool upgradePending = false;
    for (int i = best + 1; i < m_states.size(); ++i) {
        if (!m_states.at(i).finished
            && (bestTier == 0 || (bestTier == 1 && m_states.at(i).info.wordSync))) {
            upgradePending = true;
            break;
        }
    }
    if (!upgradePending) {
        finish(generation);
        return;
    }
    if (!m_graceStarted) {
        m_graceStarted = true;
        m_grace->start(k_graceMs);
    }
}

void LyricsEngine::complete(int generation, int slot, LyricsResult result) {
    if (generation != m_generation || m_finished || slot < 0 || slot >= m_states.size())
        return;
    State& state = m_states[slot];
    if (state.finished)
        return;

    result.found = !result.empty();

    if (!result.found) {
        miss(generation, slot);
        return;
    }

    result.plain = textHtmlUnescape(result.plain);
    result.title = textHtmlUnescape(result.title);
    result.artist = textHtmlUnescape(result.artist);
    result.album = textHtmlUnescape(result.album);
    for (auto& line : result.synced) {
        line.text = textHtmlUnescape(line.text);
        for (auto& word : line.words)
            word.text = textHtmlUnescape(word.text);
    }
    for (auto& line : result.romanized) {
        line.text = textHtmlUnescape(line.text);
        for (auto& word : line.words)
            word.text = textHtmlUnescape(word.text);
    }
    stripLyricMarkup(result);
    result.source = state.info.id;
    if (result.attributionName.isEmpty())
        result.attributionName = state.info.name;
    if (result.attributionUrl.isEmpty())
        result.attributionUrl = state.info.url;
    state.finished = true;
    state.result = std::move(result);
    --m_remaining;
    writeCache(state.info.id, state.result);
    checkFinished(generation);
}

void LyricsEngine::miss(int generation, int slot) {
    if (generation != m_generation || m_finished || slot < 0 || slot >= m_states.size())
        return;
    State& state = m_states[slot];
    if (state.finished)
        return;
    state.finished = true;
    state.result = {};
    --m_remaining;
    // Only successful results are cached. Caching a transient network error would
    // suppress the provider for the whole negative-cache lifetime.
    checkFinished(generation);
}

void LyricsEngine::finish(int generation) {
    if (generation != m_generation || m_finished || !m_callback)
        return;
    m_finished = true;
    m_deadline->stop();
    m_grace->stop();

    int best = -1;
    int bestTier = -1;
    for (int i = 0; i < m_states.size(); ++i) {
        const State& state = m_states.at(i);
        if (!state.finished || !state.result.found || state.result.empty())
            continue;
        const int tier = state.result.tier();
        if (tier > bestTier) {
            bestTier = tier;
            best = i;
        }
    }

    LyricsResult result;
    if (best >= 0)
        result = m_states.at(best).result;
    else
        result.found = false;

    auto callback = std::move(m_callback);
    m_callback = nullptr;
    const auto replies = m_replies;
    m_replies.clear();
    for (auto* reply : replies) {
        if (reply) {
            reply->abort();
            reply->deleteLater();
        }
    }
    const auto processes = m_processes;
    m_processes.clear();
    m_processOutput.clear();
    for (auto* process : processes) {
        if (process) {
            process->kill();
            process->deleteLater();
        }
    }
    callback(result);
}

void LyricsEngine::fetchProvider(int generation, int slot) {
    const LyricsProviderInfo info = m_states.at(slot).info;
    if (info.plugin) {
        fetchPlugin(generation, slot, info);
    } else if (info.id == u"betterlyrics"_s) {
        fetchBetterLyrics(generation, slot);
    } else if (info.id == u"unison"_s) {
        fetchUnison(generation, slot);
    } else if (info.id == u"lyricsplus"_s) {
        fetchLyricsPlus(generation, slot);
    } else if (info.id == u"kugou"_s) {
        fetchKugou(generation, slot);
    } else if (info.id == u"lrclib"_s) {
        fetchLrclib(generation, slot);
    } else if (info.id == u"youtubemusic"_s) {
        fetchYouTubeSearch(generation, slot);
    } else if (info.id == u"netease"_s) {
        fetchNetEaseSearch(generation, slot);
    } else if (info.id == u"qqmusic"_s) {
        fetchQQSearch(generation, slot);
    } else {
        miss(generation, slot);
    }
}

void LyricsEngine::getJson(int generation, const QUrl& url, const QHash<QByteArray, QByteArray>& headers,
    std::function<void(const QJsonDocument&, const QString&)> callback) {
    request(generation, "GET"_ba, url, headers, {}, std::move(callback));
}

void LyricsEngine::postJson(int generation, const QUrl& url, const QHash<QByteArray, QByteArray>& headers,
    const QByteArray& body, std::function<void(const QJsonDocument&, const QString&)> callback) {
    request(generation, "POST"_ba, url, headers, body, std::move(callback));
}

void LyricsEngine::request(int generation, const QByteArray& verb, const QUrl& url,
    const QHash<QByteArray, QByteArray>& headers, const QByteArray& body,
    std::function<void(const QJsonDocument&, const QString&)> callback) {
    if (generation != m_generation || m_finished)
        return;
    if (!m_nam) {
        callback({}, u"network unavailable"_s);
        return;
    }

    QNetworkRequest request(url);
    request.setTransferTimeout(k_transferTimeoutMs);
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setRawHeader("Cache-Control"_ba, "no-cache, no-store"_ba);
    request.setRawHeader("Connection"_ba, "close"_ba);
    request.setRawHeader("Accept"_ba, "application/json"_ba);
    for (auto it = headers.constBegin(); it != headers.constEnd(); ++it)
        request.setRawHeader(it.key(), it.value());

    QNetworkReply* reply = nullptr;
    if (verb == "POST"_ba)
        reply = m_nam->post(request, body);
    else
        reply = m_nam->get(request);
    if (!reply) {
        callback({}, u"request could not be started"_s);
        return;
    }
    m_replies.insert(reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, generation, callback = std::move(callback)] {
        m_replies.remove(reply);
        reply->deleteLater();
        if (generation != m_generation || m_finished)
            return;
        if (reply->error() != QNetworkReply::NoError) {
            callback({}, reply->errorString());
            return;
        }
        const QByteArray data = reply->readAll();
        if (data.size() > k_maxJsonBytes) {
            callback({}, u"response too large"_s);
            return;
        }
        QJsonParseError error{};
        const QJsonDocument document = QJsonDocument::fromJson(data, &error);
        if (error.error != QJsonParseError::NoError) {
            callback({}, error.errorString());
            return;
        }
        callback(document, {});
    });
}


// ---------------------------------------------------------------------------
// Local files
// ---------------------------------------------------------------------------

LyricsResult LyricsEngine::parseLocalFile(const QString& path) const {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly) || file.size() > kMaxLyricsSidecarBytes)
        return {};

    const QByteArray data = file.readAll();
    const QString suffix = QFileInfo(path).suffix().toLower();
    LyricsResult result;
    if (suffix == u"ttml"_s) {
        result = parseTtml(data);
    } else if (suffix == u"yaml"_s || suffix == u"yml"_s || suffix == u"lyrics"_s
        || suffix == u"lyricsfile"_s) {
        result = parseLyricsfile(data);
    } else {
        result = parseLrc(data);
        if (!result.found) {
            const LyricsResult sidecar = parseLyricsfile(data);
            if (sidecar.found)
                result = sidecar;
        }
    }

    if (!result.found)
        return {};
    result.source = u"local"_s;
    result.id = path;
    result.found = true;
    if (result.title.isEmpty())
        result.title = m_query.title;
    if (result.artist.isEmpty())
        result.artist = m_query.artist;
    return result;
}

QString LyricsEngine::findLocalRecursive(const QString& dir) const {
    QStringList names;
    const QString artist = m_query.artist.trimmed();
    const QString title = m_query.title.trimmed();
    if (!artist.isEmpty() && !title.isEmpty()) {
        names << (artist + u" - "_s + title).toLower();
        names << (title + u" - "_s + artist).toLower();
        names << (artist + u"_"_s + title).toLower();
        names << (title + u"_"_s + artist).toLower();
    }
    if (!title.isEmpty())
        names << title.toLower();
    if (names.isEmpty())
        return {};

    QString bestPath;
    int bestTier = -1;
    int seen = 0;
    QDirIterator it(dir, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        if (++seen > k_maxLocalFiles)
            break;
        const QFileInfo info(path);
        if (!localExtensions().contains(info.suffix().toLower()))
            continue;
        if (!names.contains(info.completeBaseName().toLower()))
            continue;
        const LyricsResult result = parseLocalFile(path);
        if (!result.found)
            continue;
        const int tier = result.tier();
        if (tier > bestTier) {
            bestTier = tier;
            bestPath = path;
            if (tier == 2)
                break;
        }
    }
    return bestPath;
}

LyricsResult LyricsEngine::lookupLocal() const {
    QString sidecarBase;
    if (!m_query.fileUrl.isEmpty()) {
        const QUrl url(m_query.fileUrl);
        sidecarBase = url.isLocalFile() ? url.toLocalFile() : m_query.fileUrl;
        if (!sidecarBase.startsWith(u'/'))
            sidecarBase.clear();
    }

    if (!sidecarBase.isEmpty()) {
        QString base = sidecarBase;
        const QString suffix = QFileInfo(base).suffix();
        if (!suffix.isEmpty())
            base.chop(suffix.size() + 1);
        LyricsResult best;
        for (const QString& extension : localExtensions()) {
            const QString path = base + u'.' + extension;
            if (!QFileInfo::exists(path))
                continue;
            LyricsResult result = parseLocalFile(path);
            if (result.found && (!best.found || result.tier() > best.tier()))
                best = std::move(result);
        }
        if (best.found)
            return best;
    }

    const QString dir = m_query.lyricsDir.trimmed();
    if (dir.isEmpty())
        return {};

    QStringList bases;
    const QString artist = m_query.artist.trimmed();
    const QString title = m_query.title.trimmed();
    if (!artist.isEmpty() && !title.isEmpty()) {
        bases << artist + u" - "_s + title;
        bases << title + u" - "_s + artist;
        bases << artist + u"_"_s + title;
        bases << artist + u"-"_s + title;
    }
    if (!title.isEmpty())
        bases << title;
    bases.removeDuplicates();

    const QDir localDir(dir);
    if (localDir.exists()) {
        const QStringList files = localDir.entryList(QDir::Files, QDir::Name);
        for (const QString& base : bases) {
            LyricsResult best;
            for (const QString& extension : localExtensions()) {
                const QString wanted = (base + u'.' + extension).toLower();
                for (const QString& file : files) {
                    if (file.toLower() != wanted)
                        continue;
                    LyricsResult result = parseLocalFile(localDir.absoluteFilePath(file));
                    if (result.found && (!best.found || result.tier() > best.tier()))
                        best = std::move(result);
                }
            }
            if (best.found)
                return best;
        }
    }

    const QString recursive = findLocalRecursive(dir);
    if (!recursive.isEmpty()) {
        LyricsResult result = parseLocalFile(recursive);
        if (result.found)
            return result;
    }
    return {};
}

// ---------------------------------------------------------------------------
// Track matching
// ---------------------------------------------------------------------------

bool LyricsEngine::matchesTrack(const QString& title, const QStringList& artists) const {
    const QString wantedTitle = normalized(m_query.title);
    const QString candidateTitle = normalized(title);
    if (wantedTitle.isEmpty() || candidateTitle.isEmpty())
        return false;
    if (!containsWords(wantedTitle, candidateTitle) && !containsWords(candidateTitle, wantedTitle))
        return false;

    // A stream or radio title may have no artist metadata at all. The title hit
    // is all the confidence we can get in that case.
    if (m_query.artist.trimmed().isEmpty())
        return true;

    const QString known = normalized(m_query.artist + u' ' + m_query.title);
    const QString wantedArtist = normalized(m_query.artist);
    for (const QString& artist : artists) {
        const QString candidate = normalized(artist);
        if (candidate.isEmpty())
            continue;
        // The provider may append featured artists or a title to the artist
        // field, so accept a word-level match in either direction.
        if (containsWords(known, candidate) || containsWords(candidate, wantedArtist)
            || containsWords(wantedArtist, candidate))
            return true;
    }
    return false;
}

int LyricsEngine::scoreSong(const QJsonObject& song) const {
    int score = 0;
    bool hit = false;

    const QString songTitle = song.value(u"name"_s).toString().trimmed();
    if (!m_query.title.isEmpty() && !songTitle.isEmpty()) {
        if (containsCi(songTitle, m_query.title) || containsCi(m_query.title, songTitle)) {
            hit = true;
            score += songTitle.compare(m_query.title, Qt::CaseInsensitive) == 0 ? 120 : 80;
        }
    }

    const QJsonArray aliases = song.value(u"alias"_s).toArray();
    for (const auto& value : aliases) {
        const QString alias = value.toString().trimmed();
        if (!m_query.title.isEmpty() && !alias.isEmpty()
            && (containsCi(alias, m_query.title) || containsCi(m_query.title, alias))) {
            hit = true;
            score += 40;
            break;
        }
    }

    if (!m_query.artist.isEmpty()) {
        QJsonArray artists = song.value(u"artists"_s).toArray();
        if (artists.isEmpty())
            artists = song.value(u"singer"_s).toArray();
        for (const auto& value : artists) {
            const QString name = value.toObject().value(u"name"_s).toString().trimmed();
            if (!name.isEmpty() && (containsCi(m_query.artist, name) || containsCi(name, m_query.artist))) {
                hit = true;
                score += 100;
                break;
            }
        }
    }

    if (m_query.duration > 0.0 && std::isfinite(m_query.duration)) {
        qreal durationMs = song.value(u"duration"_s).toDouble(0.0);
        if (durationMs <= 0.0)
            durationMs = song.value(u"interval"_s).toDouble(0.0) * 1000.0;
        const qint64 diff = static_cast<qint64>(durationMs) - static_cast<qint64>(m_query.duration * 1000.0);
        if (diff >= -2000 && diff <= 2000)
            score += 30;
    }

    return hit ? score : -1;
}

// ---------------------------------------------------------------------------
// Better Lyrics, Unison, LyricsPlus
// ---------------------------------------------------------------------------

void LyricsEngine::fetchBetterLyrics(int generation, int slot) {
    const QUrl url = queryUrl(u"https://api.betterlyrics.org/getLyrics"_s,
        {
            { u"s"_s, m_query.title },
            { u"a"_s, m_query.artist },
            { u"al"_s, m_query.album },
            { u"d"_s, secondsText(m_query.duration) },
        });
    getJson(generation, url, jsonHeaders(), [this, generation, slot](const QJsonDocument& document, const QString& error) {
        if (!error.isEmpty()) {
            miss(generation, slot);
            return;
        }
        const QString ttml = document.object().value(u"ttml"_s).toString();
        if (ttml.isEmpty()) {
            miss(generation, slot);
            return;
        }
        LyricsResult result = parseTtml(ttml.toUtf8());
        if (!result.found)
            miss(generation, slot);
        else
            complete(generation, slot, std::move(result));
    });
}

void LyricsEngine::fetchUnison(int generation, int slot, bool withDuration) {
    // Unison treats duration as a strict filter. Its community entries sometimes
    // have a wrong duration, so retry without it on a miss.
    const bool filterDuration = withDuration && m_query.duration > 0.0;
    const QUrl url = queryUrl(u"https://unison.betterlyrics.org/lyrics"_s,
        {
            { u"song"_s, m_query.title },
            { u"artist"_s, m_query.artist },
            { u"album"_s, m_query.album },
            { u"duration"_s, filterDuration ? secondsText(m_query.duration) : QString() },
        });
    getJson(generation, url, jsonHeaders(),
        [this, generation, slot, filterDuration](const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty() || !document.isObject()) {
                if (filterDuration)
                    fetchUnison(generation, slot, false);
                else
                    miss(generation, slot);
                return;
            }
            const QJsonObject data = document.object().value(u"data"_s).toObject();
            const QString lyrics = data.value(u"lyrics"_s).toString();
            const QString format = data.value(u"format"_s).toString().toLower();
            if (lyrics.isEmpty()) {
                if (filterDuration)
                    fetchUnison(generation, slot, false);
                else
                    miss(generation, slot);
                return;
            }

            // The endpoint returns its best-scored match, which can be a cover or
            // a different song for ambiguous titles.
            const QString song = data.value(u"song"_s).toString();
            QStringList artists = data.value(u"artist"_s).toString().split(
                QRegularExpression(u"[、,，&/]"_s), Qt::SkipEmptyParts);
            for (QString& artist : artists)
                artist = artist.trimmed();
            if (!song.isEmpty() && !matchesTrack(song, artists)) {
                if (filterDuration)
                    fetchUnison(generation, slot, false);
                else
                    miss(generation, slot);
                return;
            }

            LyricsResult result;
            if (format.contains(u"ttml"_s) || lyrics.trimmed().startsWith(u'<'))
                result = parseTtml(lyrics.toUtf8());
            else if (format.contains(u"lyricsfile"_s) || format.contains(u"yaml"_s))
                result = parseLyricsfile(lyrics.toUtf8());
            else if (format.contains(u"plain"_s)) {
                result.plain = lyrics;
                result.found = !lyrics.trimmed().isEmpty();
            } else
                result = parseLrc(lyrics.toUtf8());
            if (!result.found)
                miss(generation, slot);
            else
                complete(generation, slot, std::move(result));
        });
}

void LyricsEngine::fetchLyricsPlus(int generation, int slot) {
    const QUrl url = queryUrl(u"https://lyricsplus.binimum.org/v2/lyrics/get"_s,
        {
            { u"title"_s, m_query.title },
            { u"artist"_s, m_query.artist },
            { u"album"_s, m_query.album },
            { u"duration"_s, secondsText(m_query.duration) },
            // Requesting an unavailable source makes the API fail the whole
            // lookup instead of continuing, so stick to the reliable providers.
            { u"source"_s, u"apple,lyricsplus"_s },
        });
    getJson(generation, url, jsonHeaders(), [this, generation, slot](const QJsonDocument& document, const QString& error) {
        if (!error.isEmpty() || !document.isObject()) {
            miss(generation, slot);
            return;
        }
        LyricsResult result = parseLyricsPlus(document.object());
        if (!result.found)
            miss(generation, slot);
        else
            complete(generation, slot, std::move(result));
    });
}

// ---------------------------------------------------------------------------
// KuGou
// ---------------------------------------------------------------------------

void LyricsEngine::fetchKugou(int generation, int slot) {
    const QString keyword = (m_query.title + u' ' + m_query.artist).trimmed();
    QList<QPair<QString, QString>> items = {
        { u"ver"_s, u"1"_s },
        { u"man"_s, u"yes"_s },
        { u"client"_s, u"pc"_s },
        { u"keyword"_s, keyword },
    };
    if (m_query.duration > 0.0)
        items.append({ u"duration"_s, QString::number(qRound64(m_query.duration * 1000.0)) });

    const QUrl url = queryUrl(u"https://lyrics.kugou.com/search"_s, items);
    getJson(generation, url, jsonHeaders(), [this, generation, slot](const QJsonDocument& document, const QString& error) {
        if (!error.isEmpty()) {
            miss(generation, slot);
            return;
        }
        const QJsonArray candidates = document.object().value(u"candidates"_s).toArray();
        QStringList downloads;
        for (const auto& value : candidates) {
            const QJsonObject candidate = value.toObject();
            const QString title = candidate.value(u"song"_s).toString();
            QString singer = candidate.value(u"singer"_s).toString();
            QStringList artists =
                singer.split(QRegularExpression(u"[、,，&/]"_s), Qt::SkipEmptyParts);
            for (QString& artist : artists)
                artist = artist.trimmed();
            if (!matchesTrack(title, artists))
                continue;
            const QString id = jsonScalarText(candidate.value(u"id"_s));
            const QString accessKey = jsonScalarText(candidate.value(u"accesskey"_s));
            if (id.isEmpty() || accessKey.isEmpty())
                continue;
            downloads.append(id + u'\x1f' + accessKey);
        }
        if (downloads.isEmpty())
            miss(generation, slot);
        else
            fetchKugouDownload(generation, slot, downloads, 0, true);
    });
}

void LyricsEngine::fetchKugouDownload(
    int generation, int slot, const QStringList& candidates, int index, bool krc) {
    if (index < 0 || index >= candidates.size()) {
        miss(generation, slot);
        return;
    }
    const QStringList pair = candidates.at(index).split(u'\x1f');
    if (pair.size() != 2) {
        if (krc)
            fetchKugouDownload(generation, slot, candidates, index, false);
        else
            fetchKugouDownload(generation, slot, candidates, index + 1, true);
        return;
    }
    const QString id = pair.at(0);
    const QString accessKey = pair.at(1);
    const QUrl url = queryUrl(u"https://lyrics.kugou.com/download"_s,
        {
            { u"ver"_s, u"1"_s },
            { u"client"_s, u"pc"_s },
            { u"charset"_s, u"utf8"_s },
            { u"fmt"_s, krc ? u"krc"_s : u"lrc"_s },
            { u"id"_s, id },
            { u"accesskey"_s, accessKey },
        });
    const auto retryOrAdvance = [this, generation, slot, candidates, index, krc] {
        if (krc)
            fetchKugouDownload(generation, slot, candidates, index, false);
        else
            fetchKugouDownload(generation, slot, candidates, index + 1, true);
    };
    getJson(generation, url, jsonHeaders(),
        [this, generation, slot, id, accessKey, krc, retryOrAdvance](
            const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty()) {
                retryOrAdvance();
                return;
            }
            const QString encoded = document.object().value(u"content"_s).toString();
            const QByteArray data = QByteArray::fromBase64(encoded.toLatin1());
            if (data.isEmpty()) {
                retryOrAdvance();
                return;
            }

            LyricsResult result = krc ? parseKrc(data) : parseLrc(data);
            if (!result.found) {
                retryOrAdvance();
                return;
            }

            if (result.synced.size() == 1 && result.synced.first().text.contains(u"纯音乐"_s)) {
                result = {};
                result.instrumental = true;
                result.found = true;
                complete(generation, slot, std::move(result));
                return;
            }
            static const QStringList k_creditPrefixes = {
                u"composed"_s, u"composer"_s, u"produced"_s, u"producer"_s, u"written"_s,
                u"writer"_s, u"lyrics"_s, u"lyricist"_s, u"arranged"_s, u"arranger"_s,
                u"mixed"_s, u"mixer"_s, u"mastered"_s, u"mastering"_s, u"performed"_s,
                u"vocals"_s, u"guitar"_s, u"drums"_s, u"bass"_s, u"piano"_s, u"strings"_s,
                u"作词"_s, u"作詞"_s, u"作曲"_s, u"编曲"_s, u"編曲"_s, u"制作"_s,
                u"製作"_s, u"演唱"_s, u"吉他"_s, u"贝斯"_s, u"鼓"_s, u"钢琴"_s, u"弦乐"_s,
            };
            int credits = 0;
            while (credits < result.synced.size()) {
                const QString& text = result.synced.at(credits).text;
                const qsizetype asciiColon = text.indexOf(u':');
                const qsizetype wideColon = text.indexOf(u'：');
                const qsizetype colon = asciiColon < 0 ? wideColon
                    : (wideColon < 0 ? asciiColon : qMin(asciiColon, wideColon));
                const QString head = colon > 0 ? text.left(colon).trimmed().toLower() : QString();
                bool header = false;
                for (const QString& prefix : k_creditPrefixes) {
                    if (head.startsWith(prefix)) {
                        header = true;
                        break;
                    }
                }
                if (!header && credits == 0)
                    header = QRegularExpression(u"\\s-+\\s"_s).match(text).hasMatch();
                if (!header)
                    break;
                ++credits;
            }
            if (credits >= result.synced.size()) {
                retryOrAdvance();
                return;
            }
            if (credits > 0)
                result.synced.remove(0, credits);
            QStringList plain;
            for (const auto& line : result.synced)
                plain.append(line.text);
            if (!plain.isEmpty())
                result.plain = plain.join(u'\n');
            result.id = id;
            complete(generation, slot, std::move(result));
        });
}

// ---------------------------------------------------------------------------
// LRCLIB
// ---------------------------------------------------------------------------

namespace {

[[nodiscard]] int lrclibTier(const QJsonObject& record) {
    if (record.value(u"instrumental"_s).toBool(false))
        return 1;
    if (record.value(u"hasWordSync"_s).toBool(false) || !record.value(u"lyricsfile"_s).toString().isEmpty())
        return 2;
    if (!record.value(u"syncedLyrics"_s).toString().isEmpty())
        return 1;
    return 0;
}

[[nodiscard]] LyricsResult decodeLrclibRecord(const QJsonObject& record) {
    if (record.value(u"instrumental"_s).toBool(false)) {
        LyricsResult result;
        result.instrumental = true;
        result.found = true;
        result.id = QString::number(record.value(u"id"_s).toInteger(0));
        result.title = record.value(u"trackName"_s).toString();
        result.artist = record.value(u"artistName"_s).toString();
        result.album = record.value(u"albumName"_s).toString();
        return result;
    }

    const QString lyricsfile = record.value(u"lyricsfile"_s).toString();
    if (!lyricsfile.isEmpty()) {
        LyricsResult result = parseLyricsfile(lyricsfile.toUtf8());
        if (result.found) {
            result.id = QString::number(record.value(u"id"_s).toInteger(0));
            return result;
        }
    }

    LyricsResult result = parseLrc(record.value(u"syncedLyrics"_s).toString().toUtf8());
    if (!result.found) {
        result.plain = record.value(u"plainLyrics"_s).toString();
        result.found = !result.plain.trimmed().isEmpty();
    }
    result.id = QString::number(record.value(u"id"_s).toInteger(0));
    result.title = record.value(u"trackName"_s).toString();
    result.artist = record.value(u"artistName"_s).toString();
    result.album = record.value(u"albumName"_s).toString();
    result.duration = record.value(u"duration"_s).toDouble(0.0);
    return result;
}

} // namespace

void LyricsEngine::fetchLrclib(int generation, int slot) {
    QList<QPair<QString, QString>> items = {
        { u"track_name"_s, m_query.title },
        { u"artist_name"_s, m_query.artist },
        { u"album_name"_s, m_query.album },
    };
    if (m_query.duration > 0.0)
        items.append({ u"duration"_s, secondsText(m_query.duration) });
    const QUrl url = queryUrl(u"https://lrclib.net/api/get"_s, items);
    getJson(generation, url, jsonHeaders(), [this, generation, slot](const QJsonDocument& document, const QString& error) {
        QJsonObject exact;
        if (error.isEmpty() && document.isObject())
            exact = document.object();
        if (!exact.isEmpty() && lrclibTier(exact) > 0) {
            LyricsResult result = decodeLrclibRecord(exact);
            if (result.found) {
                complete(generation, slot, std::move(result));
                return;
            }
        }
        fetchLrclibSearch(generation, slot, exact);
    });
}

void LyricsEngine::fetchLrclibSearch(int generation, int slot, const QJsonObject& exact) {
    QList<QPair<QString, QString>> items = { { u"track_name"_s, m_query.title } };
    if (!m_query.artist.isEmpty())
        items.append({ u"artist_name"_s, m_query.artist });
    const QUrl url = queryUrl(u"https://lrclib.net/api/search"_s, items);
    getJson(generation, url, jsonHeaders(),
        [this, generation, slot, exact](const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty()) {
                // The exact record may still be usable as plain lyrics even when
                // the search request itself failed.
                if (!exact.isEmpty()) {
                    LyricsResult result = decodeLrclibRecord(exact);
                    if (result.found) {
                        complete(generation, slot, std::move(result));
                        return;
                    }
                }
                miss(generation, slot);
                return;
            }

            QJsonObject best;
            int bestTier = -1;
            qreal bestGap = std::numeric_limits<qreal>::max();
            for (const auto& value : document.array()) {
                const QJsonObject record = value.toObject();
                const QString title = record.value(u"trackName"_s).toString();
                QString artistName = record.value(u"artistName"_s).toString();
                if (artistName.endsWith(u" - Topic"_s))
                    artistName.chop(8);
                QStringList artists = artistName.split(QRegularExpression(u"[,;/&]"_s), Qt::SkipEmptyParts);
                for (QString& artist : artists)
                    artist = artist.trimmed();
                if (!matchesTrack(title, artists))
                    continue;
                const qreal duration = record.value(u"duration"_s).toDouble(0.0);
                if (m_query.duration > 0.0 && duration > 0.0 && std::abs(duration - m_query.duration) > 8.0)
                    continue;
                const qreal gap = m_query.duration > 0.0 && duration > 0.0
                    ? std::abs(duration - m_query.duration)
                    : 0.0;
                const int tier = lrclibTier(record);
                if (tier > bestTier || (tier == bestTier && gap < bestGap)) {
                    best = record;
                    bestTier = tier;
                    bestGap = gap;
                }
            }

            if (best.isEmpty() || (lrclibTier(exact) > bestTier && lrclibTier(exact) > 0))
                best = exact;
            if (best.isEmpty()) {
                miss(generation, slot);
                return;
            }
            LyricsResult result = decodeLrclibRecord(best);
            if (!result.found)
                miss(generation, slot);
            else
                complete(generation, slot, std::move(result));
        });
}


// ---------------------------------------------------------------------------
// NetEase
// ---------------------------------------------------------------------------

void LyricsEngine::fetchNetEaseSearch(int generation, int slot) {
    const QUrl url = queryUrl(u"https://music.163.com/api/search/get"_s,
        {
            { u"s"_s, m_query.title + u' ' + m_query.artist },
            { u"type"_s, u"1"_s },
            { u"limit"_s, u"10"_s },
        });
    getJson(generation, url, netEaseHeaders(), [this, generation, slot](const QJsonDocument& document, const QString& error) {
        if (!error.isEmpty()) {
            miss(generation, slot);
            return;
        }
        const QJsonArray songs = document.object().value(u"result"_s).toObject().value(u"songs"_s).toArray();
        QVector<QPair<int, QString>> ranked;
        for (const auto& value : songs) {
            const QJsonObject song = value.toObject();
            const int score = scoreSong(song);
            if (score < 0)
                continue;
            const QString id = QString::number(song.value(u"id"_s).toInteger(0));
            if (!id.isEmpty() && id != u"0"_s)
                ranked.append({ score, id });
        }
        std::stable_sort(ranked.begin(), ranked.end(),
            [](const QPair<int, QString>& a, const QPair<int, QString>& b) { return a.first > b.first; });
        if (ranked.isEmpty()) {
            miss(generation, slot);
            return;
        }
        QStringList ids;
        ids.reserve(ranked.size());
        for (const auto& pair : ranked)
            ids.append(pair.second);
        fetchNetEaseLyric(generation, slot, ids, 0);
    });
}

void LyricsEngine::fetchNetEaseLyric(int generation, int slot, const QStringList& ids, int index) {
    if (index < 0 || index >= ids.size()) {
        miss(generation, slot);
        return;
    }
    const QString id = ids.at(index);
    const QUrl url = queryUrl(u"https://music.163.com/api/song/lyric"_s,
        {
            { u"id"_s, id },
            { u"lv"_s, u"1"_s },
            { u"kv"_s, u"1"_s },
            { u"tv"_s, u"-1"_s },
            { u"rv"_s, u"-1"_s },
        });
    getJson(generation, url, netEaseHeaders(),
        [this, generation, slot, ids, index, id](const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty()) {
                fetchNetEaseLyric(generation, slot, ids, index + 1);
                return;
            }
            const QJsonObject object = document.object();
            const QString lrc = object.value(u"lrc"_s).toObject().value(u"lyric"_s).toString();
            LyricsResult result = parseLrc(lrc.toUtf8());
            if (!result.found) {
                fetchNetEaseLyric(generation, slot, ids, index + 1);
                return;
            }
            const QString romalrc = object.value(u"romalrc"_s).toObject().value(u"lyric"_s).toString();
            if (!romalrc.isEmpty()) {
                LyricsResult romanized = parseLrc(romalrc.toUtf8());
                // Only use the variant when every line has a counterpart;
                // otherwise the original and romanized lists drift apart.
                if (romanized.found && romanized.synced.size() == result.synced.size())
                    result.romanized = std::move(romanized.synced);
            }
            result.id = id;
            complete(generation, slot, std::move(result));
        });
}

// ---------------------------------------------------------------------------
// QQ Music
// ---------------------------------------------------------------------------

namespace {

[[nodiscard]] QJsonObject qqComm() {
    return {
        { u"ct"_s, 19 },
        { u"cv"_s, 2111 },
        { u"format"_s, u"JSON"_s },
        { u"g_tk"_s, 5381 },
        { u"platform"_s, u"yqq.json"_s },
    };
}

[[nodiscard]] QJsonDocument qqSearchPayload(const QString& query) {
    const QJsonObject param{ { u"query"_s, query }, { u"num_per_page"_s, 10 }, { u"page_num"_s, 1 } };
    const QJsonObject req{ { u"module"_s, u"music.search.SearchCgiService"_s },
        { u"method"_s, u"DoSearchForQQMusicDesktop"_s }, { u"param"_s, param } };
    return QJsonDocument(QJsonObject{ { u"comm"_s, qqComm() }, { u"req_0"_s, req } });
}

[[nodiscard]] QJsonDocument qqLyricPayload(qint64 songId) {
    const QJsonObject param{ { u"crypt"_s, 1 },
        { u"lrc_t"_s, 0 },
        { u"qrc"_s, 1 },
        { u"qrc_t"_s, 0 },
        { u"roma"_s, 1 },
        { u"roma_t"_s, 0 },
        { u"trans"_s, 0 },
        { u"trans_t"_s, 0 },
        { u"songID"_s, static_cast<double>(songId) },
        { u"type"_s, 0 } };
    const QJsonObject req{ { u"module"_s, u"music.musichallSong.PlayLyricInfo"_s },
        { u"method"_s, u"GetPlayLyricInfo"_s }, { u"param"_s, param } };
    return QJsonDocument(QJsonObject{ { u"comm"_s, qqComm() }, { u"req_1"_s, req } });
}

} // namespace

void LyricsEngine::fetchQQSearch(int generation, int slot) {
    const QUrl url(u"https://u.y.qq.com/cgi-bin/musicu.fcg"_s);
    const QByteArray body = qqSearchPayload(m_query.title + u' ' + m_query.artist).toJson(QJsonDocument::Compact);
    postJson(generation, url, qqHeaders(), body,
        [this, generation, slot](const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty()) {
                miss(generation, slot);
                return;
            }
            const QJsonArray songs = document.object().value(u"req_0"_s).toObject().value(u"data"_s).toObject()
                                         .value(u"body"_s).toObject().value(u"song"_s).toObject()
                                         .value(u"list"_s).toArray();
            QVector<QPair<int, QString>> ranked;
            for (const auto& value : songs) {
                const QJsonObject song = value.toObject();
                const int score = scoreSong(song);
                if (score < 0)
                    continue;
                const QString id = QString::number(song.value(u"id"_s).toInteger(0));
                if (!id.isEmpty() && id != u"0"_s)
                    ranked.append({ score, id });
            }
            std::stable_sort(ranked.begin(), ranked.end(),
                [](const QPair<int, QString>& a, const QPair<int, QString>& b) { return a.first > b.first; });
            if (ranked.isEmpty()) {
                miss(generation, slot);
                return;
            }
            QStringList ids;
            ids.reserve(ranked.size());
            for (const auto& pair : ranked)
                ids.append(pair.second);
            fetchQQLyric(generation, slot, ids, 0);
        });
}

void LyricsEngine::fetchQQLyric(int generation, int slot, const QStringList& ids, int index) {
    if (index < 0 || index >= ids.size()) {
        miss(generation, slot);
        return;
    }
    const QString id = ids.at(index);
    bool ok = false;
    const qint64 songId = id.toLongLong(&ok);
    if (!ok || songId <= 0) {
        fetchQQLyric(generation, slot, ids, index + 1);
        return;
    }
    const QUrl url(u"https://u.y.qq.com/cgi-bin/musicu.fcg"_s);
    const QByteArray body = qqLyricPayload(songId).toJson(QJsonDocument::Compact);
    postJson(generation, url, qqHeaders(), body,
        [this, generation, slot, ids, index, id](const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty()) {
                fetchQQLyric(generation, slot, ids, index + 1);
                return;
            }
            const QJsonObject data = document.object().value(u"req_1"_s).toObject()
                                         .value(u"data"_s).toObject();
            const QString qrcRaw = data.value(u"qrc"_s).toString();
            const QString lyricRaw = data.value(u"lyric"_s).toString();

            LyricsResult result;
            if (!qrcRaw.isEmpty()) {
                if (qrcRaw.trimmed().startsWith(u'<'))
                    result = parseQrc(qrcRaw);
                else {
                    const QString xml = qqDecryptQrc(qrcRaw);
                    if (!xml.isEmpty())
                        result = parseQrc(xml);
                }
            }
            if (!result.found && !lyricRaw.isEmpty()) {
                QString lrc = lyricRaw;
                if (!lrc.contains(u']')) {
                    const QString decoded = QString::fromUtf8(QByteArray::fromBase64(lyricRaw.toLatin1()));
                    if (decoded.contains(u']'))
                        lrc = decoded;
                }
                result = parseLrc(lrc.toUtf8());
            }
            if (!result.found) {
                fetchQQLyric(generation, slot, ids, index + 1);
                return;
            }

            const QString roma = data.value(u"roma"_s).toString();
            if (!roma.isEmpty()) {
                const QString xml = qqDecryptQrc(roma);
                if (!xml.isEmpty()) {
                    const QVector<LyricLine> romanized = qqParseQrc(xml);
                    const QVector<LyricLine> aligned = qqAlignRomanized(result.synced, romanized);
                    if (!aligned.isEmpty())
                        result.romanized = aligned;
                }
            }
            result.id = id;
            complete(generation, slot, std::move(result));
        });
}

// ---------------------------------------------------------------------------
// YouTube Music
// ---------------------------------------------------------------------------

void LyricsEngine::fetchYouTubeSearch(int generation, int slot) {
    QJsonObject client{
        { u"clientName"_s, u"WEB_REMIX"_s },
        { u"clientVersion"_s, u"1."_s + QDate::currentDate().toString(u"yyyyMMdd"_s) + u".01.00"_s },
        { u"hl"_s, youtubeLanguage(m_query) },
    };
    QJsonObject body{
        { u"context"_s, QJsonObject{ { u"client"_s, client } } },
        { u"query"_s, m_query.title + u' ' + m_query.artist },
        { u"params"_s, u"EgWKAQIIAWoMEA4QChADEAQQCRAF"_s },
    };
    auto headers = youtubeHeaders();
    headers.insert("X-Goog-FieldMask"_ba,
        "contents.tabbedSearchResultsRenderer.tabs.tabRenderer.content.sectionListRenderer.contents."
        "musicShelfRenderer.contents.musicResponsiveListItemRenderer("
        "playlistItemData.videoId,flexColumns.musicResponsiveListItemFlexColumnRenderer.text.runs.text)"_ba);

    const QUrl url = youtubeUrl(u"search"_s);
    postJson(generation, url, headers, QJsonDocument(body).toJson(QJsonDocument::Compact),
        [this, generation, slot](const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty()) {
                miss(generation, slot);
                return;
            }
            const auto songs = dig(document,
                u"contents.tabbedSearchResultsRenderer.tabs.tabRenderer.content.sectionListRenderer.contents."
                u"musicShelfRenderer.contents.musicResponsiveListItemRenderer"_s);
            for (const auto& value : songs) {
                if (!value.isObject())
                    continue;
                const QJsonObject song = value.toObject();
                const QString videoId = song.value(u"playlistItemData"_s).toObject().value(u"videoId"_s).toString();
                if (videoId.isEmpty())
                    continue;

                const auto columns = dig(QJsonDocument(song),
                    u"flexColumns.musicResponsiveListItemFlexColumnRenderer"_s);
                if (columns.size() < 2)
                    continue;

                QString title;
                for (const auto& column : columns.at(0).toObject().value(u"text"_s).toObject()
                                              .value(u"runs"_s).toArray()) {
                    if (column.isObject())
                        title += column.toObject().value(u"text"_s).toString();
                }

                QStringList details;
                for (const auto& run : columns.at(1).toObject().value(u"text"_s).toObject()
                                            .value(u"runs"_s).toArray()) {
                    if (run.isObject())
                        details.append(run.toObject().value(u"text"_s).toString());
                }
                // The detail column is normally "Artist • Title • Duration". Older
                // responses prefix the media type ("Song • Artist • ..."), so skip a
                // leading type run only when it is followed by a bullet.
                const auto isBullet = [](const QString& text) {
                    return text.trimmed() == u"•"_s;
                };
                qsizetype artistStart = 0;
                if (details.size() >= 2 && isBullet(details.at(1))) {
                    static const QStringList k_types = { u"Song"_s, u"Video"_s, u"Album"_s,
                        u"Single"_s, u"EP"_s, u"Playlist"_s, u"Artist"_s, u"Profile"_s,
                        u"Podcast"_s, u"Episode"_s, u"Upload"_s };
                    if (k_types.contains(details.at(0).trimmed(), Qt::CaseInsensitive))
                        artistStart = 2;
                }
                QStringList artists;
                for (qsizetype i = artistStart; i < details.size(); ++i) {
                    const QString detail = details.at(i);
                    if (isBullet(detail))
                        break;
                    if (detail != u" & "_s && detail != u"&"_s && !detail.trimmed().isEmpty())
                        artists.append(detail);
                }
                const int seconds = details.isEmpty() ? 0 : clockSeconds(details.last());
                if (m_query.duration > 0.0 && seconds > 0
                    && std::abs(seconds - m_query.duration) > 8.0)
                    continue;
                if (!matchesTrack(title, artists))
                    continue;
                fetchYouTubeNext(generation, slot, videoId);
                return;
            }
            miss(generation, slot);
        });
}

void LyricsEngine::fetchYouTubeNext(int generation, int slot, const QString& videoId) {
    QJsonObject client{
        { u"clientName"_s, u"WEB_REMIX"_s },
        { u"clientVersion"_s, u"1."_s + QDate::currentDate().toString(u"yyyyMMdd"_s) + u".01.00"_s },
        { u"hl"_s, youtubeLanguage(m_query) },
    };
    QJsonObject body{
        { u"context"_s, QJsonObject{ { u"client"_s, client } } },
        { u"videoId"_s, videoId },
    };
    auto headers = youtubeHeaders();
    headers.insert("X-Goog-FieldMask"_ba,
        "contents.singleColumnMusicWatchNextResultsRenderer.tabbedRenderer.watchNextTabbedResultsRenderer."
        "tabs.tabRenderer(unselectable,endpoint.browseEndpoint(browseId,"
        "browseEndpointContextSupportedConfigs))"_ba);
    const QUrl url = youtubeUrl(u"next"_s);
    postJson(generation, url, headers, QJsonDocument(body).toJson(QJsonDocument::Compact),
        [this, generation, slot](const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty()) {
                miss(generation, slot);
                return;
            }
            const auto tabs = dig(document,
                u"contents.singleColumnMusicWatchNextResultsRenderer.tabbedRenderer."
                u"watchNextTabbedResultsRenderer.tabs.tabRenderer"_s);
            for (const auto& value : tabs) {
                if (!value.isObject())
                    continue;
                const QJsonObject tab = value.toObject();
                const QJsonDocument tabDocument(tab);
                const QString pageType = digString(tabDocument,
                    u"endpoint.browseEndpoint.browseEndpointContextSupportedConfigs."
                    u"browseEndpointContextMusicConfig.pageType"_s);
                if (pageType != u"MUSIC_PAGE_TYPE_TRACK_LYRICS"_s)
                    continue;
                const QJsonValue unselectable = tab.value(u"unselectable"_s);
                if ((unselectable.isBool() && unselectable.toBool())
                    || (unselectable.isArray() && !unselectable.toArray().isEmpty())
                    || (unselectable.isObject() && !unselectable.toObject().isEmpty()))
                    continue;
                const QString browseId = digString(tabDocument, u"endpoint.browseEndpoint.browseId"_s);
                if (browseId.isEmpty())
                    continue;
                fetchYouTubeBrowse(generation, slot, browseId);
                return;
            }
            miss(generation, slot);
        });
}

void LyricsEngine::fetchYouTubeBrowse(int generation, int slot, const QString& browseId) {
    QJsonObject client{
        { u"clientName"_s, u"ANDROID_MUSIC"_s },
        { u"clientVersion"_s, u"7.21.50"_s },
        { u"hl"_s, u"en"_s },
    };
    QJsonObject body{
        { u"context"_s, QJsonObject{ { u"client"_s, client } } },
        { u"browseId"_s, browseId },
    };
    auto headers = youtubeHeaders();
    headers.insert("X-Goog-FieldMask"_ba,
        "contents.elementRenderer.newElement.type.componentType.model.timedLyricsModel.lyricsData."
        "timedLyricsData"_ba);
    const QUrl url = youtubeUrl(u"browse"_s);
    postJson(generation, url, headers, QJsonDocument(body).toJson(QJsonDocument::Compact),
        [this, generation, slot](const QJsonDocument& document, const QString& error) {
            if (!error.isEmpty()) {
                miss(generation, slot);
                return;
            }
            const auto found = dig(document,
                u"contents.elementRenderer.newElement.type.componentType.model.timedLyricsModel."
                u"lyricsData.timedLyricsData"_s);
            if (found.isEmpty() || !found.first().isArray()) {
                miss(generation, slot);
                return;
            }

            const QJsonArray rows = found.first().toArray();
            if (rows.size() > kMaxLyricsLines) {
                miss(generation, slot);
                return;
            }
            LyricsResult result;
            QStringList plain;
            bool allTimed = true;
            const auto cueMillis = [](const QJsonValue& value, bool* ok) -> qint64 {
                if (value.isString()) {
                    return value.toString().toLongLong(ok);
                }
                if (value.isDouble()) {
                    *ok = true;
                    return static_cast<qint64>(value.toDouble());
                }
                *ok = false;
                return 0;
            };
            for (const auto& value : rows) {
                const QJsonObject row = value.toObject();
                const QString text = row.value(u"lyricLine"_s).toString();
                // Timed responses contain blank spacer rows between sections.
                if (text.trimmed().isEmpty())
                    continue;
                plain.append(text);
                const QJsonObject cue = row.value(u"cueRange"_s).toObject();
                bool startOk = false;
                bool endOk = false;
                const qint64 start = cueMillis(cue.value(u"startTimeMilliseconds"_s), &startOk);
                const qint64 end = cueMillis(cue.value(u"endTimeMilliseconds"_s), &endOk);
                if (!startOk || !endOk) {
                    allTimed = false;
                    continue;
                }
                result.synced.append(LyricLine{ .time = start / 1000.0, .end = end / 1000.0, .text = text });
            }
            result.plain = plain.join(u'\n');
            if (!allTimed)
                result.synced.clear();
            sortLyricLines(result.synced);
            result.found = !result.synced.isEmpty() || !result.plain.trimmed().isEmpty();
            if (!result.found)
                miss(generation, slot);
            else
                complete(generation, slot, std::move(result));
        });
}

// ---------------------------------------------------------------------------
// Plugin command providers
// ---------------------------------------------------------------------------

void LyricsEngine::fetchPlugin(int generation, int slot, const LyricsProviderInfo& info) {
    const QStringList command =
        info.commandArgs.isEmpty() ? QProcess::splitCommand(info.command) : info.commandArgs;
    if (command.isEmpty()) {
        miss(generation, slot);
        return;
    }

    QString program = command.first();
    if (QFileInfo(program).isRelative()) {
        const QString local = info.workDir + u'/' + program;
        if (QFileInfo::exists(local))
            program = local;
    }

    auto* process = new QProcess(this);
    m_processes.insert(process);
    m_processOutput.insert(process, QByteArray());
    process->setWorkingDirectory(info.workDir);
    process->setProgram(program);
    process->setArguments(command.mid(1));
    // The protocol only defines stdout; a plugin that logs to stderr must not
    // fill its pipe and stall waiting for a reader.
    process->setStandardErrorFile(QProcess::nullDevice());

    QObject::connect(process, &QProcess::readyReadStandardOutput, this, [this, process] {
        if (!m_processOutput.contains(process))
            return;
        QByteArray& output = m_processOutput[process];
        output += process->readAllStandardOutput();
        if (output.size() > kMaxLyricsBytes) {
            output.clear();
            process->kill();
        }
    });

    QObject::connect(process, &QProcess::errorOccurred, this, [this, generation, slot, process](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        m_processes.remove(process);
        m_processOutput.remove(process);
        process->deleteLater();
        miss(generation, slot);
    });

    QObject::connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
        [this, generation, slot, process](int exitCode, QProcess::ExitStatus status) {
            QByteArray output = m_processOutput.take(process);
            output += process->readAllStandardOutput();
            m_processes.remove(process);
            process->deleteLater();
            if (generation != m_generation || m_finished)
                return;
            if (status != QProcess::NormalExit || exitCode != 0 || output.trimmed().isEmpty()) {
                miss(generation, slot);
                return;
            }

            QJsonParseError parseError{};
            const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
            if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
                miss(generation, slot);
                return;
            }
            const QJsonObject answer = document.object();
            if (answer.value(u"instrumental"_s).toBool(false)) {
                LyricsResult result;
                result.instrumental = true;
                result.found = true;
                complete(generation, slot, std::move(result));
                return;
            }

            const QString lyrics = answer.value(u"lyrics"_s).toString();
            const QString format = answer.value(u"format"_s).toString().toLower();
            if (lyrics.isEmpty()) {
                miss(generation, slot);
                return;
            }
            LyricsResult result;
            if (format == u"ttml"_s)
                result = parseTtml(lyrics.toUtf8());
            else if (format == u"lyricsfile"_s || format == u"yaml"_s || format == u"yml"_s)
                result = parseLyricsfile(lyrics.toUtf8());
            else if (format == u"qrc"_s)
                result = parseQrc(lyrics);
            else if (format == u"plain"_s) {
                result.plain = lyrics;
                result.found = !lyrics.trimmed().isEmpty();
            } else
                result = parseLrc(lyrics.toUtf8());
            if (!result.found)
                miss(generation, slot);
            else
                complete(generation, slot, std::move(result));
        });

    const bool hasDuration = std::isfinite(m_query.duration) && m_query.duration > 0.0;
    QJsonObject query{
        { u"title"_s, m_query.title },
        { u"artist"_s, m_query.artist },
        { u"album"_s, m_query.album },
        { u"duration"_s, hasDuration ? qRound(m_query.duration) : 0 },
    };
    const QByteArray input = QJsonDocument(query).toJson(QJsonDocument::Compact);
    QObject::connect(process, &QProcess::started, this, [process, input] {
        process->write(input);
        process->closeWriteChannel();
    });

    QTimer::singleShot(8000, process, [process] {
        if (process->state() != QProcess::NotRunning)
            process->kill();
    });

    process->start();
}

} // namespace caelestia::services
