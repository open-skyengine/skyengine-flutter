import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/widgets/virtual_joystick.dart';

void main() {
  testWidgets('joystick changes and releases directions while dragging', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: VirtualJoystick(
            onDirectionPressed: (direction) => events.add('down:$direction'),
            onDirectionReleased: (direction) => events.add('up:$direction'),
          ),
        ),
      ),
    );

    final joystick = find.byKey(const ValueKey('virtual-joystick'));
    final center = tester.getCenter(joystick);
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(60, 0));
    await tester.pump();
    await gesture.moveTo(center + const Offset(0, -60));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(events, [
      'down:${JoystickDirection.right}',
      'up:${JoystickDirection.right}',
      'down:${JoystickDirection.up}',
      'up:${JoystickDirection.up}',
    ]);
  });

  testWidgets('joystick supports diagonal input and releases on cancel', (
    tester,
  ) async {
    final pressed = <JoystickDirection>[];
    final released = <JoystickDirection>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: VirtualJoystick(
            onDirectionPressed: pressed.add,
            onDirectionReleased: released.add,
          ),
        ),
      ),
    );

    final joystick = find.byKey(const ValueKey('virtual-joystick'));
    final center = tester.getCenter(joystick);
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(55, -55));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();

    expect(
      pressed,
      containsAll([JoystickDirection.right, JoystickDirection.up]),
    );
    expect(
      released,
      containsAll([JoystickDirection.right, JoystickDirection.up]),
    );
    expect(released, hasLength(2));
  });

  testWidgets('joystick dead zone does not emit direction events', (
    tester,
  ) async {
    final events = <JoystickDirection>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: VirtualJoystick(
            onDirectionPressed: events.add,
            onDirectionReleased: events.add,
          ),
        ),
      ),
    );

    final joystick = find.byKey(const ValueKey('virtual-joystick'));
    final center = tester.getCenter(joystick);
    final gesture = await tester.startGesture(center + const Offset(10, 10));
    await gesture.up();
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets('joystick releases held directions when removed', (tester) async {
    final pressed = <JoystickDirection>[];
    final released = <JoystickDirection>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: VirtualJoystick(
            onDirectionPressed: pressed.add,
            onDirectionReleased: released.add,
          ),
        ),
      ),
    );

    final joystick = find.byKey(const ValueKey('virtual-joystick'));
    final center = tester.getCenter(joystick);
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(-60, 0));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(pressed, [JoystickDirection.left]);
    expect(released, [JoystickDirection.left]);
    await gesture.removePointer();
  });
}
