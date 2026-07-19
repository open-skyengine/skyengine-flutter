import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/skyengine/skyengine_engine.dart';
import 'package:skyengine/skyengine/skyengine_widget.dart';

void main() {
  testWidgets('SkyEngineWidget listens to a replacement engine', (
    tester,
  ) async {
    final firstEngine = _FakeVmrpEngine();
    final secondEngine = _FakeVmrpEngine(screenWidth: 320, screenHeight: 480);
    addTearDown(firstEngine.close);
    addTearDown(secondEngine.close);

    await tester.pumpWidget(_TestApp(engine: firstEngine));
    expect(firstEngine.hasScreenUpdateListener, isTrue);
    expect(firstEngine.hasGeometryListener, isTrue);
    expect(secondEngine.hasScreenUpdateListener, isFalse);
    expect(secondEngine.hasGeometryListener, isFalse);

    await tester.pumpWidget(_TestApp(engine: secondEngine));
    expect(firstEngine.hasScreenUpdateListener, isFalse);
    expect(firstEngine.hasGeometryListener, isFalse);
    expect(secondEngine.hasScreenUpdateListener, isTrue);
    expect(secondEngine.hasGeometryListener, isTrue);
  });

  testWidgets(
    'SkyEngineWidget resizes and maps touches after screen rotation',
    (tester) async {
      final engine = _FakeVmrpEngine();
      addTearDown(engine.close);

      await tester.pumpWidget(_TestApp(engine: engine));
      expect(
        tester.getSize(find.byType(SkyEngineWidget)),
        const Size(240, 320),
      );

      engine.setGeometry(width: 320, height: 240, rotation: 3);
      await tester.pump();

      expect(
        tester.getSize(find.byType(SkyEngineWidget)),
        const Size(320, 240),
      );
      final origin = tester.getTopLeft(find.byType(SkyEngineWidget));
      final gesture = await tester.startGesture(
        origin + const Offset(319, 239),
      );
      await gesture.up();

      expect(engine.lastTouchDown, const Offset(319, 239));
      expect(engine.lastTouchUp, const Offset(319, 239));
    },
  );
}

class _TestApp extends StatelessWidget {
  final SkyEngineEngine engine;

  const _TestApp({required this.engine});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Center(child: SkyEngineWidget(engine: engine, scale: 1)),
    );
  }
}

class _FakeVmrpEngine extends SkyEngineEngine {
  final StreamController<void> _screenUpdates =
      StreamController<void>.broadcast(sync: true);
  final StreamController<SkyEngineScreenGeometry> _geometryUpdates =
      StreamController<SkyEngineScreenGeometry>.broadcast(sync: true);
  late int _width = panelScreenWidth;
  late int _height = panelScreenHeight;
  int _rotation = 0;

  Offset? lastTouchDown;
  Offset? lastTouchUp;

  _FakeVmrpEngine({super.screenWidth, super.screenHeight});

  bool get hasScreenUpdateListener => _screenUpdates.hasListener;
  bool get hasGeometryListener => _geometryUpdates.hasListener;

  @override
  int get screenWidth => _width;

  @override
  int get screenHeight => _height;

  @override
  int get screenRotation => _rotation;

  @override
  SkyEngineScreenGeometry get screenGeometry => SkyEngineScreenGeometry(
    width: _width,
    height: _height,
    rotation: _rotation,
  );

  @override
  Stream<void> get onScreenUpdate => _screenUpdates.stream;

  @override
  Stream<SkyEngineScreenGeometry> get onScreenGeometryChanged =>
      _geometryUpdates.stream;

  @override
  Uint8List? getScreenRGBA() => null;

  @override
  void sendTouchDown(int x, int y) {
    lastTouchDown = Offset(x.toDouble(), y.toDouble());
  }

  @override
  void sendTouchUp(int x, int y) {
    lastTouchUp = Offset(x.toDouble(), y.toDouble());
  }

  void setGeometry({
    required int width,
    required int height,
    required int rotation,
  }) {
    _width = width;
    _height = height;
    _rotation = rotation;
    _geometryUpdates.add(screenGeometry);
    _screenUpdates.add(null);
  }

  Future<void> close() async {
    await _screenUpdates.close();
    await _geometryUpdates.close();
  }
}
