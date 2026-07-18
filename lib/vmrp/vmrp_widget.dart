import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'vmrp_engine.dart';

class VmrpWidget extends StatefulWidget {
  final VmrpEngine engine;
  final double scale;
  final double? width;
  final double? height;

  const VmrpWidget({
    super.key,
    required this.engine,
    this.scale = 2.0,
    this.width,
    this.height,
  });

  @override
  State<VmrpWidget> createState() => _VmrpWidgetState();
}

class _VmrpWidgetState extends State<VmrpWidget> {
  StreamSubscription<void>? _sub;
  StreamSubscription<VmrpScreenGeometry>? _geometrySub;
  ui.Image? _screenImage;
  int? _activePointer;
  Offset? _lastTouchPoint;
  Offset? _pendingMovePoint;
  bool _moveFlushScheduled = false;
  bool _screenUpdateInProgress = false;
  bool _screenUpdatePending = false;
  int _engineEpoch = 0;

  VmrpEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _subscribeToEngine();
  }

  @override
  void didUpdateWidget(covariant VmrpWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.engine, widget.engine)) {
      return;
    }

    _sub?.cancel();
    _sub = null;
    _geometrySub?.cancel();
    _geometrySub = null;
    _activePointer = null;
    _lastTouchPoint = null;
    _pendingMovePoint = null;
    _screenImage?.dispose();
    _screenImage = null;
    _subscribeToEngine();
  }

  @override
  void dispose() {
    _engineEpoch++;
    _sub?.cancel();
    _geometrySub?.cancel();
    _screenImage?.dispose();
    super.dispose();
  }

  void _subscribeToEngine() {
    final epoch = ++_engineEpoch;
    _sub = engine.onScreenUpdate.listen((_) => _queueScreenUpdate(epoch));
    _geometrySub = engine.onScreenGeometryChanged.listen(
      (_) => _handleScreenGeometryChanged(epoch),
    );
    // The engine may have rendered its first frame before this widget subscribes.
    _queueScreenUpdate(epoch);
  }

  void _handleScreenGeometryChanged(int epoch) {
    if (!mounted || epoch != _engineEpoch) return;
    _pendingMovePoint = null;
    setState(() {
      _screenImage?.dispose();
      _screenImage = null;
    });
    _queueScreenUpdate(epoch);
  }

  void _queueScreenUpdate(int epoch) {
    if (!mounted || epoch != _engineEpoch) return;
    if (_screenUpdateInProgress) {
      _screenUpdatePending = true;
      return;
    }
    _screenUpdateInProgress = true;
    unawaited(_processScreenUpdates(epoch));
  }

  Future<void> _processScreenUpdates(int epoch) async {
    try {
      do {
        _screenUpdatePending = false;
        await _updateScreen(epoch);
      } while (mounted && epoch == _engineEpoch && _screenUpdatePending);
    } finally {
      _screenUpdateInProgress = false;
      if (mounted && _screenUpdatePending) {
        _queueScreenUpdate(_engineEpoch);
      }
    }
  }

  Future<void> _updateScreen(int epoch) async {
    if (epoch != _engineEpoch) return;
    final sourceEngine = engine;
    final sourceGeometry = sourceEngine.screenGeometry;
    final rgba = sourceEngine.getScreenRGBA();
    if (rgba == null) return;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      sourceGeometry.width,
      sourceGeometry.height,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );

    final img = await completer.future;
    if (mounted &&
        epoch == _engineEpoch &&
        identical(sourceEngine, engine) &&
        sourceEngine.screenGeometry == sourceGeometry) {
      setState(() {
        _screenImage?.dispose();
        _screenImage = img;
      });
    } else {
      img.dispose();
    }
  }

  double get _paintScale {
    if (widget.width != null) {
      return widget.width! / engine.screenWidth;
    }
    return widget.scale;
  }

  Offset _toMrpCoords(Offset localPos) {
    final scale = _paintScale;
    final x = (localPos.dx / scale).floor().clamp(0, engine.screenWidth - 1);
    final y = (localPos.dy / scale).floor().clamp(0, engine.screenHeight - 1);
    return Offset(x.toDouble(), y.toDouble());
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) {
      return;
    }
    _activePointer = event.pointer;
    final p = _toMrpCoords(event.localPosition);
    _lastTouchPoint = p;
    engine.sendTouchDown(p.dx.toInt(), p.dy.toInt());
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final p = _toMrpCoords(event.localPosition);
    _lastTouchPoint = p;
    _pendingMovePoint = p;
    if (_moveFlushScheduled) {
      return;
    }
    _moveFlushScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _moveFlushScheduled = false;
      final pending = _pendingMovePoint;
      _pendingMovePoint = null;
      if (!mounted || pending == null || _activePointer != event.pointer) {
        return;
      }
      engine.sendTouchMove(pending.dx.toInt(), pending.dy.toInt());
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final p = _toMrpCoords(event.localPosition);
    _lastTouchPoint = p;
    _pendingMovePoint = null;
    engine.sendTouchUp(p.dx.toInt(), p.dy.toInt());
    _activePointer = null;
    _lastTouchPoint = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final p = _lastTouchPoint;
    if (p != null) {
      engine.sendTouchUp(p.dx.toInt(), p.dy.toInt());
    }
    _pendingMovePoint = null;
    _activePointer = null;
    _lastTouchPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? engine.screenWidth * widget.scale;
    final h = widget.height ?? engine.screenHeight * widget.scale;
    final paintScale = _paintScale;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: SizedBox(
        width: w,
        height: h,
        child: CustomPaint(
          painter: _VmrpPainter(_screenImage, paintScale),
          size: Size(w, h),
        ),
      ),
    );
  }
}

class _VmrpPainter extends CustomPainter {
  final ui.Image? image;
  final double scale;

  _VmrpPainter(this.image, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black,
      );
      return;
    }
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawImage(
      image!,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VmrpPainter old) => image != old.image;
}
