// [파일] 프레임 분석기. 기준 관절 각도 -> 이동 평균 -> 횟수 -> 오류 판정 -> 점수.
// [Spec] F-02~F-05, F-07(분석기 부분) / [Task] TASK-15, TASK-49(측정 쪽 유지, 자세 게이트, 판정 프레임 범위)
// [의존] pose/angle, pose/body, pose/rep, pose/judge, pose/score (환경 변수 사용 안 함)

import 'package:atheleo/pose/angle/joint_angle.dart';
import 'package:atheleo/pose/angle/moving_average.dart';
import 'package:atheleo/pose/body/body_check.dart';
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
/// 기준 관절은 푸쉬업 팔꿈치, 스쿼트 무릎. 시각이 직전 프레임보다 앞선 프레임,
/// 측정 쪽 각도를 쓸 수 없는 프레임, 자세 게이트를 통과하지 못한 프레임은 건너뛴다.
///
/// 측정 쪽은 세트 시작(생성, reset) 뒤 처음 고를 수 있는 프레임에서 정하고,
/// 그쪽을 쓸 수 없는 상태가 `sideSwitchAfterMs` 이상 이어진 프레임에서만
/// 반대쪽으로 바꾼다. 자세 게이트는 푸쉬업은 매 프레임, 스쿼트는 처음 UP을
/// 인정하기 전(RepPhase.unknown)에만 적용한다.
class RepAnalyzer {
  /// 분석기를 만든다. [repThresholds]가 없으면 운동별 기본값.
  new({
    required ExerciseType exercise,
    RepThresholds? repThresholds,
    this._errorThresholds = const ErrorThresholds(),
    int smoothingWindowMs = 150,
    this._sideSwitchAfterMs = 500,
    this._gateMaxDeg = 30,
  }) : _exercise = exercise,
       _smoothing = MovingAverage(windowMs: smoothingWindowMs),
       _counter = RepCounter(
         repThresholds ?? RepThresholds.forExercise(exercise),
       );

  /// 측정 쪽 각도를 쓸 수 있는 평균 visibility 하한(selectSide 기본값과 같음).
  static const double _minSideVisibility = 0.5;

  final ExerciseType _exercise;
  final ErrorThresholds _errorThresholds;
  final int _sideSwitchAfterMs;
  final double _gateMaxDeg;
  final MovingAverage _smoothing;
  final RepCounter _counter;

  /// 판정용 보관 프레임. UP 상태에서는 마지막 프레임 1개, 하강 시작부터는
  /// 그 UP 프레임에 이어 반복이 끝날 때까지 받아들인 프레임을 모두 담는다.
  final List<PoseFrame> _repFrames = [];
  int? _lastTimestampMs;
  double? _lastAngle;
  BodySide? _side;

  /// 측정 쪽을 쓸 수 없게 된 첫 프레임 시각. 쓸 수 있으면 null.
  int? _droppedSinceMs;

  /// 인정된 반복 수.
  int get count => _counter.count;

  /// 부분 반복 수.
  int get partialCount => _counter.partialCount;

  /// 마지막 이동 평균 각도. 아직 쓸 수 있는 프레임이 없으면 null.
  double? get lastAngle => _lastAngle;

  /// 현재 측정 쪽. 세트 시작 뒤 아직 정하지 못했으면 null.
  BodySide? get side => _side;

  /// 프레임 하나를 넣는다. 반복, 부분 반복, 빠른 반복이 끝난 프레임에서만 출력한다.
  AnalyzerOutput? addFrame(PoseFrame frame) {
    final t = frame.timestampMs;
    final lastT = _lastTimestampMs;
    if (lastT != null && t < lastT) return null;
    final raw = _measure(frame);
    if (raw == null || !_passesGate(frame)) return null;

    _lastTimestampMs = t;
    final angle = _smoothing.add(raw, t);
    _lastAngle = angle;
    _repFrames.add(frame);

    final event = _counter.update(timestampMs: t, angle: angle, rawAngle: raw);
    final output = event == null ? null : _toOutput(event);
    // 반복 밖이면 UP 상태의 이 프레임 1개만 남긴다(다음 하강의 첫 판정 프레임).
    if (event != null || !_inRep) {
      _repFrames.clear();
      if (_counter.phase == RepPhase.up) _repFrames.add(frame);
    }
    return output;
  }

  /// 이동 평균, 횟수, 보관 프레임, 측정 쪽을 모두 처음으로 돌린다.
  void reset() {
    _smoothing.reset();
    _counter.reset();
    _repFrames.clear();
    _lastTimestampMs = null;
    _lastAngle = null;
    _side = null;
    _droppedSinceMs = null;
  }

  bool get _inRep => switch (_counter.phase) {
    RepPhase.descending || RepPhase.down => true,
    RepPhase.unknown || RepPhase.up => false,
  };

  /// 측정 쪽 기준 관절 원시 각도. 쓸 수 없으면 null.
  ///
  /// 측정 쪽이 없으면 [selectSide]로 정한다. 측정 쪽을 쓸 수 없는 상태가
  /// [_sideSwitchAfterMs] 이상 이어진 프레임에서 [selectSide]가 반대쪽을 고르면
  /// 그 프레임부터 반대쪽을 쓴다.
  double? _measure(PoseFrame frame) {
    final t = frame.timestampMs;
    final side = _side ??= selectSide(frame)?.side;
    if (side == null) return null;
    final angle = _referenceAngle(anglesForSide(frame, side));
    if (angle != null) {
      _droppedSinceMs = null;
      return angle;
    }
    final since = _droppedSinceMs ??= t;
    if (t - since < _sideSwitchAfterMs) return null;
    final other = selectSide(frame);
    if (other == null || other.side == side) return null;
    _side = other.side;
    final switched = _referenceAngle(other);
    _droppedSinceMs = switched == null ? t : null;
    return switched;
  }

  /// visibility가 하한 이상이고 기준 관절 각도가 유한한 양수(0은 측정 불가)면 그 각도.
  double? _referenceAngle(SideAngles angles) {
    if (!(angles.visibility >= _minSideVisibility)) return null;
    final angle = switch (_exercise) {
      ExerciseType.pushUp => angles.elbow,
      ExerciseType.squat => angles.knee,
    };
    return angle.isFinite && angle > 0 ? angle : null;
  }

  /// 운동별 자세 게이트. 푸쉬업은 매 프레임, 스쿼트는 처음 UP 인정 전에만 본다.
  bool _passesGate(PoseFrame frame) => switch (_exercise) {
    ExerciseType.pushUp => passesPostureGate(
      frame,
      ExerciseType.pushUp,
      side: _side,
      maxDeg: _gateMaxDeg,
    ),
    ExerciseType.squat =>
      _counter.phase != RepPhase.unknown ||
          passesPostureGate(
            frame,
            ExerciseType.squat,
            side: _side,
            maxDeg: _gateMaxDeg,
          ),
  };

  /// 사건을 출력으로 바꾼다. 반복이면 하강 직전 UP 프레임부터 endMs까지의
  /// 보관 프레임으로 판정, 채점한다.
  AnalyzerOutput? _toOutput(RepCounterEvent event) {
    switch (event) {
      case RepEvent():
        final errors = judgeRep(
          exercise: _exercise,
          repFrames: List.of(_repFrames),
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

// [QA] 2026-11-13 PASS (docs/qa/QA-TASK-49.md)
// [보안] 외부 입력, 시크릿, 로그 없음. 시각 역행, 측정 쪽 각도를 쓸 수 없는 프레임,
//   자세 게이트를 통과하지 못한 프레임은 건너뜀.
// [유지보수] 판정 프레임은 하강 직전 UP 프레임 1개 + 하강 시작~UP 복귀 프레임(UP 상태에서는
//   1개만 보관, unknown이면 비움). 측정 쪽 전환 시 RepCounter, 이동 평균은 초기화하지 않음
//   (기본값에서는 떨어진 시간 500ms가 이동 평균 창 150ms보다 길어 좌우 값이 섞이지 않음.
//   sideSwitchAfterMs를 창보다 작게 주면 섞일 수 있음). 프레임이 끊긴 시간도 떨어진 시간으로
//   셈. 측정 쪽 각도는 정상인데 게이트만 실패하는 프레임(예: 발목 좌표 NaN)은 떨어진 시각을
//   남기지 않아 측정 쪽이 바뀌지 않음. 스쿼트 게이트는 RepCounter 취소(TASK-56) 뒤 unknown에서도
//   다시 적용됨(테스트 없음). 서서히 뜨는 뒤꿈치는 3초 반복 테스트로만 확인(Q-05 보정 후보).
