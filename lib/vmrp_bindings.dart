import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _VmrpApiInitC = Int32 Function(Int32, Int32);
typedef _VmrpApiInitDart = int Function(int, int);

typedef _VmrpApiStartC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _VmrpApiStartDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef _VmrpApiDestroyC = Void Function();
typedef _VmrpApiDestroyDart = void Function();

typedef _VmrpApiEventC = Int32 Function(Int32, Int32, Int32);
typedef _VmrpApiEventDart = int Function(int, int, int);

typedef _VmrpApiTimerC = Int32 Function();
typedef _VmrpApiTimerDart = int Function();

typedef _VmrpApiGetTimerIntervalC = Int32 Function();
typedef _VmrpApiGetTimerIntervalDart = int Function();

typedef _VmrpApiGetScreenBufferC = Pointer<Uint16> Function();
typedef _VmrpApiGetScreenBufferDart = Pointer<Uint16> Function();

typedef _VmrpApiGetScreenDirtyC = Int32 Function();
typedef _VmrpApiGetScreenDirtyDart = int Function();

typedef _VmrpApiGetScreenWidthC = Int32 Function();
typedef _VmrpApiGetScreenWidthDart = int Function();

typedef _VmrpApiGetScreenHeightC = Int32 Function();
typedef _VmrpApiGetScreenHeightDart = int Function();

typedef _VmrpApiIsEditActiveC = Int32 Function();
typedef _VmrpApiIsEditActiveDart = int Function();

typedef _VmrpApiSetEditTextC = Int32 Function(Pointer<Utf8>);
typedef _VmrpApiSetEditTextDart = int Function(Pointer<Utf8>);

typedef _VmrpApiCancelEditC = Int32 Function();
typedef _VmrpApiCancelEditDart = int Function();

class VmrpBindings {
  late final DynamicLibrary _lib;

  late final _VmrpApiInitDart init;
  late final _VmrpApiStartDart start;
  late final _VmrpApiDestroyDart destroy;
  late final _VmrpApiEventDart event;
  late final _VmrpApiTimerDart timer;
  late final _VmrpApiGetTimerIntervalDart getTimerInterval;
  late final _VmrpApiGetScreenBufferDart getScreenBuffer;
  late final _VmrpApiGetScreenDirtyDart getScreenDirty;
  late final _VmrpApiGetScreenWidthDart getScreenWidth;
  late final _VmrpApiGetScreenHeightDart getScreenHeight;
  late final _VmrpApiIsEditActiveDart isEditActive;
  late final _VmrpApiSetEditTextDart setEditText;
  late final _VmrpApiCancelEditDart cancelEdit;

  VmrpBindings() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libvmrp.so')
        : DynamicLibrary.process();

    init = _lib.lookupFunction<_VmrpApiInitC, _VmrpApiInitDart>('vmrp_api_init');
    start = _lib.lookupFunction<_VmrpApiStartC, _VmrpApiStartDart>('vmrp_api_start');
    destroy = _lib.lookupFunction<_VmrpApiDestroyC, _VmrpApiDestroyDart>('vmrp_api_destroy');
    event = _lib.lookupFunction<_VmrpApiEventC, _VmrpApiEventDart>('vmrp_api_event');
    timer = _lib.lookupFunction<_VmrpApiTimerC, _VmrpApiTimerDart>('vmrp_api_timer');
    getTimerInterval = _lib.lookupFunction<_VmrpApiGetTimerIntervalC, _VmrpApiGetTimerIntervalDart>('vmrp_api_get_timer_interval');
    getScreenBuffer = _lib.lookupFunction<_VmrpApiGetScreenBufferC, _VmrpApiGetScreenBufferDart>('vmrp_api_get_screen_buffer');
    getScreenDirty = _lib.lookupFunction<_VmrpApiGetScreenDirtyC, _VmrpApiGetScreenDirtyDart>('vmrp_api_get_screen_dirty');
    getScreenWidth = _lib.lookupFunction<_VmrpApiGetScreenWidthC, _VmrpApiGetScreenWidthDart>('vmrp_api_get_screen_width');
    getScreenHeight = _lib.lookupFunction<_VmrpApiGetScreenHeightC, _VmrpApiGetScreenHeightDart>('vmrp_api_get_screen_height');
    isEditActive = _lib.lookupFunction<_VmrpApiIsEditActiveC, _VmrpApiIsEditActiveDart>('vmrp_api_is_edit_active');
    setEditText = _lib.lookupFunction<_VmrpApiSetEditTextC, _VmrpApiSetEditTextDart>('vmrp_api_set_edit_text');
    cancelEdit = _lib.lookupFunction<_VmrpApiCancelEditC, _VmrpApiCancelEditDart>('vmrp_api_cancel_edit');
  }
}
