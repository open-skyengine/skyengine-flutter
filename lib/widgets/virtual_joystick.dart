import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum JoystickDirection { up, down, left, right }

class VirtualJoystickConfirmButton extends StatelessWidget {
  final double size;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  const VirtualJoystickConfirmButton({
    super.key,
    required this.onPressed,
    required this.onReleased,
    this.size = 84,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '确定',
      child: GestureDetector(
        key: const ValueKey('virtual-joystick-confirm-button'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPressed(),
        onTapUp: (_) => onReleased(),
        onTapCancel: onReleased,
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child: const Center(
              child: Text('确定', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

class VirtualJoystick extends StatefulWidget {
  final double size;
  final ValueChanged<JoystickDirection> onDirectionPressed;
  final ValueChanged<JoystickDirection> onDirectionReleased;

  const VirtualJoystick({
    super.key,
    required this.onDirectionPressed,
    required this.onDirectionReleased,
    this.size = 152,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  static const double _deadZoneRatio = 0.14;
  static const double _oppositeDirectionSwitchRatio = 0.05;
  static const double _diagonalAxisRatio = 0.42;
  static const double _knobTravelRatio = 0.25;

  int? _activePointer;
  Offset _knobOffset = Offset.zero;
  Set<JoystickDirection> _pressedDirections = const {};
  JoystickDirection? _lastHorizontalDirection;
  JoystickDirection? _lastVerticalDirection;

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) {
      return;
    }
    _activePointer = event.pointer;
    _updateForPosition(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _updateForPosition(event.localPosition);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _activePointer = null;
    _updateDirections(const {});
    _lastHorizontalDirection = null;
    _lastVerticalDirection = null;
    if (mounted) {
      setState(() => _knobOffset = Offset.zero);
    }
  }

  void _updateForPosition(Offset position) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = position - center;
    final distance = delta.distance;
    final maxTravel = widget.size * _knobTravelRatio;
    final knobOffset = distance > maxTravel && distance > 0
        ? delta * (maxTravel / distance)
        : delta;

    _updateDirections(_directionsForDelta(delta));
    setState(() => _knobOffset = knobOffset);
  }

  Set<JoystickDirection> _directionsForDelta(Offset delta) {
    final horizontal = delta.dx.abs();
    final vertical = delta.dy.abs();
    final directions = <JoystickDirection>{};
    final isOutsideDeadZone = delta.distance > widget.size * _deadZoneRatio;

    if (isOutsideDeadZone) {
      if (horizontal >= vertical * _diagonalAxisRatio) {
        directions.add(
          delta.dx < 0 ? JoystickDirection.left : JoystickDirection.right,
        );
      }
      if (vertical >= horizontal * _diagonalAxisRatio) {
        directions.add(
          delta.dy < 0 ? JoystickDirection.up : JoystickDirection.down,
        );
      }
    } else {
      // A reversal necessarily crosses the dead zone. Remember the previous
      // axis so the opposite direction can engage before leaving it again.
      final switchThreshold = widget.size * _oppositeDirectionSwitchRatio;
      if (horizontal >= vertical * _diagonalAxisRatio &&
          horizontal >= switchThreshold) {
        final direction = delta.dx < 0
            ? JoystickDirection.left
            : JoystickDirection.right;
        if (_shouldEngageInsideDeadZone(direction, _lastHorizontalDirection)) {
          directions.add(direction);
        }
      }
      if (vertical >= horizontal * _diagonalAxisRatio &&
          vertical >= switchThreshold) {
        final direction = delta.dy < 0
            ? JoystickDirection.up
            : JoystickDirection.down;
        if (_shouldEngageInsideDeadZone(direction, _lastVerticalDirection)) {
          directions.add(direction);
        }
      }
    }

    _rememberDirections(directions);
    return directions;
  }

  bool _shouldEngageInsideDeadZone(
    JoystickDirection direction,
    JoystickDirection? lastDirection,
  ) {
    return _pressedDirections.contains(direction) ||
        (lastDirection != null && direction != lastDirection);
  }

  void _rememberDirections(Set<JoystickDirection> directions) {
    for (final direction in directions) {
      switch (direction) {
        case JoystickDirection.left:
        case JoystickDirection.right:
          _lastHorizontalDirection = direction;
        case JoystickDirection.up:
        case JoystickDirection.down:
          _lastVerticalDirection = direction;
      }
    }
  }

  void _updateDirections(Set<JoystickDirection> directions) {
    if (setEquals(_pressedDirections, directions)) {
      return;
    }

    final previousDirections = _pressedDirections;
    _pressedDirections = Set.unmodifiable(directions);
    final removedDirections = previousDirections.difference(directions);
    final retainedDirections = previousDirections.intersection(directions);
    final replacesOverlappingState =
        removedDirections.isNotEmpty && retainedDirections.isNotEmpty;

    // Some MRP runtimes clear their current direction on any key-up event.
    // Replace an overlapping combination so retained keys are asserted last.
    final directionsToRelease = replacesOverlappingState
        ? previousDirections
        : removedDirections;
    final directionsToPress = replacesOverlappingState
        ? directions
        : directions.difference(previousDirections);
    for (final direction in directionsToRelease) {
      widget.onDirectionReleased(direction);
    }
    for (final direction in directionsToPress) {
      widget.onDirectionPressed(direction);
    }
  }

  void _releaseAllDirections() {
    for (final direction in _pressedDirections) {
      widget.onDirectionReleased(direction);
    }
    _pressedDirections = const {};
  }

  @override
  void dispose() {
    _releaseAllDirections();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final knobSize = widget.size * 0.38;

    return Semantics(
      label: '方向摇杆',
      child: Listener(
        key: const ValueKey('virtual-joystick'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
        child: SizedBox.square(
          dimension: widget.size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.outline, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _directionIcon(Icons.keyboard_arrow_up, Alignment.topCenter),
                _directionIcon(
                  Icons.keyboard_arrow_down,
                  Alignment.bottomCenter,
                ),
                _directionIcon(Icons.keyboard_arrow_left, Alignment.centerLeft),
                _directionIcon(
                  Icons.keyboard_arrow_right,
                  Alignment.centerRight,
                ),
                Transform.translate(
                  offset: _knobOffset,
                  child: Container(
                    key: const ValueKey('virtual-joystick-knob'),
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.secondaryContainer,
                      border: Border.all(
                        color: colorScheme.onSecondaryContainer.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _directionIcon(IconData icon, Alignment alignment) {
    final inset = math.max(2.0, widget.size * 0.025);
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: Align(
          alignment: alignment,
          child: Icon(icon, size: widget.size * 0.2, color: Colors.white54),
        ),
      ),
    );
  }
}
