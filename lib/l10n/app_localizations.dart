import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @app.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get app;

  /// No description provided for @appId.
  ///
  /// In en, this message translates to:
  /// **'App ID'**
  String get appId;

  /// No description provided for @appIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get appIntroduction;

  /// No description provided for @appType.
  ///
  /// In en, this message translates to:
  /// **'App type'**
  String get appType;

  /// No description provided for @appStoreLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the app store'**
  String get appStoreLoadFailed;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backToSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Back to search history'**
  String get backToSearchHistory;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @changeLog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changeLog;

  /// No description provided for @changeLogLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the changelog'**
  String get changeLogLoadFailed;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checkingForUpdates;

  /// No description provided for @clearKeyLog.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get clearKeyLog;

  /// No description provided for @clearSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get clearSearchHistory;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @collapseFilters.
  ///
  /// In en, this message translates to:
  /// **'Collapse filters'**
  String get collapseFilters;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get confirm;

  /// No description provided for @copyKeyLog.
  ///
  /// In en, this message translates to:
  /// **'Copy log'**
  String get copyKeyLog;

  /// No description provided for @currentPlatformUpdateUnsupported.
  ///
  /// In en, this message translates to:
  /// **'In-app updates are not supported on this platform'**
  String get currentPlatformUpdateUnsupported;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get currentVersion;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @darkModeFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system appearance'**
  String get darkModeFollowSystem;

  /// No description provided for @darkModeSettings.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get darkModeSettings;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the file'**
  String get deleteFailed;

  /// No description provided for @deleteFileQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteFileQuestion(String name);

  /// No description provided for @deleteFileWarning.
  ///
  /// In en, this message translates to:
  /// **'The file will also be deleted.'**
  String get deleteFileWarning;

  /// No description provided for @defaultSort.
  ///
  /// In en, this message translates to:
  /// **'Default order'**
  String get defaultSort;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get details;

  /// No description provided for @directionalKeys.
  ///
  /// In en, this message translates to:
  /// **'D-pad'**
  String get directionalKeys;

  /// No description provided for @directionalJoystick.
  ///
  /// In en, this message translates to:
  /// **'Directional joystick'**
  String get directionalJoystick;

  /// No description provided for @downloadAndRun.
  ///
  /// In en, this message translates to:
  /// **'Download and run'**
  String get downloadAndRun;

  /// No description provided for @downloadCompleteOpening.
  ///
  /// In en, this message translates to:
  /// **'Download complete. Opening...'**
  String get downloadCompleteOpening;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @downloadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} downloads'**
  String downloadCount(int count);

  /// No description provided for @downloadNotificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Download progress will appear in notifications once notifications are enabled'**
  String get downloadNotificationDescription;

  /// No description provided for @downloadedOpening.
  ///
  /// In en, this message translates to:
  /// **'Already downloaded. Opening...'**
  String get downloadedOpening;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// No description provided for @downloadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String downloadingProgress(int percent);

  /// No description provided for @emulatorSettings.
  ///
  /// In en, this message translates to:
  /// **'Emulator settings'**
  String get emulatorSettings;

  /// No description provided for @emptyStore.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get emptyStore;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get enableNotifications;

  /// No description provided for @enterFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Enter fullscreen'**
  String get enterFullscreen;

  /// No description provided for @expandFilters.
  ///
  /// In en, this message translates to:
  /// **'Expand filters'**
  String get expandFilters;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get exitFullscreen;

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted: {name}'**
  String fileDeleted(String name);

  /// No description provided for @fileHeaderName.
  ///
  /// In en, this message translates to:
  /// **'Package file name'**
  String get fileHeaderName;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// No description provided for @fileNotFoundRemoved.
  ///
  /// In en, this message translates to:
  /// **'File not found and removed from the list: {name}'**
  String fileNotFoundRemoved(String name);

  /// No description provided for @fullKeypad.
  ///
  /// In en, this message translates to:
  /// **'Full keypad'**
  String get fullKeypad;

  /// No description provided for @game.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get game;

  /// No description provided for @goEnable.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get goEnable;

  /// No description provided for @imageProcessingMode.
  ///
  /// In en, this message translates to:
  /// **'Image processing'**
  String get imageProcessingMode;

  /// No description provided for @imageProcessingModeValue.
  ///
  /// In en, this message translates to:
  /// **'Image processing: {mode}'**
  String imageProcessingModeValue(String mode);

  /// No description provided for @importMrpFile.
  ///
  /// In en, this message translates to:
  /// **'Import MRP file'**
  String get importMrpFile;

  /// No description provided for @input.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get input;

  /// No description provided for @installerOpened.
  ///
  /// In en, this message translates to:
  /// **'Installer opened'**
  String get installerOpened;

  /// No description provided for @joinedAt.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String joinedAt(String date);

  /// No description provided for @joinedTime.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get joinedTime;

  /// No description provided for @joystick.
  ///
  /// In en, this message translates to:
  /// **'Joystick'**
  String get joystick;

  /// No description provided for @keyLogCopied.
  ///
  /// In en, this message translates to:
  /// **'Key log copied'**
  String get keyLogCopied;

  /// No description provided for @keyTest.
  ///
  /// In en, this message translates to:
  /// **'Key test'**
  String get keyTest;

  /// No description provided for @keyTestDescription.
  ///
  /// In en, this message translates to:
  /// **'Record physical keys and soft-key mappings'**
  String get keyTestDescription;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest version {version}'**
  String latestVersion(String version);

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// No description provided for @leftSoftKey.
  ///
  /// In en, this message translates to:
  /// **'Left soft key'**
  String get leftSoftKey;

  /// No description provided for @loadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the next page'**
  String get loadMoreFailed;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @memorySize.
  ///
  /// In en, this message translates to:
  /// **'Memory size'**
  String get memorySize;

  /// No description provided for @memorySizeDescription.
  ///
  /// In en, this message translates to:
  /// **'Memory visible to apps; takes effect the next time an app starts'**
  String get memorySizeDescription;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @mrpDirectoryNotReady.
  ///
  /// In en, this message translates to:
  /// **'The MRP directory is not ready yet'**
  String get mrpDirectoryNotReady;

  /// No description provided for @mrpHeader.
  ///
  /// In en, this message translates to:
  /// **'MRP header'**
  String get mrpHeader;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get newVersionAvailable;

  /// No description provided for @newVersionAvailableWithVersion.
  ///
  /// In en, this message translates to:
  /// **'New version {version} available'**
  String newVersionAvailableWithVersion(String version);

  /// No description provided for @noKeypad.
  ///
  /// In en, this message translates to:
  /// **'No keypad'**
  String get noKeypad;

  /// No description provided for @noMrpFiles.
  ///
  /// In en, this message translates to:
  /// **'No MRP files. Use the button at the top right to import one.'**
  String get noMrpFiles;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching apps or games found'**
  String get noSearchResults;

  /// No description provided for @noVersionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No versions available'**
  String get noVersionsAvailable;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @notRecognized.
  ///
  /// In en, this message translates to:
  /// **'Not recognized'**
  String get notRecognized;

  /// No description provided for @numericKeypad.
  ///
  /// In en, this message translates to:
  /// **'9-key keypad'**
  String get numericKeypad;

  /// No description provided for @openGitHubFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open GitHub'**
  String get openGitHubFailed;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @mostDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Most downloaded'**
  String get mostDownloaded;

  /// No description provided for @pressPhysicalKeyForLog.
  ///
  /// In en, this message translates to:
  /// **'Press a physical key to show its log here'**
  String get pressPhysicalKeyForLog;

  /// No description provided for @publishedAt.
  ///
  /// In en, this message translates to:
  /// **'Published {date}'**
  String publishedAt(String date);

  /// No description provided for @releaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release date'**
  String get releaseDate;

  /// No description provided for @resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// No description provided for @rightSoftKey.
  ///
  /// In en, this message translates to:
  /// **'Right soft key'**
  String get rightSoftKey;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchAppsHint.
  ///
  /// In en, this message translates to:
  /// **'Search apps or games'**
  String get searchAppsHint;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get searchHistory;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get searchResults;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @software.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get software;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @store.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get store;

  /// No description provided for @switchImageProcessingMode.
  ///
  /// In en, this message translates to:
  /// **'Image processing'**
  String get switchImageProcessingMode;

  /// No description provided for @switchKeypad.
  ///
  /// In en, this message translates to:
  /// **'Switch keypad'**
  String get switchKeypad;

  /// No description provided for @switchResolution.
  ///
  /// In en, this message translates to:
  /// **'Switch resolution'**
  String get switchResolution;

  /// No description provided for @switchToDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get switchToDarkMode;

  /// No description provided for @switchToLightMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get switchToLightMode;

  /// No description provided for @themeFollowSystemDisabled.
  ///
  /// In en, this message translates to:
  /// **'Theme changed and system appearance following was turned off'**
  String get themeFollowSystemDisabled;

  /// No description provided for @unknownManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Unknown manufacturer'**
  String get unknownManufacturer;

  /// No description provided for @up.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get up;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You are up to date'**
  String get upToDate;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to check for updates. Try again later.'**
  String get updateCheckFailed;

  /// No description provided for @updateDownloadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Download and install the update?'**
  String get updateDownloadPrompt;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @valid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get valid;

  /// No description provided for @vendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendor;

  /// No description provided for @versionAndResolution.
  ///
  /// In en, this message translates to:
  /// **'Version and resolution'**
  String get versionAndResolution;

  /// No description provided for @versionInfoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Version information unavailable'**
  String get versionInfoUnavailable;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @versionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load versions'**
  String get versionLoadFailed;

  /// No description provided for @versionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionNumber;

  /// No description provided for @versionReading.
  ///
  /// In en, this message translates to:
  /// **'Reading version...'**
  String get versionReading;

  /// No description provided for @waitForKey.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a key'**
  String get waitForKey;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @goToNotificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get goToNotificationSettings;

  /// No description provided for @allowInstallThenContinue.
  ///
  /// In en, this message translates to:
  /// **'Installation will continue after permission is granted'**
  String get allowInstallThenContinue;

  /// No description provided for @storeEndReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the end'**
  String get storeEndReached;

  /// No description provided for @down.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get down;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
