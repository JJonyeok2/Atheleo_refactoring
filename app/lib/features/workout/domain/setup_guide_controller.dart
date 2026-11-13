// [파일] 촬영 가이드 상태 머신: 프레임과 주입된 시각으로 준비 조건 안정 시간, 카운트다운, ready를 판정하고 운동별 문구를 낸다.
// [Spec] F-07 촬영 가이드, F-06 음성 안내(상태 문구) / [Task] TASK-14
// [의존] pose/body(body_check), pose/angle(selectSide), pose/landmarks (환경 변수 사용 안 함)

import 'package:atheleo/pose/angle/joint_angle.dart';
import 'package:atheleo/pose/body/body_check.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter/foundation.dart';

/// 촬영 가이드 상태. 위에서부터 먼저 걸리는 조건이 상태가 된다.
enum SetupGuideStatus {
  /// 프레임 없음(사람 미검출).
  noPerson,

  /// 전신 인식 실패.
  notFullBody,

  /// 정면으로 서 있음.
  frontFacing,

  /// 자세 게이트 실패 또는 기준 관절이 펴지지 않음.
  notInPosture,

  /// 준비 조건 통과, 안정 시간 미만.
  holding,

  /// 안정 시간 유지 후 카운트다운 중.
  countdown,

  /// 카운트다운 끝(운동 시작).
  ready,
}

/// 화면, 음성에 넘기는 가이드 상태 한 개.
@immutable
class SetupGuideState {
  /// 상태를 만든다. [countdown]은 countdown 상태에서만 값이 있다.
  const new({required this.status, required this.message, this.countdown});

  /// 상태.
  final SetupGuideStatus status;

  /// 화면에 보일 문구.
  final String message;

  /// 남은 카운트다운 숫자(3, 2, 1). countdown 상태가 아니면 null.
  final int? countdown;

  @override
  bool operator ==(Object other) =>
      other is SetupGuideState &&
      other.status == status &&
      other.message == message &&
      other.countdown == countdown;

  @override
  int get hashCode => Object.hash(status, message, countdown);

  @override
  String toString() => 'SetupGuideState($status, $message, $countdown)';
}

/// 운동별 거리 안내와 준비 자세 안내 문구.
class SetupGuideTexts {
  /// 문구 묶음을 만든다.
  const new({required this.distanceHint, required this.postureHint});

  /// 전신이 안 보일 때 보이는 거리 안내.
  final String distanceHint;

  /// 준비 자세가 아닐 때 보이는 안내.
  final String postureHint;
}

const _pushUpTexts = SetupGuideTexts(
  distanceHint: '휴대폰을 옆에 세우고 측면에서 약 2m 이상 떨어져 주세요. 전신이 화면에 들어와야 해요.',
  postureHint: '엎드려 팔을 편 자세를 잡아 주세요',
);

const _squatTexts = SetupGuideTexts(
  distanceHint: '휴대폰을 옆에 세우고 측면에서 약 2m 떨어져 주세요. 전신이 화면에 들어와야 해요.',
  postureHint: '똑바로 서서 무릎을 펴 주세요',
);

const _noPersonText = '카메라 앞에 서 주세요';
const _frontFacingText = '옆으로 서 주세요';
const _holdingText = '그대로 유지하세요';
const _readyText = '시작';

/// 준비 자세로 인정하는 기준 관절(푸쉬업 팔꿈치, 스쿼트 무릎) 최소 각도.
const double _minReadyJointDeg = 160;

const _initialState = SetupGuideState(
  status: SetupGuideStatus.noPerson,
  message: _noPersonText,
);

/// [exercise]의 촬영 가이드 문구.
SetupGuideTexts setupGuideTextsFor(ExerciseType exercise) => switch (exercise) {
  ExerciseType.pushUp => _pushUpTexts,
  ExerciseType.squat => _squatTexts,
};

/// 프레임과 주입된 시각만으로 움직이는 촬영 가이드 상태 머신.
///
/// 준비 조건(전신, 측면, 자세 게이트, 기준 관절 160도 이상)이 `stableFor` 동안
/// 이어지면 `countdownSec`초 카운트다운 후 ready가 된다. 중간에 조건이 깨지면
/// 그 상태로 돌아가고 시간은 처음부터 잰다. ready가 되면 [reset] 전까지
/// 바뀌지 않는다.
class SetupGuideController {
  /// `exercise` 운동용 가이드를 만든다.
  new({
    required this._exercise,
    Duration stableFor = const Duration(seconds: 2),
    this._countdownSec = 3,
    Duration maxFrameGap = const Duration(milliseconds: 500),
  }) : _stableMs = stableFor.inMilliseconds,
       _maxGapMs = maxFrameGap.inMilliseconds,
       _texts = setupGuideTextsFor(_exercise);

  final ExerciseType _exercise;
  final int _countdownSec;
  final int _stableMs;
  final int _maxGapMs;
  final SetupGuideTexts _texts;

  SetupGuideState _state = _initialState;

  /// 준비 조건이 이어지기 시작한 시각. 조건이 깨져 있으면 null.
  int? _readySinceMs;

  /// 직전 `update`의 시각(null 프레임 포함). reset 직후에는 null.
  int? _lastUpdateMs;

  /// 마지막으로 계산한 상태.
  SetupGuideState get state => _state;

  /// 프레임 하나와 그 시각을 넣고 새 상태를 돌려준다.
  ///
  /// [frame]이 null이면 사람이 없는 것으로 본다. 시각이 준비 시작 시각보다
  /// 앞이면(역행), 또는 직전 `update`와 간격이 `maxFrameGap`을 넘으면 그 시각부터 다시 잰다.
  SetupGuideState update(PoseFrame? frame, int timestampMs) {
    if (_state.status == SetupGuideStatus.ready) return _state;
    final last = _lastUpdateMs;
    _lastUpdateMs = timestampMs;
    final blocked = _blockingState(frame);
    if (blocked != null) {
      _readySinceMs = null;
      return _state = blocked;
    }
    final since = _readySinceMs;
    final gapExceeded = last != null && timestampMs - last > _maxGapMs;
    final start = (since == null || timestampMs < since || gapExceeded)
        ? timestampMs
        : since;
    _readySinceMs = start;
    return _state = _timedState(timestampMs - start);
  }

  /// 처음 상태로 돌린다.
  void reset() {
    _state = _initialState;
    _readySinceMs = null;
    _lastUpdateMs = null;
  }

  /// 준비 조건을 막는 첫 상태. 모두 통과하면 null.
  SetupGuideState? _blockingState(PoseFrame? frame) {
    if (frame == null) return _initialState;
    if (!isFullBodyVisible(frame)) {
      return SetupGuideState(
        status: SetupGuideStatus.notFullBody,
        message: _texts.distanceHint,
      );
    }
    if (isFrontFacing(frame)) {
      return const SetupGuideState(
        status: SetupGuideStatus.frontFacing,
        message: _frontFacingText,
      );
    }
    if (!_isInPosture(frame)) {
      return SetupGuideState(
        status: SetupGuideStatus.notInPosture,
        message: _texts.postureHint,
      );
    }
    return null;
  }

  /// 자세 게이트를 통과하고 기준 관절이 [_minReadyJointDeg] 이상이면 true.
  bool _isInPosture(PoseFrame frame) {
    final side = selectSide(frame);
    if (side == null || !passesPostureGate(frame, _exercise)) return false;
    final joint = switch (_exercise) {
      ExerciseType.pushUp => side.elbow,
      ExerciseType.squat => side.knee,
    };
    return joint >= _minReadyJointDeg;
  }

  /// 준비 조건이 [elapsedMs] 동안 이어졌을 때의 상태.
  SetupGuideState _timedState(int elapsedMs) {
    if (elapsedMs < _stableMs) {
      return const SetupGuideState(
        status: SetupGuideStatus.holding,
        message: _holdingText,
      );
    }
    final remaining = _countdownSec - (elapsedMs - _stableMs) ~/ 1000;
    if (remaining <= 0) {
      return const SetupGuideState(
        status: SetupGuideStatus.ready,
        message: _readyText,
      );
    }
    return SetupGuideState(
      status: SetupGuideStatus.countdown,
      message: '$remaining',
      countdown: remaining,
    );
  }
}

// [QA] 2026-11-13 PASS (FIX 재검토)
// [보안] 외부 입력은 PoseFrame과 timestampMs뿐. 좌표 이상값은 body_check가 false로 거름.
//   시각 역행은 그 시각부터 다시 잼. 직전 update와 간격이 maxFrameGap(기본 500ms)을 넘으면
//   그 시각부터 다시 재므로 카메라 정지나 백그라운드 복귀 뒤 카운트다운을 건너뛰지 않음.
// [유지보수] 기준 관절 160도, 카운트다운 1초 단위는 상수. stableFor, countdownSec, maxFrameGap은
//   음수나 0을 막지 않음(호출은 기본값뿐, 비차단). ready는 reset 전까지 고정이라 ready 이후
//   _lastUpdateMs를 갱신하지 않아도 되고, reset의 _lastUpdateMs 비우기는 동작상 드러나지 않는 정리.
//   스쿼트 notInPosture 문구는 사용자 결정(2026-11-13)으로 '똑바로 서서 무릎을 펴 주세요'.
