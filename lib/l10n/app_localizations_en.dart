// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get all => 'All';

  @override
  String get app => 'App';

  @override
  String get appId => 'App ID';

  @override
  String get appIntroduction => 'Description';

  @override
  String get appType => 'App type';

  @override
  String get appStoreLoadFailed => 'Failed to load the app store';

  @override
  String get back => 'Back';

  @override
  String get backToSearchHistory => 'Back to search history';

  @override
  String get cancel => 'Cancel';

  @override
  String get changeLog => 'Changelog';

  @override
  String get changeLogLoadFailed => 'Unable to load the changelog';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking...';

  @override
  String get clearKeyLog => 'Clear log';

  @override
  String get clearSearchHistory => 'Clear search history';

  @override
  String get close => 'Close';

  @override
  String get collapseFilters => 'Collapse filters';

  @override
  String get confirm => 'OK';

  @override
  String get copyKeyLog => 'Copy log';

  @override
  String get currentPlatformUpdateUnsupported =>
      'In-app updates are not supported on this platform';

  @override
  String get currentVersion => 'Current version';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get darkModeFollowSystem => 'Follow system appearance';

  @override
  String get darkModeSettings => 'Appearance';

  @override
  String get debug => 'Debug';

  @override
  String get delete => 'Delete';

  @override
  String get deleteFailed => 'Failed to delete the file';

  @override
  String deleteFileQuestion(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteFileWarning => 'The file will also be deleted.';

  @override
  String get defaultSort => 'Default order';

  @override
  String get description => 'Description';

  @override
  String get details => 'View details';

  @override
  String get directionalKeys => 'D-pad';

  @override
  String get directionalJoystick => 'Directional joystick';

  @override
  String get downloadAndRun => 'Download and run';

  @override
  String get downloadCompleteOpening => 'Download complete. Opening...';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String downloadCount(int count) {
    return '$count downloads';
  }

  @override
  String get downloadNotificationDescription =>
      'Download progress will appear in notifications once notifications are enabled';

  @override
  String get downloadedOpening => 'Already downloaded. Opening...';

  @override
  String get downloading => 'Downloading';

  @override
  String downloadingProgress(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get emulatorSettings => 'Emulator settings';

  @override
  String get emptyStore => 'No content available';

  @override
  String get enableNotifications => 'Enable notifications';

  @override
  String get enterFullscreen => 'Enter fullscreen';

  @override
  String get expandFilters => 'Expand filters';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String fileDeleted(String name) {
    return 'File deleted: $name';
  }

  @override
  String get fileHeaderName => 'Package file name';

  @override
  String get fileName => 'File name';

  @override
  String fileNotFoundRemoved(String name) {
    return 'File not found and removed from the list: $name';
  }

  @override
  String get fullKeypad => 'Full keypad';

  @override
  String get game => 'Games';

  @override
  String get goEnable => 'Open settings';

  @override
  String get imageProcessingMode => 'Image processing';

  @override
  String imageProcessingModeValue(String mode) {
    return 'Image processing: $mode';
  }

  @override
  String get importMrpFile => 'Import MRP file';

  @override
  String get input => 'Input';

  @override
  String get installerOpened => 'Installer opened';

  @override
  String joinedAt(String date) {
    return 'Added $date';
  }

  @override
  String get joinedTime => 'Added';

  @override
  String get joystick => 'Joystick';

  @override
  String get keyLogCopied => 'Key log copied';

  @override
  String get keyTest => 'Key test';

  @override
  String get keyTestDescription => 'Record physical keys and soft-key mappings';

  @override
  String get latest => 'Latest';

  @override
  String latestVersion(String version) {
    return 'Latest version $version';
  }

  @override
  String get left => 'Left';

  @override
  String get leftSoftKey => 'Left soft key';

  @override
  String get loadMoreFailed => 'Failed to load the next page';

  @override
  String get local => 'Local';

  @override
  String get memorySize => 'Memory size';

  @override
  String get memorySizeDescription =>
      'Memory visible to apps; takes effect the next time an app starts';

  @override
  String get more => 'More';

  @override
  String get mrpDirectoryNotReady => 'The MRP directory is not ready yet';

  @override
  String get mrpHeader => 'MRP header';

  @override
  String get newVersionAvailable => 'New version available';

  @override
  String newVersionAvailableWithVersion(String version) {
    return 'New version $version available';
  }

  @override
  String get noKeypad => 'No keypad';

  @override
  String get noMrpFiles =>
      'No MRP files. Use the button at the top right to import one.';

  @override
  String get noSearchResults => 'No matching apps or games found';

  @override
  String get noVersionsAvailable => 'No versions available';

  @override
  String get newest => 'Newest';

  @override
  String get notRecognized => 'Not recognized';

  @override
  String get numericKeypad => '9-key keypad';

  @override
  String get openGitHubFailed => 'Unable to open GitHub';

  @override
  String get path => 'Path';

  @override
  String get mostDownloaded => 'Most downloaded';

  @override
  String get pressPhysicalKeyForLog =>
      'Press a physical key to show its log here';

  @override
  String publishedAt(String date) {
    return 'Published $date';
  }

  @override
  String get releaseDate => 'Release date';

  @override
  String get resolution => 'Resolution';

  @override
  String get retry => 'Retry';

  @override
  String get right => 'Right';

  @override
  String get rightSoftKey => 'Right soft key';

  @override
  String get search => 'Search';

  @override
  String get searchAppsHint => 'Search apps or games';

  @override
  String get searchFailed => 'Search failed';

  @override
  String get searchHistory => 'Search history';

  @override
  String get searchResults => 'Search results';

  @override
  String get settings => 'Settings';

  @override
  String get software => 'Software';

  @override
  String get sort => 'Sort';

  @override
  String get store => 'Store';

  @override
  String get switchImageProcessingMode => 'Image processing';

  @override
  String get switchKeypad => 'Switch keypad';

  @override
  String get switchResolution => 'Switch resolution';

  @override
  String get switchToDarkMode => 'Switch to dark mode';

  @override
  String get switchToLightMode => 'Switch to light mode';

  @override
  String get themeFollowSystemDisabled =>
      'Theme changed and system appearance following was turned off';

  @override
  String get unknownManufacturer => 'Unknown manufacturer';

  @override
  String get up => 'Up';

  @override
  String get upToDate => 'You are up to date';

  @override
  String get update => 'Update';

  @override
  String get updateCheckFailed =>
      'Unable to check for updates. Try again later.';

  @override
  String get updateDownloadPrompt => 'Download and install the update?';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get valid => 'Valid';

  @override
  String get vendor => 'Vendor';

  @override
  String get versionAndResolution => 'Version and resolution';

  @override
  String get versionInfoUnavailable => 'Version information unavailable';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get versionLoadFailed => 'Failed to load versions';

  @override
  String get versionNumber => 'Version';

  @override
  String get versionReading => 'Reading version...';

  @override
  String get waitForKey => 'Waiting for a key';

  @override
  String get updateLater => 'Later';

  @override
  String get goToNotificationSettings => 'Open settings';

  @override
  String get allowInstallThenContinue =>
      'Installation will continue after permission is granted';

  @override
  String get storeEndReached => 'You\'ve reached the end';

  @override
  String get down => 'Down';
}
