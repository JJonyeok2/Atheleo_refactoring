// [파일] 현재 체형 상태와 운동별 루틴 조회 provider.
// [Spec] F-09 / [Task] TASK-10
// [의존] flutter_riverpod, routine_table (환경 변수 사용 안 함)

import 'package:atheleo/features/routine/domain/body_shape.dart';
import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/features/routine/domain/routine_table.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 체형(없으면 null). 프로필이 바뀌면 [set]으로 갱신한다.
class CurrentBodyShapeNotifier extends Notifier<BodyShape?> {
  @override
  BodyShape? build() => null;

  /// 체형을 바꾼다.
  // ignore: use_setters_to_change_properties
  void set(BodyShape? shape) => state = shape;
}

/// 현재 체형 provider.
final currentBodyShapeProvider =
    NotifierProvider<CurrentBodyShapeNotifier, BodyShape?>(
      CurrentBodyShapeNotifier.new,
    );

/// 현재 체형 기준 운동별 루틴.
final ProviderFamily<RoutinePlan, ExerciseType> routinePlanProvider =
    Provider.family<RoutinePlan, ExerciseType>(
      (ref, exercise) =>
          routineFor(exercise, ref.watch(currentBodyShapeProvider)),
    );

// [QA] 2026-11-13 PASS
// [보안] 해당 없음. 체형은 메모리 상태로만 보관(저장, 전송 없음).
// [유지보수] 초기값 null(중급). 프로필 로드 후 TASK-43이 set으로 갱신해야 실제 체형이 반영된다.
