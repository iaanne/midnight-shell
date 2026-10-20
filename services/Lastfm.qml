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
    property double lastRecentAttempt: 0
    property double lastProfileRefresh: 0
    property double lastProfileAttempt: 0
    // Bumped when credentials or the integration state change, so responses
    // for the previous account cannot repopulate the feed.
    property int feedGeneration: 0
    property int detailGeneration: 0
    property int metadataGeneration: 0

    // Dashboard and desktop widget surfaces are tracked separately. The
    // dashboard keeps the global poll timer; every widget owns its own timer.
    property int activeSurfaces: 0
    property int dashboardSurfaces: 0
    property int widgetSurfaces: 0

    // Charts are shared by every widget that requests the same range. Each
    // entry is replaced (rather than mutated) so QML bindings refresh.
    property var charts: ({})
    property var chartRefs: ({})
    property var chartJobs: ({})
    property var chartQueue: []
    property bool chartRequestActive: false
    // Monotonic id for chart jobs. Resetting the chart maps must not let an
    // old response match a new job that happens to reuse the same key.
    property int chartJobSerial: 0

    // Metadata for cover overlays. These are cached separately from charts,
    // because release years and album names rarely change.
    property var albumYears: ({})
    property var trackDetails: ({})
    property var artistImages: ({})
    property double artistImagesAt: 0

    readonly property int chartTtl: 60 * 60 * 1000
    readonly property int chartRequestInterval: 250
    readonly property int chartPageLimit: 200
    readonly property int chartItemLimit: 50
    readonly property int maxChartPages: 1000
    readonly property int metadataTtl: 24 * 60 * 60 * 1000
    readonly property int metadataErrorTtl: 5 * 60 * 1000
    readonly property int minAutoRefreshMs: 10000
    readonly property int maxTimerMs: 2147483647

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
        dashboardSurfaces++;
        if (dashboardSurfaces === 1 && configured)
            reload(false);
    }

    function release(): void {
        activeSurfaces = Math.max(0, activeSurfaces - 1);
        dashboardSurfaces = Math.max(0, dashboardSurfaces - 1);
    }

    function acquireWidget(): void {
        activeSurfaces++;
        widgetSurfaces++;
        if (configured)
            reload(false);
    }

    function releaseWidget(): void {
        activeSurfaces = Math.max(0, activeSurfaces - 1);
        widgetSurfaces = Math.max(0, widgetSurfaces - 1);
    }

    function credentialsChanged(): void {
        cache = ({});
        error = "";
        feedGeneration++;
        detailGeneration++;
        metadataGeneration++;

        loadingProfile = false;
        loadingRecent = false;
        pendingDetails = 0;
        profile = null;
        recentTracks = [];
        artist = null;
        album = null;
        selectedIndex = 0;
        lastRecentRefresh = 0;
        lastRecentAttempt = 0;
        lastProfileRefresh = 0;
        lastProfileAttempt = 0;

        resetCharts();

        if (configured && activeSurfaces > 0)
            reload(true);
    }

    function reload(force: bool): void {
        if (!hasCredentials)
            return;
        refreshProfile(force === true);
        refreshRecent(force === true);
    }

    // Called by desktop widgets on their own timers. The feed is shared, so an
    // interval shortens the effective refresh rate; it never creates a second
    // copy of recent/profile data.
    function refreshFeed(mode: string, intervalMs: int, manual: bool): void {
        if (!configured)
            return;

        const minAge = Math.max(minAutoRefreshMs, Number(intervalMs) || 30000);
        const now = Date.now();
        const recentAge = now - (lastRecentAttempt || lastRecentRefresh);
        const profileAge = now - (lastProfileAttempt || lastProfileRefresh);

        if (manual === true || recentAge >= minAge)
            refreshRecent(true);

        if ((mode === "profile" || manual === true) && (manual === true || profileAge >= minAge))
            refreshProfile(manual === true || mode === "profile");
    }

    function defaultRefreshUnit(mode: string): string {
        return mode === "grid" ? "minute" : "second";
    }

    function defaultRefreshValue(mode: string): int {
        return mode === "grid" ? 60 : 30;
    }

    function normalizeRefreshUnit(unit: var): string {
        return unit === "minute" || unit === "hour" ? unit : "second";
    }

    function maxRefreshValue(unit: string): int {
        if (unit === "minute")
            return Math.floor(maxTimerMs / 60000);
        if (unit === "hour")
            return Math.floor(maxTimerMs / 3600000);
        return Math.floor(maxTimerMs / 1000);
    }

    function refreshIntervalMs(unit: var, value: var): int {
        const normalized = normalizeRefreshUnit(unit);
        const max = maxRefreshValue(normalized);
        const amount = Math.max(1, Math.min(max, Number(value) || 1));
        const factor = normalized === "hour" ? 3600000 : normalized === "minute" ? 60000 : 1000;
        return Math.max(minAutoRefreshMs, Math.min(maxTimerMs, Math.round(amount * factor)));
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
        lastProfileAttempt = Date.now();
        const generation = feedGeneration;
        request("user.getInfo", { user: username }, data => {
            if (generation !== feedGeneration)
                return;
            loadingProfile = false;
            if (!data || !data.user) {
                console.warn("Last.fm profile request returned no user");
                return;
            }
            lastProfileRefresh = Date.now();
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
        lastRecentAttempt = Date.now();
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
            error = sanitizeError(message);
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

    // ── Charts ────────────────────────────────────────────────────────────
    // Cover grids use exact scrobble aggregation for custom/bounded ranges.
    // Native Last.fm periods are kept for artist/album charts, and overall
    // song charts use the native top tracks plus lazy visible-tile details.

    function normalizeChartEntity(entity: var): string {
        return entity === "artist" || entity === "track" ? entity : "album";
    }

    function normalizeChartUnit(unit: var): string {
        return unit === "week" || unit === "year" || unit === "overall" ? unit : "month";
    }

    function normalizeChartValue(unit: var, value: var): int {
        const normalized = normalizeChartUnit(unit);
        if (normalized === "overall")
            return 0;
        const max = normalized === "week" ? 520 : normalized === "year" ? 50 : 120;
        return Math.max(1, Math.min(max, Math.round(Number(value) || 1)));
    }

    function nativePeriod(unit: var, value: var): string {
        const normalized = normalizeChartUnit(unit);
        if (normalized === "overall")
            return "overall";
        const amount = normalizeChartValue(normalized, value);
        if (normalized === "week" && amount === 1)
            return "7day";
        if (normalized === "month") {
            if (amount === 1)
                return "1month";
            if (amount === 3)
                return "3month";
            if (amount === 6)
                return "6month";
            if (amount === 12)
                return "12month";
        }
        if (normalized === "year" && amount === 1)
            return "12month";
        return "";
    }

    function chartKey(entity: var, unit: var, value: var): string {
        const normalizedUnit = normalizeChartUnit(unit);
        return `${normalizeChartEntity(entity)}:${normalizedUnit}:${normalizeChartValue(normalizedUnit, value)}`;
    }

    function chartEntry(key: string): var {
        return charts[key] ?? null;
    }

    function acquireChart(entity: var, unit: var, value: var): string {
        const key = chartKey(entity, unit, value);
        const refs = Object.assign({}, chartRefs);
        const current = refs[key] ?? { count: 0 };
        refs[key] = Object.assign({}, current, {
            count: current.count + 1,
            entity: normalizeChartEntity(entity),
            unit: normalizeChartUnit(unit),
            value: normalizeChartValue(unit, value)
        });
        chartRefs = refs;
        ensureChart(entity, unit, value);
        return key;
    }

    function releaseChart(key: string): void {
        const current = chartRefs[key];
        if (!current)
            return;
        const refs = Object.assign({}, chartRefs);
        const count = Math.max(0, current.count - 1);
        if (count === 0) {
            delete refs[key];
            const job = chartJobs[key];
            if (job)
                job.cancelled = true;
            setChart(key, {
                loading: false,
                progress: 0,
                lastAttempt: 0
            });
        } else {
            refs[key] = Object.assign({}, current, { count });
        }
        chartRefs = refs;
    }

    function ensureChart(entity: var, unit: var, value: var): void {
        if (!configured)
            return;
        const key = chartKey(entity, unit, value);
        const entry = charts[key];
        if (entry && entry.loading)
            return;
        if (entry && entry.at > 0 && Date.now() - entry.at <= chartTtl)
            return;
        refreshChart(entity, unit, value, false, 0);
    }

    function refreshChart(entity: var, unit: var, value: var, manual: bool, intervalMs: int): void {
        if (!configured)
            return;

        const normalizedEntity = normalizeChartEntity(entity);
        const normalizedUnit = normalizeChartUnit(unit);
        const normalizedValue = normalizeChartValue(normalizedUnit, value);
        const key = chartKey(normalizedEntity, normalizedUnit, normalizedValue);
        const current = charts[key] ?? null;
        const now = Date.now();

        if (current && current.loading && manual !== true)
            return;
        if (manual !== true && current && current.lastAttempt > 0) {
            const minAge = Math.max(minAutoRefreshMs, Number(intervalMs) || 0);
            if (now - current.lastAttempt < minAge)
                return;
        }

        const oldJob = chartJobs[key];
        if (oldJob)
            oldJob.cancelled = true;

        chartJobSerial += 1;
        const generation = chartJobSerial;
        chartJobs[key] = { generation: generation, cancelled: false };
        setChart(key, {
            key: key,
            entity: normalizedEntity,
            unit: normalizedUnit,
            value: normalizedValue,
            items: current?.items ?? [],
            loading: true,
            error: "",
            progress: 0,
            pagesDone: 0,
            pagesTotal: 0,
            at: current?.at ?? 0,
            lastAttempt: now,
            generation: generation,
            native: false
        });

        const period = nativePeriod(normalizedUnit, normalizedValue);
        if (normalizedEntity === "track" && normalizedUnit === "overall") {
            fetchNativeChart(key, generation, normalizedEntity, "overall");
        } else if (normalizedEntity === "track") {
            startAggregation(key, generation, normalizedEntity, normalizedUnit, normalizedValue);
        } else if (period !== "") {
            fetchNativeChart(key, generation, normalizedEntity, period);
        } else {
            startAggregation(key, generation, normalizedEntity, normalizedUnit, normalizedValue);
        }
    }

    function isChartCurrent(key: string, generation: int): bool {
        const job = chartJobs[key];
        return !!job && job.generation === generation && !job.cancelled;
    }

    function setChart(key: string, patch: var): void {
        const base = charts[key] ?? {};
        const next = Object.assign({}, charts);
        next[key] = Object.assign({}, base, patch);
        charts = next;
    }

    function setChartProgress(key: string, generation: int, done: int, total: int): void {
        if (!isChartCurrent(key, generation))
            return;
        const progress = total > 0 ? Math.max(0, Math.min(1, done / total)) : 0;
        setChart(key, {
            pagesDone: done,
            pagesTotal: total,
            progress: progress
        });
    }

    function finishChart(key: string, generation: int, items: var): void {
        if (!isChartCurrent(key, generation))
            return;
        setChart(key, {
            items: items,
            loading: false,
            error: "",
            progress: 1,
            at: Date.now()
        });
    }

    function failChart(key: string, generation: int, message: var): void {
        if (!isChartCurrent(key, generation))
            return;
        setChart(key, {
            loading: false,
            error: sanitizeError(message),
            progress: 0
        });
    }

    function fetchNativeChart(key: string, generation: int, entity: string, period: string): void {
        const method = entity === "artist" ? "user.getTopArtists" : entity === "album" ? "user.getTopAlbums" : "user.getTopTracks";
        setChart(key, { native: true, pagesTotal: 1 });
        enqueueChartTask(function (): void {
            if (!isChartCurrent(key, generation)) {
                finishChartTask();
                return;
            }
            request(method, {
                user: username,
                period: period,
                limit: chartItemLimit
            }, data => {
                finishChartTask();
                if (!isChartCurrent(key, generation))
                    return;
                const items = normalizeTopChart(entity, data);
                finishChart(key, generation, items);
            }, message => {
                finishChartTask();
                if (!isChartCurrent(key, generation))
                    return;
                failChart(key, generation, message);
            });
        });
    }

    function normalizeTopChart(entity: string, data: var): var {
        let list = [];
        if (entity === "artist")
            list = asList(data?.topartists?.artist);
        else if (entity === "album")
            list = asList(data?.topalbums?.album);
        else
            list = asList(data?.toptracks?.track);

        return list.map(entry => {
            if (!entry)
                return null;
            const name = textOf(entry.name);
            if (name === "")
                return null;
            const artist = entity === "artist" ? name : textOf(entry.artist);
            const album = entity === "album" ? name : "";
            return {
                name: name,
                artist: artist,
                album: album,
                image: imageOf(entry.image),
                url: entry.url ?? "",
                count: Number(entry.playcount ?? 0)
            };
        }).filter(entry => entry !== null).slice(0, chartItemLimit);
    }

    function startAggregation(key: string, generation: int, entity: string, unit: string, value: int): void {
        const bounds = chartBounds(unit, value);
        const state = {
            totals: ({}),
            pagesDone: 0,
            pagesTotal: 0,
            from: bounds.from,
            to: bounds.to,
            imageMap: null
        };

        if (entity === "artist") {
            withArtistImages(key, generation, function (): void {
                // Prefer the artist portraits; scrobble art is the fallback.
                state.imageMap = artistImages;
                fetchRecentPage(key, generation, entity, state, 1);
            });
            return;
        }

        fetchRecentPage(key, generation, entity, state, 1);
    }

    function chartBounds(unit: string, value: int): var {
        const end = new Date();
        const start = new Date(end.getTime());
        if (unit === "week")
            start.setDate(start.getDate() - value * 7);
        else if (unit === "year")
            start.setFullYear(start.getFullYear() - value);
        else
            start.setMonth(start.getMonth() - value);
        return {
            from: Math.floor(start.getTime() / 1000),
            to: Math.floor(end.getTime() / 1000)
        };
    }

    function withArtistImages(key: string, generation: int, next: var): void {
        if (artistImagesAt > 0 && Date.now() - artistImagesAt < metadataTtl) {
            next();
            return;
        }

        enqueueChartTask(function (): void {
            if (!isChartCurrent(key, generation)) {
                finishChartTask();
                return;
            }
            request("user.getTopArtists", {
                user: username,
                period: "overall",
                limit: 100
            }, data => {
                finishChartTask();
                if (!isChartCurrent(key, generation))
                    return;
                const map = ({});
                for (const artist of asList(data?.topartists?.artist)) {
                    const name = textOf(artist?.name);
                    if (name !== "")
                        map[name.toLowerCase()] = imageOf(artist?.image);
                }
                artistImages = map;
                artistImagesAt = Date.now();
                next();
            }, message => {
                finishChartTask();
                if (!isChartCurrent(key, generation))
                    return;
                // Images are optional; the representative track art is used.
                console.warn("Last.fm artist image request failed:", sanitizeError(message));
                next();
            });
        });
    }

    function fetchRecentPage(key: string, generation: int, entity: string, state: var, page: int): void {
        enqueueChartTask(function (): void {
            if (!isChartCurrent(key, generation)) {
                finishChartTask();
                return;
            }
            request("user.getRecentTracks", {
                user: username,
                from: state.from,
                to: state.to,
                page: page,
                limit: chartPageLimit,
                extended: 1
            }, data => {
                finishChartTask();
                if (!isChartCurrent(key, generation))
                    return;

                if (page === 1) {
                    const attr = data?.recenttracks?.["@attr"];
                    const total = Math.max(1, Math.round(Number(attr?.totalPages ?? 1)));
                    if (total > maxChartPages) {
                        failChart(key, generation, Tr.tr("This range is too large to load exactly. Choose Overall or a shorter range."));
                        return;
                    }
                    state.pagesTotal = total;
                }

                for (const track of asList(data?.recenttracks?.track))
                    accumulateChartTrack(state, entity, normalizeTrack(track));

                state.pagesDone++;
                setChartProgress(key, generation, state.pagesDone, state.pagesTotal);

                if (page < state.pagesTotal)
                    fetchRecentPage(key, generation, entity, state, page + 1);
                else
                    finishAggregation(key, generation, entity, state);
            }, message => {
                finishChartTask();
                if (!isChartCurrent(key, generation))
                    return;
                failChart(key, generation, message);
            });
        });
    }

    function accumulateChartTrack(state: var, entity: string, track: var): void {
        if (!track || track.nowPlaying || track.name === "" || track.artist === "")
            return;

        let key = "";
        let name = "";
        let album = "";
        if (entity === "artist") {
            key = track.artist.toLowerCase();
            name = track.artist;
        } else if (entity === "album") {
            if (track.album === "")
                return;
            key = `${track.artist.toLowerCase()}|${track.album.toLowerCase()}`;
            name = track.album;
            album = track.album;
        } else {
            key = `${track.artist.toLowerCase()}|${track.name.toLowerCase()}|${track.album.toLowerCase()}`;
            name = track.name;
            album = track.album;
        }

        const existing = state.totals[key] ?? {
            name: name,
            artist: track.artist,
            album: album,
            image: "",
            url: "",
            count: 0
        };
        existing.count++;
        if (existing.image === "" && track.image !== "")
            existing.image = track.image;
        if (existing.url === "" && track.url !== "")
            existing.url = track.url;
        state.totals[key] = existing;
    }

    function finishAggregation(key: string, generation: int, entity: string, state: var): void {
        const items = Object.keys(state.totals).map(itemKey => state.totals[itemKey]).sort((a, b) => {
            if (b.count !== a.count)
                return b.count - a.count;
            return String(a.name ?? "").localeCompare(String(b.name ?? ""));
        }).slice(0, chartItemLimit);

        if (entity === "artist" && state.imageMap) {
            for (const item of items) {
                const image = state.imageMap[String(item.artist).toLowerCase()];
                if (image)
                    item.image = image;
            }
        }

        finishChart(key, generation, items);
    }

    // ── Lazy cover metadata ──────────────────────────────────────────────
    // Album release years and missing album names are fetched only for the
    // tiles a grid is actually showing, then cached for a day.

    function albumYearKey(artist: string, album: string): string {
        return `${artist.trim().toLowerCase()}|${album.trim().toLowerCase()}`;
    }

    function trackDetailKey(artist: string, track: string): string {
        return `${artist.trim().toLowerCase()}|${track.trim().toLowerCase()}`;
    }

    function parseReleaseYear(value: var): string {
        const match = String(value ?? "").match(/\b(19|20)\d{2}\b/);
        return match ? match[0] : "";
    }

    function setAlbumYear(key: string, entry: var): void {
        const next = Object.assign({}, albumYears);
        next[key] = entry;
        albumYears = next;
    }

    function setTrackDetail(key: string, entry: var): void {
        const next = Object.assign({}, trackDetails);
        next[key] = entry;
        trackDetails = next;
    }

    function ensureAlbumYear(artist: string, album: string): void {
        if (!configured || artist === "" || album === "")
            return;

        const key = albumYearKey(artist, album);
        const current = albumYears[key];
        const now = Date.now();
        if (current) {
            if (current.loading)
                return;
            const ttl = current.error !== "" ? metadataErrorTtl : metadataTtl;
            if (current.at > 0 && now - current.at < ttl)
                return;
        }

        setAlbumYear(key, {
            year: current?.year ?? "",
            loading: true,
            error: "",
            at: current?.at ?? 0
        });
        const generation = metadataGeneration;
        enqueueChartTask(function (): void {
            if (generation !== metadataGeneration) {
                finishChartTask();
                return;
            }
            request("album.getInfo", {
                artist: artist,
                album: album
            }, data => {
                finishChartTask();
                if (generation !== metadataGeneration)
                    return;
                const year = parseReleaseYear(data?.album?.releasedate);
                setAlbumYear(key, {
                    year: year,
                    loading: false,
                    error: "",
                    at: Date.now()
                });
            }, message => {
                finishChartTask();
                if (generation !== metadataGeneration)
                    return;
                setAlbumYear(key, {
                    year: "",
                    loading: false,
                    error: sanitizeError(message),
                    at: Date.now()
                });
            });
        });
    }

    function ensureTrackDetails(artist: string, track: string, needYear: bool): void {
        if (!configured || artist === "" || track === "")
            return;

        const key = trackDetailKey(artist, track);
        const current = trackDetails[key];
        const now = Date.now();
        if (current) {
            if (current.loading)
                return;
            const ttl = current.error !== "" ? metadataErrorTtl : metadataTtl;
            if (current.at > 0 && now - current.at < ttl)
                return;
        }

        setTrackDetail(key, {
            album: current?.album ?? "",
            loading: true,
            error: "",
            at: current?.at ?? 0
        });
        const generation = metadataGeneration;
        enqueueChartTask(function (): void {
            if (generation !== metadataGeneration) {
                finishChartTask();
                return;
            }
            request("track.getInfo", {
                artist: artist,
                track: track
            }, data => {
                finishChartTask();
                if (generation !== metadataGeneration)
                    return;
                const album = textOf(data?.track?.album?.title);
                setTrackDetail(key, {
                    album: album,
                    loading: false,
                    error: "",
                    at: Date.now()
                });
                if (album !== "" && needYear)
                    ensureAlbumYear(artist, album);
            }, message => {
                finishChartTask();
                if (generation !== metadataGeneration)
                    return;
                setTrackDetail(key, {
                    album: "",
                    loading: false,
                    error: sanitizeError(message),
                    at: Date.now()
                });
            });
        });
    }

    function tileAlbum(item: var): string {
        if (!item)
            return "";
        if (item.album)
            return item.album;
        const detail = trackDetails[trackDetailKey(item.artist ?? "", item.name ?? "")];
        return detail?.album ?? "";
    }

    function tileYear(item: var): string {
        if (!item)
            return "";
        const album = item.album || tileAlbum(item);
        if (album === "")
            return "";
        return albumYears[albumYearKey(item.artist ?? "", album)]?.year ?? "";
    }

    function ensureTileDetails(entity: string, items: var, needAlbum: bool, needYear: bool): void {
        if (entity === "artist" || !items)
            return;
        for (const item of items) {
            if (!item)
                continue;
            if (entity === "album") {
                if (needYear)
                    ensureAlbumYear(item.artist ?? "", item.name ?? "");
                continue;
            }
            const album = item.album ?? "";
            if (album !== "") {
                if (needYear)
                    ensureAlbumYear(item.artist ?? "", album);
            } else if (needAlbum || needYear) {
                ensureTrackDetails(item.artist ?? "", item.name ?? "", needYear);
                if (needYear) {
                    const detail = trackDetails[trackDetailKey(item.artist ?? "", item.name ?? "")];
                    if (detail?.album)
                        ensureAlbumYear(item.artist ?? "", detail.album);
                }
            }
        }
    }

    function resetCharts(): void {
        for (const key in chartJobs)
            chartJobs[key].cancelled = true;
        chartJobs = ({});
        chartQueue = [];
        charts = ({});
        albumYears = ({});
        trackDetails = ({});
        artistImages = ({});
        artistImagesAt = 0;

        // Keep widget references, and restart charts that are still in use.
        for (const key in chartRefs) {
            const ref = chartRefs[key];
            if (ref && ref.count > 0)
                ensureChart(ref.entity, ref.unit, ref.value);
        }
    }

    // Serialize chart-related requests so exact aggregation and metadata
    // lookups stay under Last.fm's rate limit.
    function enqueueChartTask(task: var): void {
        const next = chartQueue.slice();
        next.push(task);
        chartQueue = next;
    }

    function runNextChartTask(): void {
        if (chartRequestActive)
            return;
        // Drop cancelled/stale tasks immediately. This matters when a range is
        // stepped quickly: the final request should not wait 250 ms per obsolete
        // task in front of it.
        while (chartQueue.length > 0 && !chartRequestActive) {
            const next = chartQueue.slice();
            const task = next.shift();
            chartQueue = next;
            chartRequestActive = true;
            try {
                task();
            } catch (e) {
                chartRequestActive = false;
                console.warn("Last.fm chart task failed:", sanitizeError(String(e)));
            }
        }
    }

    function finishChartTask(): void {
        chartRequestActive = false;
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
        metadataGeneration++;
        resetCharts();
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
        running: root.dashboardSurfaces > 0 && root.configured
        triggeredOnStart: true
        onTriggered: {
            // The dashboard interval is explicit, so bypass the short feed cache
            // when it is shorter than the cache lifetime.
            root.refreshRecent(true);
            // Cached for five minutes, so this only hits the API occasionally.
            root.refreshProfile(false);
        }
    }

    Timer {
        id: chartTaskTimer

        interval: root.chartRequestInterval
        repeat: true
        running: root.chartQueue.length > 0 && !root.chartRequestActive
        onTriggered: root.runNextChartTask()
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
