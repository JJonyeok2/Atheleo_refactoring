// [파일] 점수 배지 위젯과 등급 색 함수.
// [Spec] F-05, F-07 / [Task] TASK-23
// [의존] pose/score/rep_score.dart (환경 변수 사용 안 함)

import 'package:atheleo/pose/score/rep_score.dart';
import 'package:flutter/material.dart';

/// 등급에 대응하는 색. good 초록, fair 노랑, poor 빨강.
Color scoreColor(ScoreGrade grade) {
  return switch (grade) {
    ScoreGrade.good => const Color(0xFF2E7D32),
    ScoreGrade.fair => const Color(0xFFF9A825),
    ScoreGrade.poor => const Color(0xFFC62828),
  };
}

/// 점수를 색과 숫자로 함께 보여 주는 원형 배지.
///
/// `score`가 null이면 '-'와 회색. 0~100 밖의 값은 범위 안으로 맞춰 표시한다.
class ScoreBadge extends StatelessWidget {
  /// `score` 점수(없으면 null), [size] 지름.
  const new({required int? score, super.key, this.size = 64})
    : _score = score == null
          ? null
          : (score < 0 ? 0 : (score > 100 ? 100 : score));

  final int? _score;

  /// 배지 지름.
  final double size;

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final color = score == null ? Colors.grey : scoreColor(gradeFor(score));
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      label: score == null ? '점수 없음' : '점수 $score점',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              score == null ? '-' : '$score',
              style: TextStyle(
                color: textColor,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// [QA] 2026-11-13 PASS (재검토)
// [보안] 외부 입력, 시크릿, 로그 없음. 범위 밖 점수는 생성자에서 0~100으로 clamp.
// [유지보수] 글자색은 배경 밝기로 선택. 4개 배경 모두 대비 4.5:1 이상 확인.
//   회색 배경은 밝기 임계값 근처라 배경색 변경 시 글자색 테스트 재확인.
