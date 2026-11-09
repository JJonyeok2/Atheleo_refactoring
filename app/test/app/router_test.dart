import 'package:atheleo/app/placeholder_screen.dart';
import 'package:atheleo/app/router.dart';
import 'package:atheleo/app/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required bool enableDevMenu,
}) async {
  final router = buildRouter(enableDevMenu: enableDevMenu);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

String _placeholderTitle(WidgetTester tester) =>
    tester.widget<PlaceholderScreen>(find.byType(PlaceholderScreen)).title;

void main() {
  testWidgets('홈 경로: / 에서 PlaceholderScreen이 보인다', (tester) async {
    await _pumpRouter(tester, enableDevMenu: true);

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(_placeholderTitle(tester), '홈');
  });

  testWidgets('result 경로 우선: /workout/result 는 운동 결과 화면이다', (tester) async {
    final router = await _pumpRouter(tester, enableDevMenu: true);

    router.go(AppRoutes.workoutResult);
    await tester.pumpAndSettle();

    final title = _placeholderTitle(tester);
    expect(title, contains('결과'));
    expect(title, isNot('운동'));
  });

  testWidgets('type 경로: workoutPath(squat) 는 운동 화면이다', (tester) async {
    final router = await _pumpRouter(tester, enableDevMenu: true);

    router.go(AppRoutes.workoutPath('squat'));
    await tester.pumpAndSettle();

    expect(_placeholderTitle(tester), '운동');
  });

  testWidgets('릴리스에는 개발자 메뉴 없음 (F-14): /dev 는 없는 경로', (tester) async {
    final router = await _pumpRouter(tester, enableDevMenu: false);

    router.go(AppRoutes.dev);
    await tester.pumpAndSettle();

    expect(find.text('페이지를 찾을 수 없어요'), findsOneWidget);
    expect(find.byType(PlaceholderScreen), findsNothing);
  });

  testWidgets('디버그에는 개발자 메뉴 있음: /dev 는 개발자 메뉴 화면', (tester) async {
    final router = await _pumpRouter(tester, enableDevMenu: true);

    router.go(AppRoutes.dev);
    await tester.pumpAndSettle();

    expect(_placeholderTitle(tester), '개발자 메뉴');
  });

  testWidgets('없는 경로: 오류 화면 문구가 보인다', (tester) async {
    final router = await _pumpRouter(tester, enableDevMenu: true);

    router.go('/no-such-page');
    await tester.pumpAndSettle();

    expect(find.text('페이지를 찾을 수 없어요'), findsOneWidget);
  });

  test('경로 함수: 경로 파라미터를 채운 주소를 만든다', () {
    expect(AppRoutes.workoutSetupPath('push_up'), '/workout/push_up/setup');
    expect(AppRoutes.workoutPath('squat'), '/workout/squat');
    expect(AppRoutes.historyDetailPath('abc'), '/history/abc');
  });
}
