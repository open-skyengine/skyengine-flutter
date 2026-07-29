import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/widgets/virtual_joystick.dart';

void main() {
  testWidgets('confirm button is circular and emits a complete key press', (
    tester,
  ) async {
    final events = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: VirtualJoystickConfirmButton(
            onPressed: () => events.add('down'),
            onReleased: () => events.add('up'),
          ),
        ),
      ),
    );

    final button = find.byKey(
      const ValueKey('virtual-joystick-confirm-button'),
    );
    expect(tester.getSize(button), const Size.square(84));

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(of: button, matching: find.byType(DecoratedBox)),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);

    await tester.tap(button);
    expect(events, ['down', 'up']);
  });

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

  testWidgets('joystick reasserts up after rotating clockwise from left', (
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
    await gesture.moveTo(center + const Offset(-60, 0));
    await gesture.moveTo(center + const Offset(-45, -45));
    await gesture.moveTo(center + const Offset(0, -60));
    await gesture.up();
    await tester.pump();

    expect(events, [
      'down:${JoystickDirection.left}',
      'down:${JoystickDirection.up}',
      'up:${JoystickDirection.left}',
      'up:${JoystickDirection.up}',
      'down:${JoystickDirection.up}',
      'up:${JoystickDirection.up}',
    ]);
  });

  testWidgets('joystick engages the opposite direction inside the dead zone', (
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
    await gesture.moveTo(center + const Offset(-60, 0));
    await gesture.moveTo(center);
    await gesture.moveTo(center + const Offset(10, 0));
    await gesture.moveTo(center + const Offset(18, 0));
    await gesture.up();
    await tester.pump();

    expect(events, [
      'down:${JoystickDirection.left}',
      'up:${JoystickDirection.left}',
      'down:${JoystickDirection.right}',
      'up:${JoystickDirection.right}',
    ]);
  });

  testWidgets('joystick directly switches between opposite directions', (
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
    await gesture.moveTo(center + const Offset(-60, 0));
    await gesture.moveTo(center + const Offset(60, 0));
    await gesture.up();
    await tester.pump();

    expect(events, [
      'down:${JoystickDirection.left}',
      'up:${JoystickDirection.left}',
      'down:${JoystickDirection.right}',
      'up:${JoystickDirection.right}',
    ]);
  });

  testWidgets('joystick ignores near-center input without a prior direction', (
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
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(10, 0));
    await gesture.up();
    await tester.pump();

    expect(events, isEmpty);
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
