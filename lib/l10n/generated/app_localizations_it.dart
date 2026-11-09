// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get close => 'Chiudi';

  @override
  String get cancel => 'Annulla';

  @override
  String get retry => 'Riprova';

  @override
  String get back => 'Indietro';

  @override
  String get remove => 'Rimuovi';

  @override
  String get save => 'Salva';

  @override
  String get done => 'Fatto';

  @override
  String get importAction => 'Importa';

  @override
  String get searchAction => 'Cerca';

  @override
  String get refreshAction => 'Aggiorna';

  @override
  String get addAction => 'Aggiungi';

  @override
  String get playAction => 'Riproduci';

  @override
  String get disconnect => 'Disconnetti';

  @override
  String get clearSearch => 'Cancella ricerca';

  @override
  String get deviceFallback => 'dispositivo';

  @override
  String get computerNoun => 'computer';

  @override
  String get phoneNoun => 'telefono';

  @override
  String get onComputer => 'sul computer';

  @override
  String get onPhone => 'sul telefono';

  @override
  String get fromComputer => 'dal computer';

  @override
  String get fromPhone => 'dal telefono';

  @override
  String get openOnYouTube => 'Apri su YouTube';

  @override
  String get videoActions => 'Azioni video';

  @override
  String get openChannel => 'Apri canale';

  @override
  String get localFileLabel => 'File locale';

  @override
  String get relativeNever => 'mai';

  @override
  String get relativeNow => 'adesso';

  @override
  String get relativeYesterday => 'ieri';

  @override
  String relativeMinutes(int count) {
    return '$count min fa';
  }

  @override
  String relativeHours(int count) {
    return '$count h fa';
  }

  @override
  String relativeDays(int count) {
    return '$count g fa';
  }

  @override
  String updatedRelative(String relative) {
    return 'aggiornato $relative';
  }

  @override
  String savedRelative(String relative) {
    return 'salvato $relative';
  }

  @override
  String addedRelative(String relative) {
    return 'aggiunto $relative';
  }

  @override
  String openedRelative(String relative) {
    return 'aperto $relative';
  }

  @override
  String get navLatest => 'Ultimi';

  @override
  String get navNew => 'Nuovi';

  @override
  String get navWatchLater => 'Guarda più tardi';

  @override
  String get navSaved => 'Salvati';

  @override
  String get navLocal => 'Video locali';

  @override
  String get navRss => 'Storico RSS';

  @override
  String get navChannels => 'Canali';

  @override
  String get navUpdates => 'Aggiornamenti';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get navImport => 'Importa';

  @override
  String get navSearchChannel => 'Cerca canale';

  @override
  String get navMore => 'Altro';

  @override
  String get mobileQueueShort => 'Dopo';

  @override
  String get openMenu => 'Apri il menu';

  @override
  String get closeMenu => 'Chiudi menu';

  @override
  String get sidebarTagline =>
      'Solo ciò che hai scelto.\nNessuna raccomandazione.';

  @override
  String get viewLatest => 'Ultimi';

  @override
  String get viewNew => 'Nuovi';

  @override
  String get viewWatchLater => 'Guarda più tardi';

  @override
  String get viewSaved => 'Salvati';

  @override
  String get viewLocal => 'Video locali';

  @override
  String get viewRss => 'Storico RSS';

  @override
  String get viewChannels => 'Canali';

  @override
  String videosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String channelsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canali',
      one: '1 canale',
    );
    return '$_temp0';
  }

  @override
  String newLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi',
      one: '1 nuovo',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count iscrizioni',
      one: '1 iscrizione',
    );
    return '$_temp0';
  }

  @override
  String mp4FilesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file MP4',
      one: '1 file MP4',
    );
    return '$_temp0';
  }

  @override
  String errorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errori',
      one: '1 errore',
    );
    return '$_temp0';
  }

  @override
  String channelsImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canali importati',
      one: '1 canale importato',
    );
    return '$_temp0';
  }

  @override
  String alreadyPresentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count già presenti',
      one: '1 già presente',
    );
    return '$_temp0';
  }

  @override
  String videosAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video aggiunti',
      one: '1 video aggiunto',
    );
    return '$_temp0';
  }

  @override
  String subtitleNew(String videos) {
    return '$videos da vedere';
  }

  @override
  String subtitleWatchLater(String videos) {
    return '$videos da guardare';
  }

  @override
  String subtitleSaved(String videos) {
    return '$videos offline';
  }

  @override
  String subtitleLocal(String files, String location) {
    return '$files $location';
  }

  @override
  String subtitleRssAll(String videos) {
    return '$videos visti nel feed';
  }

  @override
  String subtitleRssFiltered(String videos, String total) {
    return '$videos · $total totali';
  }

  @override
  String subtitleChannels(String subscriptions) {
    return '$subscriptions';
  }

  @override
  String subtitleLatest(String channels, String newCount) {
    return '$channels · $newCount';
  }

  @override
  String get markAllRead => 'Segna letti';

  @override
  String get refreshWithKey => 'Aggiorna (R)';

  @override
  String get refreshTooltip => 'Aggiorna';

  @override
  String get addVideo => 'Aggiungi video';

  @override
  String get moreActions => 'Altre azioni';

  @override
  String get searchSubscriptionsHint => 'Cerca nelle iscrizioni…';

  @override
  String get searchLocalHint => 'Cerca video locali…';

  @override
  String get noChannelsImported => 'Nessun canale importato.';

  @override
  String get noVideosAdded => 'Nessun video aggiunto.';

  @override
  String get mp4VideoType => 'Video MP4';

  @override
  String get takeoutCsvType => 'Google Takeout CSV';

  @override
  String get channelFilterLabel => 'Canale';

  @override
  String allChannelsWithCount(int count) {
    return 'Tutti i canali ($count)';
  }

  @override
  String rssChannelSummary(String channels, String videos) {
    return '$channels · $videos';
  }

  @override
  String rssSelectedSummary(String videos, String channel) {
    return '$videos · $channel';
  }

  @override
  String get emptyNoResults => 'Nessun risultato';

  @override
  String get emptyNoResultsBody =>
      'Prova con un altro termine. Cerchiamo solo nei canali che segui.';

  @override
  String get emptyNoResultsLocalBody => 'Prova con un altro termine.';

  @override
  String get emptyNoLocalVideos => 'Nessun video locale';

  @override
  String emptyNoLocalVideosBody(String fromLocation) {
    return 'Aggiungi un file MP4 $fromLocation. Il titolo viene letto dai metadati del file, oppure dal nome del file.';
  }

  @override
  String get emptyInbox => 'La tua casella è vuota';

  @override
  String get emptyInboxBody =>
      'Importa le tue iscrizioni da Google Takeout, oppure incolla un handle o un URL di canale.';

  @override
  String get emptyCaughtUp => 'Sei in pari';

  @override
  String get emptyWatchLater => 'Guarda più tardi è vuoto';

  @override
  String get emptyWatchLaterBodyCompact =>
      'Metti un video in Guarda più tardi dal menu della riga (⋮), oppure aprilo e usa l’icona dell’orologio.';

  @override
  String get emptyWatchLaterBodyDesktop =>
      'Metti un video in Guarda più tardi con il tasto S o con l’icona dell’orologio nella riga del video.';

  @override
  String get emptyNoSaved => 'Nessun video salvato';

  @override
  String get emptyNoSavedBody =>
      'Apri il dettaglio di un canale e usa il pulsante di download per guardarlo offline.';

  @override
  String get emptyNoVideos => 'Nessun video';

  @override
  String get emptyRssBody =>
      'I video che compaiono nei feed RSS resteranno qui, senza duplicati, anche quando non sono più nell’ultimo feed.';

  @override
  String get emptyNoNewBody => 'Nessun nuovo video dai canali che segui.';

  @override
  String get addMp4Button => 'Aggiungi video MP4';

  @override
  String get importSubscriptions => 'Importa iscrizioni';

  @override
  String get keyboardHint => 'R per aggiornare · / per cercare';

  @override
  String get statusUpdating => 'Aggiornamento…';

  @override
  String statusUpdated(String relative) {
    return 'Aggiornato $relative';
  }

  @override
  String get statusShortcuts => '↑↓ · Invio · M · S';

  @override
  String updateAvailableTooltip(String version) {
    return 'Aggiornamento disponibile: $version';
  }

  @override
  String updateNavPrompt(String version) {
    return 'Aggiorna a $version';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get sectionReading => 'Lettura';

  @override
  String get hideDescriptions => 'Nascondi descrizioni';

  @override
  String get hideDescriptionsSubtitle =>
      'Mostra solo canale e titolo. Modalità focus.';

  @override
  String get sectionUpdate => 'Aggiornamento';

  @override
  String refreshEvery(int minutes) {
    return 'Ogni $minutes minuti';
  }

  @override
  String get rssRefreshNote =>
      'Gli RSS di YouTube sono gratuiti e non consumano quota API. Expeditus controlla i canali in modo scaglionato.';

  @override
  String get sectionSponsorBlock => 'SponsorBlock';

  @override
  String get skipSponsors => 'Salta gli sponsor';

  @override
  String get skipSponsorsSubtitle =>
      'Segmenti segnalati dalla community. Solo stream diretti.';

  @override
  String get sponsorCategorySponsor => 'Sponsor';

  @override
  String get sponsorCategorySelfPromo => 'Autopromozione';

  @override
  String get sponsorCategoryInteraction => 'Like / iscrizione';

  @override
  String get sponsorCategoryIntro => 'Intro';

  @override
  String get sponsorCategoryOutro => 'Outro';

  @override
  String get sponsorCategoryPreview => 'Anteprima';

  @override
  String get sponsorCategoryMusicOfftopic => 'Musica fuori tema';

  @override
  String get sponsorCategoryFiller => 'Riempitivo';

  @override
  String get sectionHowItWorks => 'Come funziona';

  @override
  String get howItWorksBody =>
      'Expeditus non carica il player di YouTube. Risolve lo stream del video e lo riproduce con libmpv: niente annunci del player, niente raccomandazioni, niente autoplay. SponsorBlock copre gli sponsor dentro il video.';

  @override
  String privacyNote(String location) {
    return 'La riproduzione dipende da YouTube: se un video non si apre, usa “Apri su YouTube”. Iscrizioni e stato restano $location; l’app contatta YouTube per i feed e GitHub per controllare le release.';
  }

  @override
  String get licensesButton => 'Licenze open source';

  @override
  String get licensesNote =>
      'Le licenze dei componenti nativi (libmpv, ANGLE, SQLite) sono disponibili nella pagina delle licenze.';

  @override
  String get sectionLanguage => 'Lingua';

  @override
  String get languageLabel => 'Lingua dell’app';

  @override
  String get languageSubtitle => 'Scegli la lingua usata dall’interfaccia.';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSpanish => 'Español';

  @override
  String get castTitle => 'Trasmetti su dispositivo';

  @override
  String get castStatusStarting => 'Avvio della riproduzione…';

  @override
  String get castStatusPlaying => 'In riproduzione sul dispositivo';

  @override
  String get castStatusPaused => 'In pausa sul dispositivo';

  @override
  String get castStatusStopped => 'Connesso, in attesa di avvio';

  @override
  String get castStatusError => 'Errore sul dispositivo';

  @override
  String get castStatusIdle => 'Connesso';

  @override
  String get castNoStream => 'Nessuno stream disponibile per il dispositivo.';

  @override
  String get castConnectFailed => 'Aggancio non riuscito.';

  @override
  String get castSendFailed => 'Invio al dispositivo non riuscito.';

  @override
  String get castStartFailed => 'Avvio sul dispositivo non riuscito.';

  @override
  String get castFirewallWarning =>
      'La TV non riesce a contattare il PC. Serve una regola di ingresso in Windows Firewall per Expeditus.';

  @override
  String get castAllowNetwork => 'Consenti accesso rete';

  @override
  String get castWaitingWindows => 'Attesa conferma Windows…';

  @override
  String get castExplanation =>
      'I video aperti in Expeditus vengono riprodotti anche sul dispositivo. L’audio dell’app resta disattivato durante la trasmissione.';

  @override
  String get castDlnaDevices => 'Dispositivi DLNA';

  @override
  String get castSearchAgain => 'Cerca di nuovo';

  @override
  String get castSearching => 'Ricerca dispositivi in corso…';

  @override
  String castConnecting(String device) {
    return 'Aggancio a $device…';
  }

  @override
  String get castDiscoveryHintPhone =>
      'Accendi il dispositivo e assicurati che sia sulla stessa rete locale del telefono.';

  @override
  String get castDiscoveryHintDesktop =>
      'Accendi il dispositivo e assicurati che sia sulla stessa rete locale del PC. Windows potrebbe chiedere l’accesso alla rete la prima volta.';

  @override
  String get castNoDevicesFound => 'Nessun dispositivo DLNA trovato.';

  @override
  String get castNoDevicesAvailable => 'Nessun dispositivo disponibile.';

  @override
  String get castNetworkPublicWarning =>
      'La rete Windows è impostata come “Pubblica”, quindi la ricerca dei dispositivi DLNA è bloccata. Rendi la rete “Privata” per trovare la TV.';

  @override
  String get castMakeNetworkPrivate => 'Rendi la rete privata';

  @override
  String get castTroubleshootingTitle => 'Suggerimenti per la ricerca';

  @override
  String get castTroubleshootingStep1 =>
      'Accendi la TV e verifica che sia collegata alla stessa rete Wi-Fi o LAN del PC.';

  @override
  String get castTroubleshootingStep2 =>
      'Assicurati che la rete Windows sia “Privata” e non “Pubblica” (usa il pulsante sopra per correggerla).';

  @override
  String get castTroubleshootingStep3 =>
      'Verifica che sulla TV sia attivo il renderer DLNA (es. “Condivisione” o “Screen Mirroring”).';

  @override
  String get castTroubleshootingStep4 =>
      'Consenti a Expeditus l’accesso alla rete se Windows Firewall lo richiede.';

  @override
  String get castStartOnDevice => 'Avvia sul dispositivo';

  @override
  String get castSendingToDevice => 'Invio del video al dispositivo…';

  @override
  String get castPlaybackNotStarted =>
      'Riproduzione non avviata sul dispositivo.\nPremi play per iniziare.';

  @override
  String get castAudioMuted =>
      'L’audio di Expeditus resta disattivato durante la trasmissione.';

  @override
  String get castFirewallHint =>
      'La TV non riesce a contattare il PC. Consenti a Expeditus l’accesso alla rete in Windows Firewall, poi riprova.';

  @override
  String get castNetworkHint =>
      'Se non parte, verifica che TV e PC siano sulla stessa rete e che il firewall di Windows consenta a Expeditus l’accesso alla rete locale.';

  @override
  String get castPlayHereOnly => 'Riproduci solo qui';

  @override
  String get bookmarkSaved => 'Segnalibro salvato';

  @override
  String localFileNotFound(String path) {
    return 'File locale non trovato: $path';
  }

  @override
  String resumedFrom(String time) {
    return 'Ripreso da $time';
  }

  @override
  String get sponsorSkipped => 'Sponsor saltato';

  @override
  String get permissionNotGranted => 'Permesso non concesso.';

  @override
  String get castStopped => 'Trasmissione interrotta';

  @override
  String get openingFile => 'Apertura del file…';

  @override
  String get resolvingStream => 'Risoluzione dello stream…';

  @override
  String castFooter(String device) {
    return 'Cast · $device';
  }

  @override
  String castFooterMuted(String device) {
    return 'Cast · $device · muto qui';
  }

  @override
  String playerSpeedMenu(String rate) {
    return 'Velocità ($rate)';
  }

  @override
  String get chaptersAndBookmarks => 'Capitoli e segnalibri';

  @override
  String get addBookmark => 'Aggiungi segnalibro';

  @override
  String castedTo(String device) {
    return 'Trasmesso su $device';
  }

  @override
  String get castToDevice => 'Trasmetti su dispositivo';

  @override
  String get markUnwatched => 'Segna da vedere';

  @override
  String get markWatched => 'Segna visto';

  @override
  String get removeFromWatchLater => 'Rimuovi da Guarda più tardi';

  @override
  String get openOnYouTubeWithKey => 'Apri su YouTube (O)';

  @override
  String get playbackSpeed => 'Velocità di riproduzione';

  @override
  String get markedWatched => 'Segnato come visto';

  @override
  String get markedUnwatched => 'Segnato da vedere';

  @override
  String get addedToWatchLater => 'Aggiunto a Guarda più tardi';

  @override
  String get removedFromWatchLater => 'Rimosso da Guarda più tardi';

  @override
  String get youtubeVerificationRequired =>
      'YouTube ha chiesto una verifica. Apri il video su YouTube per guardarlo.';

  @override
  String get videoUnavailable => 'Questo video non è disponibile su YouTube.';

  @override
  String get noDownloadableFormat =>
      'Nessun formato scaricabile è disponibile per questo video.';

  @override
  String get playbackFailed =>
      'Impossibile riprodurre questo video. Riprova o aprilo su YouTube.';

  @override
  String get playerErrorFileTitle => 'File non disponibile';

  @override
  String get playerErrorStreamTitle => 'Stream non disponibile';

  @override
  String get technicalDetails => 'Dettagli tecnici';

  @override
  String sponsorBlockSegments(int count) {
    return 'SponsorBlock · $count segmenti';
  }

  @override
  String sponsorBlockCount(int count) {
    return 'SponsorBlock · $count';
  }

  @override
  String get sponsorBlockActive => 'SponsorBlock attivo';

  @override
  String get seekBack10 => 'Indietro 10 s';

  @override
  String get seekForward10 => 'Avanti 10 s';

  @override
  String get seekBack10Key => 'Indietro 10 s (←)';

  @override
  String get seekForward10Key => 'Avanti 10 s (→)';

  @override
  String get offlineLabel => 'Offline';

  @override
  String get localFileMp4 => 'File locale · MP4';

  @override
  String get offlineMp4 => 'Offline · MP4';

  @override
  String directStreamQuality(String quality) {
    return 'Stream diretto · $quality';
  }

  @override
  String bookmarkAt(String time) {
    return 'Segnalibro a $time';
  }

  @override
  String get addNote => 'Aggiungi nota';

  @override
  String get chapters => 'Capitoli';

  @override
  String get bookmarks => 'Segnalibri';

  @override
  String get noBookmarks =>
      'Nessun segnalibro. Aggiungi una nota al punto corrente.';

  @override
  String get deleteBookmark => 'Elimina segnalibro';

  @override
  String get bookmarkDialogTitle => 'Segnalibro';

  @override
  String get noteHint => 'Nota personale…';

  @override
  String get tabVideos => 'Video';

  @override
  String get tabHistory => 'Cronologia';

  @override
  String get errorTitle => 'Errore';

  @override
  String channelSummary(String videos, String lastSync) {
    return '$videos · $lastSync';
  }

  @override
  String get channelMutedSuffix => ' · RSS silenziato';

  @override
  String get channelHiddenSuffix => ' · fuori dalle novità';

  @override
  String get refreshOnlyChannel => 'Aggiorna solo questo canale';

  @override
  String get loadingTags => 'Carico tag…';

  @override
  String get searchChannelHint => 'Cerca nel canale, anche nei tag…';

  @override
  String get muteRssTooltip =>
      'Silenzia l’RSS: nessun nuovo video verrà proposto. Archivio e cronologia restano disponibili.';

  @override
  String get unmuteRssTooltip =>
      'Riattiva l’RSS: i nuovi video torneranno a essere proposti.';

  @override
  String get rssMuted => 'RSS silenziato';

  @override
  String get muteRss => 'Silenzia RSS';

  @override
  String get hideFromLatestTooltip =>
      'Nascondi l’ultimo video di questo canale dalla lista delle novità.';

  @override
  String get showInLatestTooltip =>
      'Mostra l’ultimo video di questo canale nella lista delle novità.';

  @override
  String get showInLatest => 'Mostra in novità';

  @override
  String get defaultRateTooltip =>
      'Velocità predefinita quando apri i video di questo canale.';

  @override
  String get channelRateTooltip => 'Velocità predefinita del canale';

  @override
  String get global => 'Globale';

  @override
  String get globalRate => 'Velocità globale';

  @override
  String channelRate(String rate) {
    return 'Velocità $rate';
  }

  @override
  String get filterAll => 'Tutti';

  @override
  String get filterUnwatched => 'Non visti';

  @override
  String get filterWatched => 'Visti';

  @override
  String get filterWatchLater => 'Guarda più tardi';

  @override
  String get emptyMutedTitle => 'RSS silenziato';

  @override
  String get emptyMutedBody =>
      'Le novità non vengono proposte. Riattiva l’RSS dal pulsante in alto per vederle.';

  @override
  String get emptyChannelVideosTitle => 'Nessun video';

  @override
  String get emptyChannelVideosBody =>
      'Questo canale non ha video nel feed RSS corrente.';

  @override
  String get emptyFilterTitle => 'Nessun risultato';

  @override
  String get emptyFilterBody =>
      'Nessun video corrisponde al filtro o al termine cercato.';

  @override
  String get emptyHistoryTitle => 'Cronologia vuota';

  @override
  String get emptyHistoryBody =>
      'I video che apri o segni come visti appariranno qui.';

  @override
  String get emptyHistorySearchBody =>
      'Nessun video della cronologia corrisponde al termine cercato.';

  @override
  String get badgeWatched => 'Visto';

  @override
  String get watchAction => 'Guarda';

  @override
  String get saveOffline => 'Salva in locale';

  @override
  String get removeDownload => 'Rimuovi il download';

  @override
  String get noChannelsTitle => 'Nessun canale';

  @override
  String get noChannelsBody => 'Importa le tue iscrizioni per iniziare.';

  @override
  String get deleteChannelTitle => 'Rimuovere il canale?';

  @override
  String deleteChannelBody(String name) {
    return '$name verrà rimosso da Expeditus. I video già salvati verranno eliminati.';
  }

  @override
  String get unmuteTooltip => 'Riattiva';

  @override
  String get muteTooltip => 'Silenzia';

  @override
  String get removeTooltip => 'Rimuovi';

  @override
  String noChannelFound(String query) {
    return 'Nessun canale trovato per “$query”.';
  }

  @override
  String channelAddedFeedUpdating(String name) {
    return '$name aggiunto. Il feed si aggiorna.';
  }

  @override
  String channelAddedFeedFailed(String error) {
    return 'Canale aggiunto, ma il feed non è stato aggiornato: $error';
  }

  @override
  String get searchRateLimited =>
      'YouTube ha limitato la ricerca. Riprova tra poco.';

  @override
  String get searchChannelPlaceholder => 'Cerca un canale per parola…';

  @override
  String get searchExplanationPhone =>
      'La ricerca interroga YouTube. Poi aggiungi il canale con un tocco.';

  @override
  String get searchExplanationDesktop =>
      'La ricerca interroga YouTube. Poi aggiungi il canale con un click.';

  @override
  String get searchingChannels => 'Cerco canali…';

  @override
  String get searchPrompt => 'Scrivi una parola e premi Cerca.';

  @override
  String get alreadySubscribed => 'Già presente';

  @override
  String get addChannel => 'Aggiungi';

  @override
  String get importSubscriptionsTitle => 'Importa iscrizioni';

  @override
  String get importIntro =>
      'Non serve accedere a Google. Takeout è il modo più pulito: Scarica i dati → YouTube → subscriptions.csv.';

  @override
  String get tabTakeout => 'Takeout';

  @override
  String get tabPaste => 'Incolla';

  @override
  String get tabSearch => 'Cerca';

  @override
  String get tabLink => 'Link';

  @override
  String get importingEllipsis => 'Importazione…';

  @override
  String get noLoginNote =>
      'Nessun login. La ricerca canali interroga YouTube.';

  @override
  String get csvSelectTitle => 'Seleziona subscriptions.csv';

  @override
  String get csvSelectBody =>
      'Il file che Google prepara in Takeout contiene ID, URL e nome di ogni canale.';

  @override
  String get chooseCsvFile => 'Scegli file CSV';

  @override
  String get pasteInstructions => 'Un canale per riga: handle, URL o ID.';

  @override
  String get importButton => 'Importa';

  @override
  String get importStatusResolvingChannels => 'Risoluzione canali…';

  @override
  String importStatusResolvingProgress(int current, int total) {
    return 'Risoluzione $current/$total…';
  }

  @override
  String get importStatusImporting => 'Importazione…';

  @override
  String get videoLinkIntro =>
      'Incolla il link di un video YouTube. Expeditus trova il canale, si iscrive automaticamente e salva il video in Guarda più tardi.';

  @override
  String videoLinkAdded(String video, String channel) {
    return 'Aggiunto “$video” e iscritto a $channel. Il video è in Guarda più tardi.';
  }

  @override
  String get addAndSubscribe => 'Aggiungi e iscriviti';

  @override
  String get welcomeTitle => 'Benvenuto.';

  @override
  String get welcomeBody =>
      'Cerca un canale per nome per iniziare. Puoi anche incollare il link di un canale o di un video, oppure importare le iscrizioni da Google Takeout.';

  @override
  String get welcomePhilosophy =>
      'Expeditus mostrerà solo l’ultimo video di ogni canale: niente raccomandazioni, niente autoplay, niente rumore.';

  @override
  String get welcomeImportTakeout => 'Importa da Google Takeout';

  @override
  String get welcomeAddVideoLink => 'Aggiungi un video da link';

  @override
  String get welcomeSkip => 'Salta per ora';

  @override
  String get welcomeSearchHeading => 'Cerca un canale';

  @override
  String get welcomeSearchHeadingCompact => 'Oppure cerca un canale';

  @override
  String get updatesTitle => 'Aggiornamenti';

  @override
  String get installedVersion => 'Installata';

  @override
  String get availableVersion => 'Disponibile';

  @override
  String get latestRelease => 'Ultima release';

  @override
  String get downloadInstaller => 'Scarica installer';

  @override
  String get openRelease => 'Apri release';

  @override
  String get checkNow => 'Controlla ora';

  @override
  String get skipVersion => 'Salta questa versione';

  @override
  String get releasePage => 'Pagina della release';

  @override
  String get installerNote =>
      'Dopo il download, chiudi Expeditus e avvia l’installer.';

  @override
  String get releasePageNote =>
      'Apri la pagina della release per scaricare la versione più recente.';

  @override
  String skippedVersion(String version) {
    return 'Hai saltato la versione $version. Ti verrà proposta la prossima release.';
  }

  @override
  String get restore => 'Ripristina';

  @override
  String get notCheckedTitle =>
      'Nessun controllo recente. Verifica ora se è disponibile una nuova versione.';

  @override
  String get upToDate => 'Expeditus è aggiornato.';

  @override
  String get upToDateCached => 'Expeditus è aggiornato (dati in cache).';

  @override
  String get lastCheckNever => 'Mai controllato';

  @override
  String lastCheck(String relative) {
    return 'Ultimo controllo: $relative';
  }

  @override
  String lastCheckCached(String relative) {
    return 'Ultimo controllo: $relative · dati in cache';
  }

  @override
  String get updateCheckFailed => 'Controllo aggiornamenti non riuscito.';

  @override
  String updateCheckFailedDetails(String details) {
    return 'Controllo aggiornamenti non riuscito: $details';
  }

  @override
  String updateStateSaveFailed(String details) {
    return 'Impossibile salvare lo stato aggiornamenti: $details';
  }

  @override
  String updateSkipSaveFailed(String details) {
    return 'Impossibile salvare la versione saltata: $details';
  }

  @override
  String updateRestoreFailed(String details) {
    return 'Impossibile ripristinare la versione saltata: $details';
  }

  @override
  String get startupFailed => 'Expeditus non è riuscito ad avviarsi';

  @override
  String get detailsLabel => 'Dettagli:';

  @override
  String get removeFromList => 'Rimuovi dalla lista';

  @override
  String castConnectFailedDetails(String device, String details) {
    return 'Aggancio a $device non riuscito: $details';
  }

  @override
  String castSendFailedDetails(String device, String details) {
    return 'Invio a $device non riuscito: $details';
  }

  @override
  String castActionFailedDetails(String details) {
    return 'Azione sul dispositivo non riuscita: $details';
  }

  @override
  String castDiscoveryFailedDetails(String details) {
    return 'Ricerca dispositivi non riuscita: $details';
  }

  @override
  String get castUnresponsive =>
      'Il dispositivo non risponde più. Verifica che sia ancora acceso e sulla stessa rete.';

  @override
  String get castFirewallDenied =>
      'Accesso alla rete non consentito. Aggiungi una regola di ingresso per Expeditus in Windows Firewall.';

  @override
  String get castNetworkProfileFailed =>
      'Impossibile modificare il tipo di rete. Apri Impostazioni > Rete e Internet e imposta la rete come “Privata”.';

  @override
  String get updateErrorNetwork =>
      'Impossibile contattare il server aggiornamenti. Controlla la connessione e riprova.';

  @override
  String get updateErrorRateLimited =>
      'Troppe richieste di aggiornamento. Riprova più tardi.';

  @override
  String get updateErrorUnauthorized =>
      'Il server aggiornamenti ha rifiutato la richiesta.';

  @override
  String get updateErrorNotFound =>
      'Nessuna release trovata. Il repository potrebbe non avere ancora release pubblicate.';

  @override
  String get updateErrorInvalidFeed =>
      'Il server aggiornamenti ha restituito una risposta non valida.';

  @override
  String updateErrorServer(String status) {
    return 'Il server aggiornamenti ha restituito un errore ($status).';
  }

  @override
  String get localVideoLabel => 'Video locale';

  @override
  String channelsNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canali non aggiornati',
      one: '1 canale non aggiornato',
    );
    return '$_temp0';
  }

  @override
  String get audioOnlyQuality => 'Solo audio';

  @override
  String get castDiscoveryFailed => 'Ricerca dispositivi non riuscita.';

  @override
  String get castActionFailed => 'Azione sul dispositivo non riuscita.';
}
