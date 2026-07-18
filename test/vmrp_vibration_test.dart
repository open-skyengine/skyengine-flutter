import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/vmrp/vmrp_vibration.dart';

void main() {
  test('positive requests vibrate for the requested duration', () async {
    final durations = <int>[];
    var cancelCount = 0;
    final controller = VmrpVibrationController(
      vibrate: (durationMs) async => durations.add(durationMs),
      cancel: () async => cancelCount++,
    );

    await controller.handleRequest(750);

    expect(durations, [750]);
    expect(cancelCount, 0);
  });

  test('negative requests cancel and zero requests do nothing', () async {
    final durations = <int>[];
    var cancelCount = 0;
    final controller = VmrpVibrationController(
      vibrate: (durationMs) async => durations.add(durationMs),
      cancel: () async => cancelCount++,
    );

    await controller.handleRequest(-1);
    await controller.handleRequest(0);

    expect(durations, isEmpty);
    expect(cancelCount, 1);
  });

  test('explicit cancellation always stops the platform vibrator', () async {
    var cancelCount = 0;
    final controller = VmrpVibrationController(
      vibrate: (_) async {},
      cancel: () async => cancelCount++,
    );

    await controller.cancel();

    expect(cancelCount, 1);
  });
}
