// [파일] 루틴 단계 enum과 운동별 루틴 계획 값 객체.
// [Spec] F-09 / [Task] TASK-10
// [의존] ExerciseType (환경 변수 사용 안 함)

import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:flutter/foundation.dart';

/// 루틴 강도 단계.
enum RoutineLevel {
  /// 고강도.
  advanced('advanced', '고강도'),

  /// 중급.
  intermediate('intermediate', '중급'),

  /// 초보.
  beginner('beginner', '초보');

  new(this.code, this.label);

  /// 저장, 전송에 쓰는 코드 값.
  final String code;

  /// 화면에 보이는 이름.
  final String label;
}

/// 한 운동의 목표(횟수, 세트, 휴식, 최소 점수).
@immutable
class RoutinePlan {
  /// 루틴 계획을 만든다.
  const new({
    required this.exercise,
    required this.level,
    required this.targetReps,
    required this.sets,
    required this.restSec,
    required this.minScore,
  });

  /// 운동 종류.
  final ExerciseType exercise;

  /// 단계.
  final RoutineLevel level;

  /// 세트당 목표 횟수.
  final int targetReps;

  /// 세트 수.
  final int sets;

  /// 세트 사이 휴식(초).
  final int restSec;

  /// 값만 보관한다(쓰는 곳은 이번 범위에 없음).
  final int minScore;

  @override
  bool operator ==(Object other) =>
      other is RoutinePlan &&
      other.exercise == exercise &&
      other.level == level &&
      other.targetReps == targetReps &&
      other.sets == sets &&
      other.restSec == restSec &&
      other.minScore == minScore;

  @override
  int get hashCode =>
      Object.hash(exercise, level, targetReps, sets, restSec, minScore);

  @override
  String toString() =>
      'RoutinePlan($exercise, $level, '
      '$targetReps x $sets, rest $restSec, min $minScore)';
}

// [QA] 2026-11-13 PASS
// [보안] 해당 없음(순수 값 객체).
// [유지보수] minScore는 보관만 함(사용처 없음). 필드를 늘리면 ==, hashCode, toString을 함께 갱신할 것.
