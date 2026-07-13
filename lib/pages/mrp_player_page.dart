import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/emulator_settings.dart';
import '../services/local_mrp_files.dart';
import '../models/mrp_resolution.dart';
import '../vmrp/vmrp_engine.dart';
import '../vmrp/vmrp_widget.dart';

String runtimeMrpPathForWorkDir(String mrpPath, String workDir) {
  final normalizedMrpPath = mrpPath.replaceAll('\\', '/');
  var normalizedWorkDir = workDir.replaceAll('\\', '/');
  while (normalizedWorkDir.endsWith('/')) {
    normalizedWorkDir = normalizedWorkDir.substring(
      0,
      normalizedWorkDir.length - 1,
    );
  }

  final mrpPathForCompare = Platform.isWindows
      ? normalizedMrpPath.toLowerCase()
      : normalizedMrpPath;
  final workDirForCompare = Platform.isWindows
      ? normalizedWorkDir.toLowerCase()
      : normalizedWorkDir;
  final workDirPrefix = '$workDirForCompare/';

  if (mrpPathForCompare.startsWith(workDirPrefix)) {
    final relativePath = normalizedMrpPath.substring(
      normalizedWorkDir.length + 1,
    );
    if (relativePath.toLowerCase().startsWith('mythroad/')) {
      return relativePath;
    }
  }
  return mrpPath;
}

String mrpPlayerTitleForPath(String mrpPath, {String? title}) {
  final explicitTitle = title?.trim();
  if (explicitTitle != null && explicitTitle.isNotEmpty) {
    return explicitTitle;
  }

  final localFiles = LocalMrpFiles();
  final metadata = localFiles.readMetadata(mrpPath);
  if (metadata.name.isNotEmpty) {
    return metadata.name;
  }
  return fileNameWithoutExtension(localFiles.fileName(mrpPath));
}

enum _KeypadMode { directional, numeric, full, none }

extension on _KeypadMode {
  String get label => switch (this) {
    _KeypadMode.directional => '方向键',
    _KeypadMode.numeric => '9键',
    _KeypadMode.full => '全键',
    _KeypadMode.none => '无键盘',
  };
}

extension on VmrpImageProcessingMode {
  String get label => switch (this) {
    VmrpImageProcessingMode.native => 'Native',
    VmrpImageProcessingMode.opencv => 'OpenCV',
  };
}

class MrpPlayerPage extends StatefulWidget {
  final String mrpPath;
  final String? title;
  final String? dnsMap;
  final int screenWidth;
  final int screenHeight;

  const MrpPlayerPage({
    super.key,
    required this.mrpPath,
    this.title,
    this.dnsMap,
    this.screenWidth = 240,
    this.screenHeight = 320,
  });

  @override
  State<MrpPlayerPage> createState() => _MrpPlayerPageState();
}

enum _PlayerMenuAction {
  toggleFullscreen,
  switchKeyboard,
  switchResolution,
  switchImageProcessing,
}

class _EditTextDialog extends StatefulWidget {
  final String initialText;

  const _EditTextDialog({required this.initialText});

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.multiline,
        minLines: 3,
        maxLines: 8,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _MrpPlayerPageState extends State<MrpPlayerPage> {
  static const MethodChannel _hapticsChannel = MethodChannel(
    'skyengine/haptics',
  );
  static const MethodChannel _hardwareKeysChannel = MethodChannel(
    'skyengine/hardware_keys',
  );
  static const Duration _virtualKeyHapticDebounce = Duration(milliseconds: 80);
  static const double _keypadGap = 18;
  static const double _keypadColumnGap = 18;
  static const double _fullKeypadColumnGap = 8;
  static const double _fullKeypadSectionGap = 18;
  static const double _keypadRowGap = 10;
  static const double _keypadButtonWidth = 84;
  static const double _keypadButtonHeight = 44;
  VmrpEngine? _engine;
  final FocusNode _keyboardFocusNode = FocusNode();
  final Map<PhysicalKeyboardKey, int> _pressedKeyboardKeys = {};
  _KeypadMode _keypadMode = _KeypadMode.directional;
  String? _error;
  bool _exiting = false;
  bool _disposedEngine = false;
  bool _isFullscreen = false;
  late MrpResolution _currentResolution;
  late final String _title;
  VmrpImageProcessingMode _imageProcessingMode = VmrpImageProcessingMode.native;
  DateTime? _lastVirtualKeyHapticAt;

  double get _keypadReservedHeight {
    return switch (_keypadMode) {
      _KeypadMode.directional => _keypadButtonHeight * 3 + _keypadRowGap * 2,
      _KeypadMode.numeric => _keypadButtonHeight * 4 + _keypadRowGap * 3,
      _KeypadMode.full => _keypadButtonHeight * 4 + _keypadRowGap * 3,
      _KeypadMode.none => 0,
    };
  }

  @override
  void initState() {
    super.initState();
    _hardwareKeysChannel.setMethodCallHandler(_handleHardwareKeyCall);
    unawaited(_setHardwareKeyCapture(true));
    _currentResolution = MrpResolution(widget.screenWidth, widget.screenHeight);
    _title = _resolveTitle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _keyboardFocusNode.requestFocus();
      _startEngineAfterRouteTransition();
    });
  }

  // engine.init()/start() are synchronous FFI calls that block the UI thread;
  // starting them before the push transition finishes freezes the animation,
  // so the page first paints its loading state and the engine starts after
  // the route settles.
  void _startEngineAfterRouteTransition() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      Future.delayed(Duration.zero, _startEngine);
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(listener);
        Future.delayed(Duration.zero, _startEngine);
      } else if (status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
      }
    };
    animation.addStatusListener(listener);
  }

  String _resolveTitle() {
    return mrpPlayerTitleForPath(widget.mrpPath, title: widget.title);
  }

  Future<void> _startEngine() async {
    await EmulatorSettings.instance.ensureLoaded();
    if (!mounted || _disposedEngine) {
      return;
    }
    final file = File(widget.mrpPath);
    if (!file.existsSync()) {
      unawaited(_setHardwareKeyCapture(false));
      setState(() => _error = 'MRP file not found:\n${widget.mrpPath}');
      return;
    }

    debugPrint('[VMRP] mrpPath: ${widget.mrpPath}');
    debugPrint('[VMRP] file size: ${file.lengthSync()} bytes');
    final workDir = _workDirForMrp(widget.mrpPath);
    final runtimeMrpPath = runtimeMrpPathForWorkDir(widget.mrpPath, workDir);
    final dnsMap = widget.dnsMap?.trim();
    debugPrint('[VMRP] workDir: $workDir');
    debugPrint('[VMRP] runtimeMrpPath: $runtimeMrpPath');
    debugPrint(
      '[VMRP] dnsMap: '
      '${dnsMap == null || dnsMap.isEmpty ? '(empty)' : dnsMap}',
    );

    final engine = VmrpEngine(
      screenWidth: _currentResolution.width,
      screenHeight: _currentResolution.height,
    );

    final initRet = engine.init();
    debugPrint('[VMRP] init() returned $initRet');
    if (initRet != 0) {
      unawaited(_setHardwareKeyCapture(false));
      setState(() => _error = 'Engine init failed: ${engine.lastError}');
      engine.dispose();
      return;
    }

    final memoryMb = EmulatorSettings.instance.memoryMb;
    final memoryRet = engine.setMemoryMb(memoryMb);
    debugPrint('[VMRP] setMemoryMb($memoryMb) returned $memoryRet');
    if (memoryRet != 0) {
      // 设置失败时引擎沿用默认内存，不阻断启动。
      debugPrint('[VMRP] set memory failed: ${engine.lastError}');
    }

    final imageModeRet = engine.setImageProcessingMode(_imageProcessingMode);
    if (imageModeRet != 0) {
      unawaited(_setHardwareKeyCapture(false));
      setState(
        () => _error = 'Set image processing failed: ${engine.lastError}',
      );
      engine.dispose();
      return;
    }

    final startRet = engine.start(
      runtimeMrpPath,
      workDir: workDir,
      dnsMap: dnsMap,
    );
    debugPrint('[VMRP] start() returned $startRet');
    if (startRet != 0) {
      unawaited(_setHardwareKeyCapture(false));
      setState(() => _error = 'Engine start failed: ${engine.lastError}');
      engine.dispose();
      return;
    }

    engine.onEditRequest.listen((_) {
      if (identical(_engine, engine)) {
        _showEditDialog();
      }
    });
    engine.onExit.listen((_) {
      if (identical(_engine, engine)) {
        _closePlayer();
      }
    });
    setState(() => _engine = engine);
    _keyboardFocusNode.requestFocus();
  }

  String _workDirForMrp(String mrpPath) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return File(Platform.resolvedExecutable).parent.path;
    }

    final mrpParent = File(mrpPath).parent;
    if (mrpParent.path.split(Platform.pathSeparator).last.toLowerCase() ==
        'mythroad') {
      return mrpParent.parent.path;
    }
    return mrpParent.path;
  }

  @override
  void dispose() {
    _hardwareKeysChannel.setMethodCallHandler(null);
    unawaited(_setHardwareKeyCapture(false));
    if (_isFullscreen) {
      unawaited(_setSystemUiFullscreen(false));
    }
    _shutdownEngine();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleHardwareKeyCall(MethodCall call) async {
    final keyCode = call.arguments;
    if (keyCode is! int) {
      return;
    }

    final engine = _engine;
    if (engine == null) {
      return;
    }

    switch (call.method) {
      case 'keyDown':
        engine.sendKeyDown(keyCode);
      case 'keyUp':
        engine.sendKeyUp(keyCode);
    }
  }

  Future<void> _setHardwareKeyCapture(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _hardwareKeysChannel.invokeMethod<void>('setEnabled', enabled);
    } on PlatformException catch (error) {
      debugPrint(
        '[VMRP] hardware key capture failed: '
        '${error.code}, ${error.message}, ${error.details}',
      );
    } on MissingPluginException catch (error) {
      debugPrint('[VMRP] hardware key capture channel missing: $error');
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('[VMRP] hardware key capture failed: $error');
    }
  }

  int? _keyCodeForKeyEvent(KeyEvent event) {
    final character = event.character;
    if (character != null && character.length == 1) {
      final keyCode = _keyCodeForCharacter(character);
      if (keyCode != null) {
        return keyCode;
      }
    }
    return _keyCodeForLogicalKey(event.logicalKey);
  }

  int? _keyCodeForCharacter(String character) {
    return switch (character) {
      '0' => VmrpKey.key0,
      '1' => VmrpKey.key1,
      '2' => VmrpKey.key2,
      '3' => VmrpKey.key3,
      '4' => VmrpKey.key4,
      '5' => VmrpKey.key5,
      '6' => VmrpKey.key6,
      '7' => VmrpKey.key7,
      '8' => VmrpKey.key8,
      '9' => VmrpKey.key9,
      '*' => VmrpKey.star,
      '#' => VmrpKey.pound,
      _ => null,
    };
  }

  int? _keyCodeForLogicalKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      return VmrpKey.up;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      return VmrpKey.down;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      return VmrpKey.left;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      return VmrpKey.right;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return VmrpKey.select;
    }
    if (key == LogicalKeyboardKey.keyQ) {
      return VmrpKey.softLeft;
    }
    if (key == LogicalKeyboardKey.keyE) {
      return VmrpKey.softRight;
    }
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      return VmrpKey.key0;
    }
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      return VmrpKey.key1;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      return VmrpKey.key2;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      return VmrpKey.key3;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      return VmrpKey.key4;
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      return VmrpKey.key5;
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      return VmrpKey.key6;
    }
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      return VmrpKey.key7;
    }
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      return VmrpKey.key8;
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      return VmrpKey.key9;
    }
    if (key == LogicalKeyboardKey.asterisk ||
        key == LogicalKeyboardKey.numpadMultiply) {
      return VmrpKey.star;
    }
    if (key == LogicalKeyboardKey.numberSign) {
      return VmrpKey.pound;
    }
    return null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final engine = _engine;
    if (engine == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      final pressedKeyCode = _pressedKeyboardKeys[event.physicalKey];
      if (pressedKeyCode != null) {
        return KeyEventResult.handled;
      }
      final keyCode = _keyCodeForKeyEvent(event);
      if (keyCode == null) {
        return KeyEventResult.ignored;
      }
      _pressedKeyboardKeys[event.physicalKey] = keyCode;
      engine.sendKeyDown(keyCode);
      return KeyEventResult.handled;
    }

    if (event is KeyRepeatEvent) {
      final keyCode =
          _pressedKeyboardKeys[event.physicalKey] ?? _keyCodeForKeyEvent(event);
      return keyCode == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      final keyCode =
          _pressedKeyboardKeys.remove(event.physicalKey) ??
          _keyCodeForKeyEvent(event);
      if (keyCode == null) {
        return KeyEventResult.ignored;
      }
      engine.sendKeyUp(keyCode);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _releasePressedKeyboardKeys() {
    final engine = _engine;
    if (engine != null) {
      for (final keyCode in _pressedKeyboardKeys.values) {
        engine.sendKeyUp(keyCode);
      }
    }
    _pressedKeyboardKeys.clear();
  }

  void _handleKeyboardFocusChange(bool hasFocus) {
    if (!hasFocus) {
      _releasePressedKeyboardKeys();
    }
  }

  Future<void> _showEditDialog() async {
    _releasePressedKeyboardKeys();
    await _setHardwareKeyCapture(false);
    if (!mounted || _disposedEngine) {
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _EditTextDialog(initialText: _engine?.getEditText() ?? ''),
    );

    if (mounted && !_disposedEngine) {
      unawaited(_setHardwareKeyCapture(true));
      _keyboardFocusNode.requestFocus();
    }

    if (result != null) {
      _engine?.confirmEdit(result);
    } else {
      _engine?.cancelEdit();
    }
  }

  void _closePlayer() {
    if (_exiting || !mounted) return;
    _exiting = true;
    if (_isFullscreen) {
      setState(() => _isFullscreen = false);
      unawaited(_setSystemUiFullscreen(false));
    }
    _shutdownEngine();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _handleBack() {
    if (_exiting || !mounted) {
      return;
    }
    _exiting = true;
    if (_isFullscreen) {
      setState(() => _isFullscreen = false);
      unawaited(_setSystemUiFullscreen(false));
    }
    _shutdownEngine();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _shutdownEngine() {
    if (_disposedEngine) {
      return;
    }
    _disposedEngine = true;
    unawaited(_setHardwareKeyCapture(false));
    _releasePressedKeyboardKeys();
    final engine = _engine;
    _engine = null;
    engine?.dispose();
  }

  void _disposeCurrentEngineForRestart() {
    unawaited(_setHardwareKeyCapture(false));
    _releasePressedKeyboardKeys();
    final engine = _engine;
    _engine = null;
    engine?.dispose();
  }

  void _handleMenuAction(_PlayerMenuAction action) {
    switch (action) {
      case _PlayerMenuAction.toggleFullscreen:
        unawaited(_setFullscreen(!_isFullscreen));
      case _PlayerMenuAction.switchKeyboard:
        unawaited(_showKeyboardDialog());
      case _PlayerMenuAction.switchResolution:
        unawaited(_showResolutionDialog());
      case _PlayerMenuAction.switchImageProcessing:
        unawaited(_showImageProcessingDialog());
    }
  }

  Future<void> _setFullscreen(bool enabled) async {
    if (!mounted || _isFullscreen == enabled) {
      _keyboardFocusNode.requestFocus();
      return;
    }
    setState(() => _isFullscreen = enabled);
    await _setSystemUiFullscreen(enabled);
    if (mounted) {
      _keyboardFocusNode.requestFocus();
    }
  }

  Future<void> _setSystemUiFullscreen(bool enabled) async {
    try {
      if (enabled) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }
    } on PlatformException catch (error) {
      debugPrint(
        '[VMRP] set fullscreen system UI failed: '
        '${error.code}, ${error.message}, ${error.details}',
      );
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('[VMRP] set fullscreen system UI failed: $error');
    }
  }

  Future<void> _showKeyboardDialog() async {
    final selected = await showDialog<_KeypadMode>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('切换键盘'),
          children: [
            for (final mode in _KeypadMode.values)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(mode),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: mode == _keypadMode
                          ? const Icon(Icons.check, size: 20)
                          : null,
                    ),
                    Text(mode.label),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (!mounted || selected == null || selected == _keypadMode) {
      _keyboardFocusNode.requestFocus();
      return;
    }
    setState(() => _keypadMode = selected);
    _keyboardFocusNode.requestFocus();
  }

  List<MrpResolution> get _resolutionOptions {
    if (kCommonMrpResolutions.contains(_currentResolution)) {
      return kCommonMrpResolutions;
    }
    return [_currentResolution, ...kCommonMrpResolutions];
  }

  Future<void> _showResolutionDialog() async {
    final selected = await showDialog<MrpResolution>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('切换分辨率'),
          children: [
            for (final resolution in _resolutionOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(resolution),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: resolution == _currentResolution
                          ? const Icon(Icons.check, size: 20)
                          : null,
                    ),
                    Text(resolution.label),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (!mounted || selected == null || selected == _currentResolution) {
      _keyboardFocusNode.requestFocus();
      return;
    }
    _restartEngineWithResolution(selected);
  }

  void _restartEngineWithResolution(MrpResolution resolution) {
    // vmrp_api_init() owns the screen buffer size, so changing resolution must
    // recreate the engine before start() instead of only resizing the widget.
    _disposeCurrentEngineForRestart();
    setState(() {
      _currentResolution = resolution;
      _error = null;
    });
    unawaited(_setHardwareKeyCapture(true));
    Future.delayed(Duration.zero, _startEngine);
    _keyboardFocusNode.requestFocus();
  }

  Future<void> _showImageProcessingDialog() async {
    final selected = await showDialog<VmrpImageProcessingMode>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('图像处理方式'),
          children: [
            for (final mode in VmrpImageProcessingMode.values)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(mode),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: mode == _imageProcessingMode
                          ? const Icon(Icons.check, size: 20)
                          : null,
                    ),
                    Text(mode.label),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (!mounted || selected == null || selected == _imageProcessingMode) {
      _keyboardFocusNode.requestFocus();
      return;
    }

    final engine = _engine;
    if (engine != null && engine.setImageProcessingMode(selected) != 0) {
      setState(
        () => _error = 'Set image processing failed: ${engine.lastError}',
      );
      _keyboardFocusNode.requestFocus();
      return;
    }

    setState(() => _imageProcessingMode = selected);
    engine?.requestScreenRefresh();
    _keyboardFocusNode.requestFocus();
  }

  Future<void> _vibrateVirtualKey() async {
    final now = DateTime.now();
    final last = _lastVirtualKeyHapticAt;
    if (last != null && now.difference(last) < _virtualKeyHapticDebounce) {
      return;
    }
    if (!Platform.isAndroid) {
      return;
    }
    _lastVirtualKeyHapticAt = now;

    try {
      await _hapticsChannel.invokeMethod<void>('virtualKeyVibrate');
    } on PlatformException catch (error) {
      debugPrint(
        '[VMRP] virtual key vibration failed: '
        '${error.code}, ${error.message}, ${error.details}',
      );
    } on MissingPluginException catch (error) {
      debugPrint('[VMRP] virtual key vibration channel missing: $error');
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('[VMRP] virtual key vibration failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullscreen) {
          unawaited(_setFullscreen(false));
          return;
        }
        if (didPop) {
          _shutdownEngine();
        }
      },
      child: Scaffold(
        appBar: _isFullscreen ? null : _buildAppBar(),
        body: Focus(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          onFocusChange: _handleKeyboardFocusChange,
          child: Stack(
            children: [
              ColoredBox(
                color: _isFullscreen
                    ? Colors.black
                    : Theme.of(context).scaffoldBackgroundColor,
                child: _buildPlayerBody(),
              ),
              if (_isFullscreen) _buildFullscreenExitButton(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_title),
      leading: BackButton(onPressed: _handleBack),
      actions: [
        PopupMenuButton<_PlayerMenuAction>(
          tooltip: '更多',
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuAction,
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                value: _PlayerMenuAction.toggleFullscreen,
                child: Row(
                  children: [
                    Icon(
                      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                    const SizedBox(width: 12),
                    Text(_isFullscreen ? '退出全屏' : '进入全屏'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _PlayerMenuAction.switchKeyboard,
                child: Row(
                  children: [
                    Icon(
                      _keypadMode == _KeypadMode.none
                          ? Icons.keyboard_hide
                          : Icons.keyboard,
                    ),
                    const SizedBox(width: 12),
                    const Text('切换键盘'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _PlayerMenuAction.switchResolution,
                child: Row(
                  children: [
                    Icon(Icons.aspect_ratio),
                    SizedBox(width: 12),
                    Text('切换分辨率'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _PlayerMenuAction.switchImageProcessing,
                child: Row(
                  children: [
                    const Icon(Icons.image),
                    const SizedBox(width: 12),
                    Text('图像处理方式: ${_imageProcessingMode.label}'),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _buildPlayerBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _isFullscreen ? Colors.white : null),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _handleBack, child: const Text('返回')),
            ],
          ),
        ),
      );
    }

    if (_engine == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasVirtualKeypad =
            !_isFullscreen && _keypadMode != _KeypadMode.none;
        final keypadHeight = hasVirtualKeypad ? _keypadReservedHeight : 0.0;
        final gap = hasVirtualKeypad ? _keypadGap : 0.0;
        final maxScreenWidth = constraints.maxWidth;
        final maxScreenHeight = constraints.maxHeight - keypadHeight - gap;
        final maxScale = _isFullscreen ? double.infinity : 2.0;
        final scale = [
          maxScreenWidth / _engine!.screenWidth,
          maxScreenHeight > 0 ? maxScreenHeight / _engine!.screenHeight : 0.1,
          maxScale,
        ].reduce((a, b) => a < b ? a : b);
        final screenWidth = _engine!.screenWidth * scale;
        final screenHeight = _engine!.screenHeight * scale;

        return Align(
          alignment: _isFullscreen ? Alignment.center : Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VmrpWidget(
                engine: _engine!,
                width: screenWidth,
                height: screenHeight,
              ),
              if (hasVirtualKeypad) ...[SizedBox(height: gap), _buildKeypad()],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullscreenExitButton() {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
            child: IconButton(
              tooltip: '退出全屏',
              color: Colors.white,
              icon: const Icon(Icons.fullscreen_exit),
              onPressed: () => unawaited(_setFullscreen(false)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return switch (_keypadMode) {
      _KeypadMode.directional => _buildDirectionalKeypad(),
      _KeypadMode.numeric => _buildNumericKeypad(),
      _KeypadMode.full => _buildFullKeypad(),
      _KeypadMode.none => const SizedBox.shrink(),
    };
  }

  Widget _buildDirectionalKeypad({
    double buttonWidth = _keypadButtonWidth,
    double columnGap = _keypadColumnGap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _keypadRow(
          [
            _keyButton('左软键', VmrpKey.softLeft, width: buttonWidth),
            _keyButton('上', VmrpKey.up, width: buttonWidth),
            _keyButton('右软键', VmrpKey.softRight, width: buttonWidth),
          ],
          columnGap: columnGap,
        ),
        const SizedBox(height: _keypadRowGap),
        _keypadRow(
          [
            _keyButton('左', VmrpKey.left, width: buttonWidth),
            _keyButton('确定', VmrpKey.select, width: buttonWidth),
            _keyButton('右', VmrpKey.right, width: buttonWidth),
          ],
          columnGap: columnGap,
        ),
        const SizedBox(height: _keypadRowGap),
        _keypadRow(
          [
            SizedBox(width: buttonWidth),
            _keyButton('下', VmrpKey.down, width: buttonWidth),
            SizedBox(width: buttonWidth),
          ],
          columnGap: columnGap,
        ),
      ],
    );
  }

  Widget _buildNumericKeypad({
    double buttonWidth = _keypadButtonWidth,
    double columnGap = _keypadColumnGap,
  }) {
    const keys = [
      [('1', VmrpKey.key1), ('2', VmrpKey.key2), ('3', VmrpKey.key3)],
      [('4', VmrpKey.key4), ('5', VmrpKey.key5), ('6', VmrpKey.key6)],
      [('7', VmrpKey.key7), ('8', VmrpKey.key8), ('9', VmrpKey.key9)],
      [('*', VmrpKey.star), ('0', VmrpKey.key0), ('#', VmrpKey.pound)],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in keys) ...[
          _keypadRow(
            [
              for (final key in row)
                _keyButton(key.$1, key.$2, width: buttonWidth),
            ],
            columnGap: columnGap,
          ),
          if (row != keys.last) const SizedBox(height: _keypadRowGap),
        ],
      ],
    );
  }

  Widget _buildFullKeypad() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableButtonWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth -
                      _fullKeypadSectionGap -
                      _fullKeypadColumnGap * 4) /
                  6
            : _keypadButtonWidth;
        final buttonWidth = availableButtonWidth.clamp(
          1.0,
          _keypadButtonWidth,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildDirectionalKeypad(
              buttonWidth: buttonWidth,
              columnGap: _fullKeypadColumnGap,
            ),
            const SizedBox(width: _fullKeypadSectionGap),
            _buildNumericKeypad(
              buttonWidth: buttonWidth,
              columnGap: _fullKeypadColumnGap,
            ),
          ],
        );
      },
    );
  }

  Widget _keypadRow(
    List<Widget> children, {
    double columnGap = _keypadColumnGap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: columnGap),
          children[i],
        ],
      ],
    );
  }

  Widget _keyButton(
    String label,
    int keyCode, {
    double width = _keypadButtonWidth,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        unawaited(_vibrateVirtualKey());
        _engine?.sendKeyDown(keyCode);
      },
      onTapUp: (_) => _engine?.sendKeyUp(keyCode),
      onTapCancel: () => _engine?.sendKeyUp(keyCode),
      child: Container(
        width: width,
        height: _keypadButtonHeight,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
