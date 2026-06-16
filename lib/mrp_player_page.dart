import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'android_vibration.dart';
import 'vmrp_engine.dart';
import 'vmrp_widget.dart';

enum _KeypadMode { directional, numeric }

class MrpPlayerPage extends StatefulWidget {
  final String mrpPath;
  final int screenWidth;
  final int screenHeight;

  const MrpPlayerPage({
    super.key,
    required this.mrpPath,
    this.screenWidth = 240,
    this.screenHeight = 320,
  });

  @override
  State<MrpPlayerPage> createState() => _MrpPlayerPageState();
}

class _ScreenResolution {
  final int width;
  final int height;

  const _ScreenResolution(this.width, this.height);

  String get label => '${width}x$height';

  @override
  bool operator ==(Object other) {
    return other is _ScreenResolution &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);
}

enum _PlayerMenuAction { toggleKeypad, switchResolution }

class _MrpPlayerPageState extends State<MrpPlayerPage> {
  static const MethodChannel _hapticsChannel = MethodChannel('mrpoid/haptics');
  static const Duration _virtualKeyHapticDebounce = Duration(milliseconds: 80);
  static const List<_ScreenResolution> _commonResolutions = [
    _ScreenResolution(240, 320),
    _ScreenResolution(176, 220),
    _ScreenResolution(128, 160),
  ];

  VmrpEngine? _engine;
  final FocusNode _keyboardFocusNode = FocusNode();
  _KeypadMode _keypadMode = _KeypadMode.directional;
  String? _error;
  bool _exiting = false;
  bool _disposedEngine = false;
  bool _showVirtualKeypad = true;
  late _ScreenResolution _currentResolution;
  DateTime? _lastVirtualKeyHapticAt;

  @override
  void initState() {
    super.initState();
    _currentResolution = _ScreenResolution(
      widget.screenWidth,
      widget.screenHeight,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
    Future.delayed(Duration.zero, _startEngine);
  }

  void _startEngine() {
    if (!mounted || _disposedEngine) {
      return;
    }
    final file = File(widget.mrpPath);
    if (!file.existsSync()) {
      setState(() => _error = 'MRP file not found:\n${widget.mrpPath}');
      return;
    }

    debugPrint('[VMRP] mrpPath: ${widget.mrpPath}');
    debugPrint('[VMRP] file size: ${file.lengthSync()} bytes');

    final engine = VmrpEngine(
      screenWidth: _currentResolution.width,
      screenHeight: _currentResolution.height,
    );

    final initRet = engine.init();
    debugPrint('[VMRP] init() returned $initRet');
    if (initRet != 0) {
      setState(() => _error = 'Engine init failed: ${engine.lastError}');
      engine.dispose();
      return;
    }

    final startRet = engine.start(widget.mrpPath);
    debugPrint('[VMRP] start() returned $startRet');
    if (startRet != 0) {
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

  @override
  void dispose() {
    _shutdownEngine();
    _keyboardFocusNode.dispose();
    super.dispose();
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
    return null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final engine = _engine;
    if (engine == null) {
      return KeyEventResult.ignored;
    }

    final keyCode = _keyCodeForLogicalKey(event.logicalKey);
    if (keyCode == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      engine.sendKeyDown(keyCode);
    } else if (event is KeyUpEvent) {
      engine.sendKeyUp(keyCode);
    }
    return KeyEventResult.handled;
  }

  Future<void> _showEditDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('输入'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      _engine?.confirmEdit(result);
    } else {
      _engine?.cancelEdit();
    }
  }

  void _closePlayer() {
    if (_exiting || !mounted) return;
    _exiting = true;
    _shutdownEngine();
    Navigator.of(context).pop();
  }

  void _handleBack() {
    if (_exiting || !mounted) {
      return;
    }
    _exiting = true;
    _shutdownEngine();
    Navigator.of(context).pop();
  }

  void _shutdownEngine() {
    if (_disposedEngine) {
      return;
    }
    _disposedEngine = true;
    final engine = _engine;
    _engine = null;
    engine?.dispose();
  }

  void _disposeCurrentEngineForRestart() {
    final engine = _engine;
    _engine = null;
    engine?.dispose();
  }

  void _handleMenuAction(_PlayerMenuAction action) {
    switch (action) {
      case _PlayerMenuAction.toggleKeypad:
        setState(() {
          _showVirtualKeypad = !_showVirtualKeypad;
        });
        _keyboardFocusNode.requestFocus();
      case _PlayerMenuAction.switchResolution:
        unawaited(_showResolutionDialog());
    }
  }

  List<_ScreenResolution> get _resolutionOptions {
    if (_commonResolutions.contains(_currentResolution)) {
      return _commonResolutions;
    }
    return [_currentResolution, ..._commonResolutions];
  }

  Future<void> _showResolutionDialog() async {
    final selected = await showDialog<_ScreenResolution>(
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

  void _restartEngineWithResolution(_ScreenResolution resolution) {
    // vmrp_api_init() owns the screen buffer size, so changing resolution must
    // recreate the engine before start() instead of only resizing the widget.
    _disposeCurrentEngineForRestart();
    setState(() {
      _currentResolution = resolution;
      _error = null;
    });
    Future.delayed(Duration.zero, _startEngine);
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
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _shutdownEngine();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VMRP'),
          leading: BackButton(onPressed: _handleBack),
          actions: [
            PopupMenuButton<_PlayerMenuAction>(
              tooltip: '更多',
              icon: const Icon(Icons.more_vert),
              onSelected: _handleMenuAction,
              itemBuilder: (context) {
                return [
                  PopupMenuItem(
                    value: _PlayerMenuAction.toggleKeypad,
                    child: Row(
                      children: [
                        Icon(
                          _showVirtualKeypad
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
                ];
              },
            ),
          ],
        ),
        body: Focus(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _handleBack,
                          child: const Text('返回'),
                        ),
                      ],
                    ),
                  ),
                )
              : _engine == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final keypadHeight = _showVirtualKeypad ? 148.0 : 0.0;
                    final gap = _showVirtualKeypad ? 16.0 : 0.0;
                    final maxScreenWidth = constraints.maxWidth;
                    final maxScreenHeight =
                        constraints.maxHeight - keypadHeight - gap;
                    final scale = [
                      maxScreenWidth / _engine!.screenWidth,
                      maxScreenHeight > 0
                          ? maxScreenHeight / _engine!.screenHeight
                          : 0.1,
                      2.0,
                    ].reduce((a, b) => a < b ? a : b);
                    final screenWidth = _engine!.screenWidth * scale;
                    final screenHeight = _engine!.screenHeight * scale;

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          VmrpWidget(
                            engine: _engine!,
                            width: screenWidth,
                            height: screenHeight,
                          ),
                          if (_showVirtualKeypad) ...[
                            SizedBox(height: gap),
                            _buildKeypad(),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<_KeypadMode>(
          segments: const [
            ButtonSegment(
              value: _KeypadMode.directional,
              icon: Icon(Icons.gamepad_outlined),
              label: Text('方向键'),
            ),
            ButtonSegment(
              value: _KeypadMode.numeric,
              icon: Icon(Icons.dialpad_outlined),
              label: Text('九键'),
            ),
          ],
          selected: {_keypadMode},
          onSelectionChanged: (selection) {
            setState(() => _keypadMode = selection.first);
            _keyboardFocusNode.requestFocus();
          },
        ),
        const SizedBox(height: 8),
        if (_keypadMode == _KeypadMode.directional)
          _buildDirectionalKeypad()
        else
          _buildNumericKeypad(),
      ],
    );
  }

  Widget _buildDirectionalKeypad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _keyButton('左软键', VmrpKey.softLeft),
            _keyButton('上', VmrpKey.up),
            _keyButton('右软键', VmrpKey.softRight),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _keyButton('左', VmrpKey.left),
            _keyButton('确定', VmrpKey.select),
            _keyButton('右', VmrpKey.right),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _keyButton('下', VmrpKey.down),
            const SizedBox(width: 80),
          ],
        ),
      ],
    );
  }

  Widget _buildNumericKeypad() {
    const keys = [
      [('1', VmrpKey.key1), ('2', VmrpKey.key2), ('3', VmrpKey.key3)],
      [('4', VmrpKey.key4), ('5', VmrpKey.key5), ('6', VmrpKey.key6)],
      [('7', VmrpKey.key7), ('8', VmrpKey.key8), ('9', VmrpKey.key9)],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in keys)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row) _keyButton(key.$1, key.$2),
            ],
          ),
      ],
    );
  }

  void _handleVirtualKeyDown(int keyCode) {
    AndroidVibration.keyPress();
    _engine?.sendKeyDown(keyCode);
    _keyboardFocusNode.requestFocus();
  }

  void _handleVirtualKeyUp(int keyCode) {
    _engine?.sendKeyUp(keyCode);
    _keyboardFocusNode.requestFocus();
  }

  Widget _keyButton(String label, int keyCode) {
    return GestureDetector(
      onTapDown: (_) {
        unawaited(_vibrateVirtualKey());
        _engine?.sendKeyDown(keyCode);
      },
      onTapUp: (_) => _engine?.sendKeyUp(keyCode),
      onTapCancel: () => _engine?.sendKeyUp(keyCode),
      child: Container(
        width: 80,
        height: 38,
        margin: const EdgeInsets.all(4),
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
