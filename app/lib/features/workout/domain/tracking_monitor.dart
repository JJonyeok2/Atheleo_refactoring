// [파일] 추적 감시(사람 미검출 일시정지 판단, 저사양 lite 전환 판단).
// [Spec] F-01 예외 흐름(사람이 안 보일 때, 추론이 느릴 때) / [Task] TASK-26
// [의존] 없음 (순수 로직, 주입된 시각 값만 사용, 환경 변수 사용 안 함)

import 'dart:collection';

/// 감시가 내보내는 신호.
enum TrackingSignal {
  /// 사람이 기준 시간 이상 안 보임(일시정지).
  personLost,

  /// 사람이 다시 잡힘(자동 재개).
  personReturned,

  /// 추론이 느려 lite 모델로 전환.
  switchToLite,
}

/// 결과 시각만으로 "사람 미검출"과 "추론 속도 부족"을 판단한다.
class TrackingMonitor {
  /// 감시기를 만든다.
  new({
    Duration lostAfter = const Duration(seconds: 2),
    Duration fpsWindow = const Duration(seconds: 10),
    this._minFps = 10,
  }) : _lostAfterMs = lostAfter.inMilliseconds,
       _windowMs = fpsWindow.inMilliseconds;

  final int _lostAfterMs;
  final int _windowMs;
  final double _minFps;

  final Queue<int> _recent = Queue<int>();
  int? _measureStartMs;
  int? _lostSinceMs;
  bool _personLost = false;
  bool _switchedToLite = false;

  /// 사람이 2초 이상 안 보여 일시정지 판단이 난 상태인가.
  bool get isPersonLost => _personLost;

  /// lite 모델로 전환 신호를 이미 냈는가.
  bool get switchedToLite => _switchedToLite;

  /// 추론 결과 하나를 넣고 이번에 나온 신호 목록을 돌려준다.
  List<TrackingSignal> onResult({
    required int timestampMs,
    required bool hasPerson,
  }) {
    final signals = <TrackingSignal>[];
    _trackPerson(timestampMs, hasPerson, signals);
    _trackSpeed(timestampMs, signals);
    return signals;
  }

  /// 미검출 상태와 fps 창을 비운다. lite 전환 기록은 유지한다.
  void reset() {
    _recent.clear();
    _measureStartMs = null;
    _lostSinceMs = null;
    _personLost = false;
  }

  void _trackPerson(int ts, bool hasPerson, List<TrackingSignal> out) {
    if (hasPerson) {
      _lostSinceMs = null;
      if (_personLost) {
        _personLost = false;
        out.add(TrackingSignal.personReturned);
      }
      return;
    }
    final since = _lostSinceMs ??= ts;
    if (!_personLost && ts - since >= _lostAfterMs) {
      _personLost = true;
      out.add(TrackingSignal.personLost);
    }
  }

  void _trackSpeed(int ts, List<TrackingSignal> out) {
    final start = _measureStartMs ??= ts;
    _recent.addLast(ts);
    while (_recent.isNotEmpty && _recent.first <= ts - _windowMs) {
      _recent.removeFirst();
    }
    if (_switchedToLite || ts - start < _windowMs) return;
    final fps = _recent.length / (_windowMs / 1000);
    if (fps < _minFps) {
      _switchedToLite = true;
      out.add(TrackingSignal.switchToLite);
    }
  }
}

// [QA] 2026-11-13 PASS (FIX 반영 재검토)
// [보안] 외부 입력, 로그, 시크릿 없음. 시각 값은 호출부가 넣는 프레임 시각만 씀.
// [유지보수] reset은 personLost를 풀지만 personReturned를 내지 않으므로,
//   호출부(TASK-28)는 "사람이 없어 멈춤" 플래그를 resume() 경로에서 직접 풀어야 함.
//   시각이 거꾸로 들어오는 경우(reset 직후 이전 프레임 결과 도착 등)는 검사하지 않음.
//   fps는 사람 유무와 관계없이 결과 개수로 셈(감지기 처리 속도 기준).
// [FIX 반영] minFps를 private named parameter(this._minFps)로 변경, ignore 주석 제거.
