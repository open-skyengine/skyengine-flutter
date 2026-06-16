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
    return Offset(
      localPos.dx / scale,
      localPos.dy / scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? engine.screenWidth * widget.scale;
    final h = widget.height ?? engine.screenHeight * widget.scale;
    final paintScale = _paintScale;

    return GestureDetector(
      onPanStart: (d) {
        final p = _toMrpCoords(d.localPosition);
        engine.sendTouchDown(p.dx.toInt(), p.dy.toInt());
      },
      onPanUpdate: (d) {
        final p = _toMrpCoords(d.localPosition);
        engine.sendTouchMove(p.dx.toInt(), p.dy.toInt());
      },
      onPanEnd: (d) {
        engine.sendTouchUp(0, 0);
      },
      onTapDown: (d) {
        final p = _toMrpCoords(d.localPosition);
        engine.sendTouchDown(p.dx.toInt(), p.dy.toInt());
      },
      onTapUp: (d) {
        final p = _toMrpCoords(d.localPosition);
        engine.sendTouchUp(p.dx.toInt(), p.dy.toInt());
      },
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
