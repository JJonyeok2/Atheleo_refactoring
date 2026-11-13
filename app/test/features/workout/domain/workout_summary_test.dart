import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/features/workout/domain/workout_summary.dart';
import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:flutter_test/flutter_test.dart';

RepResult rep(int index, int score, [List<PoseErrorCode> errors = const []]) =>
    RepResult(
      repIndex: index,
      score: score,
      minAngle: 90,
      durationMs: 1500,
      errors: errors,
    );

const plan = RoutinePlan(
  exercise: ExerciseType.squat,
  level: RoutineLevel.intermediate,
  targetReps: 15,
  sets: 3,
  restSec: 45,
  minScore: 60,
);

WorkoutSummary build(
  List<List<RepResult>> sets, {
  List<int> partials = const [],
}) => buildSummary(
  clientId: 'c1',
  plan: plan,
  startedAt: DateTime.utc(2026, 11, 13, 10),
  endedAt: DateTime.utc(2026, 11, 13, 10, 20),
  sets: sets,
  partialsPerSet: partials,
);

void main() {
  test('총 횟수와 평균', () {
    final s = build([
      [rep(1, 100), rep(2, 75)],
      [rep(1, 80)],
    ]);
    expect(s.totalReps, 3);
    expect(s.avgScore, 85);
  });

  test('세트 평균은 반올림한다', () {
    final set = SetSummary(
      setIndex: 1,
      targetReps: 10,
      restSec: 30,
      reps: [rep(1, 100), rep(2, 75)],
    );
    expect(set.avgScore, 88);
    expect(set.doneReps, 2);
  });

  test('빈 세트는 제외하되 부분 반복만 있으면 남기고 번호를 유지한다', () {
    final s = build(
      [
        [rep(1, 90), rep(2, 90), rep(3, 90)],
        [],
        [],
      ],
      partials: [0, 2, 0],
    );
    expect(s.sets.map((e) => e.setIndex), [1, 2]);
    expect(s.sets[1].doneReps, 0);
    expect(s.sets[1].partialReps, 2);
  });

  test('반복 없는 중간 세트 제외 시 원래 번호를 유지한다', () {
    final s = build([
      [rep(1, 90)],
      [],
      [rep(1, 70)],
    ]);
    expect(s.sets.map((e) => e.setIndex), [1, 3]);
  });

  test('부분 반복 합계는 평균에 영향이 없다', () {
    final s = build(
      [
        [rep(1, 80)],
        [rep(1, 60)],
      ],
      partials: [1, 2],
    );
    expect(s.sets.map((e) => e.partialReps), [1, 2]);
    expect(s.totalPartialReps, 3);
    expect(s.avgScore, 70);
  });

  test('partialsPerSet이 짧으면 나머지는 0', () {
    final s = build(
      [
        [rep(1, 80)],
        [rep(1, 60)],
      ],
      partials: [4],
    );
    expect(s.sets.map((e) => e.partialReps), [4, 0]);
  });

  test('자주 나온 오류는 많은 순', () {
    final s = build([
      [
        rep(1, 50, [PoseErrorCode.sqShallow]),
        rep(2, 50, [PoseErrorCode.sqShallow, PoseErrorCode.sqTorsoLean]),
      ],
    ]);
    expect(s.topErrors.first.key, PoseErrorCode.sqShallow);
    expect(s.topErrors.first.value, 2);
    expect(s.topErrors.length, 2);
  });

  test('오류 빈도가 같으면 선언 순서', () {
    final s = build([
      [
        rep(1, 50, [PoseErrorCode.sqHeelLift]),
        rep(2, 50, [PoseErrorCode.puShallow]),
        rep(3, 50, [PoseErrorCode.sqShallow]),
      ],
    ]);
    expect(s.topErrors.map((e) => e.key), [
      PoseErrorCode.puShallow,
      PoseErrorCode.sqShallow,
      PoseErrorCode.sqHeelLift,
    ]);
  });

  test('반복 없음', () {
    final s = build([[]]);
    expect(s.totalReps, 0);
    expect(s.avgScore, 0);
    expect(s.topErrors, isEmpty);
    expect(s.sets, isEmpty);
  });

  test('빈 세션(세트 없음)', () {
    final s = build([]);
    expect(s.sets, isEmpty);
    expect(s.totalReps, 0);
    expect(s.totalPartialReps, 0);
    expect(s.avgScore, 0);
  });

  test('계획 값 반영', () {
    final s = build([
      [rep(1, 80)],
      [rep(1, 80)],
    ]);
    expect(s.level, RoutineLevel.intermediate);
    expect(s.exercise, ExerciseType.squat);
    expect(s.clientId, 'c1');
    for (final set in s.sets) {
      expect(set.targetReps, 15);
      expect(set.restSec, 45);
    }
  });
}
