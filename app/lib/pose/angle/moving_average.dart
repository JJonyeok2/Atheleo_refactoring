// [파일] 각도 시간 기준 이동 평균(MovingAverage). 최근 windowMs 안의 값을 평균, 최소 1프레임 유지.
// [Spec] 7장 횟수 판정 기준(이동 평균, 시간 기준) / [Task] TASK-07
// [의존] 없음 (환경 변수 사용 안 함)

import 'dart:collection';

/// 최근 `windowMs` 밀리초 안의 값들의 이동 평균(시간 기준 창).
///
/// 가장 최근 값은 항상 남고, 그 밖의 값은
/// `최근 타임스탬프 - 값의 타임스탬프 < windowMs`일 때만 남는다.
class MovingAverage {
  /// [windowMs]는 1 이상이어야 하며, 아니면 `ArgumentError`를 던진다.
  new({int windowMs = 150}) : _windowMs = _validate(windowMs);

  final int _windowMs;
  final Queue<({int timestampMs, double value})> _entries = Queue();
  double _sum = 0;

  static int _validate(int windowMs) {
    if (windowMs < 1) {
      throw ArgumentError.value(windowMs, 'windowMs', '1 이상이어야 합니다');
    }
    return windowMs;
  }

  /// 지금 창에 든 값의 개수.
  int get length => _entries.length;

  /// [value]를 넣고 넣은 뒤 창 안 값들의 평균을 돌려준다.
  ///
  /// 타임스탬프가 직전 값보다 작으면 `ArgumentError`를 던진다(reset 후 다시 넣어야 함).
  /// NaN, Infinity는 버리고 현재 평균을 돌려준다(비어 있으면 0).
  double add(double value, int timestampMs) {
    if (_entries.isNotEmpty && timestampMs < _entries.last.timestampMs) {
      throw ArgumentError.value(
        timestampMs,
        'timestampMs',
        '직전 타임스탬프(${_entries.last.timestampMs})보다 작을 수 없습니다',
      );
    }
    if (value.isFinite) {
      _entries.addLast((timestampMs: timestampMs, value: value));
      _sum += value;
      while (_entries.length > 1 &&
          timestampMs - _entries.first.timestampMs >= _windowMs) {
        _sum -= _entries.removeFirst().value;
      }
      if (_entries.length == 1) _sum = _entries.first.value; // 오차 누적 차단
    }
    return _entries.isEmpty ? 0 : _sum / _entries.length;
  }

  /// 쌓인 값을 모두 비운다.
  void reset() {
    _entries.clear();
    _sum = 0;
  }
}

// [QA] 2026-11-13 PASS
// [보안] 입력, 네트워크, 시크릿 없음. windowMs < 1, 타임스탬프 역행은 ArgumentError.
// [유지보수] NaN/Infinity는 저장하지 않으므로 그 프레임의 타임스탬프도 기억하지 않는다
//   (역행 검사는 마지막으로 저장된 유한 값 기준). 유한하지 않은 값만 오래 들어오면
//   창이 밀리지 않아 이전 평균이 그대로 유지되므로, 포즈 유실이 길거나 일시정지 후에는
//   호출하는 쪽(TASK-15, TASK-52)이 reset해야 한다.
