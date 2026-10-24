#pragma once

#include <qhash.h>
#include <qjsonarray.h>
#include <qjsonobject.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>
#include <qvector.h>

namespace caelestia::services {

// Word/syllable timing. Concatenating every word's text gives the line text back.
struct LyricWord {
    qreal time = 0.0;
    qreal end = 0.0;
    QString text;
};

struct LyricLine {
    qreal time = 0.0;
    qreal end = 0.0;
    QString text;
    QVector<LyricWord> words;
    // Key into LyricsResult::voices.
    QString voice;
    bool background = false;
    // Shared by lines split from one source line (lead + backing vocal). 0 = not grouped.
    int group = 0;
};

struct LyricVoice {
    QString name;
    QString type;
};

struct LyricsResult {
    bool found = false;
    bool instrumental = false;
    bool cached = false;
    QVector<LyricLine> synced;
    // Curated romanized/transliterated variant, line-aligned with synced when available.
    QVector<LyricLine> romanized;
    QString plain;
    QHash<QString, LyricVoice> voices;
    QString source;
    // Provider-specific id (LRCLIB record, NetEase/QQ song, local path).
    QString id;
    QString attributionName;
    QString attributionUrl;
    QString attributionText;
    QString title;
    QString artist;
    QString album;
    qreal duration = 0.0;

    [[nodiscard]] bool wordSynced() const;
    [[nodiscard]] int tier() const;
    [[nodiscard]] bool empty() const;
    [[nodiscard]] QJsonObject toJson() const;
    [[nodiscard]] static LyricsResult fromJson(const QJsonObject& object);
};

[[nodiscard]] QVariantMap lyricWordToVariant(const LyricWord& word);
[[nodiscard]] QVariantMap lyricLineToVariant(const LyricLine& line);
[[nodiscard]] QVariantList lyricLinesToVariant(const QVector<LyricLine>& lines);
[[nodiscard]] QVariantList lyricVoicesToVariant(const QHash<QString, LyricVoice>& voices);
[[nodiscard]] QStringList lyricTexts(const QVector<LyricLine>& lines);

// Joins the words, preserving their spacing exactly.
[[nodiscard]] QString joinLyricWords(const QVector<LyricWord>& words);

// Drops leading/trailing whitespace-only words without touching the words in between.
void trimLyricWords(QVector<LyricWord>& words);

void sortLyricLines(QVector<LyricLine>& lines);

// Guards providers against hostile payloads. The limits mirror the DMS engine.
constexpr int kMaxLyricsBytes = 512 << 10;
constexpr int kMaxLyricsSidecarBytes = kMaxLyricsBytes;
constexpr int kMaxLyricsLines = 2000;
constexpr int kMaxLyricsWords = 16000;

} // namespace caelestia::services
