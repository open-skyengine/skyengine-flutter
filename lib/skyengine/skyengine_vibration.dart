typedef SkyEngineVibrate = Future<void> Function(int durationMs);
typedef SkyEngineCancelVibration = Future<void> Function();

class SkyEngineVibrationController {
  const SkyEngineVibrationController({
    required SkyEngineVibrate vibrate,
    required SkyEngineCancelVibration cancel,
  }) : _vibrate = vibrate,
       _cancel = cancel;

  final SkyEngineVibrate _vibrate;
  final SkyEngineCancelVibration _cancel;

  Future<void> handleRequest(int request) async {
    if (request > 0) {
      await _vibrate(request);
    } else if (request < 0) {
      await _cancel();
    }
  }

  Future<void> cancel() => _cancel();
}
