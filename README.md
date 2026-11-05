# Expeditus

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

**A quiet, text-first inbox for your YouTube subscriptions.**

Expeditus shows only the latest upload from each channel you follow. No algorithmic home, no recommendations, no autoplay, no thumbnails. Just the channel, the title, a short description, and when it was published.

## Why Expeditus

YouTube is designed to keep you scrolling. Expeditus is designed to help you catch up and leave.

One row per channel. The latest video. That is the whole feed.

## Features

- **One latest video per channel**, in reverse chronological order.
- **No recommendations, no autoplay, no thumbnails, no Shorts feed noise.**
- **Import your subscriptions** from Google Takeout, paste channel handles or URLs, or search YouTube by keyword.
- **Channel page with two tabs:** the recent archive and the channel history, with filters, search, tags, and offline downloads.
- **Save videos for offline playback:** download a video from its channel page; it appears under **Saved** and plays from local storage.
- **RSS mute and feed visibility:** stop new uploads from a channel, and independently choose whether its latest video appears in the **latest/New** list.
- **Add a video from a link:** paste a YouTube video URL to subscribe to its channel automatically and put the video in your queue.
- **First-run onboarding:** the app opens on channel search with a short explanation.
- **Local-first:** subscriptions, watch state, queue, and settings stay on your computer. No Google login.
- **Ad-free playback:** Expeditus does not load the YouTube player, so you do not get player ads or end-screen recommendations.
- **SponsorBlock:** optionally skip creator-read sponsors and other marked segments.
- **Playback speed** from 0.25× to 3.50× in 0.25 steps, with an optional default speed per channel.
- **Chapters and timestamped bookmarks:** jump to description chapters or save a bookmark at the current second with a personal note.
- **Refresh only one channel** from its page, without waiting for the whole subscription feed.
- **±10 second seeking** with debounce: several quick presses become one combined jump.
- **Keyboard-first:** move, open, mark watched, queue, search, and refresh without touching the mouse.
- **Focus mode:** hide descriptions and keep only channel and title.

## Install (Windows)

1. Open the [latest release](https://github.com/kappa77/expeditus/releases).
2. Download `ExpeditusSetup-x.y.z.exe`.
3. Double-click it.

That is the whole installation: no wizard, no unzip, no administrator rights, and no separate runtime packages. Expeditus installs silently for the current user in `%LOCALAPPDATA%\Programs\Expeditus`, creates Start Menu and desktop shortcuts, and launches itself. Remove it from **Settings → Apps**.

The installer is not code-signed yet, so Windows SmartScreen may show a warning.

## First run

1. Launch Expeditus: the first-run screen opens channel search.
2. Search a channel by name, or choose **Import** to load a Google Takeout `subscriptions.csv`, paste channel handles/URLs/IDs, or add a video from a link.
3. Pick a video and press `Enter` to play it. Press `M` to mark it watched or `S` to add it to the queue.

## Keyboard shortcuts

| Key | Action |
|---|---|
| `↑` / `↓` or `J` / `K` | Move selection |
| `Enter` | Play selected video |
| `M` | Mark watched / unwatched |
| `S` | Add to / remove from queue |
| `R` | Refresh subscriptions |
| `/` | Focus search |
| `Esc` | Clear search |
| `O` | Open on YouTube |
| `←` / `→` or `J` / `L` (player) | Seek 10 seconds |

## Project status

- Windows desktop is the current target.
- The application interface is currently in Italian.
- Playback depends on YouTube and on the bundled media libraries. If a video does not play, use **Open on YouTube**.
- Expeditus is not affiliated with YouTube or Google. Third-party clients may be subject to YouTube's Terms of Service.

## License

Expeditus is released under the **MIT License** — see [LICENSE](LICENSE).

The Windows build bundles libmpv, which is **GPL-2.0-or-later**. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for third-party notices, license texts, and the GPL source offer.

## Documentation

- [Technical documentation](docs/TECHNICAL.md) — architecture, data flow, build, tests, installer, and release process.
- [Third-party notices](THIRD_PARTY_NOTICES.md) — licenses for bundled native components and Dart/Flutter packages.
- [License](LICENSE) — MIT.
