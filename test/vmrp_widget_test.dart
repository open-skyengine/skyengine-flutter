import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/vmrp/vmrp_engine.dart';
import 'package:skyengine/vmrp/vmrp_widget.dart';

void main() {
  testWidgets('VmrpWidget listens to a replacement engine', (tester) async {
    final firstEngine = _FakeVmrpEngine();
    final secondEngine = _FakeVmrpEngine(screenWidth: 320, screenHeight: 480);
    addTearDown(firstEngine.close);
    addTearDown(secondEngine.close);

    await tester.pumpWidget(_TestApp(engine: firstEngine));
    expect(firstEngine.hasScreenUpdateListener, isTrue);
    expect(secondEngine.hasScreenUpdateListener, isFalse);

    await tester.pumpWidget(_TestApp(engine: secondEngine));
    expect(firstEngine.hasScreenUpdateListener, isFalse);
    expect(secondEngine.hasScreenUpdateListener, isTrue);
  });
}

class _TestApp extends StatelessWidget {
  final VmrpEngine engine;

  const _TestApp({required this.engine});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: VmrpWidget(engine: engine));
  }
}

class _FakeVmrpEngine extends VmrpEngine {
  final StreamController<void> _screenUpdates =
      StreamController<void>.broadcast(sync: true);

  _FakeVmrpEngine({super.screenWidth, super.screenHeight});

  bool get hasScreenUpdateListener => _screenUpdates.hasListener;

  @override
  Stream<void> get onScreenUpdate => _screenUpdates.stream;

  @override
  Uint8List? getScreenRGBA() => null;

  Future<void> close() => _screenUpdates.close();
}
