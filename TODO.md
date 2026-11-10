# TODO

## Trasmissione DLNA

- [x] Rieseguire i test Flutter `test/cast_controller_test.dart`, `test/dlna_test.dart` e `test/media_server_test.dart`: tutti superati (36 test).
- [x] Verificare la formattazione Dart dei file modificati: `dart format --output=none --set-exit-if-changed` non segnala modifiche.
- [x] Provare la riproduzione su una TV DLNA reale: verificato su moto g(30) (Android 12) con Samsung UE40MU6470. Discovery, cast, seek espliciti a 3:07 e 8:12 e salto SponsorBlock da 11:40 a 12:46 senza replay periodici o riavvolgimenti. Anche il buffering iniziale e l'handshake sono ripartiti senza ricominciare il video.
- [x] Divergenza valutata. Il lettore locale ora riparte dalla posizione corrente della TV dopo l'handshake, quindi non nasce già in ritardo. I salti SponsorBlock usano ancora la posizione locale, ma il seek verso la TV viene inviato solo se la TV non ha già superato la fine del segmento, evitando riavvolgimenti. La deriva residua e i suoi limiti sono documentati in `docs/TECHNICAL.md`.
