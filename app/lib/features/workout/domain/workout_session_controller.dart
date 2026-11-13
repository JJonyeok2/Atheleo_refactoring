// [파일] 세트, 휴식, 일시정지를 진행하는 운동 세션 상태 머신(순수 Dart)
// [Spec] F-08 세트와 휴식, F-06 휴식 종료 3초 전 안내 / [Task] TASK-16
// [의존] RoutinePlan(TASK-10), RepResult(TASK-15). 외부 API, 환경 변수 없음

import 'dart:math' as math;

import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:flutter/foundation.dart';

/// 세션 단계.
enum WorkoutPhase {
  /// 세트 진행 중.
  exercising,

  /// 세트 사이 휴식 중.
  resting,

  /// 일시정지.
  paused,

  /// 종료.
  finished,
}

/// 화면, 저장에 넘기는 세션 상태 스냅샷.
@immutable
class WorkoutSessionState {
  /// 상태를 만든다.
  const new({
    required this.phase,
    required this.currentSet,
    required this.totalSets,
    required this.targetReps,
    required this.repsInSet,
    required this.restRemainingSec,
    required this.sets,
    required this.partialsPerSet,
  });

  /// 현재 단계.
  final WorkoutPhase phase;

  /// 1부터 세는 현재 세트 번호(휴식 중이면 다음 세트 번호).
  final int currentSet;

  /// 전체 세트 수.
  final int totalSets;

  /// 세트당 목표 횟수.
  final int targetReps;

  /// 현재 세트에서 센 횟수.
  final int repsInSet;

  /// 휴식 남은 초(휴식이 아니면 0, 일시정지 중이면 멈춘 값).
  final int restRemainingSec;

  /// 세트별 반복 결과. sets[0]이 1세트, 진행 중인 세트 포함.
  final List<List<RepResult>> sets;

  /// 세트별 부분 반복 수. sets와 길이가 같다.
  final List<int> partialsPerSet;
}

/// 컨트롤러가 내보내는 이벤트(값 비교 가능).
@immutable
sealed class WorkoutEvent {
  const new();
}

/// 반복 1회를 셌다.
final class RepCounted extends WorkoutEvent {
  /// 이벤트를 만든다.
  const new(this.rep, this.repsInSet);

  /// 센 반복 결과.
  final RepResult rep;

  /// 이 반복을 넣은 뒤 현재 세트 횟수.
  final int repsInSet;

  @override
  bool operator ==(Object other) =>
      other is RepCounted && other.rep == rep && other.repsInSet == repsInSet;

  @override
  int get hashCode => Object.hash(rep, repsInSet);

  @override
  String toString() => 'RepCounted($repsInSet)';
}

/// 세트를 마쳤다(마지막 세트에서는 나오지 않음).
final class SetCompleted extends WorkoutEvent {
  /// 이벤트를 만든다.
  const new(this.setIndex, this.restSec);

  /// 마친 세트 번호(1부터).
  final int setIndex;

  /// 이어지는 휴식(초).
  final int restSec;

  @override
  bool operator ==(Object other) =>
      other is SetCompleted &&
      other.setIndex == setIndex &&
      other.restSec == restSec;

  @override
  int get hashCode => Object.hash(setIndex, restSec);

  @override
  String toString() => 'SetCompleted($setIndex, $restSec)';
}

/// 휴식이 3초 이하로 남았다(휴식마다 한 번).
final class RestEndingSoon extends WorkoutEvent {
  /// 이벤트를 만든다.
  const new(this.remainingSec);

  /// 남은 초.
  final int remainingSec;

  @override
  bool operator ==(Object other) =>
      other is RestEndingSoon && other.remainingSec == remainingSec;

  @override
  int get hashCode => remainingSec.hashCode;

  @override
  String toString() => 'RestEndingSoon($remainingSec)';
}

/// 다음 세트를 시작한다.
final class NextSetStarted extends WorkoutEvent {
  /// 이벤트를 만든다.
  const new(this.setIndex);

  /// 시작하는 세트 번호(1부터).
  final int setIndex;

  @override
  bool operator ==(Object other) =>
      other is NextSetStarted && other.setIndex == setIndex;

  @override
  int get hashCode => setIndex.hashCode;

  @override
  String toString() => 'NextSetStarted($setIndex)';
}

/// 세션이 끝났다.
final class WorkoutFinished extends WorkoutEvent {
  /// 이벤트를 만든다.
  const new();

  @override
  bool operator ==(Object other) => other is WorkoutFinished;

  @override
  int get hashCode => (WorkoutFinished).hashCode;

  @override
  String toString() => 'WorkoutFinished()';
}

/// 부분 반복을 감지했다(세트 횟수, 점수에는 넣지 않음).
final class PartialRepNoticed extends WorkoutEvent {
  /// 이벤트를 만든다.
  const new(this.partialsInSet);

  /// 현재 세트의 부분 반복 누적 수.
  final int partialsInSet;

  @override
  bool operator ==(Object other) =>
      other is PartialRepNoticed && other.partialsInSet == partialsInSet;

  @override
  int get hashCode => partialsInSet.hashCode;

  @override
  String toString() => 'PartialRepNoticed($partialsInSet)';
}

/// 반복 결과와 앱 시계 값으로 세트, 휴식, 일시정지를 진행하는 상태 머신.
///
/// 모든 nowMs는 앱 시계(밀리초) 값이다. 이전보다 작은 값이 오면 이전 값으로 본다.
class WorkoutSessionController {
  /// 계획으로 1세트 진행 상태에서 시작한다.
  new(this._plan);

  static const int _endingSoonSec = 3;

  final RoutinePlan _plan;
  final List<List<RepResult>> _sets = [[]];
  final List<int> _partials = [0];

  WorkoutPhase _phase = WorkoutPhase.exercising;
  WorkoutPhase _phaseBeforePause = WorkoutPhase.exercising;
  int _currentSet = 1;
  int _restEndMs = 0;
  int _restRemainingSec = 0;
  int _pausedAtMs = 0;
  bool _endingSoonSent = false;
  int? _lastNowMs;

  /// 현재 상태 스냅샷(목록은 수정 불가 복사본).
  WorkoutSessionState get state => WorkoutSessionState(
    phase: _phase,
    currentSet: _currentSet,
    totalSets: _plan.sets,
    targetReps: _plan.targetReps,
    repsInSet: _sets.last.length,
    restRemainingSec: _restRemainingSec,
    sets: List.unmodifiable(_sets.map(List<RepResult>.unmodifiable)),
    partialsPerSet: List.unmodifiable(_partials),
  );

  /// 반복 1회를 넣는다. 운동 중이 아니면 무시한다.
  List<WorkoutEvent> onRep(RepResult rep, int nowMs) {
    final now = _clock(nowMs);
    if (_phase != WorkoutPhase.exercising) return const [];
    _sets.last.add(rep);
    final reps = _sets.last.length;
    final events = <WorkoutEvent>[RepCounted(rep, reps)];
    if (reps >= _plan.targetReps) events.addAll(_completeSet(now));
    return events;
  }

  /// 부분 반복 1회를 누적한다. 운동 중이 아니면 무시한다.
  List<WorkoutEvent> onPartialRep(int nowMs) {
    _clock(nowMs);
    if (_phase != WorkoutPhase.exercising) return const [];
    _partials.last++;
    return [PartialRepNoticed(_partials.last)];
  }

  /// 휴식 카운트다운을 진행한다. 휴식 중이 아니면 빈 목록.
  List<WorkoutEvent> tick(int nowMs) {
    final now = _clock(nowMs);
    if (_phase != WorkoutPhase.resting) return const [];
    _restRemainingSec = _remainingSec(now);
    if (_restRemainingSec == 0) return [_startNextSet()];
    if (!_endingSoonSent && _restRemainingSec <= _endingSoonSec) {
      _endingSoonSent = true;
      return [RestEndingSoon(_restRemainingSec)];
    }
    return const [];
  }

  /// 휴식을 건너뛰고 다음 세트를 시작한다. 휴식 중이 아니면 빈 목록.
  List<WorkoutEvent> skipRest(int nowMs) {
    _clock(nowMs);
    if (_phase != WorkoutPhase.resting) return const [];
    return [_startNextSet()];
  }

  /// 일시정지한다. 운동 중이나 휴식 중일 때만 동작한다.
  void pause(int nowMs) {
    final now = _clock(nowMs);
    if (_phase != WorkoutPhase.exercising && _phase != WorkoutPhase.resting) {
      return;
    }
    if (_phase == WorkoutPhase.resting) _restRemainingSec = _remainingSec(now);
    _phaseBeforePause = _phase;
    _pausedAtMs = now;
    _phase = WorkoutPhase.paused;
  }

  /// 일시정지를 풀고 이전 단계로 돌아간다. 멈춘 시간만큼 휴식 끝을 민다.
  void resume(int nowMs) {
    final now = _clock(nowMs);
    if (_phase != WorkoutPhase.paused) return;
    _restEndMs += now - _pausedAtMs;
    _phase = _phaseBeforePause;
  }

  /// 사용자가 세션을 끝낸다. 이미 끝났으면 빈 목록.
  List<WorkoutEvent> finish(int nowMs) {
    _clock(nowMs);
    if (_phase == WorkoutPhase.finished) return const [];
    final wasResting =
        _phase == WorkoutPhase.resting ||
        (_phase == WorkoutPhase.paused &&
            _phaseBeforePause == WorkoutPhase.resting);
    if (wasResting) {
      // 휴식 중이면 다음 세트는 시작 전이므로 기록에서 뺀다.
      _sets.removeLast();
      _partials.removeLast();
      _currentSet--;
    }
    return [_finish()];
  }

  /// 앱 시계 값을 단조 증가로 맞춘다(역행하면 이전 값 사용).
  int _clock(int nowMs) {
    final last = _lastNowMs;
    final now = last == null ? nowMs : math.max(last, nowMs);
    _lastNowMs = now;
    return now;
  }

  int _remainingSec(int now) {
    final leftMs = _restEndMs - now;
    if (leftMs <= 0) return 0;
    return math.min((leftMs / 1000).ceil(), _plan.restSec);
  }

  List<WorkoutEvent> _completeSet(int now) {
    if (_currentSet >= _plan.sets) return [_finish()];
    final completed = _currentSet;
    _currentSet++;
    _sets.add([]);
    _partials.add(0);
    final events = <WorkoutEvent>[SetCompleted(completed, _plan.restSec)];
    if (_plan.restSec <= 0) {
      events.add(NextSetStarted(_currentSet));
      return events;
    }
    _phase = WorkoutPhase.resting;
    _restEndMs = now + _plan.restSec * 1000;
    _restRemainingSec = _plan.restSec;
    _endingSoonSent = false;
    return events;
  }

  NextSetStarted _startNextSet() {
    _phase = WorkoutPhase.exercising;
    _restRemainingSec = 0;
    return NextSetStarted(_currentSet);
  }

  WorkoutFinished _finish() {
    _phase = WorkoutPhase.finished;
    _restRemainingSec = 0;
    return const WorkoutFinished();
  }
}

// [QA] 2026-11-13 PASS
// [보안] 외부 입력, 네트워크, 로그 없음. nowMs 역행은 직전 값으로 맞춰 휴식이 늘거나 당겨지지 않음.
// [유지보수] 마지막 세트는 SetCompleted 없이 WorkoutFinished만 냄. 휴식 중 finish는 빈 다음 세트를 빼므로
//   TASK-17 빈 세트 제외와 겹치지만 충돌하지 않음. tick이 3초 구간을 건너뛰면 RestEndingSoon은 생략됨.
//   state는 호출마다 목록을 복사하므로 TASK-27은 이벤트나 tick 뒤에만 읽는 편이 좋음.
