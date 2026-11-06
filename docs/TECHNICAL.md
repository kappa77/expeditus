# Expeditus — technical documentation

This document contains the implementation, build, packaging, and release details that are intentionally kept out of the main [README](../README.md).

## Overview

Expeditus is a Flutter desktop application for Windows. It turns a set of YouTube subscriptions into a text-first inbox:

- one latest upload per channel;
- a per-channel archive of recent uploads;
- local search, status filters, tags, an explicit Watch later list, and watch state;
- playback through direct media streams instead of the YouTube player;
- optional SponsorBlock skipping.

The application is local-first. Subscriptions and state are stored in SQLite; there is no Google login and no YouTube Data API quota usage.

## Architecture

```
YouTube RSS / search / watch pages
            │
            ▼
   Dart services (http, xml, youtube_explode_dart)
            │
            ▼
   SQLite (sqflite_common_ffi)
            │
            ▼
   AppState (ChangeNotifier)
            │
            ▼
   Flutter UI ──► media_kit / libmpv
```

Key modules:

| Path | Responsibility |
|---|---|
| `lib/main.dart` | Window setup, database initialization, fatal-error screen |
| `lib/src/state/app_state.dart` | Application state, refresh, import, channel actions, settings |
| `lib/src/data/database.dart` | SQLite schema, migrations, queries |
| `lib/src/services/rss_service.dart` | YouTube Atom feed parsing |
| `lib/src/services/import_service.dart` | Google Takeout CSV and channel handle/URL resolution |
| `lib/src/services/channel_search_service.dart` | YouTube channel search by keyword |
| `lib/src/services/video_tags_service.dart` | Lazy `videoDetails.keywords` fetch |
| `lib/src/services/video_chapters_service.dart` | Full-description chapter fetch |
| `lib/src/services/video_download_service.dart` | Muxed-stream download to the local app data folder |
| `lib/src/services/video_link_service.dart` | Resolve a video URL and its channel |
| `lib/src/services/stream_resolver.dart` | Direct media stream resolution |
| `lib/src/services/sponsorblock_service.dart` | SponsorBlock segment lookup |
| `lib/src/util/seek_accumulator.dart` | Debounced compound seeking |
| `lib/src/util/chapter_parser.dart` | Timestamped chapter parsing |
| `lib/src/util/playback_rates.dart` | Shared speed steps |
| `lib/src/version.dart` | Build-time version injected by the release pipeline |

## Data sources

### Subscriptions feed

Each channel is read from its public Atom feed:

```
https://www.youtube.com/feeds/videos.xml?channel_id=...
```

The feed contains the latest 15 uploads with title, description, publication time, video ID, and channel title. It needs no OAuth and consumes no YouTube Data API quota. Expeditus stores every entry it receives; the main feed selects only the newest row per channel with a `ROW_NUMBER() OVER (PARTITION BY channel_id ...)` query.

### Channel search

Channel search uses YouTube's public search page through `youtube_explode_dart`, filtered to channels. It needs no API key but depends on YouTube's page structure. Results show the channel name and description; adding a channel fetches only that channel's RSS feed.

### Tags

YouTube tags live in `videoDetails.keywords`, which is not present in the RSS feed. Expeditus fetches them lazily, one watch page per video, with limited concurrency, and caches the result in SQLite. A successful fetch with no keywords is cached as "fetched, empty" to avoid repeating the request. Many channels do not publish keywords.

## Storage

SQLite database: `expeditus.sqlite`, in the application support directory.

Tables:

- `channels`: id, title, handle, added time, last check, RSS-muted flag, show-in-latest flag, optional default playback rate, last error.
- `videos`: id, channel, title, description, publication time, first-seen time, duration, status, watch-later flag, watch-later save time, progress, fetch time, keywords JSON, tag-fetch flag, watched-at, local download path/status/time/error, chapters JSON, chapter-fetch flag, source (`rss`/`link`).
- `bookmarks`: id, video id, position seconds, personal note, creation time.
- `settings`: refresh interval, SponsorBlock options, playback rate, layout options.

Database version 2 added `keywords` and `keywords_fetched`. Version 3 added `watched_at`, `local_path`, `download_status`, `downloaded_at`, and `download_error`. Version 4 added `channels.show_in_latest`, defaulting to 1. Version 5 added `channels.default_playback_rate`, `videos.chapters`, `videos.chapters_fetched`, and the `bookmarks` table. Version 6 added `videos.first_seen_at` and `videos.source`, and backfilled first-seen times from the previous fetch timestamp. Version 7 added `videos.queued_at` and backfilled it for existing saved videos. All use `ALTER TABLE` migrations.

Migrations are idempotent: tables and indexes are created with `IF NOT EXISTS`, every added column is checked with `PRAGMA table_info` before the `ALTER TABLE`, and backfills only update rows whose value is still `NULL`. An interrupted or partially applied upgrade can therefore be retried safely without "duplicate column name" or "table already exists" errors.

## Playback and ad avoidance

Expeditus does not load the YouTube web player. `youtube_explode_dart` resolves a direct media URL, and `media_kit` plays it with libmpv. Because the ad-serving player is not used, player ads and end-screen recommendations are not part of the experience.

When a video has a local download, the player opens the local file and labels the stream **Offline**; otherwise it resolves a direct URL. SponsorBlock segments are still fetched when available.

SponsorBlock segments are fetched from `sponsor.ajay.app` and skipped during playback. The player also supports:

- playback speed from 0.25× to 3.50× in 0.25 steps, persisted in `settings`;
- an optional per-channel default speed (`channels.default_playback_rate`); the channel page sets it, and the player falls back to the global speed when it is null;
- `±10 s` seeking with a 300 ms debounce, so rapid presses compound into one seek;
- keyboard shortcuts `←` / `→` and `J` / `L` while the player is open.

### Chapters and bookmarks

Chapters are parsed from the video description with timestamp lines such as `00:00 Intro` (at least two entries). If the stored description has no chapters, the player fetches the full description with `youtube_explode_dart` and caches the parsed chapters in `videos.chapters`. The outline dialog lists chapters and personal bookmarks; both jump to their timestamp.

Bookmarks are stored in the `bookmarks` table with a second offset and a free-form personal note. They can be added from the outline dialog or from the player AppBar at the current position; they are local only and are deleted with their video row.

### Watch later

The **Guarda più tardi** view is the explicit watch-later list. The `videos.queued` flag marks membership and `videos.queued_at` records when the user saved the video. The list is ordered by `queued_at` descending, so it follows the order in which videos were added rather than their publication date; each row shows the save time. Playing or marking a video watched does not remove it from the list: removal is always an explicit action. The same list is available from the sidebar, the channel page filter, and the player toggle. `S` and `W` toggle membership from the main views.

### RSS history

`rssHistory()` lists every video ever received from an RSS feed, ordered by first-seen time. `videos.id` is the primary key, so repeated feed refreshes update the existing row instead of creating duplicates; `first_seen_at` is preserved on conflict. Link-only imports are marked `source = 'link'` and excluded from this view. If a link-only video later appears in the RSS feed, its source is upgraded to `rss`.

The **Storico RSS** view groups these rows by channel with `groupRssHistoryByChannel`. Groups are ordered by the most recent sighting in each channel, while videos keep the first-seen order inside a group. A channel dropdown filters the view; local search combines with that filter. Group headers show the number of matching videos, so counts update when a search is active. The filter is session-only and is cleared automatically if the selected channel no longer has history.

### Per-channel refresh

The channel page refresh button calls `AppState.refreshChannel`, which fetches only that channel's RSS feed and then reloads the feed and the open channel page. It can be used even when the channel RSS is muted.

### Channel page

The channel page has two tabs:

- **Video** — the stored archive (up to 50 videos from the database, newest first), with filters and search.
- **Cronologia** — every video opened or marked watched for that channel, ordered by `watched_at` and grouped by watched month.

The channel page has two independent visibility controls:

- **Silenzia RSS** (`channels.muted`): Expeditus stops refreshing that feed and hides new items from the channel page. Archive and history stay accessible. Unmuting resumes normal refreshes.
- **Mostra in novità** (`channels.show_in_latest`): controls whether the channel's latest video appears in the main **latest/New** list. The channel keeps refreshing and remains reachable from **Canali**; turning it off is useful for archive-only subscriptions.

`latestPerChannel()` requires both `muted = 0` and `show_in_latest = 1`.

### Offline downloads

The download action in the channel page saves the best **muxed** stream to `downloads/<videoId>.mp4` in the application support directory. Muxed streams are single-file and need no ffmpeg, but YouTube usually limits them to 360p. Downloads are tracked in SQLite; the **Salvati** view lists ready files and the player prefers the local file when present. Removing a download deletes the file and clears the metadata. There is no download queue, resume, or cancellation yet.

### Video links and automatic subscription

The import dialog has a **Link video** tab. It resolves a YouTube watch/short URL with `youtube_explode_dart`, reads the channel ID and video metadata, subscribes to the channel, stores the video, and adds it to Watch later. This works even when the video is older than the channel's current RSS window.

### First run

On a fresh profile (`onboardingSeen` not set, no channels), the root gate shows a welcome screen with a short explanation and the channel search tab. Adding a channel, importing subscriptions, or choosing **Salta per ora** completes onboarding; the flag is persisted in `settings`.

YouTube is experimenting with server-side ad insertion (SSAI), where ads are stitched into the stream itself. This is a long-term risk for any direct-stream client.

## Build from source (Windows)

Requirements:

- Flutter 3.47.7 or a compatible stable SDK;
- Visual Studio with the Desktop development with C++ workload;
- NSIS 3 only if you want to build the installer.

```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File tool/fetch_windows_deps.ps1
flutter run -d windows
```

`tool/fetch_windows_deps.ps1` downloads the libmpv and ANGLE archives used by `media_kit`, verifies their MD5, and places them in `build/windows/x64/`. The direct GitHub download can return `504`; the script uses a mirror as fallback.

`windows/CMakeLists.txt` forces `CMAKE_INSTALL_PREFIX` next to the executable. Without it, some Visual Studio/CMake combinations try to install into `C:/Program Files/expeditus` and require administrator rights.

## One-click installer

The installer is generated with NSIS 3 (`installer/expeditus.nsi`). It is a single self-contained `.exe`:

- double-click installs silently for the current user in `%LOCALAPPDATA%\Programs\Expeditus`;
- creates Start Menu and desktop shortcuts;
- registers an uninstaller in Windows Settings → Apps;
- includes the MIT license, third-party notices, and the GPL source offer;
- launches Expeditus at the end of installation;
- does not require administrator rights and does not install external runtime packages.

The Flutter Windows runner links the MSVC runtime dynamically. `tool/build_installer.ps1` locates `msvcp140.dll`, `vcruntime140.dll`, and `vcruntime140_1.dll` from the Visual Studio redistributable folders (or `System32` as fallback) and copies them into the release bundle. They are installed app-local, so users do not need a separate Visual C++ Redistributable installation.

Build locally:

```powershell
# Installs NSIS first if needed: choco install nsis
powershell -ExecutionPolicy Bypass -File tool/build_installer.ps1
```

Output:

```
dist/ExpeditusSetup-x.y.z.exe
dist/SHA256SUMS.txt
```

`-SkipFlutterBuild` reuses an existing release build. `-Version` and `-Build` override the values from `pubspec.yaml`.

The installer is currently unsigned. Windows SmartScreen may warn until a code-signing certificate is configured.

## Release pipeline

The source of truth for a release is the Git tag, not the version committed in `pubspec.yaml`.

1. Create a semantic tag, for example `v1.2.3`.
2. Push the tag.
3. `.github/workflows/release.yml` runs on `windows-latest`.
4. The workflow extracts `1.2.3` from the tag and writes it to `pubspec.yaml` for the CI build only.
5. Flutter is built with `--dart-define=APP_VERSION=1.2.3`, so the version shown in the application footer matches the release.
6. NSIS receives the same version and build number, so the installer filename and Windows file version match.
7. The workflow uploads the installer and `SHA256SUMS.txt` as artifacts and publishes a GitHub Release.

`workflow_dispatch` is also supported; in that case the version is read from `pubspec.yaml`.

The app footer reads `kAppVersion` from `lib/src/version.dart`, with a development fallback. The release build overrides it through the Dart define.

## Tests

```powershell
# Unit tests: RSS, CSV Takeout, resolver, seek accumulator
flutter test

# Deterministic desktop E2E: onboarding, import, feed, channel archive/history,
# tags, filters, offline download, chapters/bookmarks, per-channel speed,
# refresh-only-channel, player error
flutter test integration_test -d windows

# Live network E2E: @antirez feed, channel search, video link + auto-subscribe
flutter test integration_test_live/live_youtube_test.dart -d windows --dart-define=RUN_LIVE_TESTS=true
```

## Limits and risks

- RSS exposes at most 15 uploads per channel. Deeper history needs the YouTube Data API, yt-dlp, or another extractor.
- The fallback muxed stream is limited to 360p; HLS is used when available. 1080p/4K would require an optional yt-dlp/ffmpeg resolver.
- Tags are not available for every video and cost one watch-page request per uncached video.
- Offline downloads use muxed streams, usually 360p, and do not support resume, cancellation, or a download queue.
- RSS history keeps one row per video id; it is not a log of every feed refresh. The current feed view still shows only the latest entry per channel.
- Chapters depend on timestamps in the description; videos without timestamped descriptions have no chapters. The outline captures the playback position when it is opened for new bookmarks.
- Channel history records the first time a video was opened or marked watched; toggling watched off does not erase the history entry.
- Shorts and live streams are not filtered separately.
- SSAI can eventually put ads inside direct streams; the current approach is not future-proof.
- Third-party YouTube clients may be subject to YouTube's Terms of Service.
- The installer is unsigned and the UI is currently in Italian.

## License

Expeditus is MIT-licensed. The Windows bundle includes GPL-2.0-or-later libmpv/FFmpeg components and other third-party libraries. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) and [LICENSES](../LICENSES) for the full notices, license texts, and GPL source offer.
