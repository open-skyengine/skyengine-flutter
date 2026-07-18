import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'vmrp_audio_player.dart';
import 'vmrp_bindings.dart';
import 'vmrp_motion_sensor.dart';

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

class VmrpScreenGeometry {
  final int width;
  final int height;
  final int rotation;

  const VmrpScreenGeometry({
    required this.width,
    required this.height,
    required this.rotation,
  });

  @override
  bool operator ==(Object other) {
    return other is VmrpScreenGeometry &&
        other.width == width &&
        other.height == height &&
        other.rotation == rotation;
  }

  @override
  int get hashCode => Object.hash(width, height, rotation);
}

class VmrpEngine {
  static const Duration _statePollInterval = Duration(milliseconds: 16);

  VmrpBindings? _bindings;
  final int panelScreenWidth;
  final int panelScreenHeight;
  int _screenWidth;
  int _screenHeight;
  int _screenRotation = 0;

  int get screenWidth => _screenWidth;
  int get screenHeight => _screenHeight;
  int get screenRotation => _screenRotation;
  VmrpScreenGeometry get screenGeometry => VmrpScreenGeometry(
    width: _screenWidth,
    height: _screenHeight,
    rotation: _screenRotation,
  );

  Timer? _statePollTimer;
  VmrpAudioPlayer? _audioPlayer;
  VmrpMotionBridge? _motionBridge;
  Pointer<Uint8>? _screenRgbaPtr;
  Uint8List? _screenRgbaView;
  bool _running = false;
  bool _paused = false;
  bool _disposed = false;
  bool _editRequestActive = false;
  String? lastError;

  final StreamController<void> _onScreenUpdate = StreamController.broadcast();
  Stream<void> get onScreenUpdate => _onScreenUpdate.stream;

  final StreamController<void> _onEditRequest = StreamController.broadcast();
  Stream<void> get onEditRequest => _onEditRequest.stream;

  final StreamController<int> _onShakeRequest = StreamController.broadcast();
  Stream<int> get onShakeRequest => _onShakeRequest.stream;

  final StreamController<void> _onExit = StreamController.broadcast();
  Stream<void> get onExit => _onExit.stream;

  final StreamController<VmrpScreenGeometry> _onScreenGeometryChanged =
      StreamController.broadcast();
  Stream<VmrpScreenGeometry> get onScreenGeometryChanged =>
      _onScreenGeometryChanged.stream;

  VmrpEngine({
    int screenWidth = 240,
    int screenHeight = 320,
    VmrpMotionSampleStreamFactory? motionSampleStreamFactory,
  }) : panelScreenWidth = screenWidth,
       panelScreenHeight = screenHeight,
       _screenWidth = screenWidth,
       _screenHeight = screenHeight {
    if (motionSampleStreamFactory != null) {
      _motionBridge = VmrpMotionBridge(
        streamFactory: motionSampleStreamFactory,
        onSample: _sendMotionSample,
        onError: _handleMotionSensorError,
      );
    }
  }

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
      final ret = _bindings!.init(panelScreenWidth, panelScreenHeight);
      if (ret != 0) {
        lastError = 'vmrp_api_init returned $ret';
      } else {
        _syncScreenGeometry();
      }
      return ret;
    } catch (e) {
      lastError = 'vmrp_api_init crashed: $e';
      return -1;
    }
  }

  int setMemoryMb(int memoryMb) {
    if (!_ensureBindings()) return -1;
    try {
      final ret = _bindings!.setMemory(memoryMb);
      if (ret != 0) {
        lastError = 'vmrp_api_set_memory returned $ret';
      }
      return ret;
    } catch (e) {
      lastError = 'vmrp_api_set_memory crashed: $e';
      return -1;
    }
  }

  /// Sets the app-visible handset date for the next run.
  ///
  /// The native API accepts an ISO date (`YYYY-MM-DD`) or `host`. This must be
  /// called after [init] and before [start].
  int setDeviceDate(String date) {
    if (!_ensureBindings()) return -1;
    final setDeviceDate = _bindings!.setDeviceDate;
    if (setDeviceDate == null) {
      lastError = 'vmrp_api_set_device_date is unavailable';
      return -1;
    }
    final normalizedDate = date.trim();
    if (normalizedDate.isEmpty) {
      lastError = 'Device date must not be empty';
      return -1;
    }
    final pDate = normalizedDate.toNativeUtf8();
    try {
      final ret = setDeviceDate(pDate.cast());
      if (ret != 0) {
        lastError = 'vmrp_api_set_device_date returned $ret';
      }
      return ret;
    } catch (e) {
      lastError = 'vmrp_api_set_device_date crashed: $e';
      return -1;
    } finally {
      malloc.free(pDate);
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
    final normalizedDnsMap = dnsMap?.trim();
    final pDnsMap = normalizedDnsMap == null || normalizedDnsMap.isEmpty
        ? nullptr
        : normalizedDnsMap.toNativeUtf8();
    try {
      if (pWorkDir != nullptr) {
        final setWorkDirRet = _bindings!.setWorkDir(pWorkDir.cast());
        if (setWorkDirRet != 0) {
          lastError = 'vmrp_api_set_work_dir returned $setWorkDirRet';
          malloc.free(pPath);
          malloc.free(pExt);
          malloc.free(pWorkDir);
          if (pEntry != nullptr) malloc.free(pEntry);
          if (pDnsMap != nullptr) malloc.free(pDnsMap);
          return -1;
        }
      }

      if (pDnsMap != nullptr) {
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
      }

      final ret = _bindings!.start(pPath.cast(), pExt.cast(), pEntry.cast());

      malloc.free(pPath);
      malloc.free(pExt);
      if (pWorkDir != nullptr) malloc.free(pWorkDir);
      if (pEntry != nullptr) malloc.free(pEntry);
      if (pDnsMap != nullptr) malloc.free(pDnsMap);

      if (ret == 0) {
        _running = true;
        _paused = false;
        _editRequestActive = false;
        _syncScreenGeometry();
        _syncMotionSensor();
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
      if (pDnsMap != nullptr) malloc.free(pDnsMap);
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
    if (!_running || _paused || _onScreenUpdate.isClosed) return;
    _onScreenUpdate.add(null);
  }

  void sendTouchDown(int x, int y) {
    if (!_running || _paused) return;
    _bindings!.event(VmrpEvent.mouseDown, x, y);
  }

  void sendTouchUp(int x, int y) {
    if (!_running || _paused) return;
    _bindings!.event(VmrpEvent.mouseUp, x, y);
  }

  void sendTouchMove(int x, int y) {
    if (!_running || _paused) return;
    _bindings!.event(VmrpEvent.mouseMove, x, y);
  }

  void sendKeyDown(int keyCode) {
    if (!_running || _paused) return;
    _bindings!.event(VmrpEvent.keyPress, keyCode, 0);
  }

  void sendKeyUp(int keyCode) {
    if (!_running || _paused) return;
    _bindings!.event(VmrpEvent.keyRelease, keyCode, 0);
  }

  int pause() {
    _motionBridge?.setEnabled(false);
    if (!_running || _bindings == null || _paused) return 0;
    try {
      final ret = _bindings!.pause();
      if (ret == 0) {
        _paused = true;
        _statePollTimer?.cancel();
        _statePollTimer = null;
        _discardShakeRequest();
        unawaited(_audioPlayer?.stop() ?? Future<void>.value());
      }
      return ret;
    } catch (e) {
      lastError = 'vmrp_api_pause crashed: $e';
      return -1;
    }
  }

  int resume() {
    if (!_running || _bindings == null || !_paused) return 0;
    try {
      _discardShakeRequest();
      final ret = _bindings!.resume();
      if (ret == 0) {
        _paused = false;
        _syncMotionSensor();
        _scheduleStatePoll();
        _wakeAudio();
      }
      return ret;
    } catch (e) {
      lastError = 'vmrp_api_resume crashed: $e';
      return -1;
    }
  }

  Uint8List? getScreenRGBA() {
    if (_bindings == null) return null;
    final ptr = _bindings!.getScreenRgbaBuffer();
    if (ptr == nullptr) return null;

    if (_screenRgbaPtr != ptr || _screenRgbaView == null) {
      _screenRgbaPtr = ptr;
      _screenRgbaView = ptr.asTypedList(
        panelScreenWidth * panelScreenHeight * 4,
      );
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
    _paused = false;
    _editRequestActive = false;
    _motionBridge?.dispose();
    _motionBridge = null;
    unawaited(_audioPlayer?.dispose() ?? Future<void>.value());
    _audioPlayer = null;
    _bindings?.destroy();
    _bindings = null;
    _screenRgbaPtr = null;
    _screenRgbaView = null;
    _onScreenUpdate.close();
    _onEditRequest.close();
    _onShakeRequest.close();
    _onExit.close();
    _onScreenGeometryChanged.close();
  }

  void _checkState() {
    if (_bindings == null || _paused) return;
    if (_bindings!.isRunning() == 0) {
      _markExited();
      return;
    }
    _syncShakeRequest();
    final screenDirty = _bindings!.getScreenDirty() != 0;
    final geometryChanged = _syncScreenGeometry();
    if (screenDirty || geometryChanged) {
      _onScreenUpdate.add(null);
    }
    final editActive = _bindings!.isEditActive() != 0;
    if (editActive && !_editRequestActive) {
      _editRequestActive = true;
      _onEditRequest.add(null);
    } else if (!editActive) {
      _editRequestActive = false;
    }
    _syncMotionSensor();
    _wakeAudio();
    _scheduleStatePoll();
  }

  void _scheduleStatePoll() {
    if (!_running || _paused || _bindings == null || _statePollTimer != null) {
      return;
    }
    _statePollTimer = Timer.periodic(_statePollInterval, (_) {
      if (!_running) return;
      _checkState();
    });
  }

  void _wakeAudio() {
    if (!_running || _paused) return;
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

  void _syncShakeRequest() {
    final takeShake = _bindings?.takeShake;
    if (takeShake == null || _onShakeRequest.isClosed) return;
    try {
      final request = takeShake();
      if (request != 0) {
        _onShakeRequest.add(request);
      }
    } catch (e) {
      lastError = 'Vibration request query failed: $e';
    }
  }

  void _discardShakeRequest() {
    try {
      _bindings?.takeShake?.call();
    } catch (e) {
      lastError = 'Vibration request discard failed: $e';
    }
  }

  bool _syncScreenGeometry() {
    final bindings = _bindings;
    if (bindings == null) return false;

    try {
      final getRotation = bindings.getScreenRotation;
      final rawRotationBefore = getRotation?.call() ?? 0;
      final width = bindings.getScreenWidth();
      final height = bindings.getScreenHeight();
      final rawRotationAfter = getRotation?.call() ?? rawRotationBefore;
      if (rawRotationBefore != rawRotationAfter) {
        return false;
      }
      final rotation = rawRotationAfter >= 0 && rawRotationAfter <= 3
          ? rawRotationAfter
          : 0;
      if (width <= 0 ||
          height <= 0 ||
          width * height != panelScreenWidth * panelScreenHeight) {
        lastError = 'Invalid VMRP screen geometry: ${width}x$height';
        return false;
      }
      if (width == _screenWidth &&
          height == _screenHeight &&
          rotation == _screenRotation) {
        return false;
      }

      _screenWidth = width;
      _screenHeight = height;
      _screenRotation = rotation;
      _screenRgbaPtr = null;
      _screenRgbaView = null;
      if (!_onScreenGeometryChanged.isClosed) {
        _onScreenGeometryChanged.add(screenGeometry);
      }
      return true;
    } catch (error) {
      lastError = 'Screen geometry query failed: $error';
      return false;
    }
  }

  void _syncMotionSensor() {
    final bridge = _motionBridge;
    final bindings = _bindings;
    final motion = bindings?.motion;
    final motionActive = bindings?.motionActive;
    if (bridge == null) return;
    if (!_running || _paused || motion == null || motionActive == null) {
      bridge.setEnabled(false);
      return;
    }

    try {
      bridge.setEnabled(motionActive() >= 0);
    } catch (error) {
      lastError = 'Motion state query failed: $error';
      bridge.setEnabled(false);
    }
  }

  void _sendMotionSample(VmrpMotionSample sample) {
    final motion = _bindings?.motion;
    if (!_running || _paused || motion == null) return;
    try {
      motion(sample.x, sample.y, sample.z);
    } catch (error) {
      lastError = 'Motion input failed: $error';
    }
  }

  void _handleMotionSensorError(Object error, StackTrace stackTrace) {
    lastError = 'Motion sensor failed: $error';
  }

  void _markExited() {
    if (!_running) return;
    _statePollTimer?.cancel();
    _statePollTimer = null;
    _running = false;
    _editRequestActive = false;
    _motionBridge?.setEnabled(false);
    unawaited(_audioPlayer?.stop() ?? Future<void>.value());
    if (!_onExit.isClosed) {
      _onExit.add(null);
    }
  }
}
