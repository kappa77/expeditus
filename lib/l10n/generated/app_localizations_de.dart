// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get close => 'Schließen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get back => 'Zurück';

  @override
  String get remove => 'Entfernen';

  @override
  String get save => 'Speichern';

  @override
  String get done => 'Fertig';

  @override
  String get importAction => 'Importieren';

  @override
  String get searchAction => 'Suchen';

  @override
  String get refreshAction => 'Aktualisieren';

  @override
  String get addAction => 'Hinzufügen';

  @override
  String get playAction => 'Abspielen';

  @override
  String get disconnect => 'Trennen';

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get deviceFallback => 'Gerät';

  @override
  String get computerNoun => 'Computer';

  @override
  String get phoneNoun => 'Telefon';

  @override
  String get onComputer => 'auf deinem Computer';

  @override
  String get onPhone => 'auf deinem Telefon';

  @override
  String get fromComputer => 'von deinem Computer';

  @override
  String get fromPhone => 'von deinem Telefon';

  @override
  String get openOnYouTube => 'Auf YouTube öffnen';

  @override
  String get videoActions => 'Videoaktionen';

  @override
  String get openChannel => 'Kanal öffnen';

  @override
  String get localFileLabel => 'Lokale Datei';

  @override
  String get relativeNever => 'nie';

  @override
  String get relativeNow => 'gerade eben';

  @override
  String get relativeYesterday => 'gestern';

  @override
  String relativeMinutes(int count) {
    return 'vor $count Min.';
  }

  @override
  String relativeHours(int count) {
    return 'vor $count Std.';
  }

  @override
  String relativeDays(int count) {
    return 'vor $count T.';
  }

  @override
  String updatedRelative(String relative) {
    return 'aktualisiert $relative';
  }

  @override
  String savedRelative(String relative) {
    return 'gespeichert $relative';
  }

  @override
  String addedRelative(String relative) {
    return 'hinzugefügt $relative';
  }

  @override
  String openedRelative(String relative) {
    return 'geöffnet $relative';
  }

  @override
  String get navLatest => 'Neueste';

  @override
  String get navNew => 'Neu';

  @override
  String get navWatchLater => 'Später ansehen';

  @override
  String get navSaved => 'Gespeichert';

  @override
  String get navLocal => 'Lokale Videos';

  @override
  String get navRss => 'RSS-Verlauf';

  @override
  String get navChannels => 'Kanäle';

  @override
  String get navUpdates => 'Updates';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get navImport => 'Importieren';

  @override
  String get navSearchChannel => 'Kanal suchen';

  @override
  String get navMore => 'Mehr';

  @override
  String get mobileQueueShort => 'Später';

  @override
  String get openMenu => 'Menü öffnen';

  @override
  String get closeMenu => 'Menü schließen';

  @override
  String get sidebarTagline => 'Nur was du gewählt hast.\nKeine Empfehlungen.';

  @override
  String get viewLatest => 'Neueste';

  @override
  String get viewNew => 'Neu';

  @override
  String get viewWatchLater => 'Später ansehen';

  @override
  String get viewSaved => 'Gespeichert';

  @override
  String get viewLocal => 'Lokale Videos';

  @override
  String get viewRss => 'RSS-Verlauf';

  @override
  String get viewChannels => 'Kanäle';

  @override
  String videosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos',
      one: '1 Video',
    );
    return '$_temp0';
  }

  @override
  String channelsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kanäle',
      one: '1 Kanal',
    );
    return '$_temp0';
  }

  @override
  String newLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue',
      one: '1 neu',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Abos',
      one: '1 Abo',
    );
    return '$_temp0';
  }

  @override
  String mp4FilesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count MP4-Dateien',
      one: '1 MP4-Datei',
    );
    return '$_temp0';
  }

  @override
  String errorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fehler',
      one: '1 Fehler',
    );
    return '$_temp0';
  }

  @override
  String channelsImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kanäle importiert',
      one: '1 Kanal importiert',
    );
    return '$_temp0';
  }

  @override
  String alreadyPresentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bereits vorhanden',
      one: '1 bereits vorhanden',
    );
    return '$_temp0';
  }

  @override
  String videosAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos hinzugefügt',
      one: '1 Video hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String subtitleNew(String videos) {
    return '$videos anzusehen';
  }

  @override
  String subtitleWatchLater(String videos) {
    return '$videos anzusehen';
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
    return '$videos im Feed gesehen';
  }

  @override
  String subtitleRssFiltered(String videos, String total) {
    return '$videos · $total insgesamt';
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
  String get markAllRead => 'Alle als gelesen markieren';

  @override
  String get refreshWithKey => 'Aktualisieren (R)';

  @override
  String get refreshTooltip => 'Aktualisieren';

  @override
  String get addVideo => 'Video hinzufügen';

  @override
  String get moreActions => 'Weitere Aktionen';

  @override
  String get searchSubscriptionsHint => 'Abonnements durchsuchen…';

  @override
  String get searchLocalHint => 'Lokale Videos durchsuchen…';

  @override
  String get noChannelsImported => 'Keine Kanäle importiert.';

  @override
  String get noVideosAdded => 'Keine Videos hinzugefügt.';

  @override
  String get mp4VideoType => 'MP4-Video';

  @override
  String get takeoutCsvType => 'Google Takeout CSV';

  @override
  String get channelFilterLabel => 'Kanal';

  @override
  String allChannelsWithCount(int count) {
    return 'Alle Kanäle ($count)';
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
  String get emptyNoResults => 'Keine Ergebnisse';

  @override
  String get emptyNoResultsBody =>
      'Versuche einen anderen Begriff. Wir durchsuchen nur die Kanäle, denen du folgst.';

  @override
  String get emptyNoResultsLocalBody => 'Versuche einen anderen Begriff.';

  @override
  String get emptyNoLocalVideos => 'Keine lokalen Videos';

  @override
  String emptyNoLocalVideosBody(String fromLocation) {
    return 'Füge eine MP4-Datei $fromLocation hinzu. Der Titel stammt aus den Dateimetadaten oder aus dem Dateinamen.';
  }

  @override
  String get emptyInbox => 'Dein Posteingang ist leer';

  @override
  String get emptyInboxBody =>
      'Importiere deine Abos aus Google Takeout oder füge einen Kanal-Handle oder eine URL ein.';

  @override
  String get emptyCaughtUp => 'Du bist auf dem neuesten Stand';

  @override
  String get emptyWatchLater => 'Später ansehen ist leer';

  @override
  String get emptyWatchLaterBodyCompact =>
      'Speichere ein Video über das Zeilenmenü (⋮) für später oder öffne es und tippe auf das Uhr-Symbol.';

  @override
  String get emptyWatchLaterBodyDesktop =>
      'Speichere ein Video mit der Taste S oder dem Uhr-Symbol in der Videizeile für später.';

  @override
  String get emptyNoSaved => 'Keine gespeicherten Videos';

  @override
  String get emptyNoSavedBody =>
      'Öffne einen Kanal und nutze die Download-Schaltfläche, um offline anzusehen.';

  @override
  String get emptyNoVideos => 'Keine Videos';

  @override
  String get emptyRssBody =>
      'Videos aus RSS-Feeds bleiben hier ohne Duplikate erhalten, auch wenn sie nicht mehr im neuesten Feed stehen.';

  @override
  String get emptyNoNewBody =>
      'Keine neuen Videos von den Kanälen, denen du folgst.';

  @override
  String get addMp4Button => 'MP4-Video hinzufügen';

  @override
  String get importSubscriptions => 'Abos importieren';

  @override
  String get keyboardHint => 'R zum Aktualisieren · / zum Suchen';

  @override
  String get statusUpdating => 'Wird aktualisiert…';

  @override
  String statusUpdated(String relative) {
    return 'Aktualisiert $relative';
  }

  @override
  String get statusShortcuts => '↑↓ · Eingabe · M · S';

  @override
  String updateAvailableTooltip(String version) {
    return 'Update verfügbar: $version';
  }

  @override
  String updateNavPrompt(String version) {
    return 'Auf $version aktualisieren';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get sectionReading => 'Lesen';

  @override
  String get hideDescriptions => 'Beschreibungen ausblenden';

  @override
  String get hideDescriptionsSubtitle =>
      'Nur Kanal und Titel anzeigen. Fokusmodus.';

  @override
  String get sectionUpdate => 'Aktualisierung';

  @override
  String refreshEvery(int minutes) {
    return 'Alle $minutes Minuten';
  }

  @override
  String get rssRefreshNote =>
      'YouTube-RSS-Feeds sind kostenlos und verbrauchen kein API-Kontingent. Expeditus prüft Kanäle zeitlich gestaffelt.';

  @override
  String get sectionSponsorBlock => 'SponsorBlock';

  @override
  String get skipSponsors => 'Sponsoren überspringen';

  @override
  String get skipSponsorsSubtitle =>
      'Von der Community gemeldete Abschnitte. Nur direkte Streams.';

  @override
  String get sponsorCategorySponsor => 'Sponsor';

  @override
  String get sponsorCategorySelfPromo => 'Eigenwerbung';

  @override
  String get sponsorCategoryInteraction => 'Like / Abo';

  @override
  String get sponsorCategoryIntro => 'Intro';

  @override
  String get sponsorCategoryOutro => 'Outro';

  @override
  String get sponsorCategoryPreview => 'Vorschau';

  @override
  String get sponsorCategoryMusicOfftopic => 'Musikfremder Abschnitt';

  @override
  String get sponsorCategoryFiller => 'Füllmaterial';

  @override
  String get sectionHowItWorks => 'So funktioniert es';

  @override
  String get howItWorksBody =>
      'Expeditus lädt den YouTube-Player nicht. Es löst den Videostream auf und spielt ihn mit libmpv ab: keine Player-Werbung, keine Empfehlungen, kein Autoplay. SponsorBlock überspringt Sponsoren im Video.';

  @override
  String privacyNote(String location) {
    return 'Die Wiedergabe hängt von YouTube ab: Wenn ein Video nicht öffnet, nutze „Auf YouTube öffnen“. Abos und Status bleiben $location; die App kontaktiert YouTube für Feeds und GitHub für Release-Prüfungen.';
  }

  @override
  String get licensesButton => 'Open-Source-Lizenzen';

  @override
  String get licensesNote =>
      'Lizenzen für native Komponenten (libmpv, ANGLE, SQLite) sind auf der Lizenzseite verfügbar.';

  @override
  String get sectionLanguage => 'Sprache';

  @override
  String get languageLabel => 'App-Sprache';

  @override
  String get languageSubtitle => 'Wähle die Sprache der Benutzeroberfläche.';

  @override
  String get languageSystem => 'System';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSpanish => 'Español';

  @override
  String get castTitle => 'Auf Gerät übertragen';

  @override
  String get castStatusStarting => 'Wiedergabe wird gestartet…';

  @override
  String get castStatusPlaying => 'Wiedergabe auf dem Gerät';

  @override
  String get castStatusPaused => 'Auf dem Gerät pausiert';

  @override
  String get castStatusStopped => 'Verbunden, wartet auf Start';

  @override
  String get castStatusError => 'Fehler auf dem Gerät';

  @override
  String get castStatusIdle => 'Verbunden';

  @override
  String get castNoStream => 'Kein Stream für das Gerät verfügbar.';

  @override
  String get castConnectFailed => 'Verbindung fehlgeschlagen.';

  @override
  String get castSendFailed => 'Senden an das Gerät fehlgeschlagen.';

  @override
  String get castStartFailed => 'Start auf dem Gerät fehlgeschlagen.';

  @override
  String get castFirewallWarning =>
      'Der Fernseher kann den PC nicht erreichen. Windows Firewall benötigt eine eingehende Regel für Expeditus.';

  @override
  String get castAllowNetwork => 'Netzwerkzugriff erlauben';

  @override
  String get castWaitingWindows => 'Warten auf Windows-Bestätigung…';

  @override
  String get castExplanation =>
      'In Expeditus geöffnete Videos werden auch auf dem Gerät wiedergegeben. Der App-Ton bleibt während der Übertragung stumm.';

  @override
  String get castDlnaDevices => 'DLNA-Geräte';

  @override
  String get castSearchAgain => 'Erneut suchen';

  @override
  String get castSearching => 'Suche nach Geräten…';

  @override
  String castConnecting(String device) {
    return 'Verbinde mit $device…';
  }

  @override
  String get castDiscoveryHintPhone =>
      'Schalte das Gerät ein und stelle sicher, dass es im selben lokalen Netzwerk wie das Telefon ist.';

  @override
  String get castDiscoveryHintDesktop =>
      'Schalte das Gerät ein und stelle sicher, dass es im selben lokalen Netzwerk wie der PC ist. Windows fragt beim ersten Mal möglicherweise nach Netzwerkzugriff.';

  @override
  String get castNoDevicesFound => 'Keine DLNA-Geräte gefunden.';

  @override
  String get castNoDevicesAvailable => 'Keine Geräte verfügbar.';

  @override
  String get castNetworkPublicWarning =>
      'Das Windows-Netzwerk ist auf „Öffentlich“ eingestellt, daher ist die DLNA-Suche blockiert. Stelle es auf „Privat“, um den Fernseher zu finden.';

  @override
  String get castMakeNetworkPrivate => 'Netzwerk privat machen';

  @override
  String get castTroubleshootingTitle => 'Tipps zur Suche';

  @override
  String get castTroubleshootingStep1 =>
      'Schalte den Fernseher ein und prüfe, ob er im selben WLAN oder LAN wie der PC ist.';

  @override
  String get castTroubleshootingStep2 =>
      'Stelle sicher, dass das Windows-Netzwerk „Privat“ und nicht „Öffentlich“ ist (nutze die Schaltfläche oben).';

  @override
  String get castTroubleshootingStep3 =>
      'Prüfe, ob der DLNA-Renderer am Fernseher aktiv ist (z. B. „Freigabe“ oder „Screen Mirroring“).';

  @override
  String get castTroubleshootingStep4 =>
      'Erlaube Expeditus den Netzwerkzugriff, wenn Windows Firewall danach fragt.';

  @override
  String get castStartOnDevice => 'Auf Gerät starten';

  @override
  String get castSendingToDevice => 'Video wird an das Gerät gesendet…';

  @override
  String get castPlaybackNotStarted =>
      'Wiedergabe auf dem Gerät nicht gestartet.\nDrücke Play, um zu beginnen.';

  @override
  String get castAudioMuted =>
      'Der Expeditus-Ton bleibt während der Übertragung stumm.';

  @override
  String get castFirewallHint =>
      'Der Fernseher kann den PC nicht erreichen. Erlaube Expeditus den Netzwerkzugriff in Windows Firewall und versuche es erneut.';

  @override
  String get castNetworkHint =>
      'Wenn die Wiedergabe nicht startet, prüfe, ob Fernseher und PC im selben Netzwerk sind und Windows Firewall Expeditus den lokalen Netzwerkzugriff erlaubt.';

  @override
  String get castPlayHereOnly => 'Nur hier wiedergeben';

  @override
  String get bookmarkSaved => 'Lesezeichen gespeichert';

  @override
  String localFileNotFound(String path) {
    return 'Lokale Datei nicht gefunden: $path';
  }

  @override
  String resumedFrom(String time) {
    return 'Fortgesetzt ab $time';
  }

  @override
  String get sponsorSkipped => 'Sponsor übersprungen';

  @override
  String get permissionNotGranted => 'Berechtigung nicht erteilt.';

  @override
  String get castStopped => 'Übertragung beendet';

  @override
  String get openingFile => 'Datei wird geöffnet…';

  @override
  String get resolvingStream => 'Stream wird aufgelöst…';

  @override
  String castFooter(String device) {
    return 'Cast · $device';
  }

  @override
  String castFooterMuted(String device) {
    return 'Cast · $device · hier stumm';
  }

  @override
  String playerSpeedMenu(String rate) {
    return 'Geschwindigkeit ($rate)';
  }

  @override
  String get chaptersAndBookmarks => 'Kapitel und Lesezeichen';

  @override
  String get addBookmark => 'Lesezeichen hinzufügen';

  @override
  String castedTo(String device) {
    return 'Übertragung auf $device';
  }

  @override
  String get castToDevice => 'Auf Gerät übertragen';

  @override
  String get markUnwatched => 'Als ungesehen markieren';

  @override
  String get markWatched => 'Als gesehen markieren';

  @override
  String get removeFromWatchLater => 'Aus Später ansehen entfernen';

  @override
  String get openOnYouTubeWithKey => 'Auf YouTube öffnen (O)';

  @override
  String get playbackSpeed => 'Wiedergabegeschwindigkeit';

  @override
  String get markedWatched => 'Als gesehen markiert';

  @override
  String get markedUnwatched => 'Als ungesehen markiert';

  @override
  String get addedToWatchLater => 'Zu Später ansehen hinzugefügt';

  @override
  String get removedFromWatchLater => 'Aus Später ansehen entfernt';

  @override
  String get youtubeVerificationRequired =>
      'YouTube verlangt eine Bestätigung. Öffne das Video auf YouTube, um es anzusehen.';

  @override
  String get videoUnavailable =>
      'Dieses Video ist auf YouTube nicht verfügbar.';

  @override
  String get noDownloadableFormat =>
      'Für dieses Video ist kein herunterladbares Format verfügbar.';

  @override
  String get playbackFailed =>
      'Dieses Video konnte nicht abgespielt werden. Versuche es erneut oder öffne es auf YouTube.';

  @override
  String get playerErrorFileTitle => 'Datei nicht verfügbar';

  @override
  String get playerErrorStreamTitle => 'Stream nicht verfügbar';

  @override
  String get technicalDetails => 'Technische Details';

  @override
  String sponsorBlockSegments(int count) {
    return 'SponsorBlock · $count Segmente';
  }

  @override
  String sponsorBlockCount(int count) {
    return 'SponsorBlock · $count';
  }

  @override
  String get sponsorBlockActive => 'SponsorBlock aktiv';

  @override
  String get seekBack10 => '10 s zurück';

  @override
  String get seekForward10 => '10 s vor';

  @override
  String get seekBack10Key => '10 s zurück (←)';

  @override
  String get seekForward10Key => '10 s vor (→)';

  @override
  String get offlineLabel => 'Offline';

  @override
  String get localFileMp4 => 'Lokale Datei · MP4';

  @override
  String get offlineMp4 => 'Offline · MP4';

  @override
  String directStreamQuality(String quality) {
    return 'Direkter Stream · $quality';
  }

  @override
  String bookmarkAt(String time) {
    return 'Lesezeichen bei $time';
  }

  @override
  String get addNote => 'Notiz hinzufügen';

  @override
  String get chapters => 'Kapitel';

  @override
  String get bookmarks => 'Lesezeichen';

  @override
  String get noBookmarks =>
      'Keine Lesezeichen. Füge an der aktuellen Position eine Notiz hinzu.';

  @override
  String get deleteBookmark => 'Lesezeichen löschen';

  @override
  String get bookmarkDialogTitle => 'Lesezeichen';

  @override
  String get noteHint => 'Persönliche Notiz…';

  @override
  String get tabVideos => 'Videos';

  @override
  String get tabHistory => 'Verlauf';

  @override
  String get errorTitle => 'Fehler';

  @override
  String channelSummary(String videos, String lastSync) {
    return '$videos · $lastSync';
  }

  @override
  String get channelMutedSuffix => ' · RSS stumm';

  @override
  String get channelHiddenSuffix => ' · nicht in Neu';

  @override
  String get refreshOnlyChannel => 'Nur diesen Kanal aktualisieren';

  @override
  String get loadingTags => 'Tags werden geladen…';

  @override
  String get searchChannelHint => 'Diesen Kanal durchsuchen, auch Tags…';

  @override
  String get muteRssTooltip =>
      'RSS stumm schalten: Es werden keine neuen Videos vorgeschlagen. Archiv und Verlauf bleiben verfügbar.';

  @override
  String get unmuteRssTooltip =>
      'RSS wieder einschalten: Neue Videos werden wieder vorgeschlagen.';

  @override
  String get rssMuted => 'RSS stumm';

  @override
  String get muteRss => 'RSS stumm schalten';

  @override
  String get hideFromLatestTooltip =>
      'Das neueste Video dieses Kanals aus der Liste „Neu“ ausblenden.';

  @override
  String get showInLatestTooltip =>
      'Das neueste Video dieses Kanals in der Liste „Neu“ anzeigen.';

  @override
  String get showInLatest => 'In Neu anzeigen';

  @override
  String get defaultRateTooltip =>
      'Standardgeschwindigkeit beim Öffnen der Videos dieses Kanals.';

  @override
  String get channelRateTooltip => 'Standardgeschwindigkeit des Kanals';

  @override
  String get global => 'Global';

  @override
  String get globalRate => 'Globale Geschwindigkeit';

  @override
  String channelRate(String rate) {
    return 'Geschwindigkeit $rate';
  }

  @override
  String get filterAll => 'Alle';

  @override
  String get filterUnwatched => 'Ungesehen';

  @override
  String get filterWatched => 'Gesehen';

  @override
  String get filterWatchLater => 'Später ansehen';

  @override
  String get emptyMutedTitle => 'RSS stumm';

  @override
  String get emptyMutedBody =>
      'Neue Videos werden nicht vorgeschlagen. Schalte RSS über die Schaltfläche oben wieder ein, um sie zu sehen.';

  @override
  String get emptyChannelVideosTitle => 'Keine Videos';

  @override
  String get emptyChannelVideosBody =>
      'Dieser Kanal hat keine Videos im aktuellen RSS-Feed.';

  @override
  String get emptyFilterTitle => 'Keine Ergebnisse';

  @override
  String get emptyFilterBody =>
      'Keine Videos entsprechen dem Filter oder Suchbegriff.';

  @override
  String get emptyHistoryTitle => 'Verlauf ist leer';

  @override
  String get emptyHistoryBody =>
      'Videos, die du öffnest oder als gesehen markierst, erscheinen hier.';

  @override
  String get emptyHistorySearchBody =>
      'Keine Verlaufsvideos entsprechen dem Suchbegriff.';

  @override
  String get badgeWatched => 'Gesehen';

  @override
  String get watchAction => 'Ansehen';

  @override
  String get saveOffline => 'Offline speichern';

  @override
  String get removeDownload => 'Download entfernen';

  @override
  String get noChannelsTitle => 'Keine Kanäle';

  @override
  String get noChannelsBody => 'Importiere deine Abos, um zu beginnen.';

  @override
  String get deleteChannelTitle => 'Kanal entfernen?';

  @override
  String deleteChannelBody(String name) {
    return '$name wird aus Expeditus entfernt. Bereits gespeicherte Videos werden gelöscht.';
  }

  @override
  String get unmuteTooltip => 'Wieder aktivieren';

  @override
  String get muteTooltip => 'Stumm schalten';

  @override
  String get removeTooltip => 'Entfernen';

  @override
  String noChannelFound(String query) {
    return 'Keine Kanäle für „$query“ gefunden.';
  }

  @override
  String channelAddedFeedUpdating(String name) {
    return '$name hinzugefügt. Der Feed wird aktualisiert.';
  }

  @override
  String channelAddedFeedFailed(String error) {
    return 'Kanal hinzugefügt, aber der Feed konnte nicht aktualisiert werden: $error';
  }

  @override
  String get searchRateLimited =>
      'YouTube hat die Suche eingeschränkt. Versuche es gleich noch einmal.';

  @override
  String get searchChannelPlaceholder => 'Kanal suchen…';

  @override
  String get searchExplanationPhone =>
      'Die Suche fragt YouTube ab. Füge den Kanal dann mit einem Tippen hinzu.';

  @override
  String get searchExplanationDesktop =>
      'Die Suche fragt YouTube ab. Füge den Kanal dann mit einem Klick hinzu.';

  @override
  String get searchingChannels => 'Kanäle werden gesucht…';

  @override
  String get searchPrompt => 'Gib ein Wort ein und drücke Suchen.';

  @override
  String get alreadySubscribed => 'Bereits hinzugefügt';

  @override
  String get addChannel => 'Hinzufügen';

  @override
  String get importSubscriptionsTitle => 'Abos importieren';

  @override
  String get importIntro =>
      'Kein Google-Login nötig. Takeout ist der sauberste Weg: Daten herunterladen → YouTube → subscriptions.csv.';

  @override
  String get tabTakeout => 'Takeout';

  @override
  String get tabPaste => 'Einfügen';

  @override
  String get tabSearch => 'Suchen';

  @override
  String get tabLink => 'Link';

  @override
  String get importingEllipsis => 'Importieren…';

  @override
  String get noLoginNote => 'Kein Login. Die Kanalsuche fragt YouTube ab.';

  @override
  String get csvSelectTitle => 'subscriptions.csv auswählen';

  @override
  String get csvSelectBody =>
      'Die von Google in Takeout erstellte Datei enthält ID, URL und Namen jedes Kanals.';

  @override
  String get chooseCsvFile => 'CSV-Datei auswählen';

  @override
  String get pasteInstructions => 'Ein Kanal pro Zeile: Handle, URL oder ID.';

  @override
  String get importButton => 'Importieren';

  @override
  String get importStatusResolvingChannels => 'Kanäle werden aufgelöst…';

  @override
  String importStatusResolvingProgress(int current, int total) {
    return 'Auflösen $current/$total…';
  }

  @override
  String get importStatusImporting => 'Importieren…';

  @override
  String get videoLinkIntro =>
      'Füge den Link zu einem YouTube-Video ein. Expeditus findet den Kanal, abonniert ihn automatisch und speichert das Video unter Später ansehen.';

  @override
  String videoLinkAdded(String video, String channel) {
    return '„$video“ hinzugefügt und $channel abonniert. Das Video ist unter Später ansehen.';
  }

  @override
  String get addAndSubscribe => 'Hinzufügen und abonnieren';

  @override
  String get welcomeTitle => 'Willkommen.';

  @override
  String get welcomeBody =>
      'Suche einen Kanal nach Namen, um zu beginnen. Du kannst auch einen Kanal- oder Videolink einfügen oder Abos aus Google Takeout importieren.';

  @override
  String get welcomePhilosophy =>
      'Expeditus zeigt nur das neueste Video jedes Kanals: keine Empfehlungen, kein Autoplay, keine Ablenkung.';

  @override
  String get welcomeImportTakeout => 'Aus Google Takeout importieren';

  @override
  String get welcomeAddVideoLink => 'Video aus Link hinzufügen';

  @override
  String get welcomeSkip => 'Vorerst überspringen';

  @override
  String get welcomeSearchHeading => 'Kanal suchen';

  @override
  String get welcomeSearchHeadingCompact => 'Oder einen Kanal suchen';

  @override
  String get updatesTitle => 'Updates';

  @override
  String get installedVersion => 'Installiert';

  @override
  String get availableVersion => 'Verfügbar';

  @override
  String get latestRelease => 'Neueste Version';

  @override
  String get downloadInstaller => 'Installer herunterladen';

  @override
  String get openRelease => 'Release öffnen';

  @override
  String get checkNow => 'Jetzt prüfen';

  @override
  String get skipVersion => 'Diese Version überspringen';

  @override
  String get releasePage => 'Release-Seite';

  @override
  String get installerNote =>
      'Schließe nach dem Download Expeditus und starte den Installer.';

  @override
  String get releasePageNote =>
      'Öffne die Release-Seite, um die neueste Version herunterzuladen.';

  @override
  String skippedVersion(String version) {
    return 'Du hast Version $version übersprungen. Die nächste Version wird angeboten.';
  }

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get notCheckedTitle =>
      'Keine aktuelle Prüfung. Prüfe jetzt, ob eine neue Version verfügbar ist.';

  @override
  String get upToDate => 'Expeditus ist aktuell.';

  @override
  String get upToDateCached =>
      'Expeditus ist aktuell (zwischengespeicherte Daten).';

  @override
  String get lastCheckNever => 'Nie geprüft';

  @override
  String lastCheck(String relative) {
    return 'Letzte Prüfung: $relative';
  }

  @override
  String lastCheckCached(String relative) {
    return 'Letzte Prüfung: $relative · zwischengespeicherte Daten';
  }

  @override
  String get updateCheckFailed => 'Update-Prüfung fehlgeschlagen.';

  @override
  String updateCheckFailedDetails(String details) {
    return 'Update-Prüfung fehlgeschlagen: $details';
  }

  @override
  String updateStateSaveFailed(String details) {
    return 'Update-Status konnte nicht gespeichert werden: $details';
  }

  @override
  String updateSkipSaveFailed(String details) {
    return 'Übersprungene Version konnte nicht gespeichert werden: $details';
  }

  @override
  String updateRestoreFailed(String details) {
    return 'Übersprungene Version konnte nicht wiederhergestellt werden: $details';
  }

  @override
  String get startupFailed => 'Expeditus konnte nicht gestartet werden';

  @override
  String get detailsLabel => 'Details:';

  @override
  String get removeFromList => 'Aus Liste entfernen';

  @override
  String castConnectFailedDetails(String device, String details) {
    return 'Verbindung zu $device fehlgeschlagen: $details';
  }

  @override
  String castSendFailedDetails(String device, String details) {
    return 'Senden an $device fehlgeschlagen: $details';
  }

  @override
  String castActionFailedDetails(String details) {
    return 'Geräteaktion fehlgeschlagen: $details';
  }

  @override
  String castDiscoveryFailedDetails(String details) {
    return 'Gerätesuche fehlgeschlagen: $details';
  }

  @override
  String get castUnresponsive =>
      'Das Gerät antwortet nicht mehr. Prüfe, ob es noch eingeschaltet und im selben Netzwerk ist.';

  @override
  String get castFirewallDenied =>
      'Netzwerkzugriff nicht erteilt. Füge eine eingehende Regel für Expeditus in Windows Firewall hinzu.';

  @override
  String get castNetworkProfileFailed =>
      'Der Netzwerktyp konnte nicht geändert werden. Öffne Einstellungen > Netzwerk und Internet und stelle das Netzwerk auf „Privat“.';

  @override
  String get updateErrorNetwork =>
      'Der Update-Server ist nicht erreichbar. Prüfe die Verbindung und versuche es erneut.';

  @override
  String get updateErrorRateLimited =>
      'Zu viele Update-Anfragen. Versuche es später erneut.';

  @override
  String get updateErrorUnauthorized =>
      'Der Update-Server hat die Anfrage abgelehnt.';

  @override
  String get updateErrorNotFound =>
      'Keine Version gefunden. Das Repository hat möglicherweise noch keine veröffentlichten Releases.';

  @override
  String get updateErrorInvalidFeed =>
      'Der Update-Server hat eine ungültige Antwort geliefert.';

  @override
  String updateErrorServer(String status) {
    return 'Der Update-Server hat einen Fehler zurückgegeben ($status).';
  }

  @override
  String get localVideoLabel => 'Lokales Video';

  @override
  String channelsNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kanäle nicht aktualisiert',
      one: '1 Kanal nicht aktualisiert',
    );
    return '$_temp0';
  }

  @override
  String get audioOnlyQuality => 'Nur Audio';

  @override
  String get castDiscoveryFailed => 'Gerätesuche fehlgeschlagen.';

  @override
  String get castActionFailed => 'Geräteaktion fehlgeschlagen.';
}
