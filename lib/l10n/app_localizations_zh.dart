// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get about => '关于';

  @override
  String get all => '全部';

  @override
  String get app => '应用';

  @override
  String get appId => '应用 ID';

  @override
  String get appIntroduction => '应用介绍';

  @override
  String get appType => '应用类型';

  @override
  String get appStoreLoadFailed => '加载应用商店失败';

  @override
  String get back => '返回';

  @override
  String get backToSearchHistory => '返回搜索历史';

  @override
  String get cancel => '取消';

  @override
  String get changeLog => '更新日志';

  @override
  String get changeLogLoadFailed => '无法加载更新日志';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkingForUpdates => '正在检查...';

  @override
  String get clearKeyLog => '清空日志';

  @override
  String get clearSearchHistory => '清除搜索历史';

  @override
  String get close => '关闭';

  @override
  String get collapseFilters => '收起筛选';

  @override
  String get confirm => '确定';

  @override
  String get copyKeyLog => '复制日志';

  @override
  String get currentPlatformUpdateUnsupported => '当前平台暂不支持应用内更新';

  @override
  String get currentVersion => '当前版本';

  @override
  String get darkMode => '深色模式';

  @override
  String get darkModeFollowSystem => '深色跟随系统';

  @override
  String get darkModeSettings => '深色设置';

  @override
  String get debug => '调试';

  @override
  String get delete => '删除';

  @override
  String get deleteFailed => '删除失败';

  @override
  String deleteFileQuestion(String name) {
    return '删除 $name？';
  }

  @override
  String get deleteFileWarning => '将会同步删除文件！';

  @override
  String get defaultSort => '默认排序';

  @override
  String get description => '描述';

  @override
  String get details => '查看详情';

  @override
  String get directionalKeys => '方向键';

  @override
  String get directionalJoystick => '方向摇杆';

  @override
  String get downloadAndRun => '下载并运行';

  @override
  String get downloadCompleteOpening => '下载完成，正在打开';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get downloadNotificationDescription => '开启通知后，下载进度会显示在通知栏';

  @override
  String get downloadedOpening => '已下载，正在打开';

  @override
  String get downloading => '正在下载';

  @override
  String downloadingProgress(int percent) {
    return '正在下载 $percent%';
  }

  @override
  String get emulatorSettings => '模拟器设置';

  @override
  String get emptyStore => '暂无内容';

  @override
  String get enableNotifications => '开启通知';

  @override
  String get enterFullscreen => '进入全屏';

  @override
  String get expandFilters => '展开筛选';

  @override
  String get exitFullscreen => '退出全屏';

  @override
  String fileDeleted(String name) {
    return '已删除文件：$name';
  }

  @override
  String get fileHeaderName => '包内文件名';

  @override
  String get fileName => '文件名';

  @override
  String fileNotFoundRemoved(String name) {
    return '文件不存在，已从列表移除：$name';
  }

  @override
  String get fullKeypad => '全键';

  @override
  String get game => '游戏';

  @override
  String get goEnable => '去开启';

  @override
  String get imageProcessingMode => '图像处理方式';

  @override
  String imageProcessingModeValue(String mode) {
    return '图像处理方式: $mode';
  }

  @override
  String get importMrpFile => '导入 MRP 文件';

  @override
  String get input => '输入';

  @override
  String get installerOpened => '已打开安装程序';

  @override
  String joinedAt(String date) {
    return '加入时间 $date';
  }

  @override
  String get joinedTime => '加入时间';

  @override
  String get joystick => '摇杆';

  @override
  String get keyLogCopied => '按键日志已复制';

  @override
  String get keyTest => '按键测试';

  @override
  String get keyTestDescription => '记录物理按键和左右软键映射';

  @override
  String get latest => '最新';

  @override
  String latestVersion(String version) {
    return '最新版本 $version';
  }

  @override
  String get left => '左';

  @override
  String get leftSoftKey => '左软键';

  @override
  String get loadMoreFailed => '加载下一页失败';

  @override
  String get local => '本地';

  @override
  String get memorySize => '内存大小';

  @override
  String get memorySizeDescription => '应用可见内存，下次启动应用时生效';

  @override
  String get more => '更多';

  @override
  String get mrpDirectoryNotReady => 'MRP 目录还没有准备好';

  @override
  String get mrpHeader => 'MRP 头';

  @override
  String get newVersionAvailable => '发现新版本';

  @override
  String newVersionAvailableWithVersion(String version) {
    return '发现新版本 $version';
  }

  @override
  String get noKeypad => '无键盘';

  @override
  String get noMrpFiles => '没有 MRP 文件，点击右上角按钮导入';

  @override
  String get noSearchResults => '没有找到相关应用或游戏';

  @override
  String get noVersionsAvailable => '暂无可用版本';

  @override
  String get newest => '新发布';

  @override
  String get notRecognized => '未识别';

  @override
  String get numericKeypad => '9键';

  @override
  String get openGitHubFailed => '无法打开 GitHub';

  @override
  String get path => '路径';

  @override
  String get mostDownloaded => '下载多';

  @override
  String get pressPhysicalKeyForLog => '按下物理按键后，这里会显示日志';

  @override
  String publishedAt(String date) {
    return '发布于 $date';
  }

  @override
  String get releaseDate => '发布时间';

  @override
  String get resolution => '分辨率';

  @override
  String get retry => '重试';

  @override
  String get right => '右';

  @override
  String get rightSoftKey => '右软键';

  @override
  String get search => '搜索';

  @override
  String get searchAppsHint => '搜索软件或游戏';

  @override
  String get searchFailed => '搜索失败';

  @override
  String get searchHistory => '搜索历史';

  @override
  String get searchResults => '搜索结果';

  @override
  String get settings => '设置';

  @override
  String get software => '软件';

  @override
  String get sort => '排序';

  @override
  String get store => '商店';

  @override
  String get switchImageProcessingMode => '图像处理方式';

  @override
  String get switchKeypad => '切换键盘';

  @override
  String get switchResolution => '切换分辨率';

  @override
  String get switchToDarkMode => '切换到深色模式';

  @override
  String get switchToLightMode => '切换到浅色模式';

  @override
  String get themeFollowSystemDisabled => '切换成功，关闭了深色跟随系统';

  @override
  String get unknownManufacturer => '未知厂商';

  @override
  String get up => '上';

  @override
  String get upToDate => '已是最新版本';

  @override
  String get update => '更新';

  @override
  String get updateCheckFailed => '检查更新失败，请稍后重试';

  @override
  String get updateDownloadPrompt => '是否下载并安装更新？';

  @override
  String get updateFailed => '更新失败';

  @override
  String get valid => '有效';

  @override
  String get vendor => '厂商';

  @override
  String get versionAndResolution => '版本与分辨率';

  @override
  String get versionInfoUnavailable => '版本信息不可用';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get versionLoadFailed => '版本加载失败';

  @override
  String get versionNumber => '版本号';

  @override
  String get versionReading => '正在读取版本...';

  @override
  String get waitForKey => '等待按键';

  @override
  String get updateLater => '稍后';

  @override
  String get goToNotificationSettings => '去开启';

  @override
  String get allowInstallThenContinue => '允许后会自动继续安装';

  @override
  String get storeEndReached => '已经到底了';

  @override
  String get down => '下';
}
