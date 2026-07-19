import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

const double _standardGravity = 9.80665;
const int _vmrpMotionRange = 1000;

class SkyEngineMotionSample {
  final int x;
  final int y;
  final int z;

  const SkyEngineMotionSample(this.x, this.y, this.z);

  factory SkyEngineMotionSample.fromAcceleration({
    required double x,
    required double y,
    required double z,
  }) {
    return SkyEngineMotionSample(
      _toVmrpAxis(x),
      _toVmrpAxis(y),
      _toVmrpAxis(z),
    );
  }
}

typedef SkyEngineMotionSampleStreamFactory =
    Stream<SkyEngineMotionSample> Function();

Stream<SkyEngineMotionSample> androidMotionSampleStream() {
  // Android's device axes match VMRP: face-up is +Z and upright is +Y.
  return accelerometerEventStream(
    samplingPeriod: SensorInterval.gameInterval,
  ).map(
    (event) => SkyEngineMotionSample.fromAcceleration(
      x: event.x,
      y: event.y,
      z: event.z,
    ),
  );
}

class SkyEngineMotionBridge {
  final SkyEngineMotionSampleStreamFactory streamFactory;
  final void Function(SkyEngineMotionSample sample) onSample;
  final void Function(Object error, StackTrace stackTrace) onError;

  StreamSubscription<SkyEngineMotionSample>? _subscription;
  int _generation = 0;
  bool _failed = false;
  bool _disposed = false;

  SkyEngineMotionBridge({
    required this.streamFactory,
    required this.onSample,
    required this.onError,
  });

  bool get isListening => _subscription != null;

  void setEnabled(bool enabled) {
    if (_disposed) return;
    if (!enabled) {
      _failed = false;
      _cancelSubscription();
      return;
    }
    if (_subscription != null || _failed) return;

    final generation = ++_generation;
    try {
      _subscription = streamFactory().listen(
        onSample,
        onError: (Object error, StackTrace stackTrace) {
          if (_generation != generation) return;
          _failed = true;
          onError(error, stackTrace);
          _cancelSubscription();
        },
        onDone: () {
          if (_generation == generation) {
            _subscription = null;
          }
        },
      );
    } catch (error, stackTrace) {
      _failed = true;
      onError(error, stackTrace);
      _cancelSubscription();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelSubscription();
  }

  void _cancelSubscription() {
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
  }
}

int _toVmrpAxis(double acceleration) {
  if (!acceleration.isFinite) return 0;
  return (acceleration / _standardGravity * _vmrpMotionRange).round().clamp(
    -_vmrpMotionRange,
    _vmrpMotionRange,
  );
}
