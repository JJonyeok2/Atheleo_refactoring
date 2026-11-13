import 'package:atheleo/features/workout/widgets/rest_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  int remainingSec = 30,
  int nextSet = 2,
  int totalSets = 3,
  int targetReps = 10,
  VoidCallback? onSkip,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          RestOverlay(
            remainingSec: remainingSec,
            nextSet: nextSet,
            totalSets: totalSets,
            targetReps: targetReps,
            onSkip: onSkip ?? () {},
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('카운트다운과 다음 세트 정보를 표시한다 (F-08)', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('휴식'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('다음 세트 2 / 3 · 목표 10회'), findsOneWidget);
    expect(find.text('건너뛰기'), findsOneWidget);
  });

  testWidgets('건너뛰기를 탭하면 onSkip이 1회 호출된다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(onSkip: () => calls++));

    await tester.tap(find.text('건너뛰기'));
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('remainingSec가 바뀌면 다시 그린다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(remainingSec: 29));

    expect(find.text('29'), findsOneWidget);
    expect(find.text('30'), findsNothing);
  });

  testWidgets('남은 0초와 큰 값도 그대로 표시한다', (tester) async {
    await tester.pumpWidget(_host(remainingSec: 0));
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(_host(remainingSec: 3600, totalSets: 12));
    expect(find.text('3600'), findsOneWidget);
    expect(find.text('다음 세트 2 / 12 · 목표 10회'), findsOneWidget);
  });

  testWidgets('작은 화면에서도 오버플로 없이 버튼을 탭할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(200, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;

    await tester.pumpWidget(_host(onSkip: () => calls++));
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(calls, 1);
  });

  testWidgets('부모 전체를 덮는다', (tester) async {
    await tester.pumpWidget(_host());

    expect(
      tester.getSize(find.byType(RestOverlay)),
      tester.getSize(find.byType(Scaffold)),
    );
  });
}
