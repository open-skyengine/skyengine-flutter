import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/android_mrp_open.dart';

void main() {
  test('MRP open request parses legacy string path', () {
    final request = MrpOpenRequest.fromArguments('/tmp/demo.mrp');

    expect(request?.path, '/tmp/demo.mrp');
    expect(request?.resolution, isNull);
  });

  test('MRP open request parses resolution argument', () {
    final request = MrpOpenRequest.fromArguments({
      'path': '/tmp/demo.mrp',
      'resolution': '320x480',
    });

    expect(request?.path, '/tmp/demo.mrp');
    expect(request?.screenWidth, 320);
    expect(request?.screenHeight, 480);
  });

  test('MRP open request falls back to width and height arguments', () {
    final request = MrpOpenRequest.fromArguments({
      'path': '/tmp/demo.mrp',
      'width': 128,
      'height': 160,
    });

    expect(request?.resolution, '128x160');
    expect(request?.screenWidth, 128);
    expect(request?.screenHeight, 160);
  });
}
