# Expeditus — technical documentation

This document contains the implementation, build, packaging, and release details that are intentionally kept out of the main [README](../README.md).

## Overview

Expeditus is a Flutter desktop application for Windows. It turns a set of YouTube subscriptions into a text-first inbox:

- one latest upload per channel;
- a per-channel archive of recent uploads;
- local search, status filters, tags, queue, and watch state;
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
| `lib/src/services/stream_resolver.dart` | Direct media stream resolution |
| `lib/src/services/sponsorblock_service.dart` | SponsorBlock segment lookup |
| `lib/src/util/seek_accumulator.dart` | Debounced compound seeking |
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

- `channels`: id, title, handle, added time, last check, muted flag, last error.
- `videos`: id, channel, title, description, publication time, duration, status, queue flag, progress, fetch time, keywords JSON, tag-fetch flag.
- `settings`: refresh interval, SponsorBlock options, playback rate, layout options.

Database version 2 added `keywords` and `keywords_fetched` with an `ALTER TABLE` migration.

## Playback and ad avoidance

Expeditus does not load the YouTube web player. `youtube_explode_dart` resolves a direct media URL, and `media_kit` plays it with libmpv. Because the ad-serving player is not used, player ads and end-screen recommendations are not part of the experience.

SponsorBlock segments are fetched from `sponsor.ajay.app` and skipped during playback. The player also supports:

- playback speed from 0.25× to 3.50× in 0.25 steps, persisted in `settings`;
- `±10 s` seeking with a 300 ms debounce, so rapid presses compound into one seek;
- keyboard shortcuts `←` / `→` and `J` / `L` while the player is open.

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

# Deterministic desktop E2E: import, feed, channel archive, tags, filters, player error, speed
flutter test integration_test -d windows

# Live network E2E against @antirez
flutter test integration_test_live/live_youtube_test.dart -d windows --dart-define=RUN_LIVE_TESTS=true
```

## Limits and risks

- RSS exposes at most 15 uploads per channel. Deeper history needs the YouTube Data API, yt-dlp, or another extractor.
- The fallback muxed stream is limited to 360p; HLS is used when available. 1080p/4K would require an optional yt-dlp/ffmpeg resolver.
- Tags are not available for every video and cost one watch-page request per uncached video.
- Shorts and live streams are not filtered separately.
- SSAI can eventually put ads inside direct streams; the current approach is not future-proof.
- Third-party YouTube clients may be subject to YouTube's Terms of Service.
- The installer is unsigned and the UI is currently in Italian.

## License

Expeditus is MIT-licensed. The Windows bundle includes GPL-2.0-or-later libmpv/FFmpeg components and other third-party libraries. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) and [LICENSES](../LICENSES) for the full notices, license texts, and GPL source offer.
