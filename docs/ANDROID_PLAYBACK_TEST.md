# Android playback verification

Device: Motorola moto g(30), Android 12. Date: 2026-11-13.
The installed app before the session was 2.5.0 (19); the tested working tree is
based on 2.5.4 (23). Integration tests use their own temporary SQLite database.

The public test video is Big Buck Bunny (`aqz-KE-bpKQ`). Its extracted stream
was labeled `360p · muxed`, and the native decoder reported **640 × 360**.
The 360p label is therefore accurate for this stream. A 720p selection cap
does not upscale it; separate DASH audio/video tracks are not combined.

## Extractor measurements

The same device and video produced these individual extraction measurements:

| Client | Watch page | Time | Result |
| --- | --- | ---: | --- |
| iOS | No | 5.318 s | `YoutubeExplodeException` |
| iOS | Yes | 10.007 s | Timed out at the diagnostic limit |
| Android SDK-less | No | 0.599 s | One muxed stream; no HLS |
| Android SDK-less | Yes | 1.995 s | One muxed stream; no HLS |

The initial sequential extraction took 20.843 s and the first displayed frame
arrived after 25.032 s. This motivated racing the two fast clients on Android,
with a 750 ms HLS preference window and cancellation of the slower request.
These are measurements from one device/network/video, not a universal startup
latency guarantee.

The final complete device run measured:

| Measurement | Sequential extraction | Final Android resolver |
| --- | ---: | ---: |
| Initial stream resolution | 20.843 s | 2.849 s |
| First displayed frame | 25.032 s | 7.013 s |
| Resolution after the long pause | 16.922 s | 1.565 s |
| Resume after the long pause | 17.846 s | 2.292 s |

## Pause and resource checks

The final native-player run passed these checks:

- Open at the saved 60-second position and display a real video frame.
- Pause, deliberately reset the native clock to zero, then restore the pause
  point without another extraction.
- Pause for 125 real seconds, resolve a fresh URL, and resume at the exact
  captured native position: **60.199 seconds**.
- Send the real Android Activity to Home for eight seconds, then foreground it,
  both while manually paused and while playing. A manual pause stays paused;
  playback paused by the app resumes at the captured point.
- Pause/resume through additional Flutter lifecycle notifications.
- Open and close eight real `PlayerPage` instances, including their native
  decoder and video controller. Each memory sample follows a six-second wait
  to include media_kit's deferred native destruction.

Final post-close RSS samples in MiB:
`480.2, 492.7, 491.1, 491.3, 491.4, 490.3, 492.3, 490.1`.

After warm-up, RSS stayed around 490–493 MiB and ended below its earlier peak.
This short debug run showed no sustained memory growth. RSS includes the
Flutter debug runtime, shared libraries, allocator caches and native buffers;
it is not a count of leaked objects or the release app's memory requirement.
It cannot exclude smaller or longer-term native leaks.

The complete host suite also passed **166 tests**, and Flutter analysis reported
no issues. The normal release APK was rebuilt, installed over the test app with
`-r`, and launched successfully at the end of the session.

## Reproduction

Run the host unit/widget suite separately from Android builds. Flutter's
generated plugin registrant is shared between debug tests and release builds.
Switching modes must regenerate it, including or excluding dev-only plugins
such as `integration_test`; the device runner allows Flutter's normal pub/tooling
step for this reason.

```powershell
flutter test --no-pub
.\tool\android_playback_probe.ps1 -DeviceId DEVICE_ID
```

The runner tests actual Home/foreground transitions both while paused and while
playing, collects eight `dumpsys meminfo` snapshots under
`build/android-playback-probe`, then builds and installs the normal release APK
with `adb install -r`. It never uninstalls the app or clears its storage.

To compare extraction clients independently:

```powershell
flutter test integration_test/android_stream_probe_test.dart -d DEVICE_ID
```

That standalone diagnostic installs a test entry point. Run the full device
runner afterward to restore the regular app.
