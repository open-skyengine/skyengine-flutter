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
  late final VmrpEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = VmrpEngine(
      screenWidth: widget.screenWidth,
      screenHeight: widget.screenHeight,
    );
    _engine.init();
    _engine.start(widget.mrpPath);
    _engine.onEditRequest.listen((_) => _showEditDialog());
  }

  @override
  void dispose() {
    _engine.dispose();
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
      _engine.confirmEdit(result);
    } else {
      _engine.cancelEdit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VMRP')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VmrpWidget(engine: _engine, scale: 2.0),
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
      onTapDown: (_) => _engine.sendKeyDown(keyCode),
      onTapUp: (_) => _engine.sendKeyUp(keyCode),
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
