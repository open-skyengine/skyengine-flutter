import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef SkyEngineApiInitC = Int32 Function(Int32, Int32);
typedef SkyEngineApiInitDart = int Function(int, int);

typedef SkyEngineApiSetMemoryC = Int32 Function(Int32);
typedef SkyEngineApiSetMemoryDart = int Function(int);

typedef SkyEngineApiSetDeviceDateC = Int32 Function(Pointer<Utf8>);
typedef SkyEngineApiSetDeviceDateDart = int Function(Pointer<Utf8>);

typedef SkyEngineApiSetWorkDirC = Int32 Function(Pointer<Utf8>);
typedef SkyEngineApiSetWorkDirDart = int Function(Pointer<Utf8>);

typedef SkyEngineApiStartC =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef SkyEngineApiStartDart =
    int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef SkyEngineApiSetDnsMapC = Int32 Function(Pointer<Utf8>);
typedef SkyEngineApiSetDnsMapDart = int Function(Pointer<Utf8>);

typedef SkyEngineApiDestroyC = Void Function();
typedef SkyEngineApiDestroyDart = void Function();

typedef SkyEngineApiIsRunningC = Int32 Function();
typedef SkyEngineApiIsRunningDart = int Function();
typedef SkyEngineApiPauseC = Int32 Function();
typedef SkyEngineApiPauseDart = int Function();
typedef SkyEngineApiResumeC = Int32 Function();
typedef SkyEngineApiResumeDart = int Function();

typedef SkyEngineApiEventC = Int32 Function(Int32, Int32, Int32);
typedef SkyEngineApiEventDart = int Function(int, int, int);

typedef SkyEngineApiMotionC = Int32 Function(Int32, Int32, Int32);
typedef SkyEngineApiMotionDart = int Function(int, int, int);

typedef SkyEngineApiMotionActiveC = Int32 Function();
typedef SkyEngineApiMotionActiveDart = int Function();

typedef SkyEngineApiTakeShakeC = Int32 Function();
typedef SkyEngineApiTakeShakeDart = int Function();

typedef SkyEngineApiTimerC = Int32 Function();
typedef SkyEngineApiTimerDart = int Function();

typedef SkyEngineApiGetTimerIntervalC = Int32 Function();
typedef SkyEngineApiGetTimerIntervalDart = int Function();

typedef SkyEngineApiSetImageProcessingModeC = Int32 Function(Int32);
typedef SkyEngineApiSetImageProcessingModeDart = int Function(int);

typedef SkyEngineApiGetImageProcessingModeC = Int32 Function();
typedef SkyEngineApiGetImageProcessingModeDart = int Function();

typedef SkyEngineApiGetScreenBufferC = Pointer<Uint16> Function();
typedef SkyEngineApiGetScreenBufferDart = Pointer<Uint16> Function();

typedef SkyEngineApiGetScreenRgbaBufferC = Pointer<Uint8> Function();
typedef SkyEngineApiGetScreenRgbaBufferDart = Pointer<Uint8> Function();

typedef SkyEngineApiGetScreenDirtyC = Int32 Function();
typedef SkyEngineApiGetScreenDirtyDart = int Function();

typedef SkyEngineApiGetScreenWidthC = Int32 Function();
typedef SkyEngineApiGetScreenWidthDart = int Function();

typedef SkyEngineApiGetScreenHeightC = Int32 Function();
typedef SkyEngineApiGetScreenHeightDart = int Function();

typedef SkyEngineApiGetScreenRotationC = Int32 Function();
typedef SkyEngineApiGetScreenRotationDart = int Function();

typedef SkyEngineApiAudioSampleRateC = Int32 Function();
typedef SkyEngineApiAudioSampleRateDart = int Function();

typedef SkyEngineApiAudioChannelsC = Int32 Function();
typedef SkyEngineApiAudioChannelsDart = int Function();

typedef SkyEngineApiAudioIsActiveC = Int32 Function();
typedef SkyEngineApiAudioIsActiveDart = int Function();

typedef SkyEngineApiAudioRenderS16leC = Int32 Function(Pointer<Void>, Int32);
typedef SkyEngineApiAudioRenderS16leDart = int Function(Pointer<Void>, int);

typedef SkyEngineApiAudioStopC = Void Function();
typedef SkyEngineApiAudioStopDart = void Function();

typedef SkyEngineApiIsEditActiveC = Int32 Function();
typedef SkyEngineApiIsEditActiveDart = int Function();

typedef SkyEngineApiGetEditTextC = Pointer<Utf8> Function();
typedef SkyEngineApiGetEditTextDart = Pointer<Utf8> Function();

typedef SkyEngineApiSetEditTextC = Int32 Function(Pointer<Utf8>);
typedef SkyEngineApiSetEditTextDart = int Function(Pointer<Utf8>);

typedef SkyEngineApiCancelEditC = Int32 Function();
typedef SkyEngineApiCancelEditDart = int Function();

class SkyEngineBindings {
  late final DynamicLibrary _lib;

  late final SkyEngineApiInitDart init;
  late final SkyEngineApiSetMemoryDart setMemory;
  SkyEngineApiSetDeviceDateDart? setDeviceDate;
  late final SkyEngineApiSetWorkDirDart setWorkDir;
  late final SkyEngineApiStartDart start;
  late final SkyEngineApiSetDnsMapDart setDnsMap;
  late final SkyEngineApiDestroyDart destroy;
  late final SkyEngineApiIsRunningDart isRunning;
  late final SkyEngineApiPauseDart pause;
  late final SkyEngineApiResumeDart resume;
  late final SkyEngineApiEventDart event;
  SkyEngineApiMotionDart? motion;
  SkyEngineApiMotionActiveDart? motionActive;
  SkyEngineApiTakeShakeDart? takeShake;
  late final SkyEngineApiTimerDart timer;
  late final SkyEngineApiGetTimerIntervalDart getTimerInterval;
  late final SkyEngineApiSetImageProcessingModeDart setImageProcessingMode;
  late final SkyEngineApiGetImageProcessingModeDart getImageProcessingMode;
  late final SkyEngineApiGetScreenBufferDart getScreenBuffer;
  late final SkyEngineApiGetScreenRgbaBufferDart getScreenRgbaBuffer;
  late final SkyEngineApiGetScreenDirtyDart getScreenDirty;
  late final SkyEngineApiGetScreenWidthDart getScreenWidth;
  late final SkyEngineApiGetScreenHeightDart getScreenHeight;
  SkyEngineApiGetScreenRotationDart? getScreenRotation;
  late final SkyEngineApiAudioSampleRateDart audioSampleRate;
  late final SkyEngineApiAudioChannelsDart audioChannels;
  late final SkyEngineApiAudioIsActiveDart audioIsActive;
  late final SkyEngineApiAudioRenderS16leDart audioRenderS16le;
  late final SkyEngineApiAudioStopDart audioStop;
  late final SkyEngineApiIsEditActiveDart isEditActive;
  late final SkyEngineApiGetEditTextDart getEditText;
  late final SkyEngineApiSetEditTextDart setEditText;
  late final SkyEngineApiCancelEditDart cancelEdit;

  SkyEngineBindings() {
    if (Platform.isAndroid || Platform.isLinux) {
      _lib = DynamicLibrary.open('libskyengine.so');
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('skyengine.dll');
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('libskyengine.dylib');
    } else {
      _lib = DynamicLibrary.process();
    }

    init = _lib.lookupFunction<SkyEngineApiInitC, SkyEngineApiInitDart>(
      'skyengine_api_init',
    );
    setMemory = _lib
        .lookupFunction<SkyEngineApiSetMemoryC, SkyEngineApiSetMemoryDart>(
          'skyengine_api_set_memory',
        );
    // Keep older packaged native libraries usable while they are being
    // updated. The engine reports a failed date application to its caller.
    try {
      setDeviceDate = _lib
          .lookupFunction<
            SkyEngineApiSetDeviceDateC,
            SkyEngineApiSetDeviceDateDart
          >('skyengine_api_set_device_date');
    } catch (_) {
      setDeviceDate = null;
    }
    setWorkDir = _lib
        .lookupFunction<SkyEngineApiSetWorkDirC, SkyEngineApiSetWorkDirDart>(
          'skyengine_api_set_work_dir',
        );
    start = _lib.lookupFunction<SkyEngineApiStartC, SkyEngineApiStartDart>(
      'skyengine_api_start',
    );
    setDnsMap = _lib
        .lookupFunction<SkyEngineApiSetDnsMapC, SkyEngineApiSetDnsMapDart>(
          'skyengine_api_set_dns_map',
        );
    destroy = _lib
        .lookupFunction<SkyEngineApiDestroyC, SkyEngineApiDestroyDart>(
          'skyengine_api_destroy',
        );
    isRunning = _lib
        .lookupFunction<SkyEngineApiIsRunningC, SkyEngineApiIsRunningDart>(
          'skyengine_api_is_running',
        );
    pause = _lib.lookupFunction<SkyEngineApiPauseC, SkyEngineApiPauseDart>(
      'skyengine_api_pause',
    );
    resume = _lib.lookupFunction<SkyEngineApiResumeC, SkyEngineApiResumeDart>(
      'skyengine_api_resume',
    );
    event = _lib.lookupFunction<SkyEngineApiEventC, SkyEngineApiEventDart>(
      'skyengine_api_event',
    );
    try {
      motion = _lib.lookupFunction<SkyEngineApiMotionC, SkyEngineApiMotionDart>(
        'skyengine_api_motion',
      );
      motionActive = _lib
          .lookupFunction<
            SkyEngineApiMotionActiveC,
            SkyEngineApiMotionActiveDart
          >('skyengine_api_motion_active');
    } catch (_) {
      // Older packaged native libraries remain usable without motion support.
      motion = null;
      motionActive = null;
    }
    try {
      takeShake = _lib
          .lookupFunction<SkyEngineApiTakeShakeC, SkyEngineApiTakeShakeDart>(
            'skyengine_api_take_shake',
          );
    } catch (_) {
      // Older packaged native libraries remain usable without vibration.
      takeShake = null;
    }
    timer = _lib.lookupFunction<SkyEngineApiTimerC, SkyEngineApiTimerDart>(
      'skyengine_api_timer',
    );
    getTimerInterval = _lib
        .lookupFunction<
          SkyEngineApiGetTimerIntervalC,
          SkyEngineApiGetTimerIntervalDart
        >('skyengine_api_get_timer_interval');
    setImageProcessingMode = _lib
        .lookupFunction<
          SkyEngineApiSetImageProcessingModeC,
          SkyEngineApiSetImageProcessingModeDart
        >('skyengine_api_set_image_processing_mode');
    getImageProcessingMode = _lib
        .lookupFunction<
          SkyEngineApiGetImageProcessingModeC,
          SkyEngineApiGetImageProcessingModeDart
        >('skyengine_api_get_image_processing_mode');
    getScreenBuffer = _lib
        .lookupFunction<
          SkyEngineApiGetScreenBufferC,
          SkyEngineApiGetScreenBufferDart
        >('skyengine_api_get_screen_buffer');
    getScreenRgbaBuffer = _lib
        .lookupFunction<
          SkyEngineApiGetScreenRgbaBufferC,
          SkyEngineApiGetScreenRgbaBufferDart
        >('skyengine_api_get_screen_rgba_buffer');
    getScreenDirty = _lib
        .lookupFunction<
          SkyEngineApiGetScreenDirtyC,
          SkyEngineApiGetScreenDirtyDart
        >('skyengine_api_get_screen_dirty');
    getScreenWidth = _lib
        .lookupFunction<
          SkyEngineApiGetScreenWidthC,
          SkyEngineApiGetScreenWidthDart
        >('skyengine_api_get_screen_width');
    getScreenHeight = _lib
        .lookupFunction<
          SkyEngineApiGetScreenHeightC,
          SkyEngineApiGetScreenHeightDart
        >('skyengine_api_get_screen_height');
    try {
      getScreenRotation = _lib
          .lookupFunction<
            SkyEngineApiGetScreenRotationC,
            SkyEngineApiGetScreenRotationDart
          >('skyengine_api_get_screen_rotation');
    } catch (_) {
      getScreenRotation = null;
    }
    audioSampleRate = _lib
        .lookupFunction<
          SkyEngineApiAudioSampleRateC,
          SkyEngineApiAudioSampleRateDart
        >('skyengine_api_audio_sample_rate');
    audioChannels = _lib
        .lookupFunction<
          SkyEngineApiAudioChannelsC,
          SkyEngineApiAudioChannelsDart
        >('skyengine_api_audio_channels');
    audioIsActive = _lib
        .lookupFunction<
          SkyEngineApiAudioIsActiveC,
          SkyEngineApiAudioIsActiveDart
        >('skyengine_api_audio_is_active');
    audioRenderS16le = _lib
        .lookupFunction<
          SkyEngineApiAudioRenderS16leC,
          SkyEngineApiAudioRenderS16leDart
        >('skyengine_api_audio_render_s16le');
    audioStop = _lib
        .lookupFunction<SkyEngineApiAudioStopC, SkyEngineApiAudioStopDart>(
          'skyengine_api_audio_stop',
        );
    isEditActive = _lib
        .lookupFunction<
          SkyEngineApiIsEditActiveC,
          SkyEngineApiIsEditActiveDart
        >('skyengine_api_is_edit_active');
    getEditText = _lib
        .lookupFunction<SkyEngineApiGetEditTextC, SkyEngineApiGetEditTextDart>(
          'skyengine_api_get_edit_text',
        );
    setEditText = _lib
        .lookupFunction<SkyEngineApiSetEditTextC, SkyEngineApiSetEditTextDart>(
          'skyengine_api_set_edit_text',
        );
    cancelEdit = _lib
        .lookupFunction<SkyEngineApiCancelEditC, SkyEngineApiCancelEditDart>(
          'skyengine_api_cancel_edit',
        );
  }
}
