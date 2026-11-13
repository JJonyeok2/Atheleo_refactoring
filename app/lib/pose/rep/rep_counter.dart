// [파일] 반복 횟수 상태 머신(UP, 하강, DOWN 판정, 부분 반복 감지, 원시 각도 최저점).
// [Spec] F-03 횟수 판정, F-04 최저 각도(깊이 판정 입력) / [Task] TASK-08
// [의존] ExerciseType만 사용 (환경 변수 사용 안 함)

import 'package:atheleo/pose/landmarks/exercise_type.dart';

/// 반복 판정 임계값(도, 밀리초).
class RepThresholds {
  /// 임계값을 만든다.
  const new({
    required this.upDeg,
    required this.descendDeg,
    required this.downDeg,
    required this.minRepMs,
  });

  /// 운동별 기본 임계값. 푸쉬업 600ms, 스쿼트 800ms.
  // 계약상 static 메서드로 둔다(TASK-08 내보내는 것).
  // ignore: prefer_constructors_over_static_methods
  static RepThresholds forExercise(ExerciseType exercise) => RepThresholds(
    upDeg: 160,
    descendDeg: 145,
    downDeg: 120,
    minRepMs: switch (exercise) {
      ExerciseType.pushUp => 600,
      ExerciseType.squat => 800,
    },
  );

  /// 이 값 이상이면 UP.
  final double upDeg;

  /// 이 값 미만이면 하강 시작.
  final double descendDeg;

  /// 이 값 이하면 DOWN(횟수 인정 깊이).
  final double downDeg;

  /// 하강 시작부터 UP 복귀까지 최소 시간.
  final int minRepMs;
}

/// 반복 상태.
enum RepPhase {
  /// 아직 UP에 도달하지 않음.
  unknown,

  /// UP 자세.
  up,

  /// descendDeg 미만, 아직 downDeg 이하에 닿지 않음.
  descending,

  /// downDeg 이하에 닿음.
  down,
}

/// 반복이나 부분 반복이 끝난 프레임에서 나오는 사건.
sealed class RepCounterEvent {
  const new();
}

/// 인정된 반복 1회.
final class RepEvent extends RepCounterEvent {
  /// 사건을 만든다.
  const new({
    required this.repIndex,
    required this.startMs,
    required this.bottomMs,
    required this.endMs,
    required this.minAngle,
  });

  /// reset 이후 1부터 세는 반복 번호.
  final int repIndex;

  /// 하강 시작 시각.
  final int startMs;

  /// 원시 각도가 가장 낮은 프레임 시각.
  final int bottomMs;

  /// UP 복귀 시각.
  final int endMs;

  /// 원시 각도 최저점 주변 3프레임 중앙값.
  final double minAngle;

  /// 1회 시간.
  int get durationMs => endMs - startMs;
}

/// DOWN에 닿지 못하고 UP으로 돌아온 부분 반복.
final class PartialRepEvent extends RepCounterEvent {
  /// 사건을 만든다.
  const new({
    required this.startMs,
    required this.endMs,
    required this.minAngle,
  });

  /// 하강 시작 시각.
  final int startMs;

  /// UP 복귀 시각.
  final int endMs;

  /// 원시 각도 최저점 주변 3프레임 중앙값.
  final double minAngle;
}

/// 이동 평균 각도로 UP, 하강, DOWN을 판정해 반복을 센다.
class RepCounter {
  /// 임계값으로 카운터를 만든다.
  new(this._thresholds);

  final RepThresholds _thresholds;

  RepPhase _phase = RepPhase.unknown;
  int _count = 0;
  int _partialCount = 0;
  int _startMs = 0;
  final List<int> _timestamps = [];
  final List<double> _rawAngles = [];

  /// 인정된 반복 수.
  int get count => _count;

  /// 부분 반복 수.
  int get partialCount => _partialCount;

  /// 현재 상태.
  RepPhase get phase => _phase;

  /// 프레임 하나를 넣는다. [angle]은 이동 평균 각도(상태 전이용),
  /// [rawAngle]은 원시 각도(최저 각도용, 없으면 [angle]).
  /// 반복이나 부분 반복이 끝난 프레임에서만 사건을 돌려준다.
  RepCounterEvent? update({
    required int timestampMs,
    required double angle,
    double? rawAngle,
  }) {
    final raw = rawAngle ?? angle;
    switch (_phase) {
      case RepPhase.unknown:
        if (angle >= _thresholds.upDeg) _phase = RepPhase.up;
        return null;
      case RepPhase.up:
        if (angle < _thresholds.descendDeg) {
          _phase = RepPhase.descending;
          _startMs = timestampMs;
          _timestamps
            ..clear()
            ..add(timestampMs);
          _rawAngles
            ..clear()
            ..add(raw);
          if (angle <= _thresholds.downDeg) _phase = RepPhase.down;
        }
        return null;
      case RepPhase.descending:
      case RepPhase.down:
        _timestamps.add(timestampMs);
        _rawAngles.add(raw);
        if (angle >= _thresholds.upDeg) return _finish(timestampMs);
        if (angle <= _thresholds.downDeg) _phase = RepPhase.down;
        return null;
    }
  }

  /// UP 복귀 프레임에서 반복 또는 부분 반복을 마무리한다.
  RepCounterEvent? _finish(int endMs) {
    final reachedDown = _phase == RepPhase.down;
    _phase = RepPhase.up;
    final bottom = _bottom();
    if (!reachedDown) {
      _partialCount++;
      return PartialRepEvent(
        startMs: _startMs,
        endMs: endMs,
        minAngle: bottom.angle,
      );
    }
    if (endMs - _startMs < _thresholds.minRepMs) return null;
    _count++;
    return RepEvent(
      repIndex: _count,
      startMs: _startMs,
      bottomMs: bottom.ms,
      endMs: endMs,
      minAngle: bottom.angle,
    );
  }

  /// 원시 각도 최저 프레임 시각과, 그 주변 연속 3프레임 중앙값.
  ({int ms, double angle}) _bottom() {
    var minIndex = 0;
    for (var i = 1; i < _rawAngles.length; i++) {
      if (_rawAngles[i] < _rawAngles[minIndex]) minIndex = i;
    }
    final n = _rawAngles.length;
    final double angle;
    if (n < 3) {
      angle = _rawAngles.reduce((a, b) => a + b) / n;
    } else {
      final center = minIndex.clamp(1, n - 2);
      final window = _rawAngles.sublist(center - 1, center + 2)..sort();
      angle = window[1];
    }
    return (ms: _timestamps[minIndex], angle: angle);
  }

  /// count, partialCount, 상태를 처음으로 돌린다.
  void reset() {
    _phase = RepPhase.unknown;
    _count = 0;
    _partialCount = 0;
    _timestamps.clear();
    _rawAngles.clear();
  }
}

// [QA] 2026-11-13 PASS
// [보안] 외부 입력, 로그, 시크릿 없음. timestampMs 역행과 NaN 각도는 검증하지 않음
//   (호출하는 TASK-15가 쓸 수 없는 프레임을 건너뜀). NaN이 들어오면 상태 전이는 멈추고
//   _bottom이 NaN 프레임을 최저로 고를 수 있음.
// [유지보수] 하강/DOWN에 머무는 동안 _timestamps, _rawAngles가 계속 늘어남(상한 없음).
//   최소 시간 미달 반복은 사건 없이 버려지므로 빠른 반복은 사용자에게 아무 피드백이 없음.
//   바닥에서 오래 쉬다 일어나는 동작도 1회로 셀 수 있음(최대 시간 규칙 없음, 자세 게이트 몫).
