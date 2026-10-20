pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n

// Read-only Last.fm integration: profile, recent scrobbles and the artist /
// album behind a selected scrobble. Nothing here writes to Last.fm, so only
// unsigned Web API methods are used and no session key is needed.
Singleton {
    id: root

    readonly property string apiBase: "https://ws.audioscrobbler.com/2.0/"
    readonly property var requestHeaders: ({
        "User-Agent": "MidnightShell/1.0"
    })

    readonly property bool enabled: GlobalConfig.services.lastfmEnabled ?? false
    readonly property string username: (GlobalConfig.services.lastfmUsername ?? "").trim()
    readonly property string apiKey: (GlobalConfig.services.lastfmApiKey ?? "").trim()
    readonly property bool hasCredentials: username !== "" && apiKey !== ""
    readonly property bool configured: enabled && hasCredentials
    readonly property bool keyLooksValid: /^[0-9a-f]{32}$/i.test(apiKey)

    property var profile: null
    property var recentTracks: []
    property int selectedIndex: 0
    property var artist: null
    property var album: null

    property bool loadingProfile: false
    property bool loadingRecent: false
    property int pendingDetails: 0

    property string error: ""
    property double lastRecentRefresh: 0
    // Bumped when credentials or the integration state change, so responses
    // for the previous account cannot repopulate the feed.
    property int feedGeneration: 0
    property int detailGeneration: 0

    // Surfaces (dashboard tab, desktop widgets) acquire while visible so the
    // service only polls when something actually displays the data.
    property int activeSurfaces: 0

    readonly property bool loadingDetails: pendingDetails > 0
    readonly property var nowPlaying: recentTracks.find(track => track.nowPlaying) ?? null
    readonly property var selectedTrack: {
        if (recentTracks.length === 0)
            return null;
        return recentTracks[Math.max(0, Math.min(selectedIndex, recentTracks.length - 1))] ?? null;
    }

    property var cache: ({})

    readonly property int profileTtl: 5 * 60 * 1000
    readonly property int recentTtl: 20 * 1000
    readonly property int detailTtl: 60 * 60 * 1000

    function acquire(): void {
        activeSurfaces++;
        if (activeSurfaces === 1 && configured)
            reload(false);
    }

    function release(): void {
        activeSurfaces = Math.max(0, activeSurfaces - 1);
    }

    function credentialsChanged(): void {
        cache = ({});
        error = "";
        feedGeneration++;
        detailGeneration++;

        loadingProfile = false;
        loadingRecent = false;
        pendingDetails = 0;
        profile = null;
        recentTracks = [];
        artist = null;
        album = null;
        selectedIndex = 0;
        lastRecentRefresh = 0;

        if (configured && activeSurfaces > 0)
            reload(true);
    }

    function reload(force: bool): void {
        if (!hasCredentials)
            return;
        refreshProfile(force === true);
        refreshRecent(force === true);
    }

    function refreshProfile(force: bool): void {
        if (!hasCredentials || loadingProfile)
            return;

        const key = `profile:${username.toLowerCase()}`;
        const cached = cacheGet(key, profileTtl, force === true);
        if (cached !== undefined) {
            profile = cached;
            return;
        }

        loadingProfile = true;
        const generation = feedGeneration;
        request("user.getInfo", { user: username }, data => {
            if (generation !== feedGeneration)
                return;
            loadingProfile = false;
            if (!data || !data.user) {
                console.warn("Last.fm profile request returned no user");
                return;
            }
            profile = normalizeUser(data.user);
            cachePut(key, profile);
        }, message => {
            if (generation !== feedGeneration)
                return;
            loadingProfile = false;
            console.warn("Last.fm profile request failed:", sanitizeError(message));
        });
    }

    function refreshRecent(force: bool): void {
        if (!hasCredentials || loadingRecent)
            return;
        if (force !== true && Date.now() - lastRecentRefresh < 10000)
            return;

        const key = `recent:${username.toLowerCase()}`;
        const cached = cacheGet(key, recentTtl, force === true);
        if (cached !== undefined) {
            applyRecent(cached, true);
            return;
        }

        loadingRecent = true;
        const generation = feedGeneration;
        const limit = Math.max(1, Math.min(50, GlobalConfig.services.lastfmRecentLimit ?? 10));
        request("user.getRecentTracks", { user: username, limit: limit, extended: 1 }, data => {
            if (generation !== feedGeneration)
                return;
            loadingRecent = false;
            const raw = data?.recenttracks?.track;
            const tracks = asList(raw).map(normalizeTrack).filter(track => track && track.name !== "");
            lastRecentRefresh = Date.now();
            cachePut(key, tracks);
            error = "";
            applyRecent(tracks, true);
        }, message => {
            if (generation !== feedGeneration)
                return;
            loadingRecent = false;
            error = message;
        });
    }

    function applyRecent(tracks: var, preserveSelection: bool): void {
        const previous = preserveSelection ? trackKey(selectedTrack) : "";
        recentTracks = tracks;

        if (tracks.length === 0)
            selectedIndex = 0;
        else if (previous !== "")
            selectedIndex = Math.max(0, tracks.findIndex(track => trackKey(track) === previous));
        else
            selectedIndex = 0;

        loadDetails();
    }

    function trackKey(track: var): string {
        if (!track)
            return "";
        return `${track.name}|${track.artist}|${track.timestamp}`;
    }

    function selectTrack(index: int): void {
        if (index < 0 || index >= recentTracks.length || index === selectedIndex)
            return;
        selectedIndex = index;
        loadDetails();
    }

    function loadDetails(): void {
        const track = selectedTrack;
        const generation = ++detailGeneration;

        pendingDetails = 0;
        artist = null;
        album = null;

        if (!track)
            return;

        loadArtist(track.artist, generation);
        if (track.album !== "")
            loadAlbum(track.artist, track.album, generation);
    }

    function loadArtist(name: string, generation: int): void {
        if (name === "") {
            if (generation === detailGeneration)
                artist = null;
            return;
        }

        const key = `artist:${username.toLowerCase()}:${name.toLowerCase()}`;
        const cached = cacheGet(key, detailTtl, false);
        if (cached !== undefined) {
            if (generation === detailGeneration)
                artist = cached;
            return;
        }

        pendingDetails++;
        request("artist.getInfo", { artist: name }, data => {
            if (generation !== detailGeneration)
                return;
            pendingDetails = Math.max(0, pendingDetails - 1);
            if (!data || !data.artist)
                return;
            artist = normalizeArtist(data.artist);
            cachePut(key, artist);
        }, message => {
            if (generation !== detailGeneration)
                return;
            pendingDetails = Math.max(0, pendingDetails - 1);
            // Detail failures are non-fatal; the recent list still works.
            console.warn("Last.fm artist request failed:", sanitizeError(message));
        });
    }

    function loadAlbum(artistName: string, albumName: string, generation: int): void {
        if (artistName === "" || albumName === "") {
            if (generation === detailGeneration)
                album = null;
            return;
        }

        const key = `album:${username.toLowerCase()}:${artistName.toLowerCase()}:${albumName.toLowerCase()}`;
        const cached = cacheGet(key, detailTtl, false);
        if (cached !== undefined) {
            if (generation === detailGeneration)
                album = cached;
            return;
        }

        pendingDetails++;
        request("album.getInfo", { artist: artistName, album: albumName }, data => {
            if (generation !== detailGeneration)
                return;
            pendingDetails = Math.max(0, pendingDetails - 1);
            if (!data || !data.album)
                return;
            album = normalizeAlbum(data.album);
            cachePut(key, album);
        }, message => {
            if (generation !== detailGeneration)
                return;
            pendingDetails = Math.max(0, pendingDetails - 1);
            console.warn("Last.fm album request failed:", sanitizeError(message));
        });
    }

    // Used by the Nexus page. Works even while the integration is disabled, so
    // the key can be checked before turning the surfaces on.
    function testConnection(callback: var): void {
        if (username === "" || apiKey === "") {
            callback(false, Tr.tr("Enter a username and an API key first"));
            return;
        }

        Requests.get(apiUrl("user.getInfo", { user: username }), text => {
            let data;
            try {
                data = JSON.parse(text);
            } catch (e) {
                callback(false, Tr.tr("Last.fm returned an unreadable response"));
                return;
            }

            if (data?.user) {
                callback(true, Tr.tr("Connected as %1").arg(data.user.name ?? username));
                return;
            }

            callback(false, data?.message ?? Tr.tr("Last.fm rejected the request"));
        }, (message, metadata) => {
            const status = metadata?.statusCode ?? 0;
            callback(false, classifyError(message, status));
        }, requestHeaders);
    }

    function clearCache(): void {
        cache = ({});
    }

    function apiUrl(method: string, params: var): string {
        let url = `${apiBase}?method=${encodeURIComponent(method)}&api_key=${encodeURIComponent(apiKey)}&format=json&autocorrect=1`;
        for (const key in params) {
            const value = params[key];
            if (value === undefined || value === null || value === "")
                continue;
            url += `&${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
        }
        return url;
    }

    function request(method: string, params: var, onSuccess: var, onError: var): void {
        if (apiKey === "") {
            if (onError)
                onError(Tr.tr("Set up your Last.fm API key first"));
            return;
        }

        Requests.get(apiUrl(method, params), (text, metadata) => {
            let data;
            try {
                data = JSON.parse(text);
            } catch (e) {
                if (onError)
                    onError(Tr.tr("Last.fm returned an unreadable response"));
                return;
            }

            if (data && data.error) {
                if (onError)
                    onError(data.message ?? Tr.tr("Last.fm rejected the request"));
                return;
            }

            if (onSuccess)
                onSuccess(data, metadata);
        }, (message, metadata) => {
            const status = metadata?.statusCode ?? 0;
            if (onError)
                onError(classifyError(message, status));
        }, requestHeaders);
    }

    function sanitizeError(message: string): string {
        return String(message ?? "")
            .replace(/https?:\/\/\S+\?\S+/g, "Last.fm")
            .replace(/api_key=[^&\s]+/gi, "api_key=…")
            .replace(/\s+/g, " ")
            .trim();
    }

    function classifyError(message: string, status: int): string {
        if (status === 400 || status === 403)
            return Tr.tr("Last.fm rejected the request. Check the username and API key.");
        if (status > 0)
            return Tr.tr("Last.fm request failed (HTTP %1)").arg(status);
        const clean = sanitizeError(message);
        return clean !== "" ? clean : Tr.tr("Could not reach Last.fm");
    }

    function cacheGet(key: string, ttl: int, force: bool): var {
        if (force)
            return undefined;
        const entry = cache[key];
        if (!entry)
            return undefined;
        if (Date.now() - entry.at > ttl)
            return undefined;
        return entry.value;
    }

    function cachePut(key: string, value: var): void {
        cache[key] = {
            at: Date.now(),
            value: value
        };
    }

    function asList(value: var): var {
        if (value === undefined || value === null)
            return [];
        return Array.isArray(value) ? value : [value];
    }

    function textOf(value: var): string {
        if (value === undefined || value === null)
            return "";
        if (typeof value === "string")
            return value;
        if (typeof value === "number")
            return String(value);
        return value["#text"] ?? value.name ?? "";
    }

    function imageOf(images: var): string {
        const list = asList(images);
        const sizes = ["mega", "extralarge", "large", "medium", "small"];

        for (const size of sizes) {
            for (const image of list) {
                if (image && image.size === size && textOf(image) !== "")
                    return textOf(image);
            }
        }

        for (const image of list) {
            const url = textOf(image);
            if (url !== "")
                return url;
        }

        return "";
    }

    function plainText(html: var): string {
        if (!html)
            return "";
        return String(html)
            .replace(/<a[^>]*>\s*Read more on Last\.fm\s*<\/a>\.?/gi, "")
            .replace(/<[^>]+>/g, " ")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;/g, "'")
            .replace(/\s+/g, " ")
            .trim();
    }

    function normalizeTrack(track: var): var {
        if (!track)
            return null;
        return {
            name: textOf(track.name),
            artist: textOf(track.artist),
            album: textOf(track.album),
            image: imageOf(track.image),
            url: track.url ?? "",
            loved: track.loved === "1" || track.loved === 1 || track.loved === true,
            nowPlaying: track["@attr"]?.nowplaying === "true",
            timestamp: Number(track.date?.uts ?? 0),
            mbid: track.mbid ?? ""
        };
    }

    function normalizeUser(user: var): var {
        return {
            name: user.name ?? "",
            realname: user.realname ?? "",
            image: imageOf(user.image),
            url: user.url ?? "",
            country: user.country ?? "",
            age: Number(user.age ?? 0),
            subscriber: user.subscriber === "1" || user.subscriber === 1 || user.subscriber === true,
            playcount: Number(user.playcount ?? 0),
            artistCount: Number(user.artist_count ?? 0),
            albumCount: Number(user.album_count ?? 0),
            trackCount: Number(user.track_count ?? 0),
            registered: Number(user.registered?.unixtime ?? 0)
        };
    }

    function normalizeArtist(artistInfo: var): var {
        return {
            name: artistInfo.name ?? "",
            image: imageOf(artistInfo.image),
            url: artistInfo.url ?? "",
            listeners: Number(artistInfo.stats?.listeners ?? 0),
            playcount: Number(artistInfo.stats?.playcount ?? 0),
            tags: asList(artistInfo.tags?.tag).map(textOf).filter(tag => tag !== "").slice(0, 6),
            similar: asList(artistInfo.similar?.artist).map(similar => ({
                name: similar?.name ?? "",
                url: similar?.url ?? "",
                image: imageOf(similar?.image)
            })).filter(similar => similar.name !== "").slice(0, 4),
            bio: plainText(artistInfo.bio?.summary ?? "")
        };
    }

    function normalizeAlbum(albumInfo: var): var {
        return {
            name: albumInfo.name ?? "",
            artist: textOf(albumInfo.artist),
            image: imageOf(albumInfo.image),
            url: albumInfo.url ?? "",
            listeners: Number(albumInfo.listeners ?? 0),
            playcount: Number(albumInfo.playcount ?? 0),
            releaseDate: albumInfo.releasedate ?? "",
            tracks: asList(albumInfo.tracks?.track).map(track => ({
                name: track?.name ?? "",
                duration: Number(track?.duration ?? 0)
            })).filter(track => track.name !== ""),
            tags: asList(albumInfo.tags?.tag).map(textOf).filter(tag => tag !== "").slice(0, 6),
            wiki: plainText(albumInfo.wiki?.summary ?? "")
        };
    }

    function formatCount(value: var): string {
        const number = Math.round(Number(value));
        if (isNaN(number))
            return "0";
        const separator = Qt.locale().groupSeparator || ",";
        return number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, separator);
    }

    function formatDate(uts: var): string {
        const seconds = Number(uts);
        if (!seconds || isNaN(seconds))
            return "";
        return Qt.formatDateTime(new Date(seconds * 1000), "d MMM yyyy");
    }

    function formatDuration(seconds: var): string {
        const total = Number(seconds);
        if (!total || isNaN(total))
            return "";
        const mins = Math.floor(total / 60);
        const secs = Math.floor(total % 60).toString().padStart(2, "0");
        return `${mins}:${secs}`;
    }

    function relativeTime(uts: var): string {
        const seconds = Number(uts);
        if (!seconds || isNaN(seconds))
            return "";

        const diff = Math.max(0, Math.floor(Date.now() / 1000 - seconds));
        if (diff < 60)
            return Tr.tr("Just now");

        const mins = Math.floor(diff / 60);
        if (mins < 60)
            return Tr.trCtxN("%1 min ago", "%1 mins ago", mins, "relative time").arg(mins);

        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return Tr.trCtxN("%1 hour ago", "%1 hours ago", hours, "relative time").arg(hours);

        const days = Math.floor(hours / 24);
        if (days < 30)
            return Tr.trCtxN("%1 day ago", "%1 days ago", days, "relative time").arg(days);

        return formatDate(seconds);
    }

    Timer {
        id: pollTimer

        interval: Math.max(10000, GlobalConfig.services.lastfmRefreshInterval ?? 30000)
        repeat: true
        running: root.activeSurfaces > 0 && root.configured
        triggeredOnStart: true
        onTriggered: {
            root.refreshRecent(false);
            // Cached for five minutes, so this only hits the API occasionally.
            root.refreshProfile(false);
        }
    }

    Connections {
        function onLastfmEnabledChanged(): void {
            root.credentialsChanged();
        }

        function onLastfmUsernameChanged(): void {
            root.credentialsChanged();
        }

        function onLastfmApiKeyChanged(): void {
            root.credentialsChanged();
        }

        target: GlobalConfig.services
    }
}
