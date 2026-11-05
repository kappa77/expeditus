# Expeditus

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

**YouTube come una casella di posta, non un casinò.**

Expeditus è un'app desktop Flutter per le tue iscrizioni YouTube. Mostra **un solo video per canale** — l'ultimo pubblicato — in ordine cronologico. Niente home algoritmica, niente raccomandazioni, niente autoplay, niente thumbnail: solo canale, titolo, due righe di descrizione e tempo di pubblicazione.

La riproduzione usa stream diretti (nessun player YouTube), quindi non passa dal circuito pubblicitario del player. SponsorBlock salta gli sponsor interni al video.

## English

**Expeditus** is a Flutter desktop app that turns YouTube subscriptions into a quiet, text-first inbox. It shows only the latest upload from each channel, with no algorithmic home, no recommendations, no autoplay, and no thumbnails. It reads public RSS feeds (no Google login, no API quota), stores everything locally, and plays videos through direct streams with libmpv instead of the YouTube player. It also includes a channel archive with keyword and tag filters, SponsorBlock, playback speed from 0.25× to 3.50×, and debounced ±10-second seeking.

Released under the **MIT License**. The Windows build bundles libmpv, which is **GPL-2.0-or-later**; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for notices and the source offer.

## Cosa fa

- Feed testuale, una riga per canale, solo l'ultimo upload.
- Import da Google Takeout (`subscriptions.csv`), incolla handle/URL/ID, oppure **cerca un canale per parola** direttamente su YouTube.
- Voce **Cerca canale** nella sidebar: apre la ricerca YouTube e aggiunge il canale con un click.
- **Dettaglio canale**: click sul nome del canale nel feed o dalla lista Canali. Mostra i video passati già presenti nell'RSS, con filtro per termine, stato (tutti/non visti/visti/in coda) e **tag** del video quando disponibili.
- Player: velocità **0.25×–3.50×** a passi di 0.25, e **±10 secondi** con debounce (più pressioni rapide si sommano in un'unica seek).
- Database locale SQLite; nessun login Google, nessuna quota API.
- Ricerca locale solo tra le iscrizioni.
- Stati: nuovo, visto, in coda; “segna tutti letti”.
- Canali silenziabili o rimovibili.
- Lettura da tastiera: `↑`/`↓` o `J`/`K`, `Invio` guarda, `M` segna visto, `S` coda, `R` aggiorna, `/` cerca, `O` apre su YouTube. Nel player `←`/`→` o `J`/`L` spostano di 10 secondi.
- Player con libmpv + stream diretto; SponsorBlock con categorie selezionabili.
- Modalità focus: nasconde le descrizioni.
- Aggiornamento automatico ogni 15/30/60/120/240 minuti.

## Come funziona

1. Le iscrizioni sono salvate in SQLite.
2. Per ogni canale Expeditus legge il feed Atom pubblico:
   `https://www.youtube.com/feeds/videos.xml?channel_id=...`
   Non serve OAuth e non si consuma quota della YouTube Data API. Il feed contiene gli ultimi 15 upload.
3. L'ultimo video per canale viene selezionato con una query `ROW_NUMBER() OVER (PARTITION BY channel_id ...)`.
4. Al click, `youtube_explode_dart` risolve uno stream diretto; `media_kit`/libmpv lo riproduce. Nessun player YouTube, nessun annuncio del player, nessuna raccomandazione.
5. SponsorBlock (`sponsor.ajay.app`) fornisce i segmenti sponsor; il player li salta.

### Nota sugli annunci

YouTube sta sperimentando la **server-side ad insertion (SSAI)**: gli annunci vengono cuciti nel manifest/stream e non sono più richieste separate. Expeditus evita il problema alla radice non usando il player YouTube. Se in futuro YouTube applicasse SSAI anche agli stream estratti, servirebbe un rilevamento a livello di manifest/segmenti: è un gatto-e-topo, non una garanzia eterna.

L'uso di client di terze parti può violare i Termini di servizio di YouTube. Usa Expeditus per contenuti che hai diritto a guardare e sostieni i creator quando puoi.

## Installazione (Windows)

Scarica **`ExpeditusSetup-x.y.z.exe`** dalla pagina [Releases](https://github.com/kappa77/expeditus/releases), avvialo e segui il wizard. Non serve scompattare nulla e non serve l'amministratore: l'installazione è per-utente in `%LOCALAPPDATA%\Programs\Expeditus`, con collegamenti nel menu Start e disinstallazione da **Impostazioni → App**.

L'installer è fatto con **NSIS** (licenza zlib/libpng, nessun EULA aggiuntivo). Include le licenze MIT, le note third-party e l'offerta di sorgente GPL per libmpv. Al momento non è firmato con un certificato di code signing: Windows SmartScreen può mostrare un avviso.

## Avvio (Windows)

```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File tool/fetch_windows_deps.ps1
flutter run -d windows
```

`tool/fetch_windows_deps.ps1` scarica gli archivi precompilati di libmpv e ANGLE usati da `media_kit` e ne verifica l'MD5. Serve perché il download diretto da GitHub può rispondere `504`; lo script usa un mirror come fallback. L'archivio viene messo in `build/windows/x64/`, dove la build CMake lo trova e lo verifica.

> `windows/CMakeLists.txt` forza `CMAKE_INSTALL_PREFIX` accanto all'eseguibile. Senza questa correzione, con alcune combinazioni Visual Studio/CMake l'install step prova a scrivere in `C:/Program Files/expeditus` e richiede privilegi di amministratore.

### Installer locale

Serve NSIS 3 (`choco install nsis`, oppure <https://nsis.sourceforge.io/>). Poi:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_installer.ps1
```

Lo script legge la versione da `pubspec.yaml`, compila `flutter build windows --release`, genera `dist/ExpeditusSetup-x.y.z.exe` e `dist/SHA256SUMS.txt`. Con `-SkipFlutterBuild` riusa la build già presente.

## Release

La release è automatica via GitHub Actions (`.github/workflows/release.yml`):

1. Aggiorna `version:` in `pubspec.yaml`.
2. Commit e push.
3. Crea e pusha un tag che corrisponde alla versione, per esempio:
   `git tag v1.0.0 && git push origin v1.0.0`.
4. Il workflow compila Flutter, scarica libmpv/ANGLE, installa NSIS, crea l'installer, calcola lo SHA-256 e pubblica la release con installer e checksum.

## Test

Unit test (parser RSS, CSV Takeout, resolver):

```powershell
flutter test
```

E2E desktop con feed simulato (import, ultimo-per-canale, ricerca, visto, coda, focus mode, errore player):

```powershell
flutter test integration_test/app_test.dart -d windows
```

E2E **live** contro un canale reale (`@antirez`): risolve l'handle, legge il feed RSS reale, importa dall'interfaccia, cerca il canale per parola e risolve uno stream reale. È disattivato di default perché dipende dalla rete:

```powershell
flutter test integration_test_live/live_youtube_test.dart -d windows --dart-define=RUN_LIVE_TESTS=true
```

## Struttura

```
lib/
  main.dart
  src/
    app.dart
    models.dart
    theme.dart
    data/database.dart
    services/rss_service.dart
    services/import_service.dart
    services/channel_search_service.dart
    services/sponsorblock_service.dart
    services/stream_resolver.dart
    services/video_tags_service.dart
    state/app_state.dart
    util/format.dart
    util/seek_accumulator.dart
    ui/home_screen.dart
    ui/video_row.dart
    ui/channels_view.dart
    ui/import_dialog.dart
    ui/channel_search_tab.dart
    ui/settings_dialog.dart
    ui/channel_page.dart
    ui/player_page.dart
installer/
  expeditus.nsi
.github/
  workflows/release.yml
integration_test/
  app_test.dart
integration_test_live/
  live_youtube_test.dart
test/
  rss_service_test.dart
  import_service_test.dart
  seek_accumulator_test.dart
```

## Limiti e prossimi passi

- Lo stream “muxed” di fallback è limitato a 360p; quando disponibile Expeditus usa HLS. Per il 1080p/4K servirà un resolver yt-dlp/ffmpeg opzionale.
- Il feed RSS espone al massimo 15 video per canale. Con un polling ogni 30 minuti è più che sufficiente; per recuperare backlog o durate serve la YouTube Data API o un arricchimento lazy.
- Shorts e live non sono ancora filtrati: il feed RSS non espone la durata.
- Il dettaglio canale mostra i **15 video** dell'RSS. Per uno storico più profondo servono YouTube Data API o yt-dlp.
- I tag sono letti dalla pagina del video, uno per video, e messi in cache. Molti video non hanno tag: in quel caso non compare nulla.
- La riproduzione dipende da YouTube: se un video non si apre, c'è sempre “Apri su YouTube”.
- Nessuna sincronizzazione tra dispositivi: tutto è locale, per scelta.

## Licenza

Il codice di Expeditus è distribuito con licenza **MIT** — vedi [LICENSE](LICENSE).

Le release Windows includono anche componenti nativi con licenze proprie:

- **libmpv / FFmpeg** — GPL-2.0-or-later
- **ANGLE** — BSD-3-Clause
- **SwiftShader / Vulkan loader** — Apache-2.0
- **SQLite** — public domain
- **Flutter engine** — BSD-3-Clause

Trovi l'elenco completo, i testi delle licenze e l'offerta di sorgente GPL in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) e nella cartella [LICENSES](LICENSES). L'app mostra le licenze dei pacchetti Dart/Flutter da **Impostazioni → Licenze open source**.

> MIT e GPL-2.0 sono compatibili, ma un installer che include libmpv deve rispettare gli obblighi GPL per quel componente. Se vuoi una release interamente permissiva, va sostituito il backend libmpv con una build LGPL o un altro player.
