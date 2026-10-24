#include "lyricstypes.hpp"

#include <algorithm>

namespace caelestia::services {

using Qt::StringLiterals::operator""_s;

bool LyricsResult::wordSynced() const {
    return std::ranges::any_of(synced, [](const LyricLine& line) { return !line.words.isEmpty(); });
}

int LyricsResult::tier() const {
    if (wordSynced())
        return 2;
    if (!synced.isEmpty() || instrumental)
        return 1;
    return 0;
}

bool LyricsResult::empty() const {
    return !instrumental && synced.isEmpty() && plain.trimmed().isEmpty();
}

QVariantMap lyricWordToVariant(const LyricWord& word) {
    QVariantMap map;
    map.insert(u"t"_s, word.time);
    if (word.end > 0.0)
        map.insert(u"e"_s, word.end);
    map.insert(u"x"_s, word.text);
    return map;
}

QVariantMap lyricLineToVariant(const LyricLine& line) {
    QVariantMap map;
    map.insert(u"t"_s, line.time);
    if (line.end > 0.0)
        map.insert(u"e"_s, line.end);
    map.insert(u"x"_s, line.text);
    if (!line.words.isEmpty()) {
        QVariantList words;
        words.reserve(line.words.size());
        for (const auto& word : line.words)
            words.append(lyricWordToVariant(word));
        map.insert(u"w"_s, words);
    }
    if (!line.voice.isEmpty())
        map.insert(u"voice"_s, line.voice);
    if (line.background)
        map.insert(u"background"_s, true);
    if (line.group > 0)
        map.insert(u"group"_s, line.group);
    return map;
}

QVariantList lyricLinesToVariant(const QVector<LyricLine>& lines) {
    QVariantList list;
    list.reserve(lines.size());
    for (const auto& line : lines)
        list.append(lyricLineToVariant(line));
    return list;
}

QVariantList lyricVoicesToVariant(const QHash<QString, LyricVoice>& voices) {
    QVariantList list;
    for (auto it = voices.constBegin(); it != voices.constEnd(); ++it) {
        QVariantMap map;
        map.insert(u"id"_s, it.key());
        map.insert(u"name"_s, it.value().name);
        map.insert(u"type"_s, it.value().type);
        list.append(map);
    }
    return list;
}

QStringList lyricTexts(const QVector<LyricLine>& lines) {
    QStringList list;
    list.reserve(lines.size());
    for (const auto& line : lines)
        list.append(line.text);
    return list;
}

QString joinLyricWords(const QVector<LyricWord>& words) {
    QString text;
    for (const auto& word : words)
        text += word.text;
    return text;
}

void trimLyricWords(QVector<LyricWord>& words) {
    while (!words.isEmpty() && words.first().text.trimmed().isEmpty())
        words.removeFirst();
    while (!words.isEmpty() && words.last().text.trimmed().isEmpty())
        words.removeLast();
    // Only the outer boundary may be trimmed. The whitespace that separates two
    // words belongs to one of them, so trimming both ends of the first/last word
    // would glue the final (or first) word to its neighbour once the words are
    // rendered individually.
    if (!words.isEmpty()) {
        QString& first = words.first().text;
        qsizetype begin = 0;
        while (begin < first.size() && first.at(begin).isSpace())
            ++begin;
        first = first.mid(begin);

        QString& last = words.last().text;
        while (!last.isEmpty() && last.back().isSpace())
            last.chop(1);
    }
}

void sortLyricLines(QVector<LyricLine>& lines) {
    std::stable_sort(lines.begin(), lines.end(), [](const LyricLine& a, const LyricLine& b) {
        return a.time < b.time;
    });
}

namespace {

QJsonArray wordsToJson(const QVector<LyricWord>& words) {
    QJsonArray array;
    for (const auto& word : words) {
        QJsonObject object;
        object.insert(u"t"_s, word.time);
        if (word.end > 0.0)
            object.insert(u"e"_s, word.end);
        object.insert(u"x"_s, word.text);
        array.append(object);
    }
    return array;
}

QJsonArray linesToJson(const QVector<LyricLine>& lines) {
    QJsonArray array;
    for (const auto& line : lines) {
        QJsonObject object;
        object.insert(u"t"_s, line.time);
        if (line.end > 0.0)
            object.insert(u"e"_s, line.end);
        object.insert(u"x"_s, line.text);
        if (!line.words.isEmpty())
            object.insert(u"w"_s, wordsToJson(line.words));
        if (!line.voice.isEmpty())
            object.insert(u"voice"_s, line.voice);
        if (line.background)
            object.insert(u"background"_s, true);
        if (line.group > 0)
            object.insert(u"group"_s, line.group);
        array.append(object);
    }
    return array;
}

QVector<LyricWord> wordsFromJson(const QJsonArray& array) {
    QVector<LyricWord> words;
    for (const auto& value : array) {
        const QJsonObject object = value.toObject();
        if (!object.contains(u"t"_s) || !object.contains(u"x"_s))
            continue;
        words.append(LyricWord{ .time = object.value(u"t"_s).toDouble(),
            .end = object.value(u"e"_s).toDouble(0.0),
            .text = object.value(u"x"_s).toString() });
    }
    return words;
}

QVector<LyricLine> linesFromJson(const QJsonArray& array) {
    QVector<LyricLine> lines;
    for (const auto& value : array) {
        const QJsonObject object = value.toObject();
        if (!object.contains(u"t"_s) || !object.contains(u"x"_s))
            continue;
        lines.append(LyricLine{ .time = object.value(u"t"_s).toDouble(),
            .end = object.value(u"e"_s).toDouble(0.0),
            .text = object.value(u"x"_s).toString(),
            .words = wordsFromJson(object.value(u"w"_s).toArray()),
            .voice = object.value(u"voice"_s).toString(),
            .background = object.value(u"background"_s).toBool(false),
            .group = object.value(u"group"_s).toInt(0) });
    }
    return lines;
}

} // namespace

QJsonObject LyricsResult::toJson() const {
    QJsonObject object;
    object.insert(u"found"_s, found);
    object.insert(u"instrumental"_s, instrumental);
    object.insert(u"cached"_s, cached);
    object.insert(u"synced"_s, linesToJson(synced));
    if (!romanized.isEmpty())
        object.insert(u"romanized"_s, linesToJson(romanized));
    object.insert(u"plain"_s, plain);
    if (!voices.isEmpty()) {
        QJsonObject voiceObject;
        for (auto it = voices.constBegin(); it != voices.constEnd(); ++it) {
            QJsonObject value;
            value.insert(u"name"_s, it.value().name);
            value.insert(u"type"_s, it.value().type);
            voiceObject.insert(it.key(), value);
        }
        object.insert(u"voices"_s, voiceObject);
    }
    object.insert(u"source"_s, source);
    object.insert(u"id"_s, id);
    object.insert(u"attributionName"_s, attributionName);
    object.insert(u"attributionUrl"_s, attributionUrl);
    object.insert(u"attributionText"_s, attributionText);
    object.insert(u"title"_s, title);
    object.insert(u"artist"_s, artist);
    object.insert(u"album"_s, album);
    object.insert(u"duration"_s, duration);
    return object;
}

LyricsResult LyricsResult::fromJson(const QJsonObject& object) {
    LyricsResult result;
    result.found = object.value(u"found"_s).toBool(false);
    result.instrumental = object.value(u"instrumental"_s).toBool(false);
    result.cached = object.value(u"cached"_s).toBool(false);
    result.synced = linesFromJson(object.value(u"synced"_s).toArray());
    result.romanized = linesFromJson(object.value(u"romanized"_s).toArray());
    result.plain = object.value(u"plain"_s).toString();
    const QJsonObject voices = object.value(u"voices"_s).toObject();
    for (auto it = voices.constBegin(); it != voices.constEnd(); ++it) {
        const QJsonObject value = it.value().toObject();
        result.voices.insert(it.key(), LyricVoice{ .name = value.value(u"name"_s).toString(),
                                        .type = value.value(u"type"_s).toString() });
    }
    result.source = object.value(u"source"_s).toString();
    result.id = object.value(u"id"_s).toString();
    result.attributionName = object.value(u"attributionName"_s).toString();
    result.attributionUrl = object.value(u"attributionUrl"_s).toString();
    result.attributionText = object.value(u"attributionText"_s).toString();
    result.title = object.value(u"title"_s).toString();
    result.artist = object.value(u"artist"_s).toString();
    result.album = object.value(u"album"_s).toString();
    result.duration = object.value(u"duration"_s).toDouble(0.0);
    return result;
}

} // namespace caelestia::services
