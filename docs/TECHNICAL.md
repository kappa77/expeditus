# Expeditus — technical documentation

This document contains the implementation, build, packaging, and release details that are intentionally kept out of the main [README](../README.md).

## Overview

Expeditus is a Flutter application for Windows desktop and Android. It turns a set of YouTube subscriptions into a text-first inbox:

- one latest upload per channel;
- a per-channel archive of recent uploads;
- local search, status filters, tags, an explicit Watch later list, and watch state;
- a separate library of local MP4 files, with titles from metadata or the file name;
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
   AppState (ChangeNotifier) ──► CastController
            │                        │
            ▼                        ├──► SSDP + UPnP AVTransport (LAN)
   Flutter UI ──► media_kit / libmpv └──► local media proxy ──► renderer
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
| `lib/src/services/local_video_service.dart` | MP4 title/duration metadata and file-name fallback |
| `lib/src/services/stream_resolver.dart` | Direct media stream resolution |
| `lib/src/services/sponsorblock_service.dart` | SponsorBlock segment lookup |
| `lib/src/services/dlna/ssdp_discovery.dart` | SSDP MediaRenderer discovery and device-description fetch |
| `lib/src/services/dlna/dlna_models.dart` | SSDP/description parsing and device model |
| `lib/src/services/dlna/dlna_transport.dart` | UPnP AVTransport SOAP client |
| `lib/src/services/dlna/dlna_metadata.dart` | DIDL-Lite metadata and MIME mapping |
| `lib/src/services/dlna/media_server.dart` | Local HTTP proxy for files, MP4 and HLS |
| `lib/src/services/dlna/windows_firewall.dart` | Inbound firewall rule detection and UAC-assisted creation |
| `lib/src/state/cast_controller.dart` | Cast session and transport polling |
| `lib/src/ui/cast_dialog.dart` | Device picker, discovery progress and errors |
| `lib/src/ui/cast_waiting_cover.dart` | Poster with play symbol while remote playback is not confirmed |
| `lib/src/services/update_feed_client.dart` | GitHub Releases feed, ETag cache, redirect and response limits |
| `lib/src/services/update_service.dart` | Version comparison and Windows installer selection |
| `lib/src/models/app_update.dart` | Release and update-check models |
| `lib/src/ui/update_dialog.dart` | Update center dialog |
| `lib/src/util/app_version.dart` | Semantic version parsing and comparison |
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
- `local_videos`: path, title, added time, duration.
- `bookmarks`: id, video id, position seconds, personal note, creation time.
- `settings`: refresh interval, SponsorBlock options, playback rate, layout options.

Database version 2 added `keywords` and `keywords_fetched`. Version 3 added `watched_at`, `local_path`, `download_status`, `downloaded_at`, and `download_error`. Version 4 added `channels.show_in_latest`, defaulting to 1. Version 5 added `channels.default_playback_rate`, `videos.chapters`, `videos.chapters_fetched`, and the `bookmarks` table. Version 6 added `videos.first_seen_at` and `videos.source`, and backfilled first-seen times from the previous fetch timestamp. Version 7 added `videos.queued_at` and backfilled it for existing saved videos. Version 8 added the `local_videos` table. All migrations are idempotent.

Migrations are idempotent: tables and indexes are created with `IF NOT EXISTS`, every added column is checked with `PRAGMA table_info` before the `ALTER TABLE`, and backfills only update rows whose value is still `NULL`. An interrupted or partially applied upgrade can therefore be retried safely without "duplicate column name" or "table already exists" errors.

## Playback and ad avoidance

Expeditus does not load the YouTube web player. `youtube_explode_dart` resolves a direct media URL, and `media_kit` plays it with libmpv. Because the ad-serving player is not used, player ads and end-screen recommendations are not part of the experience.

When a video has a local download, the player opens the local file and labels the stream **Offline**; otherwise it resolves a direct URL. SponsorBlock segments are still fetched when available.

On Android, local stream resolution races iOS and Android SDK-less without a
watch-page request. A ready MP4 waits at most another 750 ms for an HLS result;
the slower extraction is then canceled and its HTTP client closed. Desktop
first tries iOS without a watch-page request. The full iOS extraction and then
Android SDK-less with a watch page are fallbacks. Each attempt has a
12-second timeout and closes its extractor/HTTP client on success, failure or
timeout. Closing `PlayerPage` cancels pending local stream resolution. HLS with
audio and video is preferred; Android selects the highest available resolution
up to 720p (or the smallest HLS rendition if all exceed that limit). Desktop has
no resolution cap. A quality label comes from the selected stream's manifest;
a 720p cap does not upscale a 360p fallback. Separate video/audio tracks are not
currently combined.

`ResumablePlayer` keeps a stable position independently of native clock resets.
The standard video controls and fullscreen controls use the same play/pause/seek
overrides. Before resuming a remote stream paused for at least two minutes, or
whose `expire` time is within 30 seconds, it resolves a fresh URL and opens it
with `Media.start` at the pause point. Brief pauses reuse the URL and restore the
decoder's position if needed. Local files and the muted DLNA clock do not renew
URLs. A manual pause remains paused when the app returns to the foreground.
Pending resumes are invalidated by pause, seek, stop or disposal, and a load
that finishes in the background stays paused.

One video controller is created per player, including across retries. The
Android demuxer cache budget is 16 MiB forward and 16 MiB backward, compared with
32 MiB each on desktop. These limits are not a limit on total process memory:
decoder buffers, textures, Dart objects and native allocations use additional
memory. All page subscriptions and the player are released on close. The
[Motorola device regression](ANDROID_PLAYBACK_TEST.md) records startup, pause,
real Activity transitions and repeated resource-release measurements. Short
regression runs cannot exclude native leaks during longer sessions.

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

### Update checks (desktop)

Android skips the GitHub update check and hides its UI; Android updates are installed manually or through a store.

Expeditus reads GitHub's public `releases/latest` endpoint for `kappa77/expeditus`:

```
https://api.github.com/repos/kappa77/expeditus/releases/latest
```

The URL can be overridden at build time with `--dart-define=UPDATE_FEED_URL=...`; a read-only token can be supplied with `--dart-define=UPDATE_FEED_TOKEN=...` for private forks. The public release needs no token. A token passed this way is embedded in the binary: use a dedicated read-only token with the minimum scope and rotate it. A generic JSON manifest with `version`, `notes`, `publishedAt`, `releaseUrl`, and `assets[]` is also accepted through the same URL.

The check runs once at startup and then every six hours. Automatic attempts are throttled by `updateLastCheck` (at least six hours apart); opening the dialog also checks when the last attempt is stale, while **Controlla ora** bypasses the throttle and the ETag cache. A failed check never blocks startup and is only surfaced in the update dialog.

The feed is read over HTTPS (plain HTTP is accepted only for localhost during tests), with a 15-second timeout, a 2 MB response limit, at most five redirects, and the `Authorization` header removed when a redirect changes host. The response is cached together with its ETag: a `304 Not Modified` or a network failure reuses the local release and marks the dialog as **dati in cache**.

Versions are parsed as SemVer (`v2.0.0`, `2.0.0+12`, pre-releases); build metadata is ignored. Assets are scored to find the Windows installer (`ExpeditusSetup-*.exe`), ignoring `SHA256SUMS.txt`. The app deliberately does not download or install automatically: the dialog opens the release page or the installer URL in the browser.

Update state is stored in the `settings` table:

| Key | Content |
|---|---|
| `updateLastCheck` | Last check attempt, ISO-8601 UTC |
| `updateSkippedVersion` | Version the user chose to skip |
| `updateEtag` | ETag for feed revalidation |
| `updateCachedRelease` | Last valid GitHub release JSON |
| `updateLastError` | Last failed check, shown in the dialog |

A skipped version stays hidden until a newer release appears. The UI exposes the check from the sidebar (**Aggiornamenti** / **Aggiorna a vX**) and from the clickable version in the status bar; when a release is available both use the accent color. The dialog shows the installed and latest versions, release notes, installer name/size, the last check time, and the cache/error state. The release workflow enables GitHub's generated release notes, so the dialog has a readable body to show.

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

### DLNA casting

DLNA casting and discovery are available on Windows and Android. On Android the app holds a `WifiManager.MulticastLock` during SSDP discovery and allows cleartext local HTTP for device descriptions and the media proxy. The Windows Firewall/network-profile repair helpers only run on Windows.

The player exposes a cast button. `CastDialog` runs SSDP discovery through
`SsdpDlnaDiscovery` the first time it is opened; the result is cached in
`CastController`, and a refresh button repeats the search. Discovery sends
`M-SEARCH` to `239.255.255.250:1900` for `MediaRenderer:1` and
`AVTransport:1`, reads each `LOCATION` description, and keeps devices that
expose an `AVTransport` control URL.

Selecting a device creates a `DlnaSoapTransport` and validates it with
`GetTransportInfo`; the dialog shows an "Aggancio a …" spinner during this
step. Action failures are shown in the dialog with a retry button.

`CastController.castVideo` publishes the media through `MediaServer`, a local
HTTP server bound to the LAN address on an ephemeral port:

- downloaded videos are served from disk;
- remote videos are resolved again with `StreamResolver.resolveForCasting`,
  which prefers a muxed MP4 (the most compatible DLNA format) and falls back
  to HLS;
- all remote content is proxied, because YouTube stream URLs may be tied to
  the requesting IP;
- `Range`/`206` requests are forwarded so the renderer can seek;
- HLS playlists are fetched and rewritten so variants, keys, init segments
  and media segments point back at the local proxy.

The proxy URL and a DIDL-Lite document (title, `object.item.videoItem`
class, `video/mp4` or HLS protocol info, YouTube thumbnail as album art) are
sent with `SetAVTransportURI`, followed by an optional `Seek` and `Play`.
The app polls `GetTransportInfo` to learn whether the renderer started.
Renderers can take several seconds to leave `TRANSITIONING`; the probe waits
up to about 15 seconds. If playback is still not confirmed, the player shows
the thumbnail with a play symbol over the muted video; pressing it sends
`Play` again. A transport error keeps local audio muted while the TV is
connected, shows the error in a snackbar with a retry action, and leaves the
poster available with **Riproduci solo qui**.

The local proxy tracks the first request for each published token. If the
renderer has not requested the media a few seconds after `Play`,
`CastController` checks the Windows Firewall with
`WindowsFirewallService`. When the rule for the current executable is
missing, the dialog and the poster expose **Consenti accesso rete**: the
button runs `netsh advfirewall firewall add rule` through an elevated
`Start-Process` (UAC). The rule is inbound, allows TCP and UDP for that
executable only, uses `profile=any` (so it also works when Windows classifies
the LAN as Public), and is named from a hash of the executable path so debug,
release and installed builds do not collide. The firewall rule is never
changed without this explicit user action.

Once connected, `PlayerPage` casts every video it opens and calls
`setVolume(0)` on the local player. Local playback is paused while the
renderer loads; when the renderer reports `PLAYING`, the app reads its current
position and seeks the muted local player there before resuming. This avoids
losing the first seconds on slow TVs and starts both clocks together. The
local audio stays muted for the whole connection: buffering, playback errors
and transport polling failures never restore it. The only ways to hear audio
locally are disconnecting or choosing **Riproduci solo qui**, which closes the
session and resumes local playback unmuted. Local play/pause events are
mirrored to the renderer, as are explicit seeks. SponsorBlock skips move the
local player to the segment end and forward the same target to the renderer,
but only after `GetPositionInfo` confirms that the renderer has not already
passed it, so a TV running ahead is never rewound. The renderer is never
periodically sought to match local playback: local buffering and position
query latency could otherwise cause visible rewinds on the TV. The clocks can
still drift after the handshake; SponsorBlock and progress use the local
clock, so a local player that falls behind may trigger a skip late, or after
the renderer has already left the segment.
Closing the player stops the renderer but keeps the connection, so the next
video is cast again. Disconnecting closes the transport and the media server.

### Offline downloads

The download action in the channel page saves the best **muxed** stream to `downloads/<videoId>.mp4` in the application support directory. Muxed streams are single-file and need no ffmpeg, but YouTube usually limits them to 360p. Downloads are tracked in SQLite; the **Salvati** view lists ready files and the player prefers the local file when present. Removing a download deletes the file and clears the metadata. There is no download queue, resume, or cancellation yet.

### Local MP4 library

The **Video locali** view is separate from subscriptions, downloads, and Watch later. **Aggiungi video** opens a native MP4 picker and stores each path in `local_videos`. The title is read from the MP4 `©nam` atom (or 3GPP `titl`), falling back to the file name without extension when no title is present; the movie header supplies the duration. Metadata parsing is bounded and reads only box headers and metadata payloads, so large files are not loaded into memory. Re-adding a path refreshes its metadata without changing its position, and removing an entry from the list does not delete the file. Local playback uses the same media_kit player but skips YouTube-only features such as SponsorBlock, chapters, watch state, and Watch later.

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

## Build from source (Android)

Requirements: Flutter 3.47.7 or a compatible stable SDK and the Android SDK. The generated `android/` project uses minSdk/targetSdk from the Flutter defaults.

```bash
flutter pub get
flutter build apk --debug
flutter run -d <android-device>
```

The main manifest declares `INTERNET`, the data-sync foreground-service permissions, and `POST_NOTIFICATIONS`. `DownloadKeepAlive` starts `DownloadService` while a video download runs; the service keeps the process alive and shows a low-priority notification. A download that does not survive process death is reset to `none` on the next launch.

The Android build hides Windows-only update entries. It uses the adaptive icon and dark launch background under `android/app/src/main/res`. Release APKs need a release signing configuration before distribution.

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

1. Create a semantic tag, for example `v2.0.0`.
2. Push the tag.
3. `.github/workflows/release.yml` runs on `windows-latest`.
4. The workflow extracts `2.0.0` from the tag and writes it to `pubspec.yaml` for the CI build only.
5. Flutter is built with `--dart-define=APP_VERSION=2.0.0`, so the version shown in the application footer matches the release.
6. NSIS receives the same version and build number, so the installer filename and Windows file version match.
7. The workflow uploads the installer and `SHA256SUMS.txt` as artifacts and publishes a GitHub Release.

`workflow_dispatch` is also supported; in that case the version is read from `pubspec.yaml`.

The app footer reads `kAppVersion` from `lib/src/version.dart`, with a development fallback. The release build overrides it through the Dart define.

## Tests

```powershell
# Unit tests: RSS, CSV Takeout, resolver, seek accumulator, migrations,
# update feed/version/model, DLNA parsing/SOAP/media proxy/cast/firewall
# All DLNA tests are hermetic: fakes, MockClient and loopback HTTP servers.
# They do not need a TV, multicast or a firewall rule, so they run in CI.
flutter test

# Deterministic desktop E2E: onboarding, import, feed, channel archive/history,
# tags, filters, offline download, chapters/bookmarks, per-channel speed,
# refresh-only-channel, player error
flutter test integration_test -d windows

# Live network E2E: @antirez feed, channel search, video link + auto-subscribe
flutter test integration_test_live/live_youtube_test.dart -d windows --dart-define=RUN_LIVE_TESTS=true

# Live DLNA testing against a real TV is manual only: it is not part of the
# repository test suite and is never run by CI.
```

Live DLNA verification was performed on a moto g(30) (Android 12) with a
Samsung UE40MU6470. Discovery, casting, explicit seeks to 3:07 and 8:12, and
a SponsorBlock skip from 11:40 to 12:46 worked without periodic replays or
backward jumps. Initial buffering and handshake also completed without the
video restarting.

## Limits and risks

- RSS exposes at most 15 uploads per channel. Deeper history needs the YouTube Data API, yt-dlp, or another extractor.
- The fallback muxed stream is usually 360p; HLS is preferred when available, up to 720p on Android. Available quality depends on the extracted manifest; separate DASH audio/video tracks are not combined.
- Tags are not available for every video and cost one watch-page request per uncached video.
- Offline downloads use muxed streams, usually 360p, and do not support resume, cancellation, or a download queue.
- Local MP4 files must remain at the path where they were added; the library stores the path, not a copy.
- RSS history keeps one row per video id; it is not a log of every feed refresh. The current feed view still shows only the latest entry per channel.
- Chapters depend on timestamps in the description; videos without timestamped descriptions have no chapters. The outline captures the playback position when it is opened for new bookmarks.
- Channel history records the first time a video was opened or marked watched; toggling watched off does not erase the history entry.
- Shorts and live streams are not filtered separately.
- SSAI can eventually put ads inside direct streams; the current approach is not future-proof.
- Third-party YouTube clients may be subject to YouTube's Terms of Service.
- Update checks use GitHub's public Releases API without authentication; the unauthenticated limit is 60 requests per hour per IP. The app checks at most every six hours and reuses ETag responses.
- The updater only checks and opens the release page or installer URL; it does not download or install silently. Updating remains a manual download-and-run step.
- DLNA casting requires the TV and the PC/phone on the same local network. Windows
  Firewall must allow inbound connections to the Expeditus executable; the
  app can add that rule after a UAC confirmation. If the network profile is
  Public and the rule is not granted, the renderer cannot fetch the proxied
  stream. There is no transcoding, so unsupported codecs still fail on the
  device. Renderer quirks (HLS support, poster/album art, metadata parsing)
  vary by model.
- The installer is unsigned and the UI is currently in Italian.

## License

Expeditus is MIT-licensed. The Windows bundle includes GPL-2.0-or-later libmpv/FFmpeg components and other third-party libraries. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) and [LICENSES](../LICENSES) for the full notices, license texts, and GPL source offer.
