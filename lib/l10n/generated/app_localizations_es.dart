// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get close => 'Cerrar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Reintentar';

  @override
  String get back => 'Atrás';

  @override
  String get remove => 'Quitar';

  @override
  String get save => 'Guardar';

  @override
  String get done => 'Hecho';

  @override
  String get importAction => 'Importar';

  @override
  String get searchAction => 'Buscar';

  @override
  String get refreshAction => 'Actualizar';

  @override
  String get addAction => 'Añadir';

  @override
  String get playAction => 'Reproducir';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get deviceFallback => 'dispositivo';

  @override
  String get computerNoun => 'ordenador';

  @override
  String get phoneNoun => 'teléfono';

  @override
  String get onComputer => 'en tu ordenador';

  @override
  String get onPhone => 'en tu teléfono';

  @override
  String get fromComputer => 'de tu ordenador';

  @override
  String get fromPhone => 'de tu teléfono';

  @override
  String get openOnYouTube => 'Abrir en YouTube';

  @override
  String get videoActions => 'Acciones del vídeo';

  @override
  String get openChannel => 'Abrir canal';

  @override
  String get localFileLabel => 'Archivo local';

  @override
  String get relativeNever => 'nunca';

  @override
  String get relativeNow => 'ahora mismo';

  @override
  String get relativeYesterday => 'ayer';

  @override
  String relativeMinutes(int count) {
    return 'hace $count min';
  }

  @override
  String relativeHours(int count) {
    return 'hace $count h';
  }

  @override
  String relativeDays(int count) {
    return 'hace $count d';
  }

  @override
  String updatedRelative(String relative) {
    return 'actualizado $relative';
  }

  @override
  String savedRelative(String relative) {
    return 'guardado $relative';
  }

  @override
  String addedRelative(String relative) {
    return 'añadido $relative';
  }

  @override
  String openedRelative(String relative) {
    return 'abierto $relative';
  }

  @override
  String get navLatest => 'Recientes';

  @override
  String get navNew => 'Nuevos';

  @override
  String get navWatchLater => 'Ver más tarde';

  @override
  String get navSaved => 'Guardados';

  @override
  String get navLocal => 'Vídeos locales';

  @override
  String get navRss => 'Historial RSS';

  @override
  String get navChannels => 'Canales';

  @override
  String get navUpdates => 'Actualizaciones';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navImport => 'Importar';

  @override
  String get navSearchChannel => 'Buscar canal';

  @override
  String get navMore => 'Más';

  @override
  String get mobileQueueShort => 'Después';

  @override
  String get openMenu => 'Abrir el menú';

  @override
  String get closeMenu => 'Cerrar menú';

  @override
  String get sidebarTagline => 'Solo lo que elegiste.\nSin recomendaciones.';

  @override
  String get viewLatest => 'Recientes';

  @override
  String get viewNew => 'Nuevos';

  @override
  String get viewWatchLater => 'Ver más tarde';

  @override
  String get viewSaved => 'Guardados';

  @override
  String get viewLocal => 'Vídeos locales';

  @override
  String get viewRss => 'Historial RSS';

  @override
  String get viewChannels => 'Canales';

  @override
  String videosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos',
      one: '1 vídeo',
    );
    return '$_temp0';
  }

  @override
  String channelsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales',
      one: '1 canal',
    );
    return '$_temp0';
  }

  @override
  String newLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuevos',
      one: '1 nuevo',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suscripciones',
      one: '1 suscripción',
    );
    return '$_temp0';
  }

  @override
  String mp4FilesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos MP4',
      one: '1 archivo MP4',
    );
    return '$_temp0';
  }

  @override
  String errorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errores',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String channelsImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales importados',
      one: '1 canal importado',
    );
    return '$_temp0';
  }

  @override
  String alreadyPresentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ya presentes',
      one: '1 ya presente',
    );
    return '$_temp0';
  }

  @override
  String videosAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos añadidos',
      one: '1 vídeo añadido',
    );
    return '$_temp0';
  }

  @override
  String subtitleNew(String videos) {
    return '$videos por ver';
  }

  @override
  String subtitleWatchLater(String videos) {
    return '$videos por ver';
  }

  @override
  String subtitleSaved(String videos) {
    return '$videos sin conexión';
  }

  @override
  String subtitleLocal(String files, String location) {
    return '$files $location';
  }

  @override
  String subtitleRssAll(String videos) {
    return '$videos vistos en el feed';
  }

  @override
  String subtitleRssFiltered(String videos, String total) {
    return '$videos · $total en total';
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
  String get markAllRead => 'Marcar todo como leído';

  @override
  String get refreshWithKey => 'Actualizar (R)';

  @override
  String get refreshTooltip => 'Actualizar';

  @override
  String get addVideo => 'Añadir vídeo';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get searchSubscriptionsHint => 'Buscar en suscripciones…';

  @override
  String get searchLocalHint => 'Buscar vídeos locales…';

  @override
  String get noChannelsImported => 'No se importó ningún canal.';

  @override
  String get noVideosAdded => 'No se añadió ningún vídeo.';

  @override
  String get mp4VideoType => 'Vídeo MP4';

  @override
  String get takeoutCsvType => 'Google Takeout CSV';

  @override
  String get channelFilterLabel => 'Canal';

  @override
  String allChannelsWithCount(int count) {
    return 'Todos los canales ($count)';
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
  String get emptyNoResults => 'Sin resultados';

  @override
  String get emptyNoResultsBody =>
      'Prueba con otro término. Solo buscamos en los canales que sigues.';

  @override
  String get emptyNoResultsLocalBody => 'Prueba con otro término.';

  @override
  String get emptyNoLocalVideos => 'No hay vídeos locales';

  @override
  String emptyNoLocalVideosBody(String fromLocation) {
    return 'Añade un archivo MP4 $fromLocation. El título se lee de los metadatos del archivo o del nombre del archivo.';
  }

  @override
  String get emptyInbox => 'Tu bandeja está vacía';

  @override
  String get emptyInboxBody =>
      'Importa tus suscripciones desde Google Takeout o pega el handle o la URL de un canal.';

  @override
  String get emptyCaughtUp => 'Estás al día';

  @override
  String get emptyWatchLater => 'Ver más tarde está vacío';

  @override
  String get emptyWatchLaterBodyCompact =>
      'Guarda un vídeo para más tarde desde el menú de la fila (⋮), o ábrelo y usa el icono del reloj.';

  @override
  String get emptyWatchLaterBodyDesktop =>
      'Guarda un vídeo para más tarde con la tecla S o el icono del reloj en la fila del vídeo.';

  @override
  String get emptyNoSaved => 'No hay vídeos guardados';

  @override
  String get emptyNoSavedBody =>
      'Abre un canal y usa el botón de descarga para verlo sin conexión.';

  @override
  String get emptyNoVideos => 'No hay vídeos';

  @override
  String get emptyRssBody =>
      'Los vídeos que aparecen en los feeds RSS se quedan aquí, sin duplicados, aunque ya no estén en el último feed.';

  @override
  String get emptyNoNewBody =>
      'No hay vídeos nuevos de los canales que sigues.';

  @override
  String get addMp4Button => 'Añadir vídeo MP4';

  @override
  String get importSubscriptions => 'Importar suscripciones';

  @override
  String get keyboardHint => 'R para actualizar · / para buscar';

  @override
  String get statusUpdating => 'Actualizando…';

  @override
  String statusUpdated(String relative) {
    return 'Actualizado $relative';
  }

  @override
  String get statusShortcuts => '↑↓ · Intro · M · S';

  @override
  String updateAvailableTooltip(String version) {
    return 'Actualización disponible: $version';
  }

  @override
  String updateNavPrompt(String version) {
    return 'Actualizar a $version';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get sectionReading => 'Lectura';

  @override
  String get hideDescriptions => 'Ocultar descripciones';

  @override
  String get hideDescriptionsSubtitle =>
      'Mostrar solo canal y título. Modo concentración.';

  @override
  String get sectionUpdate => 'Actualización';

  @override
  String refreshEvery(int minutes) {
    return 'Cada $minutes minutos';
  }

  @override
  String get rssRefreshNote =>
      'Los feeds RSS de YouTube son gratuitos y no consumen cuota de API. Expeditus comprueba los canales de forma escalonada.';

  @override
  String get sectionSponsorBlock => 'SponsorBlock';

  @override
  String get skipSponsors => 'Saltar patrocinadores';

  @override
  String get skipSponsorsSubtitle =>
      'Segmentos señalados por la comunidad. Solo streams directos.';

  @override
  String get sponsorCategorySponsor => 'Patrocinador';

  @override
  String get sponsorCategorySelfPromo => 'Autopromoción';

  @override
  String get sponsorCategoryInteraction => 'Me gusta / suscripción';

  @override
  String get sponsorCategoryIntro => 'Intro';

  @override
  String get sponsorCategoryOutro => 'Outro';

  @override
  String get sponsorCategoryPreview => 'Vista previa';

  @override
  String get sponsorCategoryMusicOfftopic => 'Música fuera de tema';

  @override
  String get sponsorCategoryFiller => 'Relleno';

  @override
  String get sectionHowItWorks => 'Cómo funciona';

  @override
  String get howItWorksBody =>
      'Expeditus no carga el reproductor de YouTube. Resuelve el stream del vídeo y lo reproduce con libmpv: sin anuncios del reproductor, sin recomendaciones, sin reproducción automática. SponsorBlock cubre los patrocinadores dentro del vídeo.';

  @override
  String privacyNote(String location) {
    return 'La reproducción depende de YouTube: si un vídeo no se abre, usa «Abrir en YouTube». Las suscripciones y el estado se quedan $location; la app contacta con YouTube para los feeds y con GitHub para comprobar las versiones.';
  }

  @override
  String get licensesButton => 'Licencias de código abierto';

  @override
  String get licensesNote =>
      'Las licencias de los componentes nativos (libmpv, ANGLE, SQLite) están disponibles en la página de licencias.';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get languageLabel => 'Idioma de la app';

  @override
  String get languageSubtitle => 'Elige el idioma de la interfaz.';

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
  String get castTitle => 'Enviar al dispositivo';

  @override
  String get castStatusStarting => 'Iniciando la reproducción…';

  @override
  String get castStatusPlaying => 'Reproduciendo en el dispositivo';

  @override
  String get castStatusPaused => 'En pausa en el dispositivo';

  @override
  String get castStatusStopped => 'Conectado, esperando el inicio';

  @override
  String get castStatusError => 'Error en el dispositivo';

  @override
  String get castStatusIdle => 'Conectado';

  @override
  String get castNoStream =>
      'No hay ningún stream disponible para el dispositivo.';

  @override
  String get castConnectFailed => 'No se pudo conectar.';

  @override
  String get castSendFailed => 'No se pudo enviar al dispositivo.';

  @override
  String get castStartFailed => 'No se pudo iniciar en el dispositivo.';

  @override
  String get castFirewallWarning =>
      'El televisor no puede contactar con el PC. Windows Firewall necesita una regla de entrada para Expeditus.';

  @override
  String get castAllowNetwork => 'Permitir acceso a la red';

  @override
  String get castWaitingWindows => 'Esperando confirmación de Windows…';

  @override
  String get castExplanation =>
      'Los vídeos abiertos en Expeditus también se reproducen en el dispositivo. El audio de la app permanece silenciado durante la emisión.';

  @override
  String get castDlnaDevices => 'Dispositivos DLNA';

  @override
  String get castSearchAgain => 'Buscar de nuevo';

  @override
  String get castSearching => 'Buscando dispositivos…';

  @override
  String castConnecting(String device) {
    return 'Conectando con $device…';
  }

  @override
  String get castDiscoveryHintPhone =>
      'Enciende el dispositivo y asegúrate de que está en la misma red local que el teléfono.';

  @override
  String get castDiscoveryHintDesktop =>
      'Enciende el dispositivo y asegúrate de que está en la misma red local que el PC. Windows puede pedir acceso a la red la primera vez.';

  @override
  String get castNoDevicesFound => 'No se encontraron dispositivos DLNA.';

  @override
  String get castNoDevicesAvailable => 'No hay dispositivos disponibles.';

  @override
  String get castNetworkPublicWarning =>
      'La red de Windows está configurada como «Pública», así que la búsqueda DLNA está bloqueada. Cámbiala a «Privada» para encontrar el televisor.';

  @override
  String get castMakeNetworkPrivate => 'Hacer la red privada';

  @override
  String get castTroubleshootingTitle => 'Consejos de búsqueda';

  @override
  String get castTroubleshootingStep1 =>
      'Enciende el televisor y comprueba que está conectado a la misma Wi-Fi o LAN que el PC.';

  @override
  String get castTroubleshootingStep2 =>
      'Asegúrate de que la red de Windows es «Privada» y no «Pública» (usa el botón de arriba para corregirla).';

  @override
  String get castTroubleshootingStep3 =>
      'Comprueba que el renderer DLNA del televisor está activo (p. ej. «Compartir» o «Screen Mirroring»).';

  @override
  String get castTroubleshootingStep4 =>
      'Permite a Expeditus el acceso a la red si Windows Firewall lo solicita.';

  @override
  String get castStartOnDevice => 'Iniciar en el dispositivo';

  @override
  String get castSendingToDevice => 'Enviando el vídeo al dispositivo…';

  @override
  String get castPlaybackNotStarted =>
      'La reproducción no se inició en el dispositivo.\nPulsa play para empezar.';

  @override
  String get castAudioMuted =>
      'El audio de Expeditus permanece silenciado durante la emisión.';

  @override
  String get castFirewallHint =>
      'El televisor no puede contactar con el PC. Permite a Expeditus el acceso a la red en Windows Firewall y vuelve a intentarlo.';

  @override
  String get castNetworkHint =>
      'Si no se inicia, comprueba que el televisor y el PC están en la misma red y que el firewall de Windows permite a Expeditus el acceso a la red local.';

  @override
  String get castPlayHereOnly => 'Reproducir solo aquí';

  @override
  String get bookmarkSaved => 'Marcador guardado';

  @override
  String localFileNotFound(String path) {
    return 'Archivo local no encontrado: $path';
  }

  @override
  String resumedFrom(String time) {
    return 'Reanudado desde $time';
  }

  @override
  String get sponsorSkipped => 'Patrocinador omitido';

  @override
  String get permissionNotGranted => 'Permiso no concedido.';

  @override
  String get castStopped => 'Emisión detenida';

  @override
  String get openingFile => 'Abriendo archivo…';

  @override
  String get resolvingStream => 'Resolviendo el stream…';

  @override
  String castFooter(String device) {
    return 'Cast · $device';
  }

  @override
  String castFooterMuted(String device) {
    return 'Cast · $device · silenciado aquí';
  }

  @override
  String playerSpeedMenu(String rate) {
    return 'Velocidad ($rate)';
  }

  @override
  String get chaptersAndBookmarks => 'Capítulos y marcadores';

  @override
  String get addBookmark => 'Añadir marcador';

  @override
  String castedTo(String device) {
    return 'Emitiendo en $device';
  }

  @override
  String get castToDevice => 'Enviar al dispositivo';

  @override
  String get markUnwatched => 'Marcar como no visto';

  @override
  String get markWatched => 'Marcar como visto';

  @override
  String get removeFromWatchLater => 'Quitar de Ver más tarde';

  @override
  String get openOnYouTubeWithKey => 'Abrir en YouTube (O)';

  @override
  String get playbackSpeed => 'Velocidad de reproducción';

  @override
  String get markedWatched => 'Marcado como visto';

  @override
  String get markedUnwatched => 'Marcado como no visto';

  @override
  String get addedToWatchLater => 'Añadido a Ver más tarde';

  @override
  String get removedFromWatchLater => 'Quitado de Ver más tarde';

  @override
  String get youtubeVerificationRequired =>
      'YouTube pidió una verificación. Abre el vídeo en YouTube para verlo.';

  @override
  String get videoUnavailable => 'Este vídeo no está disponible en YouTube.';

  @override
  String get noDownloadableFormat =>
      'No hay ningún formato descargable disponible para este vídeo.';

  @override
  String get playbackFailed =>
      'No se pudo reproducir este vídeo. Vuelve a intentarlo o ábrelo en YouTube.';

  @override
  String get playerErrorFileTitle => 'Archivo no disponible';

  @override
  String get playerErrorStreamTitle => 'Stream no disponible';

  @override
  String get technicalDetails => 'Detalles técnicos';

  @override
  String sponsorBlockSegments(int count) {
    return 'SponsorBlock · $count segmentos';
  }

  @override
  String sponsorBlockCount(int count) {
    return 'SponsorBlock · $count';
  }

  @override
  String get sponsorBlockActive => 'SponsorBlock activo';

  @override
  String get seekBack10 => 'Atrás 10 s';

  @override
  String get seekForward10 => 'Adelante 10 s';

  @override
  String get seekBack10Key => 'Atrás 10 s (←)';

  @override
  String get seekForward10Key => 'Adelante 10 s (→)';

  @override
  String get offlineLabel => 'Sin conexión';

  @override
  String get localFileMp4 => 'Archivo local · MP4';

  @override
  String get offlineMp4 => 'Sin conexión · MP4';

  @override
  String directStreamQuality(String quality) {
    return 'Stream directo · $quality';
  }

  @override
  String bookmarkAt(String time) {
    return 'Marcador en $time';
  }

  @override
  String get addNote => 'Añadir nota';

  @override
  String get chapters => 'Capítulos';

  @override
  String get bookmarks => 'Marcadores';

  @override
  String get noBookmarks =>
      'No hay marcadores. Añade una nota en la posición actual.';

  @override
  String get deleteBookmark => 'Eliminar marcador';

  @override
  String get bookmarkDialogTitle => 'Marcador';

  @override
  String get noteHint => 'Nota personal…';

  @override
  String get tabVideos => 'Vídeos';

  @override
  String get tabHistory => 'Historial';

  @override
  String get errorTitle => 'Error';

  @override
  String channelSummary(String videos, String lastSync) {
    return '$videos · $lastSync';
  }

  @override
  String get channelMutedSuffix => ' · RSS silenciado';

  @override
  String get channelHiddenSuffix => ' · fuera de nuevos';

  @override
  String get refreshOnlyChannel => 'Actualizar solo este canal';

  @override
  String get loadingTags => 'Cargando etiquetas…';

  @override
  String get searchChannelHint =>
      'Buscar en el canal, también en las etiquetas…';

  @override
  String get muteRssTooltip =>
      'Silenciar RSS: no se propondrán vídeos nuevos. El archivo y el historial siguen disponibles.';

  @override
  String get unmuteRssTooltip =>
      'Reactivar RSS: los vídeos nuevos volverán a proponerse.';

  @override
  String get rssMuted => 'RSS silenciado';

  @override
  String get muteRss => 'Silenciar RSS';

  @override
  String get hideFromLatestTooltip =>
      'Ocultar el último vídeo de este canal de la lista de nuevos.';

  @override
  String get showInLatestTooltip =>
      'Mostrar el último vídeo de este canal en la lista de nuevos.';

  @override
  String get showInLatest => 'Mostrar en nuevos';

  @override
  String get defaultRateTooltip =>
      'Velocidad predeterminada al abrir los vídeos de este canal.';

  @override
  String get channelRateTooltip => 'Velocidad predeterminada del canal';

  @override
  String get global => 'Global';

  @override
  String get globalRate => 'Velocidad global';

  @override
  String channelRate(String rate) {
    return 'Velocidad $rate';
  }

  @override
  String get filterAll => 'Todos';

  @override
  String get filterUnwatched => 'No vistos';

  @override
  String get filterWatched => 'Vistos';

  @override
  String get filterWatchLater => 'Ver más tarde';

  @override
  String get emptyMutedTitle => 'RSS silenciado';

  @override
  String get emptyMutedBody =>
      'No se proponen vídeos nuevos. Reactiva el RSS desde el botón de arriba para verlos.';

  @override
  String get emptyChannelVideosTitle => 'No hay vídeos';

  @override
  String get emptyChannelVideosBody =>
      'Este canal no tiene vídeos en el feed RSS actual.';

  @override
  String get emptyFilterTitle => 'Sin resultados';

  @override
  String get emptyFilterBody =>
      'Ningún vídeo coincide con el filtro o el término buscado.';

  @override
  String get emptyHistoryTitle => 'El historial está vacío';

  @override
  String get emptyHistoryBody =>
      'Los vídeos que abras o marques como vistos aparecerán aquí.';

  @override
  String get emptyHistorySearchBody =>
      'Ningún vídeo del historial coincide con el término buscado.';

  @override
  String get badgeWatched => 'Visto';

  @override
  String get watchAction => 'Ver';

  @override
  String get saveOffline => 'Guardar sin conexión';

  @override
  String get removeDownload => 'Quitar descarga';

  @override
  String get noChannelsTitle => 'No hay canales';

  @override
  String get noChannelsBody => 'Importa tus suscripciones para empezar.';

  @override
  String get deleteChannelTitle => '¿Quitar el canal?';

  @override
  String deleteChannelBody(String name) {
    return '$name se quitará de Expeditus. Los vídeos ya guardados se eliminarán.';
  }

  @override
  String get unmuteTooltip => 'Reactivar';

  @override
  String get muteTooltip => 'Silenciar';

  @override
  String get removeTooltip => 'Quitar';

  @override
  String noChannelFound(String query) {
    return 'No se encontraron canales para «$query».';
  }

  @override
  String channelAddedFeedUpdating(String name) {
    return '$name añadido. El feed se está actualizando.';
  }

  @override
  String channelAddedFeedFailed(String error) {
    return 'Canal añadido, pero el feed no se pudo actualizar: $error';
  }

  @override
  String get searchRateLimited =>
      'YouTube ha limitado la búsqueda. Vuelve a intentarlo en un momento.';

  @override
  String get searchChannelPlaceholder => 'Buscar un canal…';

  @override
  String get searchExplanationPhone =>
      'La búsqueda consulta YouTube. Después añade el canal con un toque.';

  @override
  String get searchExplanationDesktop =>
      'La búsqueda consulta YouTube. Después añade el canal con un clic.';

  @override
  String get searchingChannels => 'Buscando canales…';

  @override
  String get searchPrompt => 'Escribe una palabra y pulsa Buscar.';

  @override
  String get alreadySubscribed => 'Ya añadido';

  @override
  String get addChannel => 'Añadir';

  @override
  String get importSubscriptionsTitle => 'Importar suscripciones';

  @override
  String get importIntro =>
      'No hace falta iniciar sesión en Google. Takeout es la forma más limpia: Descargar datos → YouTube → subscriptions.csv.';

  @override
  String get tabTakeout => 'Takeout';

  @override
  String get tabPaste => 'Pegar';

  @override
  String get tabSearch => 'Buscar';

  @override
  String get tabLink => 'Enlace';

  @override
  String get importingEllipsis => 'Importando…';

  @override
  String get noLoginNote =>
      'Sin inicio de sesión. La búsqueda de canales consulta YouTube.';

  @override
  String get csvSelectTitle => 'Selecciona subscriptions.csv';

  @override
  String get csvSelectBody =>
      'El archivo que Google prepara en Takeout contiene el ID, la URL y el nombre de cada canal.';

  @override
  String get chooseCsvFile => 'Elegir archivo CSV';

  @override
  String get pasteInstructions => 'Un canal por línea: handle, URL o ID.';

  @override
  String get importButton => 'Importar';

  @override
  String get importStatusResolvingChannels => 'Resolviendo canales…';

  @override
  String importStatusResolvingProgress(int current, int total) {
    return 'Resolviendo $current/$total…';
  }

  @override
  String get importStatusImporting => 'Importando…';

  @override
  String get videoLinkIntro =>
      'Pega el enlace de un vídeo de YouTube. Expeditus encuentra el canal, se suscribe automáticamente y guarda el vídeo en Ver más tarde.';

  @override
  String videoLinkAdded(String video, String channel) {
    return 'Añadido «$video» y suscrito a $channel. El vídeo está en Ver más tarde.';
  }

  @override
  String get addAndSubscribe => 'Añadir y suscribirse';

  @override
  String get welcomeTitle => 'Bienvenido.';

  @override
  String get welcomeBody =>
      'Busca un canal por nombre para empezar. También puedes pegar el enlace de un canal o de un vídeo, o importar las suscripciones desde Google Takeout.';

  @override
  String get welcomePhilosophy =>
      'Expeditus mostrará solo el último vídeo de cada canal: sin recomendaciones, sin reproducción automática, sin ruido.';

  @override
  String get welcomeImportTakeout => 'Importar desde Google Takeout';

  @override
  String get welcomeAddVideoLink => 'Añadir un vídeo desde un enlace';

  @override
  String get welcomeSkip => 'Saltar por ahora';

  @override
  String get welcomeSearchHeading => 'Buscar un canal';

  @override
  String get welcomeSearchHeadingCompact => 'O busca un canal';

  @override
  String get updatesTitle => 'Actualizaciones';

  @override
  String get installedVersion => 'Instalada';

  @override
  String get availableVersion => 'Disponible';

  @override
  String get latestRelease => 'Última versión';

  @override
  String get downloadInstaller => 'Descargar instalador';

  @override
  String get openRelease => 'Abrir versión';

  @override
  String get checkNow => 'Comprobar ahora';

  @override
  String get skipVersion => 'Saltar esta versión';

  @override
  String get releasePage => 'Página de la versión';

  @override
  String get installerNote =>
      'Después de la descarga, cierra Expeditus y ejecuta el instalador.';

  @override
  String get releasePageNote =>
      'Abre la página de la versión para descargar la más reciente.';

  @override
  String skippedVersion(String version) {
    return 'Has saltado la versión $version. Se te ofrecerá la siguiente.';
  }

  @override
  String get restore => 'Restaurar';

  @override
  String get notCheckedTitle =>
      'No hay comprobaciones recientes. Comprueba ahora si hay una versión nueva.';

  @override
  String get upToDate => 'Expeditus está actualizado.';

  @override
  String get upToDateCached => 'Expeditus está actualizado (datos en caché).';

  @override
  String get lastCheckNever => 'Nunca comprobado';

  @override
  String lastCheck(String relative) {
    return 'Última comprobación: $relative';
  }

  @override
  String lastCheckCached(String relative) {
    return 'Última comprobación: $relative · datos en caché';
  }

  @override
  String get updateCheckFailed => 'Error al comprobar actualizaciones.';

  @override
  String updateCheckFailedDetails(String details) {
    return 'Error al comprobar actualizaciones: $details';
  }

  @override
  String updateStateSaveFailed(String details) {
    return 'No se pudo guardar el estado de actualización: $details';
  }

  @override
  String updateSkipSaveFailed(String details) {
    return 'No se pudo guardar la versión saltada: $details';
  }

  @override
  String updateRestoreFailed(String details) {
    return 'No se pudo restaurar la versión saltada: $details';
  }

  @override
  String get startupFailed => 'Expeditus no pudo iniciarse';

  @override
  String get detailsLabel => 'Detalles:';

  @override
  String get removeFromList => 'Quitar de la lista';

  @override
  String castConnectFailedDetails(String device, String details) {
    return 'No se pudo conectar con $device: $details';
  }

  @override
  String castSendFailedDetails(String device, String details) {
    return 'No se pudo enviar a $device: $details';
  }

  @override
  String castActionFailedDetails(String details) {
    return 'Error en la acción del dispositivo: $details';
  }

  @override
  String castDiscoveryFailedDetails(String details) {
    return 'Error al buscar dispositivos: $details';
  }

  @override
  String get castUnresponsive =>
      'El dispositivo ya no responde. Comprueba que sigue encendido y en la misma red.';

  @override
  String get castFirewallDenied =>
      'Acceso a la red no concedido. Añade una regla de entrada para Expeditus en Windows Firewall.';

  @override
  String get castNetworkProfileFailed =>
      'No se pudo cambiar el tipo de red. Abre Configuración > Red e Internet y establece la red como «Privada».';

  @override
  String get updateErrorNetwork =>
      'No se pudo contactar con el servidor de actualizaciones. Comprueba la conexión y vuelve a intentarlo.';

  @override
  String get updateErrorRateLimited =>
      'Demasiadas solicitudes de actualización. Vuelve a intentarlo más tarde.';

  @override
  String get updateErrorUnauthorized =>
      'El servidor de actualizaciones rechazó la solicitud.';

  @override
  String get updateErrorNotFound =>
      'No se encontró ninguna versión. Es posible que el repositorio aún no tenga versiones publicadas.';

  @override
  String get updateErrorInvalidFeed =>
      'El servidor de actualizaciones devolvió una respuesta no válida.';

  @override
  String updateErrorServer(String status) {
    return 'El servidor de actualizaciones devolvió un error ($status).';
  }

  @override
  String get localVideoLabel => 'Vídeo local';

  @override
  String channelsNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales no actualizados',
      one: '1 canal no actualizado',
    );
    return '$_temp0';
  }

  @override
  String get audioOnlyQuality => 'Solo audio';

  @override
  String get castDiscoveryFailed => 'Error al buscar dispositivos.';

  @override
  String get castActionFailed => 'Error en la acción del dispositivo.';
}
