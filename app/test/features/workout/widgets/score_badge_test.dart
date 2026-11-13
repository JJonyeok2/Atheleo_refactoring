import 'package:atheleo/features/workout/widgets/score_badge.dart';
import 'package:atheleo/pose/score/rep_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, int? score, {double size = 64}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: ScoreBadge(score: score, size: size),
      ),
    ),
  );
}

Color? badgeColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(ScoreBadge),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  group('scoreColor', () {
    test('등급별 색', () {
      expect(scoreColor(ScoreGrade.good), const Color(0xFF2E7D32));
      expect(scoreColor(ScoreGrade.fair), const Color(0xFFF9A825));
      expect(scoreColor(ScoreGrade.poor), const Color(0xFFC62828));
    });
  });

  group('ScoreBadge', () {
    testWidgets('100점 초록 (F-05)', (tester) async {
      await pump(tester, 100);
      expect(find.text('100'), findsOneWidget);
      expect(badgeColor(tester), const Color(0xFF2E7D32));
    });

    testWidgets('75점 노랑 (F-05)', (tester) async {
      await pump(tester, 75);
      expect(find.text('75'), findsOneWidget);
      expect(badgeColor(tester), const Color(0xFFF9A825));
    });

    testWidgets('59점 빨강', (tester) async {
      await pump(tester, 59);
      expect(find.text('59'), findsOneWidget);
      expect(badgeColor(tester), const Color(0xFFC62828));
    });

    testWidgets('점수 없음은 -와 회색', (tester) async {
      await pump(tester, null);
      expect(find.text('-'), findsOneWidget);
      expect(badgeColor(tester), Colors.grey);
    });

    testWidgets('글자색은 배경 밝기에 맞춘다 (대비)', (tester) async {
      Color? textColor() => tester.widget<Text>(find.byType(Text)).style?.color;
      await pump(tester, 100);
      expect(textColor(), Colors.white);
      await pump(tester, 59);
      expect(textColor(), Colors.white);
      await pump(tester, 75);
      expect(textColor(), Colors.black);
      await pump(tester, null);
      expect(textColor(), Colors.black);
    });

    testWidgets('접근성 라벨', (tester) async {
      await pump(tester, 85);
      expect(find.bySemanticsLabel('점수 85점'), findsOneWidget);
    });

    testWidgets('경계값 0, 60, 84, 85', (tester) async {
      const expected = {
        0: Color(0xFFC62828),
        60: Color(0xFFF9A825),
        84: Color(0xFFF9A825),
        85: Color(0xFF2E7D32),
      };
      for (final e in expected.entries) {
        await pump(tester, e.key);
        expect(find.text('${e.key}'), findsOneWidget);
        expect(badgeColor(tester), e.value);
      }
    });

    testWidgets('범위 밖 값은 0~100으로 맞춘다', (tester) async {
      await pump(tester, 150);
      expect(find.text('100'), findsOneWidget);
      expect(badgeColor(tester), const Color(0xFF2E7D32));
      await pump(tester, -5);
      expect(find.text('0'), findsOneWidget);
      expect(badgeColor(tester), const Color(0xFFC62828));
    });

    testWidgets('점수 없음 접근성 라벨과 size', (tester) async {
      await pump(tester, null, size: 40);
      expect(find.bySemanticsLabel('점수 없음'), findsOneWidget);
      expect(tester.getSize(find.byType(ScoreBadge)), const Size(40, 40));
    });
  });
}
