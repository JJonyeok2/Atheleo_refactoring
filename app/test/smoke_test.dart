import 'package:atheleo/app/env.dart';
import 'package:atheleo/main.dart';
import 'package:dio/dio.dart' as dio;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' as go_router;

void main() {
  testWidgets('앱이 빌드됨: 루트 위젯을 띄우면 MaterialApp이 하나 존재한다', (tester) async {
    await tester.pumpWidget(
      const riverpod.ProviderScope(child: AtheleoApp()),
    );
    await tester.pumpAndSettle();

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

  group('bootstrap', () {
    testWidgets('잘못된 설정(릴리스 + http)이면 StateError를 내고 앱을 띄우지 않는다', (
      tester,
    ) async {
      Widget? launched;

      await expectLater(
        bootstrap(
          env: const AppEnv(
            apiBaseUrl: 'http://example.com',
            sentryDsn: '',
            isRelease: true,
          ),
          run: (app) => launched = app,
        ),
        throwsStateError,
      );
      expect(launched, isNull);
    });

    testWidgets('올바른 설정이면 ProviderScope로 감싼 AtheleoApp을 띄운다', (
      tester,
    ) async {
      Widget? launched;

      // SystemChrome 플랫폼 호출은 실제 비동기로 끝나므로 runAsync로 감싼다.
      await tester.runAsync(
        () => bootstrap(
          env: const AppEnv(
            apiBaseUrl: 'https://api.example.com',
            sentryDsn: '',
            isRelease: true,
          ),
          run: (app) => launched = app,
        ),
      );

      expect(launched, isA<riverpod.ProviderScope>());
      expect((launched! as riverpod.ProviderScope).child, isA<AtheleoApp>());
    });
  });
}
