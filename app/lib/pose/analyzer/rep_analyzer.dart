// [파일] 프레임 분석기. 기준 관절 각도 -> 이동 평균 -> 횟수 -> 오류 판정 -> 점수.
// [Spec] F-02~F-05 / [Task] TASK-15 (측정 쪽 유지, 자세 게이트는 TASK-49에서 추가)
// [의존] pose/angle, pose/rep, pose/judge, pose/score (환경 변수 사용 안 함)

import 'package:atheleo/pose/angle/joint_angle.dart';
import 'package:atheleo/pose/angle/moving_average.dart';
import 'package:atheleo/pose/judge/error_judge.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:atheleo/pose/rep/rep_counter.dart';
import 'package:atheleo/pose/score/rep_score.dart';

/// 프레임 분석기가 내보내는 사건.
sealed class AnalyzerOutput {
  const new();
}

/// 횟수로 인정된 반복 1회의 판정 결과.
final class RepResult extends AnalyzerOutput {
  /// 결과를 만든다.
  const new({
    required this.repIndex,
    required this.score,
    required this.minAngle,
    required this.durationMs,
    required this.errors,
  });

  /// reset 이후 1부터 세는 반복 번호.
  final int repIndex;

  /// 반복 점수(0~100).
  final int score;

  /// 원시 각도 최저점 주변 3프레임 중앙값.
  final double minAngle;

  /// 하강 시작부터 UP 복귀까지 시간.
  final int durationMs;

  /// 자세 오류 코드.
  final List<PoseErrorCode> errors;
}

/// DOWN에 닿지 못하고 UP으로 돌아온 부분 반복. 점수와 오류 판정 없음.
final class PartialRep extends AnalyzerOutput {
  /// 결과를 만든다.
  const new({required this.minAngle, required this.endMs});

  /// 원시 각도 최저점 주변 3프레임 중앙값.
  final double minAngle;

  /// UP 복귀 프레임 시각.
  final int endMs;
}

/// 최소 1회 시간에 못 미친 반복. 점수, 오류 없음, count와 partialCount에 넣지 않음.
final class TooFastRep extends AnalyzerOutput {
  /// 결과를 만든다.
  const new({required this.durationMs, required this.endMs});

  /// 하강 시작부터 UP 복귀까지 시간.
  final int durationMs;

  /// UP 복귀 프레임 시각.
  final int endMs;
}

/// 프레임마다 기준 관절 각도를 이동 평균해 반복을 세고,
/// 반복이 끝나면 오류 판정과 점수 계산까지 마친 결과를 내보낸다.
///
/// 기준 관절은 푸쉬업 팔꿈치, 스쿼트 무릎. 각도를 얻지 못한 프레임과
/// 시각이 직전 프레임보다 앞선 프레임은 건너뛴다.
class RepAnalyzer {
  /// 분석기를 만든다. [repThresholds]가 없으면 운동별 기본값.
  new({
    required ExerciseType exercise,
    RepThresholds? repThresholds,
    this._errorThresholds = const ErrorThresholds(),
    int smoothingWindowMs = 150,
  }) : _exercise = exercise,
       _smoothing = MovingAverage(windowMs: smoothingWindowMs),
       _counter = RepCounter(
         repThresholds ?? RepThresholds.forExercise(exercise),
       );

  final ExerciseType _exercise;
  final ErrorThresholds _errorThresholds;
  final MovingAverage _smoothing;
  final RepCounter _counter;

  /// 진행 중인 반복(하강 시작 이후)의 쓸 수 있는 프레임.
  final List<PoseFrame> _repFrames = [];
  int? _lastTimestampMs;
  double? _lastAngle;

  /// 인정된 반복 수.
  int get count => _counter.count;

  /// 부분 반복 수.
  int get partialCount => _counter.partialCount;

  /// 마지막 이동 평균 각도. 아직 쓸 수 있는 프레임이 없으면 null.
  double? get lastAngle => _lastAngle;

  /// 프레임 하나를 넣는다. 반복, 부분 반복, 빠른 반복이 끝난 프레임에서만 출력한다.
  AnalyzerOutput? addFrame(PoseFrame frame) {
    final t = frame.timestampMs;
    final lastT = _lastTimestampMs;
    if (lastT != null && t < lastT) return null;
    final raw = _rawAngle(frame);
    if (raw == null) return null;

    _lastTimestampMs = t;
    final angle = _smoothing.add(raw, t);
    _lastAngle = angle;
    _repFrames.add(frame);

    final event = _counter.update(timestampMs: t, angle: angle, rawAngle: raw);
    final output = event == null ? null : _toOutput(event);
    // 사건이 났거나 반복 밖(UP, 시작 전)이면 보관 프레임을 비운다.
    if (event != null || !_inRep) _repFrames.clear();
    return output;
  }

  /// 이동 평균, 횟수, 보관 프레임을 모두 처음으로 돌린다.
  void reset() {
    _smoothing.reset();
    _counter.reset();
    _repFrames.clear();
    _lastTimestampMs = null;
    _lastAngle = null;
  }

  bool get _inRep => switch (_counter.phase) {
    RepPhase.descending || RepPhase.down => true,
    RepPhase.unknown || RepPhase.up => false,
  };

  /// 고른 쪽의 기준 관절 원시 각도. 고를 수 없거나 유한하지 않으면 null.
  double? _rawAngle(PoseFrame frame) {
    final side = selectSide(frame);
    if (side == null) return null;
    final angle = switch (_exercise) {
      ExerciseType.pushUp => side.elbow,
      ExerciseType.squat => side.knee,
    };
    return angle.isFinite ? angle : null;
  }

  /// 사건을 출력으로 바꾼다. 반복이면 보관 프레임 중 startMs~endMs로 판정, 채점한다.
  AnalyzerOutput? _toOutput(RepCounterEvent event) {
    switch (event) {
      case RepEvent():
        final repFrames = [
          for (final f in _repFrames)
            if (f.timestampMs >= event.startMs && f.timestampMs <= event.endMs)
              f,
        ];
        final errors = judgeRep(
          exercise: _exercise,
          repFrames: repFrames,
          rep: event,
          thresholds: _errorThresholds,
        );
        return RepResult(
          repIndex: event.repIndex,
          score: scoreRep(errors: errors, durationMs: event.durationMs),
          minAngle: event.minAngle,
          durationMs: event.durationMs,
          errors: errors,
        );
      case PartialRepEvent():
        return PartialRep(minAngle: event.minAngle, endMs: event.endMs);
      case TooFastRepEvent():
        return TooFastRep(durationMs: event.durationMs, endMs: event.endMs);
      case RepCancelledEvent():
        return null;
    }
  }
}

// [QA] 2026-11-13 PASS (docs/qa/QA-TASK-15.md)
// [보안] 외부 입력, 시크릿, 로그 없음. 시각 역행, 쓸 수 없는 프레임은 건너뜀.
// [유지보수] 보관 프레임은 하강 시작 이후만 쌓아 judgeRep 시작 자세가 하강 시작
//   프레임이 됨(Task 계약 startMs~endMs). 스쿼트 뒤꿈치 기준이 이 영향을 받음.
//   반복 시간은 하강 시작~UP 복귀라 스쿼트 1초 반복은 빠른 반복이 됨(Spec 보정 후보).
