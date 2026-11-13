import 'package:atheleo/features/routine/domain/body_shape.dart';
import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/features/routine/domain/routine_table.dart';
import 'package:atheleo/features/routine/routine_providers.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('역삼각형 스쿼트 (F-09)', () {
    final p = routineFor(ExerciseType.squat, BodyShape.invertedTriangle);
    expect(p.targetReps, 20);
    expect(p.sets, 3);
    expect(p.restSec, 30);
    expect(p.minScore, 70);
    expect(p.level, RoutineLevel.advanced);
  });

  test('체형 없음 스쿼트 (F-09)', () {
    final p = routineFor(ExerciseType.squat, null);
    expect(p.targetReps, 15);
    expect(p.sets, 3);
    expect(p.restSec, 45);
    expect(p.minScore, 60);
    expect(p.level, RoutineLevel.intermediate);
  });

  test('8개 체형 단계', () {
    const expected = {
      BodyShape.invertedTriangle: RoutineLevel.advanced,
      BodyShape.rectangle: RoutineLevel.advanced,
      BodyShape.hourglass: RoutineLevel.intermediate,
      BodyShape.triangle: RoutineLevel.beginner,
      BodyShape.ideal: RoutineLevel.beginner,
      BodyShape.round: RoutineLevel.beginner,
      BodyShape.tube: RoutineLevel.beginner,
      BodyShape.diamond: RoutineLevel.beginner,
    };
    expect(expected.length, BodyShape.values.length);
    expected.forEach((s, l) => expect(levelForBodyShape(s), l, reason: '$s'));
    expect(levelForBodyShape(null), RoutineLevel.intermediate);
  });

  test('초보 푸쉬업', () {
    final p = routineFor(ExerciseType.pushUp, BodyShape.tube);
    expect(
      p,
      const RoutinePlan(
        exercise: ExerciseType.pushUp,
        level: RoutineLevel.beginner,
        targetReps: 8,
        sets: 2,
        restSec: 60,
        minScore: 50,
      ),
    );
  });

  test('나머지 표 값', () {
    final a = routineFor(ExerciseType.pushUp, BodyShape.rectangle);
    expect([a.targetReps, a.sets, a.restSec, a.minScore], [15, 3, 30, 70]);
    final m = routineFor(ExerciseType.pushUp, BodyShape.hourglass);
    expect([m.targetReps, m.sets, m.restSec, m.minScore], [12, 3, 45, 60]);
    final b = routineFor(ExerciseType.squat, BodyShape.round);
    expect([b.targetReps, b.sets, b.restSec, b.minScore], [10, 2, 60, 50]);
  });

  test('코드 왕복', () {
    expect(BodyShape.fromCode('diamond'), BodyShape.diamond);
    expect(BodyShape.fromCode(null), isNull);
    expect(BodyShape.fromCode('x'), isNull);
    for (final s in BodyShape.values) {
      expect(BodyShape.fromCode(s.code), s);
    }
    expect(BodyShape.invertedTriangle.label, '역삼각형');
    expect(RoutineLevel.beginner.label, '초보');
    expect(RoutineLevel.advanced.code, 'advanced');
  });

  test('provider 반영', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(currentBodyShapeProvider), isNull);
    expect(c.read(routinePlanProvider(ExerciseType.squat)).targetReps, 15);
    c.read(currentBodyShapeProvider.notifier).set(BodyShape.invertedTriangle);
    expect(c.read(routinePlanProvider(ExerciseType.squat)).targetReps, 20);
  });
}
