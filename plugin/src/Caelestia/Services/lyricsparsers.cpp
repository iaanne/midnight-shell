#include "lyricsparsers.hpp"

#include <cmath>
#include <zlib.h>

#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qregularexpression.h>
#include <qstringlist.h>
#include <qxmlstream.h>

#include <algorithm>
#include <utility>

namespace caelestia::services {

using Qt::StringLiterals::operator""_s;
using Qt::StringLiterals::operator""_ba;

namespace {

[[nodiscard]] bool finite(qreal value) {
    return std::isfinite(value);
}

[[nodiscard]] QString normalizeSpace(const QString& text) {
    QString out;
    out.reserve(text.size());
    for (const QChar c : text) {
        if (c == u'\n') {
            out.append(c);
            continue;
        }
        out.append(c.isSpace() ? u' ' : c);
    }
    return out;
}

[[nodiscard]] qreal shift(qreal value, qreal offset) {
    const qreal shifted = value - offset;
    return finite(shifted) ? std::max<qreal>(0.0, shifted) : value;
}

[[nodiscard]] qreal parseStamp(const QString& raw) {
    QString value = raw.trimmed();
    if (value.isEmpty())
        return -1.0;
    if (value.endsWith(u's'))
        value.chop(1);
    const QStringList parts = value.split(u':');
    if (parts.size() < 2 || parts.size() > 3)
        return -1.0;
    qreal total = 0.0;
    for (qsizetype i = 0; i < parts.size(); ++i) {
        QString part = parts.at(i);
        if (i == parts.size() - 1)
            part.replace(u',', u'.');
        else if (part.contains(u'.') || part.contains(u','))
            return -1.0;
        bool ok = false;
        const qreal number = part.toDouble(&ok);
        if (!ok || number < 0.0 || !finite(number))
            return -1.0;
        total = total * 60.0 + number;
    }
    return finite(total) ? total : -1.0;
}

[[nodiscard]] qreal parseTtmlTime(QString value) {
    value = value.trimmed();
    if (value.isEmpty())
        return -1.0;
    qreal scale = 1.0;
    if (value.endsWith(u"ms"_s)) {
        value.chop(2);
        scale = 0.001;
    } else if (value.endsWith(u's')) {
        value.chop(1);
    } else if (value.endsWith(u'm')) {
        value.chop(1);
        scale = 60.0;
    } else if (value.endsWith(u'h')) {
        value.chop(1);
        scale = 3600.0;
    }
    const QStringList parts = value.split(u':');
    if (parts.isEmpty() || parts.size() > 3)
        return -1.0;
    qreal total = 0.0;
    for (const QString& part : parts) {
        bool ok = false;
        const qreal number = part.toDouble(&ok);
        if (!ok || number < 0.0 || !finite(number))
            return -1.0;
        total = total * 60.0 + number;
    }
    total *= scale;
    return finite(total) ? total : -1.0;
}

[[nodiscard]] QVector<qreal> splitTimestamps(const QString& line, QString& rest) {
    QVector<qreal> stamps;
    QString remaining = line;
    while (true) {
        const QString trimmed = remaining.trimmed();
        if (!trimmed.startsWith(u'['))
            break;
        const qsizetype end = trimmed.indexOf(u']');
        if (end < 0)
            break;
        const qreal at = parseStamp(trimmed.mid(1, end - 1));
        if (at < 0.0)
            break;
        stamps.append(at);
        remaining = trimmed.mid(end + 1);
    }
    rest = stamps.isEmpty() ? line : remaining;
    return stamps;
}

[[nodiscard]] QString stripEnhanced(const QString& text) {
    static const QRegularExpression k_tag(u"<\\d+:\\d+(?::\\d+)?(?:[.,]\\d+)?>"_s);
    if (!text.contains(u'<'))
        return text;
    QString out = text;
    out.remove(k_tag);
    return out;
}

[[nodiscard]] qreal clockSeconds(QString value) {
    value = value.trimmed();
    if (value.isEmpty())
        return 0.0;
    const qsizetype space = value.indexOf(u' ');
    if (space > 0)
        value = value.left(space);
    if (value.contains(u':'))
        return std::max<qreal>(0.0, parseStamp(value));
    bool ok = false;
    const qreal number = value.toDouble(&ok);
    return ok && finite(number) && number >= 0.0 ? number : 0.0;
}

[[nodiscard]] qreal parseOffset(const QString& raw) {
    QString value = raw.trimmed();
    if (value.startsWith(u'+'))
        value.remove(0, 1);
    bool ok = false;
    const qreal ms = value.toDouble(&ok);
    return ok && finite(ms) ? ms / 1000.0 : 0.0;
}

[[nodiscard]] QVector<LyricWord> splitWords(const QString& text, qreal start) {
    static const QRegularExpression k_tag(u"<\\d+:\\d+(?::\\d+)?(?:[.,]\\d+)?>"_s);
    const auto matches = k_tag.globalMatch(text);
    if (!matches.isValid())
        return {};
    QVector<LyricWord> words;
    qsizetype previous = 0;
    qreal at = start;
    auto it = matches;
    while (it.hasNext()) {
        const auto match = it.next();
        const qreal next = parseStamp(match.captured().mid(1, match.captured().size() - 2));
        if (next < 0.0 || next < at)
            return {};
        if (match.capturedStart() > previous)
            words.append(LyricWord{ .time = at, .end = next, .text = text.mid(previous, match.capturedStart() - previous) });
        at = next;
        previous = match.capturedEnd();
    }
    if (previous < text.size())
        words.append(LyricWord{ .time = at, .text = text.mid(previous) });
    trimLyricWords(words);
    return words;
}

} // namespace

QString decodeLyricText(const QByteArray& data, bool* ok) {
    if (ok)
        *ok = false;
    if (data.isEmpty() || data.size() > kMaxLyricsBytes)
        return {};

    QByteArray body = data;
    if (body.startsWith("\xEF\xBB\xBF"_ba))
        body.remove(0, 3);

    if (body.size() >= 2 && body.startsWith("\xFF\xFE"_ba)) {
        body.remove(0, 2);
        if (body.size() % 2 != 0)
            return {};
        const QString text = QString::fromUtf16(
            reinterpret_cast<const char16_t*>(body.constData()), body.size() / 2);
        if (ok)
            *ok = true;
        return text;
    }
    if (body.size() >= 2 && body.startsWith("\xFE\xFF"_ba)) {
        body.remove(0, 2);
        if (body.size() % 2 != 0)
            return {};
        for (qsizetype i = 0; i + 1 < body.size(); i += 2)
            std::swap(body[i], body[i + 1]);
        const QString text = QString::fromUtf16(
            reinterpret_cast<const char16_t*>(body.constData()), body.size() / 2);
        if (ok)
            *ok = true;
        return text;
    }

    QString text = QString::fromUtf8(body);
    if (ok)
        *ok = true;
    return text;
}

LyricsResult parseLrc(const QByteArray& data) {
    bool ok = false;
    const QString text = decodeLyricText(data, &ok);
    if (!ok)
        return {};

    LyricsResult result;
    qreal offset = 0.0;
    QStringList plain;
    qsizetype expandedBytes = 0;
    qsizetype expandedWords = 0;

    for (QString raw : text.split(u'\n')) {
        if (raw.endsWith(u'\r'))
            raw.chop(1);

        QString rest;
        const QVector<qreal> stamps = splitTimestamps(raw, rest);
        if (stamps.isEmpty()) {
            const QString trimmed = raw.trimmed();
            if (trimmed.startsWith(u'[') && trimmed.endsWith(u']')) {
                const qsizetype colon = trimmed.indexOf(u':');
                if (colon > 1) {
                    const QString name = trimmed.mid(1, colon - 1).trimmed().toLower();
                    const QString value = trimmed.mid(colon + 1, trimmed.size() - colon - 2).trimmed();
                    if (name == u"offset")
                        offset = parseOffset(value);
                    else if (name == u"ti")
                        result.title = value;
                    else if (name == u"ar")
                        result.artist = value;
                    else if (name == u"al")
                        result.album = value;
                    else if (name == u"length")
                        result.duration = clockSeconds(value);
                }
                continue;
            }
            const QString body = stripEnhanced(raw).trimmed();
            if (!body.isEmpty()) {
                plain.append(body);
                if (plain.size() > kMaxLyricsLines)
                    return {};
            }
            continue;
        }

        QString body = stripEnhanced(rest).trimmed();
        const QVector<LyricWord> words = splitWords(rest, stamps.first());
        if (body.isEmpty() && !words.isEmpty())
            body = joinLyricWords(words).trimmed();
        // Bare timestamp lines carry no displayable text. Keeping them would make
        // the renderer show placeholder rows instead of a gap.
        if (body.isEmpty())
            continue;
        plain.append(body);

        expandedBytes += body.size() * stamps.size();
        expandedWords += words.size() * stamps.size();
        if (result.synced.size() + stamps.size() > kMaxLyricsLines || plain.size() > kMaxLyricsLines
            || expandedBytes > kMaxLyricsBytes || expandedWords > kMaxLyricsWords)
            return {};

        for (const qreal at : stamps) {
            LyricLine line;
            line.time = at;
            line.text = body;
            for (const auto& word : words) {
                LyricWord shifted{ .time = at + (word.time - stamps.first()), .text = word.text };
                if (word.end > word.time)
                    shifted.end = at + (word.end - stamps.first());
                line.words.append(shifted);
            }
            result.synced.append(line);
        }
    }

    for (auto& line : result.synced) {
        line.time = shift(line.time, offset);
        if (line.end > 0.0)
            line.end = shift(line.end, offset);
        for (auto& word : line.words) {
            word.time = shift(word.time, offset);
            if (word.end > 0.0)
                word.end = shift(word.end, offset);
        }
    }

    sortLyricLines(result.synced);
    result.plain = plain.join(u'\n');
    result.found = !result.synced.isEmpty() || !result.plain.trimmed().isEmpty();
    return result;
}

LyricsResult parseTtml(const QByteArray& data) {
    // The word/character handling needs the element stack, so the real parser
    // keeps text collection separate from the XML event loop below.
    bool ok = false;
    QString text = decodeLyricText(data, &ok);
    if (!ok)
        return {};

    QXmlStreamReader reader(text);
    struct Scope {
        qreal start = -1.0;
        qreal end = -1.0;
        bool timed = false;
        bool wordTimed = false;
        bool skipped = false;
        bool background = false;
        QString voice;
        QString name;
        bool inName = false;
    };

    struct Part {
        qreal start = -1.0;
        qreal end = -1.0;
        QString voice;
        bool background = false;
        bool wordTimed = false;
        QString text;
        QVector<LyricWord> words;
    };

    QVector<Scope> scopes;
    QVector<Part> parts;
    QVector<LyricLine> lines;
    QStringList plain;
    QHash<QString, LyricVoice> voices;
    QString agent;
    QString agentName;
    bool rootSeen = false;
    bool inBody = false;
    bool inParagraph = false;
    int paragraph = 0;
    int wordCount = 0;

    auto partFor = [&](const Scope& scope) -> Part* {
        for (auto& part : parts) {
            if (part.voice == scope.voice && part.background == scope.background)
                return &part;
        }
        parts.append(Part{ .voice = scope.voice, .background = scope.background });
        return &parts.last();
    };

    auto finishParagraph = [&] {
        if (parts.isEmpty())
            return;
        const int group = parts.size() > 1 ? paragraph : 0;
        for (auto& part : parts) {
            QString bodyText = part.text.trimmed();
            QVector<LyricWord> words = part.words;
            if (part.wordTimed) {
                trimLyricWords(words);
                bodyText = joinLyricWords(words).trimmed();
            } else {
                words.clear();
            }
            if (bodyText.isEmpty())
                continue;

            // An untimed paragraph still contributes to plain lyrics, but it has
            // no place in the synced list (and must not make the whole result
            // look timed at 0:00).
            if (part.start < 0.0) {
                plain.append(bodyText);
                continue;
            }

            wordCount += words.size();
            if (lines.size() >= kMaxLyricsLines || wordCount > kMaxLyricsWords)
                break;
            for (auto& word : words)
                word.time = std::max(word.time, part.start);
            lines.append(LyricLine{ .time = part.start,
                .end = part.end > part.start ? part.end : 0.0,
                .text = bodyText,
                .words = words,
                .voice = part.voice,
                .background = part.background,
                .group = group });
            plain.append(bodyText);
        }
        parts.clear();
    };

    while (!reader.atEnd()) {
        reader.readNext();
        if (reader.hasError())
            return {};

        if (reader.isStartElement()) {
            const QString name = reader.name().toString();
            Scope scope = scopes.isEmpty() ? Scope{} : scopes.last();
            if (scopes.isEmpty()) {
                if (rootSeen || name != u"tt")
                    return {};
                rootSeen = true;
            }

            QString id;
            QString kind;
            qreal duration = -1.0;
            for (const auto& attr : reader.attributes()) {
                const QString attrName = attr.name().toString();
                if (attrName == u"begin" || attrName == u"end" || attrName == u"dur") {
                    const qreal at = parseTtmlTime(attr.value().toString());
                    if (at < 0.0)
                        return {};
                    if (attrName == u"begin") {
                        scope.start = at;
                        scope.timed = true;
                        scope.wordTimed = name == u"span";
                    } else if (attrName == u"end") {
                        scope.end = at;
                    } else {
                        duration = at;
                    }
                } else if (attrName == u"role") {
                    const QString role = attr.value().toString();
                    if (role == u"x-translation" || role == u"x-transliteration")
                        scope.skipped = true;
                    else if (role == u"x-bg")
                        scope.background = true;
                } else if (attrName == u"agent") {
                    scope.voice = attr.value().toString();
                } else if (attrName == u"id") {
                    id = attr.value().toString();
                } else if (attrName == u"type") {
                    kind = attr.value().toString();
                }
            }
            if (duration >= 0.0)
                scope.end = scope.start + duration;
            if (!finite(scope.end))
                return {};

            if (!inBody) {
                if (name == u"agent" && !id.isEmpty()) {
                    agent = id;
                    voices.insert(id, LyricVoice{ .name = {}, .type = kind });
                } else if (name == u"name" && !agent.isEmpty()) {
                    const QString existing = voices.value(agent).name;
                    if (kind == u"full" || existing.isEmpty()) {
                        scope.inName = true;
                        scope.name = agent;
                        agentName.clear();
                    }
                }
            }

            if (scopes.size() >= 32)
                return {};
            scopes.append(scope);
            if (name == u"body")
                inBody = true;
            if (!inBody || scope.skipped)
                continue;

            if (name == u"p") {
                if (inParagraph)
                    return {};
                if (++paragraph > kMaxLyricsLines)
                    return {};
                inParagraph = true;
            } else if (name == u"br") {
                Part* part = partFor(scope);
                part->text += u'\n';
                if (!part->words.isEmpty())
                    part->words.last().text += u'\n';
            }
        } else if (reader.isCharacters()) {
            if (scopes.isEmpty())
                continue;
            const Scope& scope = scopes.last();
            QString chunk = reader.text().toString();
            if (chunk.isEmpty())
                continue;

            if (scope.inName) {
                agentName += chunk;
                continue;
            }
            if (!inBody || scope.skipped || !inParagraph)
                continue;

            chunk = normalizeSpace(chunk);
            Part* part = partFor(scope);
            if (chunk.trimmed().isEmpty()) {
                // Keep the single separator between spans, and attach it to the
                // previous timed word so karaoke text still joins back exactly.
                if (!part->text.endsWith(u' '))
                    part->text += u' ';
                if (!part->words.isEmpty() && !part->words.last().text.endsWith(u' '))
                    part->words.last().text += u' ';
                continue;
            }

            part->wordTimed = part->wordTimed || scope.wordTimed;
            if (scope.timed) {
                part->start = part->start < 0.0 ? scope.start : std::min(part->start, scope.start);
                if (scope.end > scope.start)
                    part->end = std::max(part->end, scope.end);
            }
            part->text += chunk;

            const qreal at = scope.timed ? scope.start : -1.0;
            if (!part->words.isEmpty() && (!scope.wordTimed || part->words.last().time == at)) {
                part->words.last().text += chunk;
                if (scope.timed)
                    part->words.last().end = std::max(part->words.last().end, scope.end);
            } else {
                part->words.append(LyricWord{ .time = at,
                    .end = scope.timed && scope.end > at ? scope.end : 0.0,
                    .text = chunk });
            }
        } else if (reader.isEndElement()) {
            const QString name = reader.name().toString();
            if (name == u"name") {
                for (auto& scope : scopes) {
                    if (scope.inName && !scope.name.isEmpty()) {
                        auto it = voices.find(scope.name);
                        if (it != voices.end())
                            it->name = agentName.trimmed();
                        break;
                    }
                }
                agentName.clear();
            }
            if (name == u"p" && inParagraph) {
                finishParagraph();
                inParagraph = false;
            }
            if (name == u"body")
                inBody = false;
            if (name == u"agent")
                agent.clear();
            if (!scopes.isEmpty())
                scopes.removeLast();
        }
    }

    if (!rootSeen || !reader.atEnd())
        return {};
    if (inParagraph)
        finishParagraph();

    sortLyricLines(lines);
    LyricsResult result;
    result.synced = lines;
    result.plain = plain.join(u'\n');
    result.voices = voices;
    result.found = !lines.isEmpty() || !result.plain.trimmed().isEmpty();
    return result;
}

namespace {

[[nodiscard]] QString unquote(const QString& raw) {
    QString value = raw.trimmed();
    if (value.size() >= 2 && ((value.startsWith(u'"') && value.endsWith(u'"'))
                                 || (value.startsWith(u'\'') && value.endsWith(u'\'')))) {
        const QChar quote = value.front();
        value = value.mid(1, value.size() - 2);
        value.replace(quote == u'"' ? u"\\\""_s : u"\\'"_s, quote);
        value.replace(u"\\n"_s, u"\n"_s);
        value.replace(u"\\\\"_s, u"\\"_s);
    }
    return value;
}

[[nodiscard]] int indentation(const QString& line) {
    int count = 0;
    for (const QChar c : line) {
        if (c != u' ')
            break;
        ++count;
    }
    return count;
}

struct PendingWord {
    QString text;
    qint64 start = -1;
    qint64 end = -1;
};

struct PendingLine {
    QString text;
    qint64 start = -1;
    qint64 end = -1;
    QVector<PendingWord> words;
};

} // namespace

LyricsResult parseLyricsfile(const QByteArray& data) {
    bool ok = false;
    const QString text = decodeLyricText(data, &ok);
    if (!ok)
        return {};

    // Lyricsfile is YAML, but the format is a narrow, line-oriented subset:
    // metadata/plain scalars plus a lines list with optional words.
    QString version;
    QString title;
    QString artist;
    QString album;
    qint64 durationMs = 0;
    bool instrumental = false;
    QString plain;
    QVector<PendingLine> pendingLines;
    int currentLine = -1;
    int currentWord = -1;
    int currentLineIndent = -1;
    bool inLines = false;
    bool inWords = false;
    bool inPlainBlock = false;
    int plainIndent = 0;

    const QStringList rawLines = text.split(u'\n');
    for (QString raw : rawLines) {
        if (raw.endsWith(u'\r'))
            raw.chop(1);
        if (inPlainBlock) {
            if (raw.trimmed().isEmpty()) {
                plain += u"\n"_s;
                continue;
            }
            const int contentIndent = indentation(raw);
            if (contentIndent <= 0) {
                inPlainBlock = false;
            } else {
                if (plainIndent < 0)
                    plainIndent = contentIndent;
                if (contentIndent >= plainIndent) {
                    plain += (plain.isEmpty() ? QString() : u"\n"_s)
                        + raw.mid(std::min<qsizetype>(plainIndent, raw.size()));
                    continue;
                }
                inPlainBlock = false;
            }
        }

        const QString trimmed = raw.trimmed();
        if (trimmed.isEmpty() || trimmed.startsWith(u'#'))
            continue;
        const int indent = indentation(raw);

        // YAML also allows a block sequence at the same indentation as its key.
        if (indent == 0 && !(inLines && trimmed.startsWith(u"- "_s))) {
            inWords = false;
            inLines = false;
            const qsizetype colon = trimmed.indexOf(u':');
            if (colon < 0)
                continue;
            const QString key = trimmed.left(colon).trimmed();
            const QString value = trimmed.mid(colon + 1).trimmed();
            if (key == u"version")
                version = unquote(value);
            else if (key == u"lines")
                inLines = true;
            else if (key == u"plain") {
                if (value == u"|" || value == u">" || value == u"|-" || value == u"|+"
                    || value == u">-" || value == u">+") {
                    inPlainBlock = true;
                    plainIndent = -1;
                } else {
                    plain = unquote(value);
                }
            } else if (key == u"metadata") {
                // Also accept the compact single-line form from hand-written sidecars.
                if (value.startsWith(u'{') && value.endsWith(u'}')) {
                    const QStringList fields = value.mid(1, value.size() - 2).split(u',');
                    for (const QString& field : fields) {
                        const qsizetype fieldColon = field.indexOf(u':');
                        if (fieldColon < 0)
                            continue;
                        const QString fieldKey = field.left(fieldColon).trimmed();
                        const QString fieldValue = unquote(field.mid(fieldColon + 1));
                        if (fieldKey == u"title")
                            title = fieldValue;
                        else if (fieldKey == u"artist")
                            artist = fieldValue;
                        else if (fieldKey == u"album")
                            album = fieldValue;
                        else if (fieldKey == u"instrumental")
                            instrumental = fieldValue.compare(u"true"_s, Qt::CaseInsensitive) == 0;
                        else if (fieldKey == u"duration_ms") {
                            bool valid = false;
                            durationMs = fieldValue.toLongLong(&valid);
                            if (!valid)
                                durationMs = 0;
                        }
                    }
                }
            } else if (key != u"metadata")
                inLines = false;
            continue;
        }

        if (inLines) {
            const bool isItem = trimmed.startsWith(u"- ");
            const QString content = isItem ? trimmed.mid(2).trimmed() : trimmed;
            if (content == u"words:") {
                inWords = true;
                continue;
            }

            auto setLineField = [&](const QString& key, const QString& value) {
                if (currentLine < 0)
                    return;
                if (key == u"start_ms") {
                    bool valid = false;
                    const qint64 number = value.toLongLong(&valid);
                    if (valid)
                        pendingLines[currentLine].start = number;
                } else if (key == u"end_ms") {
                    bool valid = false;
                    const qint64 number = value.toLongLong(&valid);
                    if (valid)
                        pendingLines[currentLine].end = number;
                } else if (key == u"text")
                    pendingLines[currentLine].text = unquote(value);
            };

            // A line item starts at the line-list indentation. Word items are
            // nested deeper than the line they belong to, including the compact
            // YAML form where "words:" and its items share an indentation.
            const bool beginsLine = isItem && (currentLine < 0 || !inWords || indent <= currentLineIndent);
            if (beginsLine) {
                pendingLines.append(PendingLine{});
                currentLine = static_cast<int>(pendingLines.size()) - 1;
                currentWord = -1;
                currentLineIndent = indent;
                inWords = false;
                // The first key may share the list-item line, e.g. "- start_ms: 1200".
                const qsizetype colon = content.indexOf(u':');
                if (colon > 0)
                    setLineField(content.left(colon).trimmed(), content.mid(colon + 1).trimmed());
                continue;
            }

            if (isItem && currentLine >= 0 && inWords && indent > currentLineIndent) {
                auto& line = pendingLines[currentLine];
                line.words.append(PendingWord{});
                currentWord = static_cast<int>(line.words.size()) - 1;
                const qsizetype colon = content.indexOf(u':');
                if (colon > 0) {
                    const QString key = content.left(colon).trimmed();
                    const QString value = content.mid(colon + 1).trimmed();
                    if (key == u"start_ms") {
                        bool valid = false;
                        const qint64 number = value.toLongLong(&valid);
                        if (valid)
                            line.words[currentWord].start = number;
                    } else if (key == u"end_ms") {
                        bool valid = false;
                        const qint64 number = value.toLongLong(&valid);
                        if (valid)
                            line.words[currentWord].end = number;
                    } else if (key == u"text")
                        line.words[currentWord].text = unquote(value);
                }
                continue;
            }

            const qsizetype colon = content.indexOf(u':');
            if (colon < 0)
                continue;
            const QString key = content.left(colon).trimmed();
            const QString value = content.mid(colon + 1).trimmed();
            if (currentLine < 0)
                continue;
            const bool wordField = inWords && currentWord >= 0 && indent > currentLineIndent;
            if (key == u"start_ms") {
                bool valid = false;
                const qint64 number = value.toLongLong(&valid);
                if (valid) {
                    if (wordField)
                        pendingLines[currentLine].words[currentWord].start = number;
                    else
                        pendingLines[currentLine].start = number;
                }
            } else if (key == u"end_ms") {
                bool valid = false;
                const qint64 number = value.toLongLong(&valid);
                if (valid) {
                    if (wordField)
                        pendingLines[currentLine].words[currentWord].end = number;
                    else
                        pendingLines[currentLine].end = number;
                }
            } else if (key == u"text") {
                if (wordField)
                    pendingLines[currentLine].words[currentWord].text = unquote(value);
                else
                    pendingLines[currentLine].text = unquote(value);
            }
            continue;
        }

        // metadata block
        if (indent > 0) {
            const qsizetype colon = trimmed.indexOf(u':');
            if (colon < 0)
                continue;
            const QString key = trimmed.left(colon).trimmed();
            const QString value = trimmed.mid(colon + 1).trimmed();
            if (key == u"title")
                title = unquote(value);
            else if (key == u"artist")
                artist = unquote(value);
            else if (key == u"album")
                album = unquote(value);
            else if (key == u"duration_ms") {
                bool valid = false;
                durationMs = value.toLongLong(&valid);
                if (!valid)
                    durationMs = 0;
            } else if (key == u"instrumental")
                instrumental = value.compare(u"true"_s, Qt::CaseInsensitive) == 0;
        }
    }

    if (!version.isEmpty() && version != u"1.0")
        return {};

    LyricsResult result;
    result.title = title;
    result.artist = artist;
    result.album = album;
    result.duration = durationMs / 1000.0;
    result.instrumental = instrumental;
    result.plain = plain;
    if (instrumental) {
        result.found = true;
        return result;
    }

    for (const auto& source : pendingLines) {
        if (source.start < 0)
            return {};
        LyricLine line;
        line.time = source.start / 1000.0;
        if (source.end >= source.start)
            line.end = source.end / 1000.0;
        line.text = source.text;
        for (const auto& word : source.words) {
            if (word.start < 0)
                return {};
            line.words.append(LyricWord{ .time = word.start / 1000.0,
                .end = word.end >= word.start ? word.end / 1000.0 : 0.0,
                .text = word.text });
        }
        if (line.text.isEmpty())
            line.text = joinLyricWords(line.words);
        const QString joined = joinLyricWords(line.words);
        if (joined.trimmed() == line.text.trimmed() && !joined.trimmed().isEmpty()) {
            line.text = joined.trimmed();
            if (!line.words.isEmpty())
                line.time = std::min(line.time, line.words.first().time);
        } else {
            line.words.clear();
        }
        if (line.text.isEmpty())
            continue;
        result.synced.append(line);
        if (result.synced.size() > kMaxLyricsLines)
            return {};
    }

    sortLyricLines(result.synced);
    if (result.plain.isEmpty()) {
        QStringList texts;
        for (const auto& line : result.synced)
            texts.append(line.text);
        result.plain = texts.join(u'\n');
    }
    result.found = !result.synced.isEmpty() || !result.plain.trimmed().isEmpty();
    return result;
}

LyricsResult parseKrc(const QByteArray& data) {
    if (!data.startsWith("krc1"_ba))
        return {};
    static const QByteArray key = QByteArray::fromRawData(
        "\x40\x47\x61\x77\x5e\x32\x74\x47\x51\x36\x31\x2d\xce\xd2\x6e\x69", 16);
    QByteArray compressed = data.mid(4);
    for (qsizetype i = 0; i < compressed.size(); ++i)
        compressed[i] = compressed[i] ^ key.at(i % key.size());

    z_stream stream{};
    stream.next_in = reinterpret_cast<Bytef*>(compressed.data());
    stream.avail_in = static_cast<uInt>(compressed.size());
    // KRC payloads are gzip-compressed after the XOR pass, but accept plain
    // zlib streams too so locally produced files still parse.
    const bool gzip = compressed.size() >= 2 && static_cast<uchar>(compressed.at(0)) == 0x1f
        && static_cast<uchar>(compressed.at(1)) == 0x8b;
    if (inflateInit2(&stream, (gzip ? 16 : 0) + MAX_WBITS) != Z_OK)
        return {};
    QByteArray out;
    char buffer[16384];
    int ret = Z_OK;
    do {
        stream.next_out = reinterpret_cast<Bytef*>(buffer);
        stream.avail_out = sizeof(buffer);
        ret = ::inflate(&stream, Z_NO_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END) {
            inflateEnd(&stream);
            return {};
        }
        out.append(buffer, static_cast<qsizetype>(sizeof(buffer)) - stream.avail_out);
        if (out.size() > kMaxLyricsBytes) {
            inflateEnd(&stream);
            return {};
        }
    } while (ret != Z_STREAM_END);
    inflateEnd(&stream);
    if (ret != Z_STREAM_END)
        return {};

    const QString text = QString::fromUtf8(out);
    static const QRegularExpression k_line(u"^\\[(\\d+),(\\d+)\\](.*)$"_s);
    static const QRegularExpression k_word(u"<(\\d+),(\\d+),\\d+>([^<]*)"_s);

    LyricsResult result;
    for (const QString& raw : text.split(u'\n')) {
        const QString lineText = raw.trimmed();
        const auto lineMatch = k_line.match(lineText);
        if (!lineMatch.hasMatch())
            continue;
        bool okStart = false;
        bool okLength = false;
        const qint64 startMs = lineMatch.captured(1).toLongLong(&okStart);
        const qint64 lengthMs = lineMatch.captured(2).toLongLong(&okLength);
        if (!okStart || !okLength)
            continue;
        LyricLine line;
        line.time = startMs / 1000.0;
        line.end = (startMs + lengthMs) / 1000.0;
        const QString body = lineMatch.captured(3);
        auto words = k_word.globalMatch(body);
        while (words.hasNext()) {
            const auto match = words.next();
            bool okOffset = false;
            bool okSpan = false;
            const qint64 offset = match.captured(1).toLongLong(&okOffset);
            const qint64 span = match.captured(2).toLongLong(&okSpan);
            if (!okOffset || !okSpan)
                continue;
            line.words.append(LyricWord{ .time = (startMs + offset) / 1000.0,
                .end = (startMs + offset + span) / 1000.0,
                .text = match.captured(3) });
        }
        if (line.words.isEmpty())
            continue;
        trimLyricWords(line.words);
        line.text = joinLyricWords(line.words).trimmed();
        if (line.text.isEmpty())
            continue;
        if (result.synced.size() >= kMaxLyricsLines)
            return {};
        result.synced.append(line);
        result.plain += (result.plain.isEmpty() ? QString() : u"\n"_s) + line.text;
    }

    sortLyricLines(result.synced);
    result.found = !result.synced.isEmpty();
    return result;
}

LyricsResult parseQrc(const QString& xml) {
    static const QRegularExpression k_content(u"LyricContent=\"([\\s\\S]*?)\"[^>]*/>"_s);
    const auto contentMatch = k_content.match(xml);
    if (!contentMatch.hasMatch())
        return {};

    QString content = contentMatch.captured(1);
    content.replace(u"&#10;"_s, u"\n"_s);
    content.replace(u"&#13;"_s, u"\r"_s);
    content.replace(u"&lt;"_s, u"<"_s);
    content.replace(u"&gt;"_s, u">"_s);
    content.replace(u"&quot;"_s, u"\""_s);
    content.replace(u"&apos;"_s, u"'"_s);
    content.replace(u"&amp;"_s, u"&"_s);

    static const QRegularExpression k_line(u"^\\[(\\d+),(\\d+)\\](.*)$"_s);
    static const QRegularExpression k_word(u"\\((\\d+),(\\d+)\\)"_s);

    LyricsResult result;
    for (const QString& raw : content.split(u'\n')) {
        const auto lineMatch = k_line.match(raw.trimmed());
        if (!lineMatch.hasMatch())
            continue;
        bool okStart = false;
        bool okLength = false;
        const qint64 startMs = lineMatch.captured(1).toLongLong(&okStart);
        const qint64 lengthMs = lineMatch.captured(2).toLongLong(&okLength);
        if (!okStart || !okLength)
            continue;

        const QString body = lineMatch.captured(3);
        QVector<LyricWord> words;
        qsizetype previous = 0;
        bool timedWords = false;
        qint64 lastWordEnd = startMs;
        auto matches = k_word.globalMatch(body);
        while (matches.hasNext()) {
            const auto match = matches.next();
            bool okWordStart = false;
            bool okWordSpan = false;
            const qint64 wordStart = match.captured(1).toLongLong(&okWordStart);
            const qint64 wordSpan = match.captured(2).toLongLong(&okWordSpan);
            if (!okWordStart || !okWordSpan)
                return {};
            timedWords = true;

            // QRC writes the timestamp after the syllables it belongs to:
            // "[lineStart,lineDur]For (absStart,dur)the (absStart,dur)...".
            const QString segment = body.mid(previous, match.capturedStart() - previous);
            if (!segment.isEmpty()) {
                words.append(LyricWord{ .time = wordStart / 1000.0,
                    .end = (wordStart + wordSpan) / 1000.0,
                    .text = segment });
            }
            lastWordEnd = wordStart + wordSpan;
            previous = match.capturedEnd();
        }
        if (previous < body.size()) {
            // A missing final marker means the remaining text belongs to the
            // end of the line.
            const qint64 lineEnd = startMs + lengthMs;
            const qint64 tailStart = qBound(startMs, lastWordEnd, lineEnd);
            words.append(LyricWord{ .time = tailStart / 1000.0,
                .end = lineEnd / 1000.0,
                .text = body.mid(previous) });
        }
        trimLyricWords(words);
        if (!timedWords)
            words.clear();
        if (words.isEmpty() && body.trimmed().isEmpty())
            continue;

        LyricLine line;
        line.time = startMs / 1000.0;
        line.end = (startMs + lengthMs) / 1000.0;
        line.words = words;
        line.text = words.isEmpty() ? body.trimmed() : joinLyricWords(words).trimmed();
        // Whole-line parentheses are the QRC convention for backing vocals.
        if (line.text.startsWith(u'(') && line.text.endsWith(u')') && line.text.size() > 2) {
            line.background = true;
            if (line.words.isEmpty()) {
                line.text = line.text.mid(1, line.text.size() - 2).trimmed();
            } else {
                if (line.words.first().text.startsWith(u'('))
                    line.words.first().text.remove(0, 1);
                if (!line.words.isEmpty() && line.words.last().text.endsWith(u')'))
                    line.words.last().text.chop(1);
                trimLyricWords(line.words);
                line.text = line.words.isEmpty() ? QString() : joinLyricWords(line.words).trimmed();
            }
        }
        if (line.text.isEmpty())
            continue;
        if (result.synced.size() >= kMaxLyricsLines)
            return {};
        result.synced.append(line);
        result.plain += (result.plain.isEmpty() ? QString() : u"\n"_s) + line.text;
    }

    sortLyricLines(result.synced);
    result.found = !result.synced.isEmpty();
    return result;
}

LyricsResult parseLyricsPlus(const QJsonObject& object) {
    const QString type = object.value(u"type"_s).toString();
    const bool wordType = type.compare(u"Word"_s, Qt::CaseInsensitive) == 0;
    const bool lineType = type.compare(u"Line"_s, Qt::CaseInsensitive) == 0;
    const QJsonArray source = object.value(u"lyrics"_s).toArray();
    if (source.size() > kMaxLyricsLines)
        return {};

    LyricsResult result;
    QVector<LyricLine> romanized;
    bool transliterated = false;
    const QJsonObject agents = object.value(u"metadata"_s).toObject().value(u"agents"_s).toObject();
    for (auto it = agents.constBegin(); it != agents.constEnd(); ++it) {
        const QJsonObject agent = it.value().toObject();
        QString key = it.key();
        if (!agent.value(u"alias"_s).toString().isEmpty())
            key = agent.value(u"alias"_s).toString();
        result.voices.insert(key, LyricVoice{ .name = agent.value(u"name"_s).toString(),
                                .type = agent.value(u"type"_s).toString() });
    }

    int wordCount = 0;
    int index = 0;
    const auto appendRomanized = [&](const LyricLine& line, const QString& transliteration) {
        LyricLine converted;
        converted.time = line.time;
        converted.end = line.end;
        converted.voice = line.voice;
        converted.background = line.background;
        converted.group = line.group;
        converted.text = transliteration.isEmpty() ? line.text : transliteration;
        romanized.append(converted);
    };
    for (const auto& value : source) {
        ++index;
        const QJsonObject entry = value.toObject();
        const QString text = entry.value(u"text"_s).toString();
        result.plain += (result.plain.isEmpty() ? QString() : u"\n"_s) + text;
        if (!wordType && !lineType)
            continue;
        if (!entry.contains(u"time"_s) || entry.value(u"time"_s).toInt(-1) < 0)
            continue;

        const qint64 startMs = entry.value(u"time"_s).toInteger(0);
        const qint64 durationMs = entry.value(u"duration"_s).toInteger(0);
        LyricLine line;
        line.time = startMs / 1000.0;
        if (durationMs > 0)
            line.end = (startMs + durationMs) / 1000.0;
        line.text = text;
        line.voice = entry.value(u"element"_s).toObject().value(u"singer"_s).toString();
        const QString transliteration =
            entry.value(u"transliteration"_s).toObject().value(u"text"_s).toString().trimmed();
        transliterated = transliterated || !transliteration.isEmpty();

        if (wordType) {
            const QJsonArray syllables = entry.value(u"syllabus"_s).toArray();
            bool valid = true;
            for (const auto& syllableValue : syllables) {
                const QJsonObject syllable = syllableValue.toObject();
                if (!syllable.contains(u"time"_s) || syllable.value(u"time"_s).toInteger(-1) < startMs) {
                    valid = false;
                    break;
                }
                const qint64 wordStart = syllable.value(u"time"_s).toInteger(0);
                const qint64 wordDuration = syllable.value(u"duration"_s).toInteger(0);
                line.words.append(LyricWord{ .time = wordStart / 1000.0,
                    .end = wordDuration > 0 ? (wordStart + wordDuration) / 1000.0 : 0.0,
                    .text = syllable.value(u"text"_s).toString() });
            }
            wordCount += line.words.size();
            if (!valid || line.words.isEmpty()
                || joinLyricWords(line.words).trimmed() != line.text.trimmed())
                line.words.clear();
            else
                line.text = line.text.trimmed();
        }

        if (line.words.isEmpty()) {
            result.synced.append(line);
            appendRomanized(line, transliteration);
            continue;
        }

        // Split lead and backing vocals into separate lines sharing a group id.
        bool hasBackground = false;
        for (const auto& syllableValue : entry.value(u"syllabus"_s).toArray()) {
            if (syllableValue.toObject().value(u"isBackground"_s).toBool(false)) {
                hasBackground = true;
                break;
            }
        }
        if (!hasBackground) {
            result.synced.append(line);
            appendRomanized(line, transliteration);
            continue;
        }

        QVector<LyricLine> split;
        for (const bool background : { false, true }) {
            LyricLine part;
            part.voice = line.voice;
            part.background = background;
            const QJsonArray syllables = entry.value(u"syllabus"_s).toArray();
            for (qsizetype i = 0; i < line.words.size() && i < syllables.size(); ++i) {
                if (syllables.at(i).toObject().value(u"isBackground"_s).toBool(false) == background)
                    part.words.append(line.words.at(i));
            }
            trimLyricWords(part.words);
            if (part.words.isEmpty())
                continue;
            part.time = part.words.first().time;
            for (const auto& word : part.words) {
                part.time = std::min(part.time, word.time);
                part.end = std::max(part.end, word.end);
            }
            part.text = joinLyricWords(part.words).trimmed();
            part.group = index;
            split.append(part);
        }
        result.synced += split;
        for (const auto& part : split)
            appendRomanized(part, transliteration);
        if (wordCount > kMaxLyricsWords || result.synced.size() > kMaxLyricsLines)
            return {};
    }

    sortLyricLines(result.synced);
    if (transliterated && romanized.size() == result.synced.size()) {
        sortLyricLines(romanized);
        result.romanized = std::move(romanized);
    }
    result.found = !result.synced.isEmpty() || !result.plain.trimmed().isEmpty();
    return result;
}

QString stripLyricMarkup(const QString& text) {
    static const QRegularExpression k_tag(u"<[A-Za-z/!?][^<>]*>"_s);
    static const QRegularExpression k_open(u"<[A-Za-z/!?]"_s);
    QString out = text;
    for (int i = 0; i < 8 && out.contains(u'<'); ++i) {
        QString next = out;
        next.remove(k_tag);
        if (next == out)
            next.remove(k_open);
        if (next == out)
            break;
        out = next;
    }
    return out;
}

void stripLyricMarkup(LyricsResult& result) {
    result.attributionName = stripLyricMarkup(result.attributionName);
    result.attributionText = stripLyricMarkup(result.attributionText);
    result.plain = stripLyricMarkup(result.plain);
    result.title = stripLyricMarkup(result.title);
    result.artist = stripLyricMarkup(result.artist);
    result.album = stripLyricMarkup(result.album);
    for (auto& line : result.synced) {
        line.text = stripLyricMarkup(line.text);
        for (auto& word : line.words)
            word.text = stripLyricMarkup(word.text);
    }
    for (auto& line : result.romanized) {
        line.text = stripLyricMarkup(line.text);
        for (auto& word : line.words)
            word.text = stripLyricMarkup(word.text);
    }
}

} // namespace caelestia::services
