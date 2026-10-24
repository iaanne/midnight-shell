#pragma once

#include <qbytearray.h>
#include <qjsonobject.h>
#include <qstring.h>

#include "lyricstypes.hpp"

namespace caelestia::services {

// Enhanced LRC: multiple timestamps per line, <mm:ss.xx> word timing, [offset:].
[[nodiscard]] LyricsResult parseLrc(const QByteArray& data);

// TTML with ttm:agent voices and the x-bg / x-translation roles.
[[nodiscard]] LyricsResult parseTtml(const QByteArray& data);

// Lyricsfile 1.0, the subset used by LRCLIB and local sidecar files.
[[nodiscard]] LyricsResult parseLyricsfile(const QByteArray& data);

// KuGou KRC. Caller passes the de-obfuscated document ("krc1" header included).
[[nodiscard]] LyricsResult parseKrc(const QByteArray& data);

// QQ Music QRC XML, including the per-word timings the old parser discarded.
[[nodiscard]] LyricsResult parseQrc(const QString& xml);

// LyricsPlus v2 JSON.
[[nodiscard]] LyricsResult parseLyricsPlus(const QJsonObject& object);

// Removes HTML-like markup from provider text the same way the DMS engine does.
[[nodiscard]] QString stripLyricMarkup(const QString& text);
void stripLyricMarkup(LyricsResult& result);

[[nodiscard]] QString decodeLyricText(const QByteArray& data, bool* ok = nullptr);

} // namespace caelestia::services
