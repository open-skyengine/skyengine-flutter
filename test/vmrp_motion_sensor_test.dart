import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/vmrp/vmrp_motion_sensor.dart';

void main() {
  test('motion samples use the VMRP gravity range and Android axes', () {
    final sample = VmrpMotionSample.fromAcceleration(
      x: 9.80665,
      y: -4.903325,
      z: 9.80665,
    );

    expect(sample.x, 1000);
    expect(sample.y, -500);
    expect(sample.z, 1000);
  });

  test('motion samples clamp over-range and invalid sensor values', () {
    final sample = VmrpMotionSample.fromAcceleration(
      x: 19.6133,
      y: double.negativeInfinity,
      z: -19.6133,
    );

    expect(sample.x, 1000);
    expect(sample.y, 0);
    expect(sample.z, -1000);
  });

  test('motion bridge subscribes only while the guest listener is active', () {
    final controller = StreamController<VmrpMotionSample>.broadcast(sync: true);
    final received = <VmrpMotionSample>[];
    var subscriptions = 0;
    final bridge = VmrpMotionBridge(
      streamFactory: () {
        subscriptions++;
        return controller.stream;
      },
      onSample: received.add,
      onError: (error, stackTrace) => fail('Unexpected sensor error: $error'),
    );
    addTearDown(() async {
      bridge.dispose();
      await controller.close();
    });

    bridge.setEnabled(true);
    bridge.setEnabled(true);
    controller.add(const VmrpMotionSample(1, 2, 3));

    expect(subscriptions, 1);
    expect(bridge.isListening, isTrue);
    expect(received.single.x, 1);

    bridge.setEnabled(false);
    expect(bridge.isListening, isFalse);

    bridge.setEnabled(true);
    expect(subscriptions, 2);
    expect(bridge.isListening, isTrue);
  });

  test('motion bridge stops retrying after a platform sensor error', () {
    final controller = StreamController<VmrpMotionSample>.broadcast(sync: true);
    final errors = <Object>[];
    var subscriptions = 0;
    final bridge = VmrpMotionBridge(
      streamFactory: () {
        subscriptions++;
        return controller.stream;
      },
      onSample: (_) {},
      onError: (error, stackTrace) => errors.add(error),
    );
    addTearDown(() async {
      bridge.dispose();
      await controller.close();
    });

    bridge.setEnabled(true);
    controller.addError(StateError('sensor unavailable'));
    bridge.setEnabled(true);

    expect(errors, hasLength(1));
    expect(subscriptions, 1);
    expect(bridge.isListening, isFalse);

    bridge.setEnabled(false);
    bridge.setEnabled(true);
    expect(subscriptions, 2);
  });
}
