// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get remove => 'Remove';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get importAction => 'Import';

  @override
  String get searchAction => 'Search';

  @override
  String get refreshAction => 'Refresh';

  @override
  String get addAction => 'Add';

  @override
  String get playAction => 'Play';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get deviceFallback => 'device';

  @override
  String get computerNoun => 'computer';

  @override
  String get phoneNoun => 'phone';

  @override
  String get onComputer => 'on your computer';

  @override
  String get onPhone => 'on your phone';

  @override
  String get fromComputer => 'from your computer';

  @override
  String get fromPhone => 'from your phone';

  @override
  String get openOnYouTube => 'Open on YouTube';

  @override
  String get videoActions => 'Video actions';

  @override
  String get openChannel => 'Open channel';

  @override
  String get localFileLabel => 'Local file';

  @override
  String get relativeNever => 'never';

  @override
  String get relativeNow => 'just now';

  @override
  String get relativeYesterday => 'yesterday';

  @override
  String relativeMinutes(int count) {
    return '$count min ago';
  }

  @override
  String relativeHours(int count) {
    return '$count h ago';
  }

  @override
  String relativeDays(int count) {
    return '$count d ago';
  }

  @override
  String updatedRelative(String relative) {
    return 'updated $relative';
  }

  @override
  String savedRelative(String relative) {
    return 'saved $relative';
  }

  @override
  String addedRelative(String relative) {
    return 'added $relative';
  }

  @override
  String openedRelative(String relative) {
    return 'opened $relative';
  }

  @override
  String get navLatest => 'Latest';

  @override
  String get navNew => 'New';

  @override
  String get navWatchLater => 'Watch later';

  @override
  String get navSaved => 'Saved';

  @override
  String get navLocal => 'Local videos';

  @override
  String get navRss => 'RSS history';

  @override
  String get navChannels => 'Channels';

  @override
  String get navUpdates => 'Updates';

  @override
  String get navSettings => 'Settings';

  @override
  String get navImport => 'Import';

  @override
  String get navSearchChannel => 'Search channel';

  @override
  String get navMore => 'More';

  @override
  String get mobileQueueShort => 'Later';

  @override
  String get openMenu => 'Open menu';

  @override
  String get closeMenu => 'Close menu';

  @override
  String get sidebarTagline => 'Only what you chose.\nNo recommendations.';

  @override
  String get viewLatest => 'Latest';

  @override
  String get viewNew => 'New';

  @override
  String get viewWatchLater => 'Watch later';

  @override
  String get viewSaved => 'Saved';

  @override
  String get viewLocal => 'Local videos';

  @override
  String get viewRss => 'RSS history';

  @override
  String get viewChannels => 'Channels';

  @override
  String videosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String channelsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '1 channel',
    );
    return '$_temp0';
  }

  @override
  String newLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions',
      one: '1 subscription',
    );
    return '$_temp0';
  }

  @override
  String mp4FilesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count MP4 files',
      one: '1 MP4 file',
    );
    return '$_temp0';
  }

  @override
  String errorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String channelsImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels imported',
      one: '1 channel imported',
    );
    return '$_temp0';
  }

  @override
  String alreadyPresentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count already present',
      one: '1 already present',
    );
    return '$_temp0';
  }

  @override
  String videosAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos added',
      one: '1 video added',
    );
    return '$_temp0';
  }

  @override
  String subtitleNew(String videos) {
    return '$videos to watch';
  }

  @override
  String subtitleWatchLater(String videos) {
    return '$videos to watch';
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
    return '$videos seen in the feed';
  }

  @override
  String subtitleRssFiltered(String videos, String total) {
    return '$videos · $total total';
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
  String get markAllRead => 'Mark all read';

  @override
  String get refreshWithKey => 'Refresh (R)';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get addVideo => 'Add video';

  @override
  String get moreActions => 'More actions';

  @override
  String get searchSubscriptionsHint => 'Search subscriptions…';

  @override
  String get searchLocalHint => 'Search local videos…';

  @override
  String get noChannelsImported => 'No channels imported.';

  @override
  String get noVideosAdded => 'No videos added.';

  @override
  String get mp4VideoType => 'MP4 video';

  @override
  String get takeoutCsvType => 'Google Takeout CSV';

  @override
  String get channelFilterLabel => 'Channel';

  @override
  String allChannelsWithCount(int count) {
    return 'All channels ($count)';
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
  String get emptyNoResults => 'No results';

  @override
  String get emptyNoResultsBody =>
      'Try another term. We only search the channels you follow.';

  @override
  String get emptyNoResultsLocalBody => 'Try another term.';

  @override
  String get emptyNoLocalVideos => 'No local videos';

  @override
  String emptyNoLocalVideosBody(String fromLocation) {
    return 'Add an MP4 file $fromLocation. The title comes from the file metadata, or from the file name.';
  }

  @override
  String get emptyInbox => 'Your inbox is empty';

  @override
  String get emptyInboxBody =>
      'Import your subscriptions from Google Takeout, or paste a channel handle or URL.';

  @override
  String get emptyCaughtUp => 'You’re all caught up';

  @override
  String get emptyWatchLater => 'Watch later is empty';

  @override
  String get emptyWatchLaterBodyCompact =>
      'Save a video for later from the row menu (⋮), or open it and use the clock icon.';

  @override
  String get emptyWatchLaterBodyDesktop =>
      'Save a video for later with the S key or the clock icon in the video row.';

  @override
  String get emptyNoSaved => 'No saved videos';

  @override
  String get emptyNoSavedBody =>
      'Open a channel and use the download button to watch offline.';

  @override
  String get emptyNoVideos => 'No videos';

  @override
  String get emptyRssBody =>
      'Videos that appear in RSS feeds stay here, without duplicates, even after they leave the latest feed.';

  @override
  String get emptyNoNewBody => 'No new videos from the channels you follow.';

  @override
  String get addMp4Button => 'Add MP4 video';

  @override
  String get importSubscriptions => 'Import subscriptions';

  @override
  String get keyboardHint => 'R to refresh · / to search';

  @override
  String get statusUpdating => 'Updating…';

  @override
  String statusUpdated(String relative) {
    return 'Updated $relative';
  }

  @override
  String get statusShortcuts => '↑↓ · Enter · M · S';

  @override
  String updateAvailableTooltip(String version) {
    return 'Update available: $version';
  }

  @override
  String updateNavPrompt(String version) {
    return 'Update to $version';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionReading => 'Reading';

  @override
  String get hideDescriptions => 'Hide descriptions';

  @override
  String get hideDescriptionsSubtitle =>
      'Show only channel and title. Focus mode.';

  @override
  String get sectionUpdate => 'Refresh';

  @override
  String refreshEvery(int minutes) {
    return 'Every $minutes minutes';
  }

  @override
  String get rssRefreshNote =>
      'YouTube RSS feeds are free and do not use API quota. Expeditus checks channels on a staggered schedule.';

  @override
  String get sectionSponsorBlock => 'SponsorBlock';

  @override
  String get skipSponsors => 'Skip sponsors';

  @override
  String get skipSponsorsSubtitle =>
      'Community-reported segments. Direct streams only.';

  @override
  String get sponsorCategorySponsor => 'Sponsor';

  @override
  String get sponsorCategorySelfPromo => 'Self-promotion';

  @override
  String get sponsorCategoryInteraction => 'Like / subscribe';

  @override
  String get sponsorCategoryIntro => 'Intro';

  @override
  String get sponsorCategoryOutro => 'Outro';

  @override
  String get sponsorCategoryPreview => 'Preview';

  @override
  String get sponsorCategoryMusicOfftopic => 'Non-music section';

  @override
  String get sponsorCategoryFiller => 'Filler';

  @override
  String get sectionHowItWorks => 'How it works';

  @override
  String get howItWorksBody =>
      'Expeditus does not load the YouTube player. It resolves the video stream and plays it with libmpv: no player ads, no recommendations, no autoplay. SponsorBlock covers sponsors inside the video.';

  @override
  String privacyNote(String location) {
    return 'Playback depends on YouTube: if a video does not open, use “Open on YouTube”. Subscriptions and state stay $location; the app contacts YouTube for feeds and GitHub to check releases.';
  }

  @override
  String get licensesButton => 'Open source licenses';

  @override
  String get licensesNote =>
      'Licenses for native components (libmpv, ANGLE, SQLite) are available on the licenses page.';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get languageLabel => 'App language';

  @override
  String get languageSubtitle => 'Choose the language used by the interface.';

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
  String get castTitle => 'Cast to device';

  @override
  String get castStatusStarting => 'Starting playback…';

  @override
  String get castStatusPlaying => 'Playing on device';

  @override
  String get castStatusPaused => 'Paused on device';

  @override
  String get castStatusStopped => 'Connected, waiting to start';

  @override
  String get castStatusError => 'Error on device';

  @override
  String get castStatusIdle => 'Connected';

  @override
  String get castNoStream => 'No stream available for the device.';

  @override
  String get castConnectFailed => 'Could not connect.';

  @override
  String get castSendFailed => 'Could not send to device.';

  @override
  String get castStartFailed => 'Could not start on device.';

  @override
  String get castFirewallWarning =>
      'The TV cannot reach the PC. Windows Firewall needs an inbound rule for Expeditus.';

  @override
  String get castAllowNetwork => 'Allow network access';

  @override
  String get castWaitingWindows => 'Waiting for Windows confirmation…';

  @override
  String get castExplanation =>
      'Videos opened in Expeditus also play on the device. App audio stays muted while casting.';

  @override
  String get castDlnaDevices => 'DLNA devices';

  @override
  String get castSearchAgain => 'Search again';

  @override
  String get castSearching => 'Searching for devices…';

  @override
  String castConnecting(String device) {
    return 'Connecting to $device…';
  }

  @override
  String get castDiscoveryHintPhone =>
      'Turn on the device and make sure it is on the same local network as the phone.';

  @override
  String get castDiscoveryHintDesktop =>
      'Turn on the device and make sure it is on the same local network as the PC. Windows may ask for network access the first time.';

  @override
  String get castNoDevicesFound => 'No DLNA devices found.';

  @override
  String get castNoDevicesAvailable => 'No devices available.';

  @override
  String get castNetworkPublicWarning =>
      'The Windows network is set to \"Public\", so DLNA discovery is blocked. Set it to \"Private\" to find the TV.';

  @override
  String get castMakeNetworkPrivate => 'Make network private';

  @override
  String get castTroubleshootingTitle => 'Discovery tips';

  @override
  String get castTroubleshootingStep1 =>
      'Turn on the TV and check that it is connected to the same Wi-Fi or LAN as the PC.';

  @override
  String get castTroubleshootingStep2 =>
      'Make sure the Windows network is \"Private\", not \"Public\" (use the button above to fix it).';

  @override
  String get castTroubleshootingStep3 =>
      'Check that the TV has its DLNA renderer enabled (e.g. \"Sharing\" or \"Screen Mirroring\").';

  @override
  String get castTroubleshootingStep4 =>
      'Allow Expeditus network access if Windows Firewall asks for it.';

  @override
  String get castStartOnDevice => 'Start on device';

  @override
  String get castSendingToDevice => 'Sending the video to the device…';

  @override
  String get castPlaybackNotStarted =>
      'Playback did not start on the device.\nPress play to start.';

  @override
  String get castAudioMuted => 'Expeditus audio stays muted while casting.';

  @override
  String get castFirewallHint =>
      'The TV cannot reach the PC. Allow Expeditus network access in Windows Firewall, then try again.';

  @override
  String get castNetworkHint =>
      'If playback does not start, check that the TV and PC are on the same network and that Windows Firewall allows Expeditus local network access.';

  @override
  String get castPlayHereOnly => 'Play here only';

  @override
  String get bookmarkSaved => 'Bookmark saved';

  @override
  String localFileNotFound(String path) {
    return 'Local file not found: $path';
  }

  @override
  String resumedFrom(String time) {
    return 'Resumed from $time';
  }

  @override
  String get sponsorSkipped => 'Sponsor skipped';

  @override
  String get permissionNotGranted => 'Permission not granted.';

  @override
  String get castStopped => 'Casting stopped';

  @override
  String get openingFile => 'Opening file…';

  @override
  String get resolvingStream => 'Resolving stream…';

  @override
  String castFooter(String device) {
    return 'Cast · $device';
  }

  @override
  String castFooterMuted(String device) {
    return 'Cast · $device · muted here';
  }

  @override
  String playerSpeedMenu(String rate) {
    return 'Speed ($rate)';
  }

  @override
  String get chaptersAndBookmarks => 'Chapters and bookmarks';

  @override
  String get addBookmark => 'Add bookmark';

  @override
  String castedTo(String device) {
    return 'Casting to $device';
  }

  @override
  String get castToDevice => 'Cast to device';

  @override
  String get markUnwatched => 'Mark unwatched';

  @override
  String get markWatched => 'Mark watched';

  @override
  String get removeFromWatchLater => 'Remove from Watch later';

  @override
  String get openOnYouTubeWithKey => 'Open on YouTube (O)';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get markedWatched => 'Marked as watched';

  @override
  String get markedUnwatched => 'Marked as unwatched';

  @override
  String get addedToWatchLater => 'Added to Watch later';

  @override
  String get removedFromWatchLater => 'Removed from Watch later';

  @override
  String get youtubeVerificationRequired =>
      'YouTube asked for verification. Open the video on YouTube to watch it.';

  @override
  String get videoUnavailable => 'This video is not available on YouTube.';

  @override
  String get noDownloadableFormat =>
      'No downloadable format is available for this video.';

  @override
  String get playbackFailed =>
      'Could not play this video. Try again or open it on YouTube.';

  @override
  String get playerErrorFileTitle => 'File unavailable';

  @override
  String get playerErrorStreamTitle => 'Stream unavailable';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String sponsorBlockSegments(int count) {
    return 'SponsorBlock · $count segments';
  }

  @override
  String sponsorBlockCount(int count) {
    return 'SponsorBlock · $count';
  }

  @override
  String get sponsorBlockActive => 'SponsorBlock active';

  @override
  String get seekBack10 => 'Back 10 s';

  @override
  String get seekForward10 => 'Forward 10 s';

  @override
  String get seekBack10Key => 'Back 10 s (←)';

  @override
  String get seekForward10Key => 'Forward 10 s (→)';

  @override
  String get offlineLabel => 'Offline';

  @override
  String get localFileMp4 => 'Local file · MP4';

  @override
  String get offlineMp4 => 'Offline · MP4';

  @override
  String directStreamQuality(String quality) {
    return 'Direct stream · $quality';
  }

  @override
  String bookmarkAt(String time) {
    return 'Bookmark at $time';
  }

  @override
  String get addNote => 'Add note';

  @override
  String get chapters => 'Chapters';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get noBookmarks => 'No bookmarks. Add a note at the current position.';

  @override
  String get deleteBookmark => 'Delete bookmark';

  @override
  String get bookmarkDialogTitle => 'Bookmark';

  @override
  String get noteHint => 'Personal note…';

  @override
  String get tabVideos => 'Videos';

  @override
  String get tabHistory => 'History';

  @override
  String get errorTitle => 'Error';

  @override
  String channelSummary(String videos, String lastSync) {
    return '$videos · $lastSync';
  }

  @override
  String get channelMutedSuffix => ' · RSS muted';

  @override
  String get channelHiddenSuffix => ' · hidden from new';

  @override
  String get refreshOnlyChannel => 'Refresh only this channel';

  @override
  String get loadingTags => 'Loading tags…';

  @override
  String get searchChannelHint => 'Search this channel, including tags…';

  @override
  String get muteRssTooltip =>
      'Mute RSS: no new videos will be suggested. Archive and history remain available.';

  @override
  String get unmuteRssTooltip =>
      'Turn RSS back on: new videos will be suggested again.';

  @override
  String get rssMuted => 'RSS muted';

  @override
  String get muteRss => 'Mute RSS';

  @override
  String get hideFromLatestTooltip =>
      'Hide this channel’s latest video from the new list.';

  @override
  String get showInLatestTooltip =>
      'Show this channel’s latest video in the new list.';

  @override
  String get showInLatest => 'Show in new';

  @override
  String get defaultRateTooltip =>
      'Default speed when you open this channel’s videos.';

  @override
  String get channelRateTooltip => 'Channel default speed';

  @override
  String get global => 'Global';

  @override
  String get globalRate => 'Global speed';

  @override
  String channelRate(String rate) {
    return 'Speed $rate';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterUnwatched => 'Unwatched';

  @override
  String get filterWatched => 'Watched';

  @override
  String get filterWatchLater => 'Watch later';

  @override
  String get emptyMutedTitle => 'RSS muted';

  @override
  String get emptyMutedBody =>
      'New videos are not suggested. Turn RSS back on from the button above to see them.';

  @override
  String get emptyChannelVideosTitle => 'No videos';

  @override
  String get emptyChannelVideosBody =>
      'This channel has no videos in the current RSS feed.';

  @override
  String get emptyFilterTitle => 'No results';

  @override
  String get emptyFilterBody => 'No videos match the filter or search term.';

  @override
  String get emptyHistoryTitle => 'History is empty';

  @override
  String get emptyHistoryBody =>
      'Videos you open or mark as watched will appear here.';

  @override
  String get emptyHistorySearchBody =>
      'No history videos match the search term.';

  @override
  String get badgeWatched => 'Watched';

  @override
  String get watchAction => 'Watch';

  @override
  String get saveOffline => 'Save offline';

  @override
  String get removeDownload => 'Remove download';

  @override
  String get noChannelsTitle => 'No channels';

  @override
  String get noChannelsBody => 'Import your subscriptions to get started.';

  @override
  String get deleteChannelTitle => 'Remove channel?';

  @override
  String deleteChannelBody(String name) {
    return '$name will be removed from Expeditus. Saved videos will be deleted.';
  }

  @override
  String get unmuteTooltip => 'Resume';

  @override
  String get muteTooltip => 'Mute';

  @override
  String get removeTooltip => 'Remove';

  @override
  String noChannelFound(String query) {
    return 'No channels found for “$query”.';
  }

  @override
  String channelAddedFeedUpdating(String name) {
    return '$name added. The feed is updating.';
  }

  @override
  String channelAddedFeedFailed(String error) {
    return 'Channel added, but the feed could not be updated: $error';
  }

  @override
  String get searchRateLimited =>
      'YouTube limited the search. Try again shortly.';

  @override
  String get searchChannelPlaceholder => 'Search for a channel…';

  @override
  String get searchExplanationPhone =>
      'Search queries YouTube. Then add the channel with a tap.';

  @override
  String get searchExplanationDesktop =>
      'Search queries YouTube. Then add the channel with a click.';

  @override
  String get searchingChannels => 'Searching channels…';

  @override
  String get searchPrompt => 'Type a word and press Search.';

  @override
  String get alreadySubscribed => 'Already added';

  @override
  String get addChannel => 'Add';

  @override
  String get importSubscriptionsTitle => 'Import subscriptions';

  @override
  String get importIntro =>
      'No Google login needed. Takeout is the cleanest way: Download data → YouTube → subscriptions.csv.';

  @override
  String get tabTakeout => 'Takeout';

  @override
  String get tabPaste => 'Paste';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabLink => 'Link';

  @override
  String get importingEllipsis => 'Importing…';

  @override
  String get noLoginNote => 'No login. Channel search queries YouTube.';

  @override
  String get csvSelectTitle => 'Select subscriptions.csv';

  @override
  String get csvSelectBody =>
      'The file Google prepares in Takeout contains the ID, URL and name of each channel.';

  @override
  String get chooseCsvFile => 'Choose CSV file';

  @override
  String get pasteInstructions => 'One channel per line: handle, URL or ID.';

  @override
  String get importButton => 'Import';

  @override
  String get importStatusResolvingChannels => 'Resolving channels…';

  @override
  String importStatusResolvingProgress(int current, int total) {
    return 'Resolving $current/$total…';
  }

  @override
  String get importStatusImporting => 'Importing…';

  @override
  String get videoLinkIntro =>
      'Paste a YouTube video link. Expeditus finds the channel, subscribes automatically, and saves the video to Watch later.';

  @override
  String videoLinkAdded(String video, String channel) {
    return 'Added “$video” and subscribed to $channel. The video is in Watch later.';
  }

  @override
  String get addAndSubscribe => 'Add and subscribe';

  @override
  String get welcomeTitle => 'Welcome.';

  @override
  String get welcomeBody =>
      'Search for a channel by name to get started. You can also paste a channel or video link, or import subscriptions from Google Takeout.';

  @override
  String get welcomePhilosophy =>
      'Expeditus shows only the latest video from each channel: no recommendations, no autoplay, no noise.';

  @override
  String get welcomeImportTakeout => 'Import from Google Takeout';

  @override
  String get welcomeAddVideoLink => 'Add a video from a link';

  @override
  String get welcomeSkip => 'Skip for now';

  @override
  String get welcomeSearchHeading => 'Search for a channel';

  @override
  String get welcomeSearchHeadingCompact => 'Or search for a channel';

  @override
  String get updatesTitle => 'Updates';

  @override
  String get installedVersion => 'Installed';

  @override
  String get availableVersion => 'Available';

  @override
  String get latestRelease => 'Latest release';

  @override
  String get downloadInstaller => 'Download installer';

  @override
  String get openRelease => 'Open release';

  @override
  String get checkNow => 'Check now';

  @override
  String get skipVersion => 'Skip this version';

  @override
  String get releasePage => 'Release page';

  @override
  String get installerNote =>
      'After downloading, close Expeditus and run the installer.';

  @override
  String get releasePageNote =>
      'Open the release page to download the latest version.';

  @override
  String skippedVersion(String version) {
    return 'You skipped version $version. The next release will be offered.';
  }

  @override
  String get restore => 'Restore';

  @override
  String get notCheckedTitle => 'No recent check. Check now for a new version.';

  @override
  String get upToDate => 'Expeditus is up to date.';

  @override
  String get upToDateCached => 'Expeditus is up to date (cached data).';

  @override
  String get lastCheckNever => 'Never checked';

  @override
  String lastCheck(String relative) {
    return 'Last check: $relative';
  }

  @override
  String lastCheckCached(String relative) {
    return 'Last check: $relative · cached data';
  }

  @override
  String get updateCheckFailed => 'Update check failed.';

  @override
  String updateCheckFailedDetails(String details) {
    return 'Update check failed: $details';
  }

  @override
  String updateStateSaveFailed(String details) {
    return 'Could not save the update state: $details';
  }

  @override
  String updateSkipSaveFailed(String details) {
    return 'Could not save the skipped version: $details';
  }

  @override
  String updateRestoreFailed(String details) {
    return 'Could not restore the skipped version: $details';
  }

  @override
  String get startupFailed => 'Expeditus could not start';

  @override
  String get detailsLabel => 'Details:';

  @override
  String get removeFromList => 'Remove from list';

  @override
  String castConnectFailedDetails(String device, String details) {
    return 'Could not connect to $device: $details';
  }

  @override
  String castSendFailedDetails(String device, String details) {
    return 'Could not send to $device: $details';
  }

  @override
  String castActionFailedDetails(String details) {
    return 'Device action failed: $details';
  }

  @override
  String castDiscoveryFailedDetails(String details) {
    return 'Device search failed: $details';
  }

  @override
  String get castUnresponsive =>
      'The device is no longer responding. Check that it is still on and on the same network.';

  @override
  String get castFirewallDenied =>
      'Network access not granted. Add an inbound rule for Expeditus in Windows Firewall.';

  @override
  String get castNetworkProfileFailed =>
      'Could not change the network type. Open Settings > Network & Internet and set the network to “Private”.';

  @override
  String get updateErrorNetwork =>
      'Could not contact the update server. Check your connection and try again.';

  @override
  String get updateErrorRateLimited =>
      'Too many update requests. Try again later.';

  @override
  String get updateErrorUnauthorized =>
      'The update server refused the request.';

  @override
  String get updateErrorNotFound =>
      'No release found. The repository may not have any published releases yet.';

  @override
  String get updateErrorInvalidFeed =>
      'The update server returned an invalid response.';

  @override
  String updateErrorServer(String status) {
    return 'The update server returned an error ($status).';
  }

  @override
  String get localVideoLabel => 'Local video';

  @override
  String channelsNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels not updated',
      one: '1 channel not updated',
    );
    return '$_temp0';
  }

  @override
  String get audioOnlyQuality => 'Audio only';

  @override
  String get castDiscoveryFailed => 'Device search failed.';

  @override
  String get castActionFailed => 'Device action failed.';
}
