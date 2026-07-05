import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vmrp/vmrp_engine.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.keyboard),
          title: const Text('按键测试'),
          subtitle: const Text('记录物理按键和左右软键映射'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DebugKeyTestPage()));
          },
        ),
      ],
    );
  }
}

class DebugKeyTestPage extends StatefulWidget {
  const DebugKeyTestPage({super.key});

  @override
  State<DebugKeyTestPage> createState() => _DebugKeyTestPageState();
}

class _DebugKeyTestPageState extends State<DebugKeyTestPage> {
  static const MethodChannel _debugKeysChannel = MethodChannel(
    'skyengine/debug_keys',
  );

  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  int? _lastVmrpKeyCode;
  String _lastSummary = '等待按键';

  @override
  void initState() {
    super.initState();
    _debugKeysChannel.setMethodCallHandler(_handleDebugKeyCall);
    unawaited(_setDebugKeyCapture(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debugKeysChannel.setMethodCallHandler(null);
    unawaited(_setDebugKeyCapture(false));
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setDebugKeyCapture(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _debugKeysChannel.invokeMethod<void>('setEnabled', enabled);
    } on PlatformException catch (error) {
      _appendLog(
        'debug channel error code=${error.code} message=${error.message}',
      );
    } on MissingPluginException catch (error) {
      _appendLog('debug channel missing $error');
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      _appendLog('debug channel failed $error');
    }
  }

  Future<void> _handleDebugKeyCall(MethodCall call) async {
    if (call.method != 'keyEvent') {
      return;
    }
    final event = call.arguments;
    if (event is! Map) {
      _appendLog('native keyEvent invalid arguments: $event');
      return;
    }
    _recordNativeEvent(event);
  }

  void _recordNativeEvent(Map<dynamic, dynamic> event) {
    final vmrpKeyCode = event['vmrpKeyCode'] as int?;
    final actionName = _stringValue(event['actionName']);
    final keyCodeName = _stringValue(event['keyCodeName']);
    final scanCode = _intValue(event['scanCode']);
    final keyCode = _intValue(event['keyCode']);
    final repeatCount = _intValue(event['repeatCount']);
    final vmrpKeyName = _stringValue(event['vmrpKeyName']);
    final source = _intValue(event['source']);
    final deviceId = _intValue(event['deviceId']);
    final metaStateName = _stringValue(event['metaStateName']);
    final unicodeChar = _intValue(event['unicodeChar']);
    final flags = _intValue(event['flags']);

    final mapped = vmrpKeyCode == null
        ? 'unmapped'
        : 'vmrp=$vmrpKeyCode(${_vmrpKeyLabel(vmrpKeyCode, vmrpKeyName)})';
    final line =
        '${_timestamp()} native $actionName '
        'keyCode=$keyCode $keyCodeName scanCode=$scanCode repeat=$repeatCount '
        '$mapped source=$source deviceId=$deviceId meta=$metaStateName '
        'unicode=$unicodeChar flags=$flags';

    setState(() {
      _lastVmrpKeyCode = vmrpKeyCode;
      _lastSummary = '$actionName $keyCodeName -> $mapped';
    });
    _appendLog(line);
  }

  KeyEventResult _handleFlutterKeyEvent(FocusNode node, KeyEvent event) {
    final logical = event.logicalKey;
    final physical = event.physicalKey;
    final vmrpKeyCode = _vmrpKeyCodeForFlutterKey(event);
    final mapped = vmrpKeyCode == null
        ? 'unmapped'
        : 'vmrp=$vmrpKeyCode(${_vmrpKeyLabel(vmrpKeyCode, null)})';
    final line =
        '${_timestamp()} flutter ${event.runtimeType} '
        'logical=${logical.keyLabel}/${logical.debugName} '
        'physical=${physical.usbHidUsage}/${physical.debugName} '
        'character=${event.character ?? '-'} $mapped';

    setState(() {
      _lastVmrpKeyCode = vmrpKeyCode;
      _lastSummary = '${event.runtimeType} ${logical.debugName} -> $mapped';
    });
    _appendLog(line);
    return KeyEventResult.handled;
  }

  int? _vmrpKeyCodeForFlutterKey(KeyEvent event) {
    final character = event.character;
    if (character != null && character.length == 1) {
      final keyCode = _vmrpKeyCodeForCharacter(character);
      if (keyCode != null) {
        return keyCode;
      }
    }
    return _vmrpKeyCodeForLogicalKey(event.logicalKey);
  }

  int? _vmrpKeyCodeForCharacter(String character) {
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

  int? _vmrpKeyCodeForLogicalKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyQ) {
      return VmrpKey.softLeft;
    }
    if (key == LogicalKeyboardKey.keyE) {
      return VmrpKey.softRight;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return VmrpKey.select;
    }
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

  void _appendLog(String line) {
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.add(line);
      if (_logs.length > 300) {
        _logs.removeRange(0, _logs.length - 300);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _copyLogs() async {
    final text = _logText;
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('按键日志已复制')));
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _lastVmrpKeyCode = null;
      _lastSummary = '等待按键';
    });
  }

  String get _logText => _logs.join('\n');

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.'
        '${three(now.millisecond)}';
  }

  int? _intValue(Object? value) => value is int ? value : null;

  String _stringValue(Object? value) {
    if (value == null) {
      return '-';
    }
    final text = value.toString();
    return text.isEmpty ? '-' : text;
  }

  String _vmrpKeyLabel(int keyCode, String? nativeName) {
    if (nativeName != null && nativeName.isNotEmpty) {
      return nativeName;
    }
    return switch (keyCode) {
      VmrpKey.key0 => '0',
      VmrpKey.key1 => '1',
      VmrpKey.key2 => '2',
      VmrpKey.key3 => '3',
      VmrpKey.key4 => '4',
      VmrpKey.key5 => '5',
      VmrpKey.key6 => '6',
      VmrpKey.key7 => '7',
      VmrpKey.key8 => '8',
      VmrpKey.key9 => '9',
      VmrpKey.star => '*',
      VmrpKey.pound => '#',
      VmrpKey.up => 'up',
      VmrpKey.down => 'down',
      VmrpKey.left => 'left',
      VmrpKey.right => 'right',
      VmrpKey.power => 'power',
      VmrpKey.softLeft => 'softLeft',
      VmrpKey.softRight => 'softRight',
      VmrpKey.send => 'send',
      VmrpKey.select => 'select',
      _ => 'unknown',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('按键测试'),
        actions: [
          IconButton(
            tooltip: '复制日志',
            onPressed: _logs.isEmpty ? null : _copyLogs,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: '清空日志',
            onPressed: _logs.isEmpty ? null : _clearLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleFlutterKeyEvent,
        child: SafeArea(
          child: Column(
            children: [
              Material(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _KeyStateChip(
                        label: '左软键',
                        active: _lastVmrpKeyCode == VmrpKey.softLeft,
                      ),
                      const SizedBox(width: 8),
                      _KeyStateChip(
                        label: '右软键',
                        active: _lastVmrpKeyCode == VmrpKey.softRight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lastSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _logs.isEmpty
                    ? const Center(child: Text('按下物理按键后，这里会显示日志'))
                    : Scrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _logText,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyStateChip extends StatelessWidget {
  final String label;
  final bool active;

  const _KeyStateChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? colorScheme.primary : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? colorScheme.onPrimary : colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
