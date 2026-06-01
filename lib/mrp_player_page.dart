import 'dart:io';
import 'package:flutter/material.dart';
import 'vmrp_engine.dart';
import 'vmrp_widget.dart';

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

class _MrpPlayerPageState extends State<MrpPlayerPage> {
  VmrpEngine? _engine;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _startEngine);
  }

  void _startEngine() {
    final file = File(widget.mrpPath);
    if (!file.existsSync()) {
      setState(() => _error = 'MRP file not found:\n${widget.mrpPath}');
      return;
    }

    debugPrint('[VMRP] mrpPath: ${widget.mrpPath}');
    debugPrint('[VMRP] file size: ${file.lengthSync()} bytes');

    final engine = VmrpEngine(
      screenWidth: widget.screenWidth,
      screenHeight: widget.screenHeight,
    );

    final initRet = engine.init();
    debugPrint('[VMRP] init() returned $initRet');
    if (initRet != 0) {
      setState(() => _error = 'Engine init failed: ${engine.lastError}');
      return;
    }

    final startRet = engine.start(widget.mrpPath);
    debugPrint('[VMRP] start() returned $startRet');
    if (startRet != 0) {
      setState(() => _error = 'Engine start failed: ${engine.lastError}');
      engine.dispose();
      return;
    }

    engine.onEditRequest.listen((_) => _showEditDialog());
    setState(() => _engine = engine);
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VMRP')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回'),
                    ),
                  ],
                ),
              ),
            )
          : _engine == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      VmrpWidget(engine: _engine!, scale: 2.0),
                      const SizedBox(height: 16),
                      _buildKeypad(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKeypad() {
    return Column(
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

  Widget _keyButton(String label, int keyCode) {
    return GestureDetector(
      onTapDown: (_) => _engine?.sendKeyDown(keyCode),
      onTapUp: (_) => _engine?.sendKeyUp(keyCode),
      child: Container(
        width: 80,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
