import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'vmrp_audio_player.dart';
import 'vmrp_bindings.dart';

class VmrpEvent {
  static const int keyPress = 0;
  static const int keyRelease = 1;
  static const int mouseDown = 2;
  static const int mouseUp = 3;
  static const int mouseMove = 12;
}

class VmrpKey {
  static const int key0 = 0;
  static const int key1 = 1;
  static const int key2 = 2;
  static const int key3 = 3;
  static const int key4 = 4;
  static const int key5 = 5;
  static const int key6 = 6;
  static const int key7 = 7;
  static const int key8 = 8;
  static const int key9 = 9;
  static const int star = 10;
  static const int pound = 11;
  static const int up = 12;
  static const int down = 13;
  static const int left = 14;
  static const int right = 15;
  static const int power = 16;
  static const int softLeft = 17;
  static const int softRight = 18;
  static const int send = 19;
  static const int select = 20;
}

class VmrpEngine {
  VmrpBindings? _bindings;
  final int screenWidth;
  final int screenHeight;

  Timer? _timer;
  VmrpAudioPlayer? _audioPlayer;
  bool _running = false;
  bool _disposed = false;
  String? lastError;

  final StreamController<void> _onScreenUpdate = StreamController.broadcast();
  Stream<void> get onScreenUpdate => _onScreenUpdate.stream;

  final StreamController<void> _onEditRequest = StreamController.broadcast();
  Stream<void> get onEditRequest => _onEditRequest.stream;

  final StreamController<void> _onExit = StreamController.broadcast();
  Stream<void> get onExit => _onExit.stream;

  VmrpEngine({this.screenWidth = 240, this.screenHeight = 320});

  bool _ensureBindings() {
    if (_disposed) {
      lastError = 'Engine already disposed';
      return false;
    }
    if (_bindings != null) return true;
    try {
      _bindings = VmrpBindings();
      _audioPlayer = VmrpAudioPlayer(bindings: _bindings!);
      return true;
    } catch (e) {
      lastError = 'Failed to load vmrp library: $e';
      return false;
    }
  }

  int init() {
    if (!_ensureBindings()) return -1;
    try {
      final ret = _bindings!.init(screenWidth, screenHeight);
      if (ret != 0) {
        lastError = 'vmrp_api_init returned $ret';
      }
      return ret;
    } catch (e) {
      lastError = 'vmrp_api_init crashed: $e';
      return -1;
    }
  }

  int start(String mrpPath, {String ext = 'start.mr', String? entry}) {
    if (_disposed) {
      lastError = 'Engine already disposed';
      return -1;
    }
    if (_bindings == null) {
      lastError = 'Engine not initialized';
      return -1;
    }
    final pPath = mrpPath.toNativeUtf8();
    final pExt = ext.toNativeUtf8();
    final pEntry = entry?.toNativeUtf8() ?? nullptr;

    try {
      final ret = _bindings!.start(pPath.cast(), pExt.cast(), pEntry.cast());

      malloc.free(pPath);
      malloc.free(pExt);
      if (pEntry != nullptr) malloc.free(pEntry);

      if (ret == 0) {
        _running = true;
        if (_bindings!.isRunning() == 0) {
          scheduleMicrotask(_markExited);
        } else {
          _scheduleTimer();
        }
        _wakeAudio();
      } else {
        lastError = 'vmrp_api_start returned $ret';
      }
      return ret;
    } catch (e) {
      malloc.free(pPath);
      malloc.free(pExt);
      if (pEntry != nullptr) malloc.free(pEntry);
      lastError = 'vmrp_api_start crashed: $e';
      return -1;
    }
  }

  void sendTouchDown(int x, int y) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.mouseDown, x, y);
    _checkState();
  }

  void sendTouchUp(int x, int y) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.mouseUp, x, y);
    _checkState();
  }

  void sendTouchMove(int x, int y) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.mouseMove, x, y);
    _checkState();
  }

  void sendKeyDown(int keyCode) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.keyPress, keyCode, 0);
    _checkState();
  }

  void sendKeyUp(int keyCode) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.keyRelease, keyCode, 0);
    _checkState();
  }

  Uint8List? getScreenRGBA() {
    if (_bindings == null) return null;
    final ptr = _bindings!.getScreenBuffer();
    if (ptr == nullptr) return null;

    final pixelCount = screenWidth * screenHeight;
    final rgb565 = ptr.asTypedList(pixelCount);
    final rgba = Uint8List(pixelCount * 4);

    for (int i = 0; i < pixelCount; i++) {
      final c = rgb565[i];
      final r = ((c >> 11) & 0x1F) * 255 ~/ 31;
      final g = ((c >> 5) & 0x3F) * 255 ~/ 63;
      final b = (c & 0x1F) * 255 ~/ 31;
      rgba[i * 4 + 0] = r;
      rgba[i * 4 + 1] = g;
      rgba[i * 4 + 2] = b;
      rgba[i * 4 + 3] = 255;
    }
    return rgba;
  }

  void confirmEdit(String text) {
    if (_bindings == null) return;
    final pText = text.toNativeUtf8();
    _bindings!.setEditText(pText.cast());
    malloc.free(pText);
    _checkState();
  }

  void cancelEdit() {
    if (_bindings == null) return;
    _bindings!.cancelEdit();
    _checkState();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _running = false;
    unawaited(_audioPlayer?.dispose() ?? Future<void>.value());
    _audioPlayer = null;
    _bindings?.destroy();
    _bindings = null;
    _onScreenUpdate.close();
    _onEditRequest.close();
    _onExit.close();
  }

  void _checkState() {
    if (_bindings == null) return;
    if (_bindings!.isRunning() == 0) {
      _markExited();
      return;
    }
    if (_bindings!.getScreenDirty() != 0) {
      _onScreenUpdate.add(null);
    }
    if (_bindings!.isEditActive() != 0) {
      _onEditRequest.add(null);
    }
    _wakeAudio();
    _scheduleTimer();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_running || _bindings == null) return;

    final ms = _bindings!.getTimerInterval();
    if (ms > 0) {
      _timer = Timer(Duration(milliseconds: ms), () {
        if (!_running) return;
        _bindings?.timer();
        if (_bindings?.isRunning() == 0) {
          _markExited();
          return;
        }
        _wakeAudio();
        _checkState();
      });
    }
  }

  void _wakeAudio() {
    if (!_running) return;
    try {
      _audioPlayer?.wake();
      final audioError = _audioPlayer?.lastError;
      if (audioError != null) {
        lastError = audioError;
      }
    } catch (e) {
      lastError = 'Audio wake failed: $e';
    }
  }

  void _markExited() {
    if (!_running) return;
    _timer?.cancel();
    _timer = null;
    _running = false;
    unawaited(_audioPlayer?.stop() ?? Future<void>.value());
    if (!_onExit.isClosed) {
      _onExit.add(null);
    }
  }
}
