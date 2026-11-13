// [파일] 체형 -> 단계 -> 운동별 루틴 표 조회.
// [Spec] F-09 / [Task] TASK-10
// [의존] BodyShape, RoutinePlan, ExerciseType (환경 변수 사용 안 함)

import 'package:atheleo/features/routine/domain/body_shape.dart';
import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';

/// 체형에 맞는 단계. 체형이 없으면 중급.
RoutineLevel levelForBodyShape(BodyShape? shape) {
  switch (shape) {
    case BodyShape.invertedTriangle:
    case BodyShape.rectangle:
      return RoutineLevel.advanced;
    case BodyShape.triangle:
    case BodyShape.ideal:
    case BodyShape.round:
    case BodyShape.tube:
    case BodyShape.diamond:
      return RoutineLevel.beginner;
    case BodyShape.hourglass:
    case null:
      return RoutineLevel.intermediate;
  }
}

// (횟수, 세트, 휴식초, 최소점수)
typedef _Row = (int, int, int, int);

const Map<RoutineLevel, Map<ExerciseType, _Row>> _table = {
  RoutineLevel.advanced: {
    ExerciseType.squat: (20, 3, 30, 70),
    ExerciseType.pushUp: (15, 3, 30, 70),
  },
  RoutineLevel.intermediate: {
    ExerciseType.squat: (15, 3, 45, 60),
    ExerciseType.pushUp: (12, 3, 45, 60),
  },
  RoutineLevel.beginner: {
    ExerciseType.squat: (10, 2, 60, 50),
    ExerciseType.pushUp: (8, 2, 60, 50),
  },
};

/// [exercise]의 루틴을 [shape] 기준으로 돌려준다.
RoutinePlan routineFor(ExerciseType exercise, BodyShape? shape) {
  final level = levelForBodyShape(shape);
  final (reps, sets, rest, min) = _table[level]![exercise]!;
  return RoutinePlan(
    exercise: exercise,
    level: level,
    targetReps: reps,
    sets: sets,
    restSec: rest,
    minScore: min,
  );
}

// [QA] 2026-11-13 PASS
// [보안] 해당 없음(상수 표 조회).
// [유지보수] 값은 기존 RN exerciseRoutines.js와 대조해 일치.
//   _table의 ! 두 번은 표가 모든 단계, 운동을 채워야 안전하다.
//   ExerciseType에 운동이 추가되면 컴파일 오류가 아니라 실행 시 오류가 나므로
//   표에 행을 함께 추가할 것.
