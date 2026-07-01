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

enum VmrpImageProcessingMode {
  native(0),
  opencv(1);

  final int code;

  const VmrpImageProcessingMode(this.code);

  static VmrpImageProcessingMode fromCode(int code) {
    return switch (code) {
      1 => VmrpImageProcessingMode.opencv,
      _ => VmrpImageProcessingMode.native,
    };
  }
}

class VmrpEngine {
  static const Duration _statePollInterval = Duration(milliseconds: 16);

  VmrpBindings? _bindings;
  final int screenWidth;
  final int screenHeight;

  Timer? _statePollTimer;
  VmrpAudioPlayer? _audioPlayer;
  Pointer<Uint8>? _screenRgbaPtr;
  Uint8List? _screenRgbaView;
  bool _running = false;
  bool _disposed = false;
  bool _editRequestActive = false;
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

  int start(
    String mrpPath, {
    String ext = 'start.mr',
    String? entry,
    String? workDir,
    String? dnsMap,
  }) {
    if (_disposed) {
      lastError = 'Engine already disposed';
      return -1;
    }
    if (_bindings == null) {
      lastError = 'Engine not initialized';
      return -1;
    }

    final pWorkDir = workDir?.toNativeUtf8() ?? nullptr;
    final pPath = mrpPath.toNativeUtf8();
    final pExt = ext.toNativeUtf8();
    final pEntry = entry?.toNativeUtf8() ?? nullptr;
    final pDnsMap = (dnsMap ?? '').toNativeUtf8();
    try {
      if (pWorkDir != nullptr) {
        final setWorkDirRet = _bindings!.setWorkDir(pWorkDir.cast());
        if (setWorkDirRet != 0) {
          lastError = 'vmrp_api_set_work_dir returned $setWorkDirRet';
          malloc.free(pPath);
          malloc.free(pExt);
          malloc.free(pWorkDir);
          if (pEntry != nullptr) malloc.free(pEntry);
          malloc.free(pDnsMap);
          return -1;
        }
      }

      final setDnsMapRet = _bindings!.setDnsMap(pDnsMap.cast());
      if (setDnsMapRet != 0) {
        lastError = 'vmrp_api_set_dns_map returned $setDnsMapRet';
        malloc.free(pPath);
        malloc.free(pExt);
        if (pWorkDir != nullptr) malloc.free(pWorkDir);
        if (pEntry != nullptr) malloc.free(pEntry);
        malloc.free(pDnsMap);
        return -1;
      }

      final ret = _bindings!.start(pPath.cast(), pExt.cast(), pEntry.cast());

      malloc.free(pPath);
      malloc.free(pExt);
      if (pWorkDir != nullptr) malloc.free(pWorkDir);
      if (pEntry != nullptr) malloc.free(pEntry);
      malloc.free(pDnsMap);

      if (ret == 0) {
        _running = true;
        _editRequestActive = false;
        if (_bindings!.isRunning() == 0) {
          scheduleMicrotask(_markExited);
        } else {
          _scheduleStatePoll();
        }
        _wakeAudio();
      } else {
        lastError = 'vmrp_api_start returned $ret';
      }
      return ret;
    } catch (e) {
      malloc.free(pPath);
      malloc.free(pExt);
      if (pWorkDir != nullptr) malloc.free(pWorkDir);
      if (pEntry != nullptr) malloc.free(pEntry);
      malloc.free(pDnsMap);
      lastError = 'vmrp_api_start crashed: $e';
      return -1;
    }
  }

  int setImageProcessingMode(VmrpImageProcessingMode mode) {
    if (!_ensureBindings()) return -1;
    try {
      final ret = _bindings!.setImageProcessingMode(mode.code);
      if (ret != 0) {
        lastError = 'vmrp_api_set_image_processing_mode returned $ret';
      }
      return ret;
    } catch (e) {
      lastError = 'vmrp_api_set_image_processing_mode crashed: $e';
      return -1;
    }
  }

  VmrpImageProcessingMode getImageProcessingMode() {
    if (_bindings == null) return VmrpImageProcessingMode.native;
    try {
      return VmrpImageProcessingMode.fromCode(
        _bindings!.getImageProcessingMode(),
      );
    } catch (_) {
      return VmrpImageProcessingMode.native;
    }
  }

  void requestScreenRefresh() {
    if (!_running || _onScreenUpdate.isClosed) return;
    _onScreenUpdate.add(null);
  }

  void sendTouchDown(int x, int y) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.mouseDown, x, y);
  }

  void sendTouchUp(int x, int y) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.mouseUp, x, y);
  }

  void sendTouchMove(int x, int y) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.mouseMove, x, y);
  }

  void sendKeyDown(int keyCode) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.keyPress, keyCode, 0);
  }

  void sendKeyUp(int keyCode) {
    if (!_running) return;
    _bindings!.event(VmrpEvent.keyRelease, keyCode, 0);
  }

  Uint8List? getScreenRGBA() {
    if (_bindings == null) return null;
    final ptr = _bindings!.getScreenRgbaBuffer();
    if (ptr == nullptr) return null;

    if (_screenRgbaPtr != ptr || _screenRgbaView == null) {
      _screenRgbaPtr = ptr;
      _screenRgbaView = ptr.asTypedList(screenWidth * screenHeight * 4);
    }
    return _screenRgbaView;
  }

  String getEditText() {
    if (_bindings == null) return '';
    final text = _bindings!.getEditText();
    return text == nullptr ? '' : text.toDartString();
  }

  void confirmEdit(String text) {
    if (_bindings == null) return;
    final pText = text.toNativeUtf8();
    _bindings!.setEditText(pText.cast());
    malloc.free(pText);
  }

  void cancelEdit() {
    if (_bindings == null) return;
    _bindings!.cancelEdit();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _statePollTimer?.cancel();
    _statePollTimer = null;
    _running = false;
    _editRequestActive = false;
    unawaited(_audioPlayer?.dispose() ?? Future<void>.value());
    _audioPlayer = null;
    _bindings?.destroy();
    _bindings = null;
    _screenRgbaPtr = null;
    _screenRgbaView = null;
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
    final editActive = _bindings!.isEditActive() != 0;
    if (editActive && !_editRequestActive) {
      _editRequestActive = true;
      _onEditRequest.add(null);
    } else if (!editActive) {
      _editRequestActive = false;
    }
    _wakeAudio();
    _scheduleStatePoll();
  }

  void _scheduleStatePoll() {
    if (!_running || _bindings == null || _statePollTimer != null) return;
    _statePollTimer = Timer.periodic(_statePollInterval, (_) {
      if (!_running) return;
      _checkState();
    });
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
    _statePollTimer?.cancel();
    _statePollTimer = null;
    _running = false;
    _editRequestActive = false;
    unawaited(_audioPlayer?.stop() ?? Future<void>.value());
    if (!_onExit.isClosed) {
      _onExit.add(null);
    }
  }
}
