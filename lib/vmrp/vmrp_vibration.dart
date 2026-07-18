typedef VmrpVibrate = Future<void> Function(int durationMs);
typedef VmrpCancelVibration = Future<void> Function();

class VmrpVibrationController {
  const VmrpVibrationController({
    required VmrpVibrate vibrate,
    required VmrpCancelVibration cancel,
  }) : _vibrate = vibrate,
       _cancel = cancel;

  final VmrpVibrate _vibrate;
  final VmrpCancelVibration _cancel;

  Future<void> handleRequest(int request) async {
    if (request > 0) {
      await _vibrate(request);
    } else if (request < 0) {
      await _cancel();
    }
  }

  Future<void> cancel() => _cancel();
}
