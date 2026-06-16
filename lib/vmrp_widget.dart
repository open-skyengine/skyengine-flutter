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
  StreamSubscription? _sub;
  ui.Image? _screenImage;
  int? _activePointer;
  Offset? _lastTouchPoint;

  VmrpEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _sub = engine.onScreenUpdate.listen((_) => _updateScreen());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _screenImage?.dispose();
    super.dispose();
  }

  Future<void> _updateScreen() async {
    final rgba = engine.getScreenRGBA();
    if (rgba == null) return;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      engine.screenWidth,
      engine.screenHeight,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );

    final img = await completer.future;
    if (mounted) {
      setState(() {
        _screenImage?.dispose();
        _screenImage = img;
      });
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
    return Offset(
      x.toDouble(),
      y.toDouble(),
    );
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
    engine.sendTouchMove(p.dx.toInt(), p.dy.toInt());
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final p = _toMrpCoords(event.localPosition);
    _lastTouchPoint = p;
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
    canvas.drawImage(image!, Offset.zero, Paint()..filterQuality = FilterQuality.none);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VmrpPainter old) => image != old.image;
}
