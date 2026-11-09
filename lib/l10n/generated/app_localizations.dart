import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('it'),
    Locale('en'),
    Locale('de'),
    Locale('es'),
  ];

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @searchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchAction;

  /// No description provided for @refreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshAction;

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAction;

  /// No description provided for @playAction.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playAction;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @deviceFallback.
  ///
  /// In en, this message translates to:
  /// **'device'**
  String get deviceFallback;

  /// No description provided for @computerNoun.
  ///
  /// In en, this message translates to:
  /// **'computer'**
  String get computerNoun;

  /// No description provided for @phoneNoun.
  ///
  /// In en, this message translates to:
  /// **'phone'**
  String get phoneNoun;

  /// No description provided for @onComputer.
  ///
  /// In en, this message translates to:
  /// **'on your computer'**
  String get onComputer;

  /// No description provided for @onPhone.
  ///
  /// In en, this message translates to:
  /// **'on your phone'**
  String get onPhone;

  /// No description provided for @fromComputer.
  ///
  /// In en, this message translates to:
  /// **'from your computer'**
  String get fromComputer;

  /// No description provided for @fromPhone.
  ///
  /// In en, this message translates to:
  /// **'from your phone'**
  String get fromPhone;

  /// No description provided for @openOnYouTube.
  ///
  /// In en, this message translates to:
  /// **'Open on YouTube'**
  String get openOnYouTube;

  /// No description provided for @videoActions.
  ///
  /// In en, this message translates to:
  /// **'Video actions'**
  String get videoActions;

  /// No description provided for @openChannel.
  ///
  /// In en, this message translates to:
  /// **'Open channel'**
  String get openChannel;

  /// No description provided for @localFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Local file'**
  String get localFileLabel;

  /// No description provided for @relativeNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get relativeNever;

  /// No description provided for @relativeNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeNow;

  /// No description provided for @relativeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get relativeYesterday;

  /// No description provided for @relativeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String relativeMinutes(int count);

  /// No description provided for @relativeHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String relativeHours(int count);

  /// No description provided for @relativeDays.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String relativeDays(int count);

  /// No description provided for @updatedRelative.
  ///
  /// In en, this message translates to:
  /// **'updated {relative}'**
  String updatedRelative(String relative);

  /// No description provided for @savedRelative.
  ///
  /// In en, this message translates to:
  /// **'saved {relative}'**
  String savedRelative(String relative);

  /// No description provided for @addedRelative.
  ///
  /// In en, this message translates to:
  /// **'added {relative}'**
  String addedRelative(String relative);

  /// No description provided for @openedRelative.
  ///
  /// In en, this message translates to:
  /// **'opened {relative}'**
  String openedRelative(String relative);

  /// No description provided for @navLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get navLatest;

  /// No description provided for @navNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get navNew;

  /// No description provided for @navWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Watch later'**
  String get navWatchLater;

  /// No description provided for @navSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get navSaved;

  /// No description provided for @navLocal.
  ///
  /// In en, this message translates to:
  /// **'Local videos'**
  String get navLocal;

  /// No description provided for @navRss.
  ///
  /// In en, this message translates to:
  /// **'RSS history'**
  String get navRss;

  /// No description provided for @navChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get navChannels;

  /// No description provided for @navUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get navUpdates;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get navImport;

  /// No description provided for @navSearchChannel.
  ///
  /// In en, this message translates to:
  /// **'Search channel'**
  String get navSearchChannel;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @mobileQueueShort.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get mobileQueueShort;

  /// No description provided for @openMenu.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get openMenu;

  /// No description provided for @closeMenu.
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get closeMenu;

  /// No description provided for @sidebarTagline.
  ///
  /// In en, this message translates to:
  /// **'Only what you chose.\nNo recommendations.'**
  String get sidebarTagline;

  /// No description provided for @viewLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get viewLatest;

  /// No description provided for @viewNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get viewNew;

  /// No description provided for @viewWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Watch later'**
  String get viewWatchLater;

  /// No description provided for @viewSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get viewSaved;

  /// No description provided for @viewLocal.
  ///
  /// In en, this message translates to:
  /// **'Local videos'**
  String get viewLocal;

  /// No description provided for @viewRss.
  ///
  /// In en, this message translates to:
  /// **'RSS history'**
  String get viewRss;

  /// No description provided for @viewChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get viewChannels;

  /// No description provided for @videosLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 video} other{{count} videos}}'**
  String videosLabel(int count);

  /// No description provided for @channelsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 channel} other{{count} channels}}'**
  String channelsLabel(int count);

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new} other{{count} new}}'**
  String newLabel(int count);

  /// No description provided for @subscriptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subscription} other{{count} subscriptions}}'**
  String subscriptionsLabel(int count);

  /// No description provided for @mp4FilesLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 MP4 file} other{{count} MP4 files}}'**
  String mp4FilesLabel(int count);

  /// No description provided for @errorsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 error} other{{count} errors}}'**
  String errorsCount(int count);

  /// No description provided for @channelsImportedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 channel imported} other{{count} channels imported}}'**
  String channelsImportedCount(int count);

  /// No description provided for @alreadyPresentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 already present} other{{count} already present}}'**
  String alreadyPresentCount(int count);

  /// No description provided for @videosAddedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 video added} other{{count} videos added}}'**
  String videosAddedCount(int count);

  /// No description provided for @subtitleNew.
  ///
  /// In en, this message translates to:
  /// **'{videos} to watch'**
  String subtitleNew(String videos);

  /// No description provided for @subtitleWatchLater.
  ///
  /// In en, this message translates to:
  /// **'{videos} to watch'**
  String subtitleWatchLater(String videos);

  /// No description provided for @subtitleSaved.
  ///
  /// In en, this message translates to:
  /// **'{videos} offline'**
  String subtitleSaved(String videos);

  /// No description provided for @subtitleLocal.
  ///
  /// In en, this message translates to:
  /// **'{files} {location}'**
  String subtitleLocal(String files, String location);

  /// No description provided for @subtitleRssAll.
  ///
  /// In en, this message translates to:
  /// **'{videos} seen in the feed'**
  String subtitleRssAll(String videos);

  /// No description provided for @subtitleRssFiltered.
  ///
  /// In en, this message translates to:
  /// **'{videos} · {total} total'**
  String subtitleRssFiltered(String videos, String total);

  /// No description provided for @subtitleChannels.
  ///
  /// In en, this message translates to:
  /// **'{subscriptions}'**
  String subtitleChannels(String subscriptions);

  /// No description provided for @subtitleLatest.
  ///
  /// In en, this message translates to:
  /// **'{channels} · {newCount}'**
  String subtitleLatest(String channels, String newCount);

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @refreshWithKey.
  ///
  /// In en, this message translates to:
  /// **'Refresh (R)'**
  String get refreshWithKey;

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @addVideo.
  ///
  /// In en, this message translates to:
  /// **'Add video'**
  String get addVideo;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @searchSubscriptionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search subscriptions…'**
  String get searchSubscriptionsHint;

  /// No description provided for @searchLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Search local videos…'**
  String get searchLocalHint;

  /// No description provided for @noChannelsImported.
  ///
  /// In en, this message translates to:
  /// **'No channels imported.'**
  String get noChannelsImported;

  /// No description provided for @noVideosAdded.
  ///
  /// In en, this message translates to:
  /// **'No videos added.'**
  String get noVideosAdded;

  /// No description provided for @mp4VideoType.
  ///
  /// In en, this message translates to:
  /// **'MP4 video'**
  String get mp4VideoType;

  /// No description provided for @takeoutCsvType.
  ///
  /// In en, this message translates to:
  /// **'Google Takeout CSV'**
  String get takeoutCsvType;

  /// No description provided for @channelFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channelFilterLabel;

  /// No description provided for @allChannelsWithCount.
  ///
  /// In en, this message translates to:
  /// **'All channels ({count})'**
  String allChannelsWithCount(int count);

  /// No description provided for @rssChannelSummary.
  ///
  /// In en, this message translates to:
  /// **'{channels} · {videos}'**
  String rssChannelSummary(String channels, String videos);

  /// No description provided for @rssSelectedSummary.
  ///
  /// In en, this message translates to:
  /// **'{videos} · {channel}'**
  String rssSelectedSummary(String videos, String channel);

  /// No description provided for @emptyNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get emptyNoResults;

  /// No description provided for @emptyNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another term. We only search the channels you follow.'**
  String get emptyNoResultsBody;

  /// No description provided for @emptyNoResultsLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Try another term.'**
  String get emptyNoResultsLocalBody;

  /// No description provided for @emptyNoLocalVideos.
  ///
  /// In en, this message translates to:
  /// **'No local videos'**
  String get emptyNoLocalVideos;

  /// No description provided for @emptyNoLocalVideosBody.
  ///
  /// In en, this message translates to:
  /// **'Add an MP4 file {fromLocation}. The title comes from the file metadata, or from the file name.'**
  String emptyNoLocalVideosBody(String fromLocation);

  /// No description provided for @emptyInbox.
  ///
  /// In en, this message translates to:
  /// **'Your inbox is empty'**
  String get emptyInbox;

  /// No description provided for @emptyInboxBody.
  ///
  /// In en, this message translates to:
  /// **'Import your subscriptions from Google Takeout, or paste a channel handle or URL.'**
  String get emptyInboxBody;

  /// No description provided for @emptyCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You’re all caught up'**
  String get emptyCaughtUp;

  /// No description provided for @emptyWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Watch later is empty'**
  String get emptyWatchLater;

  /// No description provided for @emptyWatchLaterBodyCompact.
  ///
  /// In en, this message translates to:
  /// **'Save a video for later from the row menu (⋮), or open it and use the clock icon.'**
  String get emptyWatchLaterBodyCompact;

  /// No description provided for @emptyWatchLaterBodyDesktop.
  ///
  /// In en, this message translates to:
  /// **'Save a video for later with the S key or the clock icon in the video row.'**
  String get emptyWatchLaterBodyDesktop;

  /// No description provided for @emptyNoSaved.
  ///
  /// In en, this message translates to:
  /// **'No saved videos'**
  String get emptyNoSaved;

  /// No description provided for @emptyNoSavedBody.
  ///
  /// In en, this message translates to:
  /// **'Open a channel and use the download button to watch offline.'**
  String get emptyNoSavedBody;

  /// No description provided for @emptyNoVideos.
  ///
  /// In en, this message translates to:
  /// **'No videos'**
  String get emptyNoVideos;

  /// No description provided for @emptyRssBody.
  ///
  /// In en, this message translates to:
  /// **'Videos that appear in RSS feeds stay here, without duplicates, even after they leave the latest feed.'**
  String get emptyRssBody;

  /// No description provided for @emptyNoNewBody.
  ///
  /// In en, this message translates to:
  /// **'No new videos from the channels you follow.'**
  String get emptyNoNewBody;

  /// No description provided for @addMp4Button.
  ///
  /// In en, this message translates to:
  /// **'Add MP4 video'**
  String get addMp4Button;

  /// No description provided for @importSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Import subscriptions'**
  String get importSubscriptions;

  /// No description provided for @keyboardHint.
  ///
  /// In en, this message translates to:
  /// **'R to refresh · / to search'**
  String get keyboardHint;

  /// No description provided for @statusUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get statusUpdating;

  /// No description provided for @statusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {relative}'**
  String statusUpdated(String relative);

  /// No description provided for @statusShortcuts.
  ///
  /// In en, this message translates to:
  /// **'↑↓ · Enter · M · S'**
  String get statusShortcuts;

  /// No description provided for @updateAvailableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String updateAvailableTooltip(String version);

  /// No description provided for @updateNavPrompt.
  ///
  /// In en, this message translates to:
  /// **'Update to {version}'**
  String updateNavPrompt(String version);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get sectionReading;

  /// No description provided for @hideDescriptions.
  ///
  /// In en, this message translates to:
  /// **'Hide descriptions'**
  String get hideDescriptions;

  /// No description provided for @hideDescriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show only channel and title. Focus mode.'**
  String get hideDescriptionsSubtitle;

  /// No description provided for @sectionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sectionUpdate;

  /// No description provided for @refreshEvery.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} minutes'**
  String refreshEvery(int minutes);

  /// No description provided for @rssRefreshNote.
  ///
  /// In en, this message translates to:
  /// **'YouTube RSS feeds are free and do not use API quota. Expeditus checks channels on a staggered schedule.'**
  String get rssRefreshNote;

  /// No description provided for @sectionSponsorBlock.
  ///
  /// In en, this message translates to:
  /// **'SponsorBlock'**
  String get sectionSponsorBlock;

  /// No description provided for @skipSponsors.
  ///
  /// In en, this message translates to:
  /// **'Skip sponsors'**
  String get skipSponsors;

  /// No description provided for @skipSponsorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Community-reported segments. Direct streams only.'**
  String get skipSponsorsSubtitle;

  /// No description provided for @sponsorCategorySponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get sponsorCategorySponsor;

  /// No description provided for @sponsorCategorySelfPromo.
  ///
  /// In en, this message translates to:
  /// **'Self-promotion'**
  String get sponsorCategorySelfPromo;

  /// No description provided for @sponsorCategoryInteraction.
  ///
  /// In en, this message translates to:
  /// **'Like / subscribe'**
  String get sponsorCategoryInteraction;

  /// No description provided for @sponsorCategoryIntro.
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get sponsorCategoryIntro;

  /// No description provided for @sponsorCategoryOutro.
  ///
  /// In en, this message translates to:
  /// **'Outro'**
  String get sponsorCategoryOutro;

  /// No description provided for @sponsorCategoryPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get sponsorCategoryPreview;

  /// No description provided for @sponsorCategoryMusicOfftopic.
  ///
  /// In en, this message translates to:
  /// **'Non-music section'**
  String get sponsorCategoryMusicOfftopic;

  /// No description provided for @sponsorCategoryFiller.
  ///
  /// In en, this message translates to:
  /// **'Filler'**
  String get sponsorCategoryFiller;

  /// No description provided for @sectionHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get sectionHowItWorks;

  /// No description provided for @howItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'Expeditus does not load the YouTube player. It resolves the video stream and plays it with libmpv: no player ads, no recommendations, no autoplay. SponsorBlock covers sponsors inside the video.'**
  String get howItWorksBody;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Playback depends on YouTube: if a video does not open, use “Open on YouTube”. Subscriptions and state stay {location}; the app contacts YouTube for feeds and GitHub to check releases.'**
  String privacyNote(String location);

  /// No description provided for @licensesButton.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get licensesButton;

  /// No description provided for @licensesNote.
  ///
  /// In en, this message translates to:
  /// **'Licenses for native components (libmpv, ANGLE, SQLite) are available on the licenses page.'**
  String get licensesNote;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageLabel;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used by the interface.'**
  String get languageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @castTitle.
  ///
  /// In en, this message translates to:
  /// **'Cast to device'**
  String get castTitle;

  /// No description provided for @castStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting playback…'**
  String get castStatusStarting;

  /// No description provided for @castStatusPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing on device'**
  String get castStatusPlaying;

  /// No description provided for @castStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused on device'**
  String get castStatusPaused;

  /// No description provided for @castStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Connected, waiting to start'**
  String get castStatusStopped;

  /// No description provided for @castStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error on device'**
  String get castStatusError;

  /// No description provided for @castStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get castStatusIdle;

  /// No description provided for @castNoStream.
  ///
  /// In en, this message translates to:
  /// **'No stream available for the device.'**
  String get castNoStream;

  /// No description provided for @castConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect.'**
  String get castConnectFailed;

  /// No description provided for @castSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send to device.'**
  String get castSendFailed;

  /// No description provided for @castStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start on device.'**
  String get castStartFailed;

  /// No description provided for @castFirewallWarning.
  ///
  /// In en, this message translates to:
  /// **'The TV cannot reach the PC. Windows Firewall needs an inbound rule for Expeditus.'**
  String get castFirewallWarning;

  /// No description provided for @castAllowNetwork.
  ///
  /// In en, this message translates to:
  /// **'Allow network access'**
  String get castAllowNetwork;

  /// No description provided for @castWaitingWindows.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Windows confirmation…'**
  String get castWaitingWindows;

  /// No description provided for @castExplanation.
  ///
  /// In en, this message translates to:
  /// **'Videos opened in Expeditus also play on the device. App audio stays muted while casting.'**
  String get castExplanation;

  /// No description provided for @castDlnaDevices.
  ///
  /// In en, this message translates to:
  /// **'DLNA devices'**
  String get castDlnaDevices;

  /// No description provided for @castSearchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get castSearchAgain;

  /// No description provided for @castSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices…'**
  String get castSearching;

  /// No description provided for @castConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {device}…'**
  String castConnecting(String device);

  /// No description provided for @castDiscoveryHintPhone.
  ///
  /// In en, this message translates to:
  /// **'Turn on the device and make sure it is on the same local network as the phone.'**
  String get castDiscoveryHintPhone;

  /// No description provided for @castDiscoveryHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'Turn on the device and make sure it is on the same local network as the PC. Windows may ask for network access the first time.'**
  String get castDiscoveryHintDesktop;

  /// No description provided for @castNoDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No DLNA devices found.'**
  String get castNoDevicesFound;

  /// No description provided for @castNoDevicesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No devices available.'**
  String get castNoDevicesAvailable;

  /// No description provided for @castNetworkPublicWarning.
  ///
  /// In en, this message translates to:
  /// **'The Windows network is set to \"Public\", so DLNA discovery is blocked. Set it to \"Private\" to find the TV.'**
  String get castNetworkPublicWarning;

  /// No description provided for @castMakeNetworkPrivate.
  ///
  /// In en, this message translates to:
  /// **'Make network private'**
  String get castMakeNetworkPrivate;

  /// No description provided for @castTroubleshootingTitle.
  ///
  /// In en, this message translates to:
  /// **'Discovery tips'**
  String get castTroubleshootingTitle;

  /// No description provided for @castTroubleshootingStep1.
  ///
  /// In en, this message translates to:
  /// **'Turn on the TV and check that it is connected to the same Wi-Fi or LAN as the PC.'**
  String get castTroubleshootingStep1;

  /// No description provided for @castTroubleshootingStep2.
  ///
  /// In en, this message translates to:
  /// **'Make sure the Windows network is \"Private\", not \"Public\" (use the button above to fix it).'**
  String get castTroubleshootingStep2;

  /// No description provided for @castTroubleshootingStep3.
  ///
  /// In en, this message translates to:
  /// **'Check that the TV has its DLNA renderer enabled (e.g. \"Sharing\" or \"Screen Mirroring\").'**
  String get castTroubleshootingStep3;

  /// No description provided for @castTroubleshootingStep4.
  ///
  /// In en, this message translates to:
  /// **'Allow Expeditus network access if Windows Firewall asks for it.'**
  String get castTroubleshootingStep4;

  /// No description provided for @castStartOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Start on device'**
  String get castStartOnDevice;

  /// No description provided for @castSendingToDevice.
  ///
  /// In en, this message translates to:
  /// **'Sending the video to the device…'**
  String get castSendingToDevice;

  /// No description provided for @castPlaybackNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Playback did not start on the device.\nPress play to start.'**
  String get castPlaybackNotStarted;

  /// No description provided for @castAudioMuted.
  ///
  /// In en, this message translates to:
  /// **'Expeditus audio stays muted while casting.'**
  String get castAudioMuted;

  /// No description provided for @castFirewallHint.
  ///
  /// In en, this message translates to:
  /// **'The TV cannot reach the PC. Allow Expeditus network access in Windows Firewall, then try again.'**
  String get castFirewallHint;

  /// No description provided for @castNetworkHint.
  ///
  /// In en, this message translates to:
  /// **'If playback does not start, check that the TV and PC are on the same network and that Windows Firewall allows Expeditus local network access.'**
  String get castNetworkHint;

  /// No description provided for @castPlayHereOnly.
  ///
  /// In en, this message translates to:
  /// **'Play here only'**
  String get castPlayHereOnly;

  /// No description provided for @bookmarkSaved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark saved'**
  String get bookmarkSaved;

  /// No description provided for @localFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Local file not found: {path}'**
  String localFileNotFound(String path);

  /// No description provided for @resumedFrom.
  ///
  /// In en, this message translates to:
  /// **'Resumed from {time}'**
  String resumedFrom(String time);

  /// No description provided for @sponsorSkipped.
  ///
  /// In en, this message translates to:
  /// **'Sponsor skipped'**
  String get sponsorSkipped;

  /// No description provided for @permissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Permission not granted.'**
  String get permissionNotGranted;

  /// No description provided for @castStopped.
  ///
  /// In en, this message translates to:
  /// **'Casting stopped'**
  String get castStopped;

  /// No description provided for @openingFile.
  ///
  /// In en, this message translates to:
  /// **'Opening file…'**
  String get openingFile;

  /// No description provided for @resolvingStream.
  ///
  /// In en, this message translates to:
  /// **'Resolving stream…'**
  String get resolvingStream;

  /// No description provided for @castFooter.
  ///
  /// In en, this message translates to:
  /// **'Cast · {device}'**
  String castFooter(String device);

  /// No description provided for @castFooterMuted.
  ///
  /// In en, this message translates to:
  /// **'Cast · {device} · muted here'**
  String castFooterMuted(String device);

  /// No description provided for @playerSpeedMenu.
  ///
  /// In en, this message translates to:
  /// **'Speed ({rate})'**
  String playerSpeedMenu(String rate);

  /// No description provided for @chaptersAndBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Chapters and bookmarks'**
  String get chaptersAndBookmarks;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get addBookmark;

  /// No description provided for @castedTo.
  ///
  /// In en, this message translates to:
  /// **'Casting to {device}'**
  String castedTo(String device);

  /// No description provided for @castToDevice.
  ///
  /// In en, this message translates to:
  /// **'Cast to device'**
  String get castToDevice;

  /// No description provided for @markUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Mark unwatched'**
  String get markUnwatched;

  /// No description provided for @markWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark watched'**
  String get markWatched;

  /// No description provided for @removeFromWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Remove from Watch later'**
  String get removeFromWatchLater;

  /// No description provided for @openOnYouTubeWithKey.
  ///
  /// In en, this message translates to:
  /// **'Open on YouTube (O)'**
  String get openOnYouTubeWithKey;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @markedWatched.
  ///
  /// In en, this message translates to:
  /// **'Marked as watched'**
  String get markedWatched;

  /// No description provided for @markedUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Marked as unwatched'**
  String get markedUnwatched;

  /// No description provided for @addedToWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Added to Watch later'**
  String get addedToWatchLater;

  /// No description provided for @removedFromWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Removed from Watch later'**
  String get removedFromWatchLater;

  /// No description provided for @youtubeVerificationRequired.
  ///
  /// In en, this message translates to:
  /// **'YouTube asked for verification. Open the video on YouTube to watch it.'**
  String get youtubeVerificationRequired;

  /// No description provided for @videoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This video is not available on YouTube.'**
  String get videoUnavailable;

  /// No description provided for @noDownloadableFormat.
  ///
  /// In en, this message translates to:
  /// **'No downloadable format is available for this video.'**
  String get noDownloadableFormat;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this video. Try again or open it on YouTube.'**
  String get playbackFailed;

  /// No description provided for @playerErrorFileTitle.
  ///
  /// In en, this message translates to:
  /// **'File unavailable'**
  String get playerErrorFileTitle;

  /// No description provided for @playerErrorStreamTitle.
  ///
  /// In en, this message translates to:
  /// **'Stream unavailable'**
  String get playerErrorStreamTitle;

  /// No description provided for @technicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get technicalDetails;

  /// No description provided for @sponsorBlockSegments.
  ///
  /// In en, this message translates to:
  /// **'SponsorBlock · {count} segments'**
  String sponsorBlockSegments(int count);

  /// No description provided for @sponsorBlockCount.
  ///
  /// In en, this message translates to:
  /// **'SponsorBlock · {count}'**
  String sponsorBlockCount(int count);

  /// No description provided for @sponsorBlockActive.
  ///
  /// In en, this message translates to:
  /// **'SponsorBlock active'**
  String get sponsorBlockActive;

  /// No description provided for @seekBack10.
  ///
  /// In en, this message translates to:
  /// **'Back 10 s'**
  String get seekBack10;

  /// No description provided for @seekForward10.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 s'**
  String get seekForward10;

  /// No description provided for @seekBack10Key.
  ///
  /// In en, this message translates to:
  /// **'Back 10 s (←)'**
  String get seekBack10Key;

  /// No description provided for @seekForward10Key.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 s (→)'**
  String get seekForward10Key;

  /// No description provided for @offlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineLabel;

  /// No description provided for @localFileMp4.
  ///
  /// In en, this message translates to:
  /// **'Local file · MP4'**
  String get localFileMp4;

  /// No description provided for @offlineMp4.
  ///
  /// In en, this message translates to:
  /// **'Offline · MP4'**
  String get offlineMp4;

  /// No description provided for @directStreamQuality.
  ///
  /// In en, this message translates to:
  /// **'Direct stream · {quality}'**
  String directStreamQuality(String quality);

  /// No description provided for @bookmarkAt.
  ///
  /// In en, this message translates to:
  /// **'Bookmark at {time}'**
  String bookmarkAt(String time);

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks. Add a note at the current position.'**
  String get noBookmarks;

  /// No description provided for @deleteBookmark.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark'**
  String get deleteBookmark;

  /// No description provided for @bookmarkDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmarkDialogTitle;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Personal note…'**
  String get noteHint;

  /// No description provided for @tabVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get tabVideos;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @channelSummary.
  ///
  /// In en, this message translates to:
  /// **'{videos} · {lastSync}'**
  String channelSummary(String videos, String lastSync);

  /// No description provided for @channelMutedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · RSS muted'**
  String get channelMutedSuffix;

  /// No description provided for @channelHiddenSuffix.
  ///
  /// In en, this message translates to:
  /// **' · hidden from new'**
  String get channelHiddenSuffix;

  /// No description provided for @refreshOnlyChannel.
  ///
  /// In en, this message translates to:
  /// **'Refresh only this channel'**
  String get refreshOnlyChannel;

  /// No description provided for @loadingTags.
  ///
  /// In en, this message translates to:
  /// **'Loading tags…'**
  String get loadingTags;

  /// No description provided for @searchChannelHint.
  ///
  /// In en, this message translates to:
  /// **'Search this channel, including tags…'**
  String get searchChannelHint;

  /// No description provided for @muteRssTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute RSS: no new videos will be suggested. Archive and history remain available.'**
  String get muteRssTooltip;

  /// No description provided for @unmuteRssTooltip.
  ///
  /// In en, this message translates to:
  /// **'Turn RSS back on: new videos will be suggested again.'**
  String get unmuteRssTooltip;

  /// No description provided for @rssMuted.
  ///
  /// In en, this message translates to:
  /// **'RSS muted'**
  String get rssMuted;

  /// No description provided for @muteRss.
  ///
  /// In en, this message translates to:
  /// **'Mute RSS'**
  String get muteRss;

  /// No description provided for @hideFromLatestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide this channel’s latest video from the new list.'**
  String get hideFromLatestTooltip;

  /// No description provided for @showInLatestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show this channel’s latest video in the new list.'**
  String get showInLatestTooltip;

  /// No description provided for @showInLatest.
  ///
  /// In en, this message translates to:
  /// **'Show in new'**
  String get showInLatest;

  /// No description provided for @defaultRateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Default speed when you open this channel’s videos.'**
  String get defaultRateTooltip;

  /// No description provided for @channelRateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Channel default speed'**
  String get channelRateTooltip;

  /// No description provided for @global.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get global;

  /// No description provided for @globalRate.
  ///
  /// In en, this message translates to:
  /// **'Global speed'**
  String get globalRate;

  /// No description provided for @channelRate.
  ///
  /// In en, this message translates to:
  /// **'Speed {rate}'**
  String channelRate(String rate);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Unwatched'**
  String get filterUnwatched;

  /// No description provided for @filterWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get filterWatched;

  /// No description provided for @filterWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Watch later'**
  String get filterWatchLater;

  /// No description provided for @emptyMutedTitle.
  ///
  /// In en, this message translates to:
  /// **'RSS muted'**
  String get emptyMutedTitle;

  /// No description provided for @emptyMutedBody.
  ///
  /// In en, this message translates to:
  /// **'New videos are not suggested. Turn RSS back on from the button above to see them.'**
  String get emptyMutedBody;

  /// No description provided for @emptyChannelVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'No videos'**
  String get emptyChannelVideosTitle;

  /// No description provided for @emptyChannelVideosBody.
  ///
  /// In en, this message translates to:
  /// **'This channel has no videos in the current RSS feed.'**
  String get emptyChannelVideosBody;

  /// No description provided for @emptyFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get emptyFilterTitle;

  /// No description provided for @emptyFilterBody.
  ///
  /// In en, this message translates to:
  /// **'No videos match the filter or search term.'**
  String get emptyFilterBody;

  /// No description provided for @emptyHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History is empty'**
  String get emptyHistoryTitle;

  /// No description provided for @emptyHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Videos you open or mark as watched will appear here.'**
  String get emptyHistoryBody;

  /// No description provided for @emptyHistorySearchBody.
  ///
  /// In en, this message translates to:
  /// **'No history videos match the search term.'**
  String get emptyHistorySearchBody;

  /// No description provided for @badgeWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get badgeWatched;

  /// No description provided for @watchAction.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watchAction;

  /// No description provided for @saveOffline.
  ///
  /// In en, this message translates to:
  /// **'Save offline'**
  String get saveOffline;

  /// No description provided for @removeDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get removeDownload;

  /// No description provided for @noChannelsTitle.
  ///
  /// In en, this message translates to:
  /// **'No channels'**
  String get noChannelsTitle;

  /// No description provided for @noChannelsBody.
  ///
  /// In en, this message translates to:
  /// **'Import your subscriptions to get started.'**
  String get noChannelsBody;

  /// No description provided for @deleteChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove channel?'**
  String get deleteChannelTitle;

  /// No description provided for @deleteChannelBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from Expeditus. Saved videos will be deleted.'**
  String deleteChannelBody(String name);

  /// No description provided for @unmuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get unmuteTooltip;

  /// No description provided for @muteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get muteTooltip;

  /// No description provided for @removeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeTooltip;

  /// No description provided for @noChannelFound.
  ///
  /// In en, this message translates to:
  /// **'No channels found for “{query}”.'**
  String noChannelFound(String query);

  /// No description provided for @channelAddedFeedUpdating.
  ///
  /// In en, this message translates to:
  /// **'{name} added. The feed is updating.'**
  String channelAddedFeedUpdating(String name);

  /// No description provided for @channelAddedFeedFailed.
  ///
  /// In en, this message translates to:
  /// **'Channel added, but the feed could not be updated: {error}'**
  String channelAddedFeedFailed(String error);

  /// No description provided for @searchRateLimited.
  ///
  /// In en, this message translates to:
  /// **'YouTube limited the search. Try again shortly.'**
  String get searchRateLimited;

  /// No description provided for @searchChannelPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search for a channel…'**
  String get searchChannelPlaceholder;

  /// No description provided for @searchExplanationPhone.
  ///
  /// In en, this message translates to:
  /// **'Search queries YouTube. Then add the channel with a tap.'**
  String get searchExplanationPhone;

  /// No description provided for @searchExplanationDesktop.
  ///
  /// In en, this message translates to:
  /// **'Search queries YouTube. Then add the channel with a click.'**
  String get searchExplanationDesktop;

  /// No description provided for @searchingChannels.
  ///
  /// In en, this message translates to:
  /// **'Searching channels…'**
  String get searchingChannels;

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type a word and press Search.'**
  String get searchPrompt;

  /// No description provided for @alreadySubscribed.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get alreadySubscribed;

  /// No description provided for @addChannel.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addChannel;

  /// No description provided for @importSubscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Import subscriptions'**
  String get importSubscriptionsTitle;

  /// No description provided for @importIntro.
  ///
  /// In en, this message translates to:
  /// **'No Google login needed. Takeout is the cleanest way: Download data → YouTube → subscriptions.csv.'**
  String get importIntro;

  /// No description provided for @tabTakeout.
  ///
  /// In en, this message translates to:
  /// **'Takeout'**
  String get tabTakeout;

  /// No description provided for @tabPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get tabPaste;

  /// No description provided for @tabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tabSearch;

  /// No description provided for @tabLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get tabLink;

  /// No description provided for @importingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importingEllipsis;

  /// No description provided for @noLoginNote.
  ///
  /// In en, this message translates to:
  /// **'No login. Channel search queries YouTube.'**
  String get noLoginNote;

  /// No description provided for @csvSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select subscriptions.csv'**
  String get csvSelectTitle;

  /// No description provided for @csvSelectBody.
  ///
  /// In en, this message translates to:
  /// **'The file Google prepares in Takeout contains the ID, URL and name of each channel.'**
  String get csvSelectBody;

  /// No description provided for @chooseCsvFile.
  ///
  /// In en, this message translates to:
  /// **'Choose CSV file'**
  String get chooseCsvFile;

  /// No description provided for @pasteInstructions.
  ///
  /// In en, this message translates to:
  /// **'One channel per line: handle, URL or ID.'**
  String get pasteInstructions;

  /// No description provided for @importButton.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importButton;

  /// No description provided for @importStatusResolvingChannels.
  ///
  /// In en, this message translates to:
  /// **'Resolving channels…'**
  String get importStatusResolvingChannels;

  /// No description provided for @importStatusResolvingProgress.
  ///
  /// In en, this message translates to:
  /// **'Resolving {current}/{total}…'**
  String importStatusResolvingProgress(int current, int total);

  /// No description provided for @importStatusImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importStatusImporting;

  /// No description provided for @videoLinkIntro.
  ///
  /// In en, this message translates to:
  /// **'Paste a YouTube video link. Expeditus finds the channel, subscribes automatically, and saves the video to Watch later.'**
  String get videoLinkIntro;

  /// No description provided for @videoLinkAdded.
  ///
  /// In en, this message translates to:
  /// **'Added “{video}” and subscribed to {channel}. The video is in Watch later.'**
  String videoLinkAdded(String video, String channel);

  /// No description provided for @addAndSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Add and subscribe'**
  String get addAndSubscribe;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome.'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Search for a channel by name to get started. You can also paste a channel or video link, or import subscriptions from Google Takeout.'**
  String get welcomeBody;

  /// No description provided for @welcomePhilosophy.
  ///
  /// In en, this message translates to:
  /// **'Expeditus shows only the latest video from each channel: no recommendations, no autoplay, no noise.'**
  String get welcomePhilosophy;

  /// No description provided for @welcomeImportTakeout.
  ///
  /// In en, this message translates to:
  /// **'Import from Google Takeout'**
  String get welcomeImportTakeout;

  /// No description provided for @welcomeAddVideoLink.
  ///
  /// In en, this message translates to:
  /// **'Add a video from a link'**
  String get welcomeAddVideoLink;

  /// No description provided for @welcomeSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get welcomeSkip;

  /// No description provided for @welcomeSearchHeading.
  ///
  /// In en, this message translates to:
  /// **'Search for a channel'**
  String get welcomeSearchHeading;

  /// No description provided for @welcomeSearchHeadingCompact.
  ///
  /// In en, this message translates to:
  /// **'Or search for a channel'**
  String get welcomeSearchHeadingCompact;

  /// No description provided for @updatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesTitle;

  /// No description provided for @installedVersion.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installedVersion;

  /// No description provided for @availableVersion.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableVersion;

  /// No description provided for @latestRelease.
  ///
  /// In en, this message translates to:
  /// **'Latest release'**
  String get latestRelease;

  /// No description provided for @downloadInstaller.
  ///
  /// In en, this message translates to:
  /// **'Download installer'**
  String get downloadInstaller;

  /// No description provided for @openRelease.
  ///
  /// In en, this message translates to:
  /// **'Open release'**
  String get openRelease;

  /// No description provided for @checkNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get checkNow;

  /// No description provided for @skipVersion.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get skipVersion;

  /// No description provided for @releasePage.
  ///
  /// In en, this message translates to:
  /// **'Release page'**
  String get releasePage;

  /// No description provided for @installerNote.
  ///
  /// In en, this message translates to:
  /// **'After downloading, close Expeditus and run the installer.'**
  String get installerNote;

  /// No description provided for @releasePageNote.
  ///
  /// In en, this message translates to:
  /// **'Open the release page to download the latest version.'**
  String get releasePageNote;

  /// No description provided for @skippedVersion.
  ///
  /// In en, this message translates to:
  /// **'You skipped version {version}. The next release will be offered.'**
  String skippedVersion(String version);

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @notCheckedTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent check. Check now for a new version.'**
  String get notCheckedTitle;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Expeditus is up to date.'**
  String get upToDate;

  /// No description provided for @upToDateCached.
  ///
  /// In en, this message translates to:
  /// **'Expeditus is up to date (cached data).'**
  String get upToDateCached;

  /// No description provided for @lastCheckNever.
  ///
  /// In en, this message translates to:
  /// **'Never checked'**
  String get lastCheckNever;

  /// No description provided for @lastCheck.
  ///
  /// In en, this message translates to:
  /// **'Last check: {relative}'**
  String lastCheck(String relative);

  /// No description provided for @lastCheckCached.
  ///
  /// In en, this message translates to:
  /// **'Last check: {relative} · cached data'**
  String lastCheckCached(String relative);

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed.'**
  String get updateCheckFailed;

  /// No description provided for @updateCheckFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Update check failed: {details}'**
  String updateCheckFailedDetails(String details);

  /// No description provided for @updateStateSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the update state: {details}'**
  String updateStateSaveFailed(String details);

  /// No description provided for @updateSkipSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the skipped version: {details}'**
  String updateSkipSaveFailed(String details);

  /// No description provided for @updateRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the skipped version: {details}'**
  String updateRestoreFailed(String details);

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'Expeditus could not start'**
  String get startupFailed;

  /// No description provided for @detailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details:'**
  String get detailsLabel;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get removeFromList;

  /// No description provided for @castConnectFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to {device}: {details}'**
  String castConnectFailedDetails(String device, String details);

  /// No description provided for @castSendFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not send to {device}: {details}'**
  String castSendFailedDetails(String device, String details);

  /// No description provided for @castActionFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Device action failed: {details}'**
  String castActionFailedDetails(String details);

  /// No description provided for @castDiscoveryFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Device search failed: {details}'**
  String castDiscoveryFailedDetails(String details);

  /// No description provided for @castUnresponsive.
  ///
  /// In en, this message translates to:
  /// **'The device is no longer responding. Check that it is still on and on the same network.'**
  String get castUnresponsive;

  /// No description provided for @castFirewallDenied.
  ///
  /// In en, this message translates to:
  /// **'Network access not granted. Add an inbound rule for Expeditus in Windows Firewall.'**
  String get castFirewallDenied;

  /// No description provided for @castNetworkProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the network type. Open Settings > Network & Internet and set the network to “Private”.'**
  String get castNetworkProfileFailed;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not contact the update server. Check your connection and try again.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many update requests. Try again later.'**
  String get updateErrorRateLimited;

  /// No description provided for @updateErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The update server refused the request.'**
  String get updateErrorUnauthorized;

  /// No description provided for @updateErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'No release found. The repository may not have any published releases yet.'**
  String get updateErrorNotFound;

  /// No description provided for @updateErrorInvalidFeed.
  ///
  /// In en, this message translates to:
  /// **'The update server returned an invalid response.'**
  String get updateErrorInvalidFeed;

  /// No description provided for @updateErrorServer.
  ///
  /// In en, this message translates to:
  /// **'The update server returned an error ({status}).'**
  String updateErrorServer(String status);

  /// No description provided for @localVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Local video'**
  String get localVideoLabel;

  /// No description provided for @channelsNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 channel not updated} other{{count} channels not updated}}'**
  String channelsNotUpdated(int count);

  /// No description provided for @audioOnlyQuality.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get audioOnlyQuality;

  /// No description provided for @castDiscoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Device search failed.'**
  String get castDiscoveryFailed;

  /// No description provided for @castActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Device action failed.'**
  String get castActionFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
