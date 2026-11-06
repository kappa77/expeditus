# Changelog

## 2.2.0

Automatic network setup and troubleshooting for DLNA discovery.

### Added

- Windows network detection: when no DLNA device is found and the active
  network is categorised as **Public**, the cast dialog offers a
  **Rendi la rete privata** button that switches it to Private through UAC
  and repeats the search. Discovery is blocked on Public networks because
  Windows applies the built-in Network Discovery rules only to Private
  networks.
- A troubleshooting checklist in the cast dialog when no device is found
  (TV on and on the same network, network Private, DLNA renderer enabled on
  the TV, firewall access).

## 2.0.0

DLNA casting to TVs and MediaRenderers on the local network.

### Added

- Cast button in the player with the standard cast / cast-connected icons.
- SSDP discovery of DLNA MediaRenderers, cached in the app and repeatable with
  a refresh button. Devices without an AVTransport service are ignored.
- Device connection through UPnP AVTransport (SOAP), with connection spinner,
  clear error messages and retry.
- Local media proxy: downloaded files are served from disk, remote YouTube
  streams are proxied with Range support, and HLS playlists are rewritten so
  variants and segments keep pointing at the PC.
- DIDL-Lite metadata with title, video class, protocol info and YouTube
  thumbnail as album art.
- Poster with a play symbol when the renderer has not confirmed playback yet.
- Every video opened while connected is cast to the TV. Local playback is
  paused during the handshake and resumes, muted, when the TV starts.
- App audio stays muted for the whole TV connection, including buffering and
  errors. It returns only on disconnect or **Riproduci solo qui**.
- Play/pause mirroring, seek forwarding and drift correction against the
  renderer.
- Windows Firewall detection: when the TV cannot reach the local proxy, the
  app offers a **Consenti accesso rete** button that adds an inbound rule
  through UAC (`netsh`, scoped to the Expeditus executable, all profiles).

### Tests

- Hermetic DLNA unit tests for parsing, SOAP, DIDL metadata, the local media
  proxy, cast state and the firewall service. They use fakes, `MockClient` and
  loopback servers, so CI does not need a TV, multicast or firewall changes.
- Live TV verification remains manual and is not part of the repository test
  suite.
