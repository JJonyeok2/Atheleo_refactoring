import 'package:atheleo/main.dart';
import 'package:dio/dio.dart' as dio;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' as go_router;

void main() {
  testWidgets('앱이 빌드됨: 루트 위젯을 띄우면 MaterialApp이 하나 존재한다', (tester) async {
    await tester.pumpWidget(const AtheleoApp());

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('의존성 import 확인: 핵심 패키지 타입을 참조할 수 있다', () {
    // 컴파일이 되면 의존성이 해석된 것이다. 타입 참조로 import가 실제로 쓰이게 한다.
    expect(
      <Type>[
        riverpod.ProviderScope,
        go_router.GoRouter,
        dio.Dio,
        drift.GeneratedDatabase,
      ],
      hasLength(4),
    );
  });
}
