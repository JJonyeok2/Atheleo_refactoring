// [파일] 운동 한 번의 결과 요약 모델(세트별 요약, 전체 합계, 자주 나온 오류)과 생성 함수.
// [Spec] F-05, 4장 정상 흐름 7번, 7장 WorkoutSession/WorkoutSet/RepRecord / [Task] TASK-17
// [의존] RoutinePlan, RepResult, PoseErrorCode, averageScore (환경 변수 사용 안 함)

import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/score/rep_score.dart';
import 'package:flutter/foundation.dart';

/// 한 세트의 결과.
@immutable
class SetSummary {
  /// 세트 요약을 만든다.
  const new({
    required this.setIndex,
    required this.targetReps,
    required this.restSec,
    required this.reps,
    this.partialReps = 0,
  });

  /// 1부터 세는 세트 번호(빈 세트를 빼도 원래 번호 유지).
  final int setIndex;

  /// 계획 목표 횟수.
  final int targetReps;

  /// 계획 휴식(초).
  final int restSec;

  /// 인정된 반복 결과.
  final List<RepResult> reps;

  /// 부분 반복 수(점수 없음, 평균 제외).
  final int partialReps;

  /// 인정된 반복 수.
  int get doneReps => reps.length;

  /// 반복 점수 평균(반올림, 반복이 없으면 0).
  int get avgScore => averageScore(reps.map((r) => r.score));
}

/// 운동 한 번의 결과.
@immutable
class WorkoutSummary {
  /// 운동 요약을 만든다.
  const new({
    required this.clientId,
    required this.exercise,
    required this.level,
    required this.startedAt,
    required this.endedAt,
    required this.sets,
  });

  /// 클라이언트가 만든 uuid.
  final String clientId;

  /// 운동 종류.
  final ExerciseType exercise;

  /// 루틴 단계.
  final RoutineLevel level;

  /// 시작 시각.
  final DateTime startedAt;

  /// 종료 시각.
  final DateTime endedAt;

  /// 세트 요약(빈 세트 제외).
  final List<SetSummary> sets;

  /// 전체 인정 반복 수.
  int get totalReps => sets.fold(0, (sum, s) => sum + s.doneReps);

  /// 전체 부분 반복 수.
  int get totalPartialReps => sets.fold(0, (sum, s) => sum + s.partialReps);

  /// 모든 반복 점수 평균(반올림, 반복이 없으면 0).
  int get avgScore =>
      averageScore(sets.expand((s) => s.reps).map((r) => r.score));

  /// 오류 코드별 횟수. 많은 순, 같으면 [PoseErrorCode] 선언 순서.
  List<MapEntry<PoseErrorCode, int>> get topErrors {
    final counts = <PoseErrorCode, int>{};
    for (final rep in sets.expand((s) => s.reps)) {
      for (final error in rep.errors) {
        counts[error] = (counts[error] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.index.compareTo(b.key.index);
      });
    return entries;
  }
}

/// 세트별 반복 결과로 요약을 만든다. sets[0]이 1세트.
///
/// 반복과 부분 반복이 모두 0인 세트는 뺀다. [partialsPerSet]이 짧으면 나머지는 0.
WorkoutSummary buildSummary({
  required String clientId,
  required RoutinePlan plan,
  required DateTime startedAt,
  required DateTime endedAt,
  required List<List<RepResult>> sets,
  List<int> partialsPerSet = const [],
}) {
  final summaries = <SetSummary>[];
  for (var i = 0; i < sets.length; i++) {
    final partial = i < partialsPerSet.length ? partialsPerSet[i] : 0;
    if (sets[i].isEmpty && partial == 0) continue;
    summaries.add(
      SetSummary(
        setIndex: i + 1,
        targetReps: plan.targetReps,
        restSec: plan.restSec,
        reps: sets[i],
        partialReps: partial,
      ),
    );
  }
  return WorkoutSummary(
    clientId: clientId,
    exercise: plan.exercise,
    level: plan.level,
    startedAt: startedAt,
    endedAt: endedAt,
    sets: summaries,
  );
}

// [QA] 2026-11-13 PASS
// [보안] 외부 입력, 로그, 시크릿 없음. clientId는 그대로 보관만 함(형식 검증은 생성하는 TASK-27 몫).
// [유지보수] 부분 반복 수가 음수로 들어와도 검사하지 않음(호출부 TASK-27이 0 이상을 보장).
//   partialsPerSet이 sets보다 길면 남는 값은 무시함.
//   const 생성자라 reps 리스트를 복사하지 않음.
//   호출부는 바꾸지 않을 리스트(TASK-16의 unmodifiable 스냅숏 등)를 넘길 것.
//   반복 0개 + 부분 반복만 있는 세트는 남고 그 세트 avgScore는 0(화면 TASK-30에서 표시 방식 결정).
//   JSON 직렬화는 이 Task 범위 밖(TASK-32, 38). 새 필드는 SetSummary/WorkoutSummary에 함께 추가할 것.
