import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/features/workout/domain/workout_session_controller.dart';
import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:flutter_test/flutter_test.dart';

RoutinePlan _plan({int targetReps = 10, int sets = 3, int restSec = 30}) =>
    RoutinePlan(
      exercise: ExerciseType.squat,
      level: RoutineLevel.beginner,
      targetReps: targetReps,
      sets: sets,
      restSec: restSec,
      minScore: 60,
    );

RepResult _rep(int index) => RepResult(
  repIndex: index,
  score: 80,
  minAngle: 90,
  durationMs: 1200,
  errors: const [],
);

/// 현재 세트를 nowMs에 다 채우고 마지막 onRep의 이벤트를 돌려준다.
List<WorkoutEvent> _fillSet(WorkoutSessionController c, int nowMs) {
  var events = <WorkoutEvent>[];
  for (var i = c.state.repsInSet; i < c.state.targetReps; i++) {
    events = c.onRep(_rep(i + 1), nowMs);
  }
  return events;
}

void main() {
  group('세트 진행 (F-08)', () {
    test('10회 채우면 2세트와 휴식', () {
      final c = WorkoutSessionController(_plan());
      for (var i = 1; i <= 9; i++) {
        final events = c.onRep(_rep(i), i * 1000);
        expect(events, hasLength(1));
        expect((events.single as RepCounted).repsInSet, i);
      }
      final events = c.onRep(_rep(10), 10000);
      expect(events, hasLength(2));
      expect(events[0], isA<RepCounted>());
      expect((events[0] as RepCounted).repsInSet, 10);
      expect(events[1], const SetCompleted(1, 30));
      expect(c.state.currentSet, 2);
      expect(c.state.phase, WorkoutPhase.resting);
      expect(c.state.restRemainingSec, 30);
      expect(c.state.repsInSet, 0);
      expect(c.state.sets, hasLength(2));
      expect(c.state.sets[0], hasLength(10));
      expect(c.state.sets[1], isEmpty);
      expect(c.state.partialsPerSet, [0, 0]);
    });

    test('휴식 카운트다운과 다음 세트', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      expect(c.tick(10000), isEmpty);
      expect(c.state.restRemainingSec, 20);
      expect(c.tick(30000), [const NextSetStarted(2)]);
      expect(c.state.phase, WorkoutPhase.exercising);
      expect(c.state.restRemainingSec, 0);
      expect(c.state.currentSet, 2);
    });

    test('남은 초는 올림으로 계산한다', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      c.tick(10001);
      expect(c.state.restRemainingSec, 20);
      c.tick(10999);
      expect(c.state.restRemainingSec, 20);
      c.tick(11000);
      expect(c.state.restRemainingSec, 19);
    });
  });

  group('휴식 종료 3초 전 (F-06)', () {
    test('27초에 한 번만 RestEndingSoon(3)', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      expect(c.tick(26000), isEmpty);
      expect(c.tick(27000), [const RestEndingSoon(3)]);
      expect(c.tick(28000), isEmpty);
      expect(c.tick(29000), isEmpty);
      expect(c.tick(30000), [const NextSetStarted(2)]);
    });

    test('3초 전 tick을 건너뛰고 바로 끝나면 NextSetStarted만', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      expect(c.tick(20000), isEmpty);
      expect(c.tick(31000), [const NextSetStarted(2)]);
    });

    test('다음 휴식에서는 다시 한 번 나온다', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      c
        ..tick(27000)
        ..tick(30000);
      _fillSet(c, 40000);
      expect(c.tick(67000), [const RestEndingSoon(3)]);
    });
  });

  group('부분 반복', () {
    test('부분 반복 누적', () {
      final c = WorkoutSessionController(_plan());
      expect(c.onPartialRep(100), [const PartialRepNoticed(1)]);
      expect(c.onRep(_rep(1), 200), hasLength(1));
      expect(c.onPartialRep(300), [const PartialRepNoticed(2)]);
      expect(c.state.repsInSet, 1);
      expect(c.state.partialsPerSet[0], 2);
      expect(c.state.sets[0], hasLength(1));
    });

    test('부분 반복은 세트별로 따로 센다', () {
      final c = WorkoutSessionController(_plan())..onPartialRep(0);
      _fillSet(c, 0);
      c.tick(30000);
      expect(c.onPartialRep(31000), [const PartialRepNoticed(1)]);
      expect(c.state.partialsPerSet, [1, 1]);
    });
  });

  group('무시 조건', () {
    test('휴식 중 무시', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      expect(c.onRep(_rep(11), 1000), isEmpty);
      expect(c.onPartialRep(1000), isEmpty);
      expect(c.state.repsInSet, 0);
      expect(c.state.partialsPerSet[1], 0);
      expect(c.state.sets[1], isEmpty);
    });

    test('일시정지 중 이벤트는 무시', () {
      final c = WorkoutSessionController(_plan())..pause(0);
      expect(c.state.phase, WorkoutPhase.paused);
      expect(c.onRep(_rep(1), 100), isEmpty);
      expect(c.onPartialRep(100), isEmpty);
      expect(c.tick(100), isEmpty);
      expect(c.skipRest(100), isEmpty);
      expect(c.state.repsInSet, 0);
      expect(c.state.partialsPerSet[0], 0);
      c.resume(200);
      expect(c.state.phase, WorkoutPhase.exercising);
      expect(c.onRep(_rep(1), 300), hasLength(1));
    });

    test('종료 후 무시', () {
      final c = WorkoutSessionController(_plan())..finish(0);
      expect(c.onRep(_rep(1), 100), isEmpty);
      expect(c.onPartialRep(100), isEmpty);
      expect(c.tick(100), isEmpty);
      expect(c.skipRest(100), isEmpty);
      expect(c.finish(100), isEmpty);
      c
        ..pause(100)
        ..resume(200);
      expect(c.state.phase, WorkoutPhase.finished);
    });

    test('운동 중 tick, skipRest는 빈 목록', () {
      final c = WorkoutSessionController(_plan());
      expect(c.tick(1000), isEmpty);
      expect(c.skipRest(1000), isEmpty);
      expect(c.state.phase, WorkoutPhase.exercising);
    });
  });

  group('건너뛰기', () {
    test('건너뛰기', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      expect(c.skipRest(5000), [const NextSetStarted(2)]);
      expect(c.state.phase, WorkoutPhase.exercising);
      expect(c.state.restRemainingSec, 0);
      expect(c.tick(27000), isEmpty);
      expect(c.tick(30000), isEmpty);
    });

    test('3초 안쪽에서 건너뛰어도 이후 RestEndingSoon 없음', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      expect(c.skipRest(28500), [const NextSetStarted(2)]);
      expect(c.tick(29000), isEmpty);
    });
  });

  group('일시정지', () {
    test('일시정지 중 휴식 멈춤', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      c.pause(5000);
      expect(c.state.phase, WorkoutPhase.paused);
      expect(c.state.restRemainingSec, 25);
      c.resume(25000);
      expect(c.state.phase, WorkoutPhase.resting);
      expect(c.tick(49999), [const RestEndingSoon(1)]);
      expect(c.state.restRemainingSec, 1);
      expect(c.tick(50000), [const NextSetStarted(2)]);
    });

    test('일시정지 중에는 휴식 남은 초가 줄지 않는다', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      c
        ..pause(5000)
        ..tick(40000);
      expect(c.state.restRemainingSec, 25);
      expect(c.state.phase, WorkoutPhase.paused);
    });

    test('pause 두 번, 쉬지 않는 resume은 무시', () {
      final c = WorkoutSessionController(_plan())..resume(0);
      expect(c.state.phase, WorkoutPhase.exercising);
      _fillSet(c, 0);
      c
        ..pause(5000)
        ..pause(10000)
        ..resume(25000);
      // 첫 pause 기준 20초가 밀림.
      expect(c.tick(49999), [const RestEndingSoon(1)]);
      expect(c.tick(50000), [const NextSetStarted(2)]);
    });
  });

  group('종료', () {
    test('3세트 모두 채우면 WorkoutFinished', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      c.tick(30000);
      _fillSet(c, 40000);
      c.skipRest(41000);
      final events = _fillSet(c, 50000);
      expect(events, hasLength(2));
      expect(events[0], isA<RepCounted>());
      expect(events[1], const WorkoutFinished());
      expect(c.state.phase, WorkoutPhase.finished);
      expect(c.state.sets, hasLength(3));
      expect(c.state.partialsPerSet, hasLength(3));
      expect(c.state.currentSet, 3);
      expect(c.state.restRemainingSec, 0);
    });

    test('1세트 4회에서 finish', () {
      final c = WorkoutSessionController(_plan());
      for (var i = 1; i <= 4; i++) {
        c.onRep(_rep(i), i * 1000);
      }
      expect(c.finish(5000), [const WorkoutFinished()]);
      expect(c.state.phase, WorkoutPhase.finished);
      expect(c.state.sets, hasLength(1));
      expect(c.state.sets[0], hasLength(4));
    });

    test('휴식 중 finish는 시작 안 한 다음 세트를 빼고 끝낸다', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      expect(c.finish(1000), [const WorkoutFinished()]);
      expect(c.state.sets, hasLength(1));
      expect(c.state.partialsPerSet, hasLength(1));
      expect(c.state.currentSet, 1);
      expect(c.state.restRemainingSec, 0);
    });

    test('일시정지 중 finish도 끝낸다', () {
      final c = WorkoutSessionController(_plan())..pause(0);
      expect(c.finish(100), [const WorkoutFinished()]);
      expect(c.state.phase, WorkoutPhase.finished);
    });

    test('1세트 계획은 휴식 없이 바로 끝난다', () {
      final c = WorkoutSessionController(_plan(sets: 1));
      final events = _fillSet(c, 0);
      expect(events.last, const WorkoutFinished());
      expect(events.whereType<SetCompleted>(), isEmpty);
    });
  });

  group('경계', () {
    test('휴식 0초면 세트 완료와 동시에 다음 세트', () {
      final c = WorkoutSessionController(_plan(restSec: 0));
      final events = _fillSet(c, 0);
      expect(events, hasLength(3));
      expect(events[1], const SetCompleted(1, 0));
      expect(events[2], const NextSetStarted(2));
      expect(c.state.phase, WorkoutPhase.exercising);
      expect(c.state.currentSet, 2);
      expect(c.state.restRemainingSec, 0);
      expect(c.tick(1000), isEmpty);
    });

    test('목표 도달 직후 같은 시각 이벤트는 무시', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 1000);
      expect(c.onRep(_rep(11), 1000), isEmpty);
      expect(c.onPartialRep(1000), isEmpty);
      expect(c.tick(1000), isEmpty);
      expect(c.state.restRemainingSec, 30);
    });

    test('시각이 거꾸로 와도 남은 초가 늘지 않는다', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 10000);
      expect(c.tick(20000), isEmpty);
      expect(c.state.restRemainingSec, 20);
      expect(c.tick(5000), isEmpty);
      expect(c.state.restRemainingSec, 20);
      expect(c.tick(40000), [const NextSetStarted(2)]);
    });

    test('resume 시각이 pause보다 앞서도 휴식이 당겨지지 않는다', () {
      final c = WorkoutSessionController(_plan());
      _fillSet(c, 0);
      c
        ..pause(10000)
        ..resume(8000);
      expect(c.tick(29999), [const RestEndingSoon(1)]);
      expect(c.tick(30000), [const NextSetStarted(2)]);
    });

    test('3초 이하 휴식은 첫 tick에 RestEndingSoon', () {
      final c = WorkoutSessionController(_plan(restSec: 2));
      _fillSet(c, 0);
      expect(c.tick(100), [const RestEndingSoon(2)]);
      expect(c.tick(2000), [const NextSetStarted(2)]);
    });
  });

  group('상태 불변', () {
    test('state의 목록을 바꿀 수 없다', () {
      final c = WorkoutSessionController(_plan())..onRep(_rep(1), 0);
      final s = c.state;
      expect(() => s.sets.add([]), throwsUnsupportedError);
      expect(() => s.sets[0].add(_rep(2)), throwsUnsupportedError);
      expect(() => s.partialsPerSet.add(1), throwsUnsupportedError);
    });

    test('초기 상태', () {
      final s = WorkoutSessionController(_plan()).state;
      expect(s.phase, WorkoutPhase.exercising);
      expect(s.currentSet, 1);
      expect(s.totalSets, 3);
      expect(s.targetReps, 10);
      expect(s.repsInSet, 0);
      expect(s.restRemainingSec, 0);
      expect(s.sets, [isEmpty]);
      expect(s.partialsPerSet, [0]);
    });
  });
}
