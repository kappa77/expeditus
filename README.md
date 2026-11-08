# Expeditus

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

**A quiet, text-first inbox for your YouTube subscriptions.**

Expeditus shows only the latest upload from each channel you follow. No algorithmic home, no recommendations, no autoplay, no thumbnails in the feed. Just the channel, the title, a short description, and when it was published.

## Why Expeditus

YouTube is designed to keep you scrolling. Expeditus is designed to help you catch up and leave.

One row per channel. The latest video. That is the whole feed.

## Features

- **One latest video per channel**, in reverse chronological order.
- **No recommendations, no autoplay, no thumbnails in the feed, no Shorts feed noise.**
- **Import your subscriptions** from Google Takeout, paste channel handles or URLs, or search YouTube by keyword.
- **Channel page with two tabs:** the recent archive and the channel history, with filters, search, tags, and offline downloads.
- **Save videos for offline playback:** download a video from its channel page; it appears under **Saved** and plays from local storage.
- **Separate local MP4 library:** add video files from your computer to **Video locali**. The title comes from the file metadata, or from the file name when the metadata is missing; removing an entry never deletes the file.
- **RSS mute and feed visibility:** stop new uploads from a channel, and independently choose whether its latest video appears in the **latest/New** list.
- **Explicit Watch later list:** press `S` on a video to save it; the **Guarda più tardi** view lists saved videos in the order you added them, with the save time.
- **Add a video from a link:** paste a YouTube video URL to subscribe to its channel automatically and save the video in Watch later.
- **First-run onboarding:** the app opens on channel search with a short explanation.
- **Local-first:** subscriptions, watch state, Watch later, and settings stay on your computer. No Google login. The update check contacts GitHub without sending account data.
- **Ad-free playback:** Expeditus does not load the YouTube player, so you do not get player ads or end-screen recommendations.
- **DLNA casting:** send the current video to a TV or MediaRenderer on the same network (desktop and Android). Expeditus discovers devices with SSDP, remembers the list, and has a refresh button to search again. While connected, every opened video plays both on the device and in the app, with the app audio muted for the whole connection (including buffering and errors); audio returns only after disconnecting or choosing **Riproduci solo qui**. If the renderer does not start, the player shows the thumbnail with a play symbol so you can start it; connection and streaming errors are shown in the cast dialog and in a snackbar.
- **SponsorBlock:** optionally skip creator-read sponsors and other marked segments.
- **Playback speed** from 0.25× to 3.50× in 0.25 steps, with an optional default speed per channel.
- **Chapters and timestamped bookmarks:** jump to description chapters or save a bookmark at the current second with a personal note.
- **RSS history grouped by channel:** every video ever seen in a feed is kept once, even after it leaves the current 15-item feed. The history is grouped under each channel and can be filtered by channel or searched.
- **Update check:** at startup, and then at most every six hours, Expeditus asks GitHub for the latest release, caches the response, and shows a discreet update entry in the sidebar and status bar. The dialog opens the release page or the installer; installation stays manual.
- **Refresh only one channel** from its page, without waiting for the whole subscription feed.
- **±10 second seeking** with debounce: several quick presses become one combined jump.
- **Keyboard-first (desktop):** move, open, mark watched, save to Watch later, search, and refresh without touching the mouse.
- **Touch-first Android layout:** bottom navigation, full-width search with a clear button, row action sheets, pull-to-refresh, safe-area handling, and layouts that follow the system font size.
- **Android app:** adaptive icon, dark splash screen, offline downloads kept alive by a foreground service, and no Windows-only update entries.
- **Focus mode:** hide descriptions and keep only channel and title.

## Casting to a TV

Open a video and press the cast icon in the player bar. The first time, Expeditus searches the local network for DLNA MediaRenderers; use the refresh button in the dialog to search again. Select a device and wait for the connection animation. From then on, every video you open plays on the TV and in Expeditus with the app audio muted. The TV must be on the same network as the PC or phone. On Android, Expeditus holds a multicast lock while it searches for renderers.

The TV reaches the video through a small media server inside Expeditus. If Windows Firewall blocks it, the app detects that the TV never contacted the PC and shows a **Consenti accesso rete** button; Windows asks for confirmation (UAC) and then adds an inbound rule for Expeditus. This also works when the home network is classified as Public. If you prefer to add the rule manually, run this in an administrator prompt with the Expeditus executable path:

```powershell
netsh advfirewall firewall add rule name="Expeditus-DLNA" dir=in action=allow program="C:\Path\To\expeditus.exe" enable=yes profile=any protocol=any
```

Some renderers support only a subset of codecs. Expeditus prefers a muxed MP4 for casting and falls back to a proxied HLS stream.

## Install (Windows)

1. Open the [latest release](https://github.com/kappa77/expeditus/releases).
2. Download `ExpeditusSetup-x.y.z.exe`.
3. Double-click it.

That is the whole installation: no wizard, no unzip, no administrator rights, and no separate runtime packages. Expeditus installs silently for the current user in `%LOCALAPPDATA%\Programs\Expeditus`, creates Start Menu and desktop shortcuts, and launches itself. Remove it from **Settings → Apps**.

The installer is not code-signed yet, so Windows SmartScreen may show a warning.

## Install (Android)

The Android build is not on a store yet. Build a release APK from the repository:

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

Configure a release signing key before distributing the APK. Updates on Android are installed manually (or through a store later); the GitHub update entry is Windows-only.

## First run

1. Launch Expeditus: the first-run screen opens channel search.
2. Search a channel by name, or choose **Import** to load a Google Takeout `subscriptions.csv`, paste channel handles/URLs/IDs, or add a video from a link.
3. On desktop, pick a video and press `Enter` to play it; press `M` to mark it watched or `S` to add it to Watch later. On Android, tap a row to play it, and use the row menu for watched / Watch later / channel actions.

## Keyboard shortcuts (desktop)

| Key | Action |
|---|---|
| `↑` / `↓` or `J` / `K` | Move selection |
| `Enter` | Play selected video |
| `M` | Mark watched / unwatched |
| `S` or `W` | Add to / remove from Watch later |
| `R` | Refresh subscriptions |
| `/` | Focus search |
| `Esc` | Clear search |
| `O` | Open on YouTube |
| `←` / `→` or `J` / `L` (player) | Seek 10 seconds |

## Project status

- Windows desktop and Android are the current targets.
- Windows updates use the GitHub installer; Android updates are manual (or store-managed later). DLNA casting works on both platforms; the Windows Firewall helper is desktop-only.
- The application interface is currently in Italian.
- Playback depends on YouTube and on the bundled media libraries. If a video does not play, use **Open on YouTube**.
- Expeditus is not affiliated with YouTube or Google. Third-party clients may be subject to YouTube's Terms of Service.

## License

Expeditus is released under the **MIT License** — see [LICENSE](LICENSE).

The Windows build bundles libmpv, which is **GPL-2.0-or-later**. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for third-party notices, license texts, and the GPL source offer.

## Documentation

- [Technical documentation](docs/TECHNICAL.md) — architecture, data flow, build, tests, installer, and release process.
- [Changelog](CHANGELOG.md) — release notes.
- [Third-party notices](THIRD_PARTY_NOTICES.md) — licenses for bundled native components and Dart/Flutter packages.
- [License](LICENSE) — MIT.
