import 'dart:async';
import 'dart:ffi';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'skyengine_bindings.dart';

class SkyEngineAudioPlayer {
  static const int _framesPerChunk = 2048;
  static const int _startupChunks = 3;
  static const int _maxChunksPerPump = 8;
  static const Duration _minPumpInterval = Duration(milliseconds: 10);
  static const Duration _lowBufferDuration = Duration(milliseconds: 120);
  static const Duration _targetBufferDuration = Duration(milliseconds: 260);
  static const Duration _idleInterval = Duration(milliseconds: 120);
  static const Duration _maxBufferDuration = Duration(seconds: 3);

  final SkyEngineBindings bindings;
  final SoLoud _soloud;

  AudioSource? _source;
  SoundHandle? _handle;
  Timer? _pumpTimer;
  Pointer<Uint8>? _nativeChunk;
  Uint8List? _dartChunk;
  int _chunkBytes = 0;
  int _sampleRate = 0;
  int _channels = 0;
  int _queuedFramesEstimate = 0;
  DateTime? _lastPumpAt;
  bool _starting = false;
  bool _pumping = false;
  bool _disposed = false;
  int _startEpoch = 0;

  String? lastError;

  SkyEngineAudioPlayer({required this.bindings, SoLoud? soloud})
    : _soloud = soloud ?? SoLoud.instance;

  void wake() {
    if (_disposed) return;
    if (_source != null) {
      _pump();
    } else if (bindings.audioIsActive() != 0) {
      unawaited(_ensureStarted());
    }
  }

  Future<void> stop() async {
    _pumpTimer?.cancel();
    _pumpTimer = null;
    _starting = false;
    _startEpoch++;

    try {
      bindings.audioStop();
    } catch (e) {
      lastError = 'vmrp_api_audio_stop failed: $e';
    }

    final handle = _handle;
    _handle = null;
    final source = _source;
    _source = null;
    _sampleRate = 0;
    _channels = 0;
    _resetBufferEstimate();

    if (_soloud.isInitialized) {
      if (handle != null) {
        try {
          await _soloud.stop(handle);
        } catch (e) {
          lastError = 'SoLoud stop failed: $e';
        }
      }
      if (source != null) {
        try {
          await _soloud.disposeSource(source);
        } catch (e) {
          lastError = 'SoLoud disposeSource failed: $e';
        }
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    final chunk = _nativeChunk;
    if (chunk != null) {
      malloc.free(chunk);
      _nativeChunk = null;
    }
    _dartChunk = null;
  }

  Future<void> _ensureStarted() async {
    if (_disposed || _source != null || _starting) return;
    _starting = true;
    final epoch = _startEpoch;
    try {
      final sampleRate = bindings.audioSampleRate();
      final channels = bindings.audioChannels();
      if (sampleRate <= 0 || channels <= 0) {
        lastError = 'Invalid VMRP audio format: ${sampleRate}Hz/$channels';
        _schedule(_idleInterval);
        return;
      }
      _sampleRate = sampleRate;
      _channels = channels;

      if (!_soloud.isInitialized) {
        await _soloud.init(
          sampleRate: sampleRate,
          bufferSize: _framesPerChunk,
          channels: channels == 1 ? Channels.mono : Channels.stereo,
        );
      }
      if (_disposed || epoch != _startEpoch || bindings.audioIsActive() == 0) {
        return;
      }

      final source = _soloud.setBufferStream(
        maxBufferSizeDuration: _maxBufferDuration,
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.05,
        sampleRate: sampleRate,
        channels: channels == 1 ? Channels.mono : Channels.stereo,
        format: BufferType.s16le,
      );

      _source = source;
      _resetBufferEstimate();
      _ensureChunkBuffer(channels);
      var queuedFrames = 0;
      for (var i = 0; i < _startupChunks; i++) {
        final frames = _readAndQueue(source, channels);
        if (frames <= 0) break;
        queuedFrames += frames;
        if (bindings.audioIsActive() == 0) break;
      }
      if (queuedFrames <= 0) {
        _finishStream(source);
        return;
      }

      _handle = _soloud.play(source);
      if (_disposed || epoch != _startEpoch || bindings.audioIsActive() == 0) {
        if (bindings.audioIsActive() == 0) {
          _finishStream(source);
        } else {
          await stop();
        }
        return;
      }
      _pump();
    } catch (e) {
      lastError = 'Audio init failed: $e';
      debugPrint('[VMRP] $lastError');
      await stop();
      if (!_disposed && bindings.audioIsActive() != 0) {
        _schedule(_idleInterval);
      }
    } finally {
      _starting = false;
    }
  }

  void _ensureChunkBuffer(int channels) {
    final bytes = _framesPerChunk * channels * sizeOf<Int16>();
    if (_nativeChunk == null || _chunkBytes != bytes) {
      final oldChunk = _nativeChunk;
      if (oldChunk != null) {
        malloc.free(oldChunk);
      }
      _nativeChunk = malloc.allocate<Uint8>(bytes);
      _dartChunk = Uint8List(bytes);
      _chunkBytes = bytes;
    }
  }

  int _readAndQueue(AudioSource source, int channels) {
    final nativeChunk = _nativeChunk;
    final dartChunk = _dartChunk;
    if (nativeChunk == null || dartChunk == null) return 0;

    final frames = bindings.audioRenderS16le(
      nativeChunk.cast<Void>(),
      _framesPerChunk,
    );
    if (frames <= 0) return 0;

    final byteCount = frames * channels * sizeOf<Int16>();
    dartChunk.setRange(0, byteCount, nativeChunk.asTypedList(byteCount));
    _soloud.addAudioDataStream(
      source,
      Uint8List.sublistView(dartChunk, 0, byteCount),
    );
    _queuedFramesEstimate += frames;
    return frames;
  }

  void _pump() {
    if (_disposed) return;
    final source = _source;
    final nativeChunk = _nativeChunk;
    final dartChunk = _dartChunk;
    if (source == null || nativeChunk == null || dartChunk == null) {
      _schedule(_idleInterval);
      return;
    }

    if (_pumping) return;
    _pumping = true;
    try {
      if (bindings.audioIsActive() == 0) {
        _finishStream(source);
        return;
      }

      final sampleRate = _sampleRate > 0
          ? _sampleRate
          : bindings.audioSampleRate();
      final channels = _channels > 0 ? _channels : bindings.audioChannels();
      if (sampleRate <= 0 || channels <= 0) {
        _finishStream(source);
        return;
      }

      final targetFrames = _durationToFrames(_targetBufferDuration, sampleRate);
      var queuedFrames = _bufferedFrames(source, sampleRate, channels);
      var queuedChunks = 0;

      while (queuedFrames < targetFrames && queuedChunks < _maxChunksPerPump) {
        final frames = _readAndQueue(source, channels);
        if (frames <= 0) {
          _finishStream(source);
          return;
        }
        queuedFrames += frames;
        queuedChunks++;
        if (bindings.audioIsActive() == 0) {
          _finishStream(source);
          return;
        }
      }

      final currentFrames = _bufferedFrames(source, sampleRate, channels);
      _schedule(_nextPumpInterval(currentFrames, sampleRate));
    } catch (e) {
      lastError = 'Audio pump failed: $e';
      debugPrint('[VMRP] $lastError');
      unawaited(stop());
      _schedule(_idleInterval);
    } finally {
      _pumping = false;
    }
  }

  void _finishStream(AudioSource source) {
    _pumpTimer?.cancel();
    _pumpTimer = null;
    try {
      _soloud.setDataIsEnded(source);
    } catch (_) {
      // The stream may already be ended by SoLoud when the buffer is drained.
    }
    _handle = null;
    _source = null;
    _sampleRate = 0;
    _channels = 0;
    _resetBufferEstimate();
    unawaited(
      source.allInstancesFinished.first
          .then((_) async {
            if (_soloud.isInitialized) {
              await _soloud.disposeSource(source);
            }
          })
          .catchError((Object _) {}),
    );
  }

  void _schedule(Duration interval) {
    if (_disposed) return;
    _pumpTimer?.cancel();
    _pumpTimer = Timer(interval, () {
      if (_source != null) {
        _pump();
      } else if (bindings.audioIsActive() != 0) {
        unawaited(_ensureStarted());
      }
    });
  }

  int? _safeBufferSize(AudioSource source) {
    try {
      return _soloud.getBufferSize(source);
    } catch (_) {
      return null;
    }
  }

  int _bufferedFrames(AudioSource source, int sampleRate, int channels) {
    final reportedBytes = _safeBufferSize(source);
    if (reportedBytes != null) {
      final reportedFrames = _soloudBufferBytesToFrames(
        reportedBytes,
        channels,
      );
      _syncEstimate(reportedFrames);
      return reportedFrames;
    }

    _decayQueuedEstimate(sampleRate);
    return _queuedFramesEstimate;
  }

  int _soloudBufferBytesToFrames(int bytes, int channels) {
    final bytesPerFrame = channels * sizeOf<Float>();
    if (bytesPerFrame <= 0) return 0;
    return bytes ~/ bytesPerFrame;
  }

  void _syncEstimate(int frames) {
    _queuedFramesEstimate = frames;
    _lastPumpAt = DateTime.now();
  }

  void _decayQueuedEstimate(int sampleRate) {
    final now = DateTime.now();
    final lastPumpAt = _lastPumpAt;
    _lastPumpAt = now;
    if (lastPumpAt == null || sampleRate <= 0) return;

    final elapsedMicros = now.difference(lastPumpAt).inMicroseconds;
    final consumedFrames =
        elapsedMicros * sampleRate ~/ Duration.microsecondsPerSecond;
    _queuedFramesEstimate = math.max(0, _queuedFramesEstimate - consumedFrames);
  }

  void _resetBufferEstimate() {
    _queuedFramesEstimate = 0;
    _lastPumpAt = null;
  }

  int _durationToFrames(Duration duration, int sampleRate) {
    return duration.inMicroseconds *
        sampleRate ~/
        Duration.microsecondsPerSecond;
  }

  Duration _framesToDuration(int frames, int sampleRate) {
    if (sampleRate <= 0) return _minPumpInterval;
    final micros = frames * Duration.microsecondsPerSecond ~/ sampleRate;
    return Duration(microseconds: micros);
  }

  Duration _nextPumpInterval(int queuedFrames, int sampleRate) {
    final queuedDuration = _framesToDuration(queuedFrames, sampleRate);
    if (queuedDuration <= _lowBufferDuration) {
      return _minPumpInterval;
    }

    final waitMicros =
        queuedDuration.inMicroseconds - _lowBufferDuration.inMicroseconds;
    if (waitMicros <= _minPumpInterval.inMicroseconds) {
      return _minPumpInterval;
    }
    return Duration(microseconds: waitMicros);
  }
}
