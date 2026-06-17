import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef VmrpApiInitC = Int32 Function(Int32, Int32);
typedef VmrpApiInitDart = int Function(int, int);

typedef VmrpApiSetWorkDirC = Int32 Function(Pointer<Utf8>);
typedef VmrpApiSetWorkDirDart = int Function(Pointer<Utf8>);

typedef VmrpApiStartC =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef VmrpApiStartDart =
    int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef VmrpApiDestroyC = Void Function();
typedef VmrpApiDestroyDart = void Function();

typedef VmrpApiIsRunningC = Int32 Function();
typedef VmrpApiIsRunningDart = int Function();

typedef VmrpApiEventC = Int32 Function(Int32, Int32, Int32);
typedef VmrpApiEventDart = int Function(int, int, int);

typedef VmrpApiTimerC = Int32 Function();
typedef VmrpApiTimerDart = int Function();

typedef VmrpApiGetTimerIntervalC = Int32 Function();
typedef VmrpApiGetTimerIntervalDart = int Function();

typedef VmrpApiGetScreenBufferC = Pointer<Uint16> Function();
typedef VmrpApiGetScreenBufferDart = Pointer<Uint16> Function();

typedef VmrpApiGetScreenDirtyC = Int32 Function();
typedef VmrpApiGetScreenDirtyDart = int Function();

typedef VmrpApiGetScreenWidthC = Int32 Function();
typedef VmrpApiGetScreenWidthDart = int Function();

typedef VmrpApiGetScreenHeightC = Int32 Function();
typedef VmrpApiGetScreenHeightDart = int Function();

typedef VmrpApiAudioSampleRateC = Int32 Function();
typedef VmrpApiAudioSampleRateDart = int Function();

typedef VmrpApiAudioChannelsC = Int32 Function();
typedef VmrpApiAudioChannelsDart = int Function();

typedef VmrpApiAudioIsActiveC = Int32 Function();
typedef VmrpApiAudioIsActiveDart = int Function();

typedef VmrpApiAudioRenderS16leC = Int32 Function(Pointer<Void>, Int32);
typedef VmrpApiAudioRenderS16leDart = int Function(Pointer<Void>, int);

typedef VmrpApiAudioStopC = Void Function();
typedef VmrpApiAudioStopDart = void Function();

typedef VmrpApiIsEditActiveC = Int32 Function();
typedef VmrpApiIsEditActiveDart = int Function();

typedef VmrpApiSetEditTextC = Int32 Function(Pointer<Utf8>);
typedef VmrpApiSetEditTextDart = int Function(Pointer<Utf8>);

typedef VmrpApiCancelEditC = Int32 Function();
typedef VmrpApiCancelEditDart = int Function();

class VmrpBindings {
  late final DynamicLibrary _lib;

  late final VmrpApiInitDart init;
  late final VmrpApiSetWorkDirDart setWorkDir;
  late final VmrpApiStartDart start;
  late final VmrpApiDestroyDart destroy;
  late final VmrpApiIsRunningDart isRunning;
  late final VmrpApiEventDart event;
  late final VmrpApiTimerDart timer;
  late final VmrpApiGetTimerIntervalDart getTimerInterval;
  late final VmrpApiGetScreenBufferDart getScreenBuffer;
  late final VmrpApiGetScreenDirtyDart getScreenDirty;
  late final VmrpApiGetScreenWidthDart getScreenWidth;
  late final VmrpApiGetScreenHeightDart getScreenHeight;
  late final VmrpApiAudioSampleRateDart audioSampleRate;
  late final VmrpApiAudioChannelsDart audioChannels;
  late final VmrpApiAudioIsActiveDart audioIsActive;
  late final VmrpApiAudioRenderS16leDart audioRenderS16le;
  late final VmrpApiAudioStopDart audioStop;
  late final VmrpApiIsEditActiveDart isEditActive;
  late final VmrpApiSetEditTextDart setEditText;
  late final VmrpApiCancelEditDart cancelEdit;

  VmrpBindings() {
    if (Platform.isAndroid || Platform.isLinux) {
      _lib = DynamicLibrary.open('libvmrp.so');
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('vmrp.dll');
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('libvmrp.dylib');
    } else {
      _lib = DynamicLibrary.process();
    }

    init = _lib.lookupFunction<VmrpApiInitC, VmrpApiInitDart>('vmrp_api_init');
    setWorkDir = _lib.lookupFunction<VmrpApiSetWorkDirC, VmrpApiSetWorkDirDart>(
      'vmrp_api_set_work_dir',
    );
    start = _lib.lookupFunction<VmrpApiStartC, VmrpApiStartDart>(
      'vmrp_api_start',
    );
    destroy = _lib.lookupFunction<VmrpApiDestroyC, VmrpApiDestroyDart>(
      'vmrp_api_destroy',
    );
    isRunning = _lib.lookupFunction<VmrpApiIsRunningC, VmrpApiIsRunningDart>(
      'vmrp_api_is_running',
    );
    event = _lib.lookupFunction<VmrpApiEventC, VmrpApiEventDart>(
      'vmrp_api_event',
    );
    timer = _lib.lookupFunction<VmrpApiTimerC, VmrpApiTimerDart>(
      'vmrp_api_timer',
    );
    getTimerInterval = _lib
        .lookupFunction<VmrpApiGetTimerIntervalC, VmrpApiGetTimerIntervalDart>(
          'vmrp_api_get_timer_interval',
        );
    getScreenBuffer = _lib
        .lookupFunction<VmrpApiGetScreenBufferC, VmrpApiGetScreenBufferDart>(
          'vmrp_api_get_screen_buffer',
        );
    getScreenDirty = _lib
        .lookupFunction<VmrpApiGetScreenDirtyC, VmrpApiGetScreenDirtyDart>(
          'vmrp_api_get_screen_dirty',
        );
    getScreenWidth = _lib
        .lookupFunction<VmrpApiGetScreenWidthC, VmrpApiGetScreenWidthDart>(
          'vmrp_api_get_screen_width',
        );
    getScreenHeight = _lib
        .lookupFunction<VmrpApiGetScreenHeightC, VmrpApiGetScreenHeightDart>(
          'vmrp_api_get_screen_height',
        );
    audioSampleRate = _lib
        .lookupFunction<VmrpApiAudioSampleRateC, VmrpApiAudioSampleRateDart>(
          'vmrp_api_audio_sample_rate',
        );
    audioChannels = _lib
        .lookupFunction<VmrpApiAudioChannelsC, VmrpApiAudioChannelsDart>(
          'vmrp_api_audio_channels',
        );
    audioIsActive = _lib
        .lookupFunction<VmrpApiAudioIsActiveC, VmrpApiAudioIsActiveDart>(
          'vmrp_api_audio_is_active',
        );
    audioRenderS16le = _lib
        .lookupFunction<VmrpApiAudioRenderS16leC, VmrpApiAudioRenderS16leDart>(
          'vmrp_api_audio_render_s16le',
        );
    audioStop = _lib.lookupFunction<VmrpApiAudioStopC, VmrpApiAudioStopDart>(
      'vmrp_api_audio_stop',
    );
    isEditActive = _lib
        .lookupFunction<VmrpApiIsEditActiveC, VmrpApiIsEditActiveDart>(
          'vmrp_api_is_edit_active',
        );
    setEditText = _lib
        .lookupFunction<VmrpApiSetEditTextC, VmrpApiSetEditTextDart>(
          'vmrp_api_set_edit_text',
        );
    cancelEdit = _lib.lookupFunction<VmrpApiCancelEditC, VmrpApiCancelEditDart>(
      'vmrp_api_cancel_edit',
    );
  }
}
