import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // flutter test는 패키지 루트(app/)를 작업 디렉터리로 실행한다.
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  group('main AndroidManifest', () {
    test('INTERNET 권한이 있다 (릴리스 네트워크 요청용)', () {
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.INTERNET"/>',
        ),
      );
    });

    test('CAMERA 권한이 있다', () {
      expect(
        manifest,
        contains('<uses-permission android:name="android.permission.CAMERA"/>'),
      );
    });

    test('cleartext 통신을 막는다', () {
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
    });

    test('세로 화면으로 고정한다', () {
      expect(manifest, contains('android:screenOrientation="portrait"'));
    });
  });
}
