import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/rep/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_clip.dart';

/// 30fps 프레임 번호를 밀리초 시각으로 바꾼다.
int _ms30(int frame) => (frame * 1000 / 30).round();

/// [angles]를 차례로 넣고 나온 사건을 모두 돌려준다.
/// [stepMs]가 없으면 30fps 시각을 쓴다. [startMs]부터 시각을 센다.
List<RepCounterEvent> _feed(
  RepCounter counter,
  List<double> angles, {
  List<double>? rawAngles,
  int? stepMs,
  int startMs = 0,
}) {
  final events = <RepCounterEvent>[];
  for (var i = 0; i < angles.length; i++) {
    final ts = startMs + (stepMs == null ? _ms30(i) : i * stepMs);
    final event = counter.update(
      timestampMs: ts,
      angle: angles[i],
      rawAngle: rawAngles?[i],
    );
    if (event != null) events.add(event);
  }
  return events;
}

RepCounter _pushUp() =>
    RepCounter(RepThresholds.forExercise(ExerciseType.pushUp));

RepCounter _squat() =>
    RepCounter(RepThresholds.forExercise(ExerciseType.squat));

void main() {
  group('RepThresholds.forExercise', () {
    test('푸쉬업, 스쿼트 기본 임계값', () {
      final push = RepThresholds.forExercise(ExerciseType.pushUp);
      expect(push.upDeg, 160);
      expect(push.descendDeg, 145);
      expect(push.downDeg, 120);
      expect(push.minRepMs, 600);
      final squat = RepThresholds.forExercise(ExerciseType.squat);
      expect(squat.upDeg, 160);
      expect(squat.descendDeg, 145);
      expect(squat.downDeg, 120);
      expect(squat.minRepMs, 800);
    });
  });

  group('RepCounter', () {
    test('푸쉬업 10회 (F-03)', () {
      final counter = _pushUp();
      final events = _feed(counter, repAngleSequence(reps: 10));
      final reps = events.whereType<RepEvent>().toList();
      expect(counter.count, 10);
      expect(reps, hasLength(10));
      expect(
        [for (final r in reps) r.repIndex],
        [for (var i = 1; i <= 10; i++) i],
      );
      expect(events.whereType<PartialRepEvent>(), isEmpty);
      expect(counter.partialCount, 0);
      // 코사인 곡선 최저점(80) 양옆 프레임 값이 3프레임 중앙값이 된다.
      final neighbor = repAngleSequence(reps: 1, padFrames: 0)[14];
      for (final r in reps) {
        expect(r.startMs < r.bottomMs && r.bottomMs < r.endMs, isTrue);
        expect(r.durationMs, r.endMs - r.startMs);
        expect(r.minAngle, closeTo(neighbor, 1e-9));
      }
    });

    test('130도 부분 반복 (F-03)', () {
      final counter = _pushUp();
      final events = _feed(counter, repAngleSequence(reps: 1, bottom: 130));
      expect(counter.count, 0);
      expect(counter.partialCount, 1);
      expect(events, hasLength(1));
      final partial = events.single as PartialRepEvent;
      expect(partial.minAngle, closeTo(130, 0.5));
      expect(partial.startMs < partial.endMs, isTrue);
      expect(counter.phase, RepPhase.up);
    });

    test('155도 흔들림은 사건 없음 (F-03)', () {
      final counter = _pushUp();
      final events = _feed(counter, repAngleSequence(reps: 1, bottom: 155));
      expect(events, isEmpty);
      expect(counter.count, 0);
      expect(counter.partialCount, 0);
      expect(counter.phase, RepPhase.up);
    });

    test('얕아도 120 이하면 셈 (rawAngle 생략)', () {
      final counter = _pushUp();
      // 1초 반복, 최저점 2프레임 유지(하강 시작 200ms, 복귀 1200ms)
      final events = _feed(counter, [
        170,
        150,
        140,
        130,
        120,
        110,
        105,
        105,
        110,
        120,
        130,
        140,
        170,
      ], stepMs: 100);
      expect(events, hasLength(1));
      final rep = events.single as RepEvent;
      expect(rep.minAngle, closeTo(105, 0.5));
      expect(counter.count, 1);
    });

    test('DOWN 뒤 120~160 사이에서는 상태 유지', () {
      final counter = _pushUp();
      final events = _feed(counter, [
        170,
        150,
        140,
        125,
        110,
        125,
        140,
        140,
        125,
        110,
        125,
        140,
        150,
        170,
      ], stepMs: 100);
      expect(counter.count, 1);
      expect(events.whereType<RepEvent>(), hasLength(1));
      expect(events.whereType<PartialRepEvent>(), isEmpty);
    });

    test('하강, DOWN 단계 전이', () {
      final counter = _pushUp();
      expect(counter.phase, RepPhase.unknown);
      counter.update(timestampMs: 0, angle: 170);
      expect(counter.phase, RepPhase.up);
      counter.update(timestampMs: 100, angle: 140);
      expect(counter.phase, RepPhase.descending);
      counter.update(timestampMs: 200, angle: 120);
      expect(counter.phase, RepPhase.down);
    });

    test('푸쉬업 0.3초 안의 반복은 세지 않음', () {
      final counter = _pushUp();
      final events = _feed(counter, [170, 140, 90, 140, 170]);
      expect(events, isEmpty);
      expect(counter.count, 0);
      expect(counter.partialCount, 0);
      expect(counter.phase, RepPhase.up);
    });

    test('스쿼트 0.7초 반복은 0, 1.0초 반복은 1', () {
      final short = _squat();
      // 하강 시작 100ms, 복귀 800ms
      final shortEvents = _feed(short, [
        170,
        140,
        120,
        90,
        90,
        90,
        120,
        140,
        170,
      ], stepMs: 100);
      expect(shortEvents, isEmpty);
      expect(short.count, 0);
      expect(short.phase, RepPhase.up);

      final long = _squat();
      // 하강 시작 100ms, 복귀 1100ms
      final longEvents = _feed(long, [
        170,
        140,
        120,
        90,
        90,
        90,
        90,
        90,
        90,
        120,
        140,
        170,
      ], stepMs: 100);
      expect(long.count, 1);
      final rep = longEvents.single as RepEvent;
      expect(rep.startMs, 100);
      expect(rep.endMs, 1100);
      expect(rep.durationMs, 1000);
    });

    test('원시 최저 각도 3프레임 중앙값 (F-04)', () {
      final counter = _pushUp();
      const angles = <double>[
        170, 150, 140, 130, 120, 110, 100, 100, 100, //
        110, 120, 130, 140, 150, 170,
      ];
      const raw = <double>[
        170, 150, 140, 130, 110, 95, 92, 88, 88, //
        92, 95, 130, 140, 150, 170,
      ];
      final events = _feed(counter, angles, rawAngles: raw, stepMs: 100);
      final rep = events.single as RepEvent;
      expect(rep.minAngle, closeTo(88, 0.01));
      expect(rep.bottomMs, 700);
      expect(rep.startMs, 200);
      expect(rep.endMs, 1400);

      const raw2 = <double>[
        170, 150, 140, 130, 110, 92, 92, 70, 92, //
        92, 95, 130, 140, 150, 170,
      ];
      final events2 = _feed(
        counter,
        angles,
        rawAngles: raw2,
        stepMs: 100,
        startMs: 2000,
      );
      final rep2 = events2.single as RepEvent;
      expect(rep2.minAngle, closeTo(92, 0.01));
      expect(rep2.repIndex, 2);
    });

    test('부분 반복 minAngle도 원시 각도 3프레임 중앙값', () {
      final counter = _pushUp();
      final events = _feed(
        counter,
        [170, 150, 140, 130, 128, 130, 140, 150, 170],
        rawAngles: [170, 150, 140, 131, 100, 129, 140, 150, 170],
        stepMs: 100,
      );
      final partial = events.single as PartialRepEvent;
      expect(partial.minAngle, closeTo(129, 0.01));
    });

    test('최저 프레임이 구간 맨 끝이거나 구간이 짧을 때', () {
      // 구간 2프레임(원시 130, 150): 두 값의 평균 140
      final counter = _pushUp();
      final events = _feed(
        counter,
        [170, 140, 170],
        rawAngles: [170, 130, 150],
        stepMs: 100,
      );
      final partial = events.single as PartialRepEvent;
      expect(partial.minAngle, closeTo(140, 0.01));

      // 최저 프레임이 구간 맨 끝: 연속 3프레임(최저 포함) 중앙값
      final counter2 = _pushUp();
      final events2 = _feed(
        counter2,
        [170, 140, 135, 165],
        rawAngles: [170, 140, 135, 100],
        stepMs: 100,
      );
      final partial2 = events2.single as PartialRepEvent;
      expect(partial2.minAngle, closeTo(135, 0.01));
    });

    test('시작 전 움직임 무시', () {
      final counter = _pushUp();
      final events = _feed(counter, [90, 90, 100, 130, 150, 170]);
      expect(events, isEmpty);
      expect(counter.count, 0);
      expect(counter.phase, RepPhase.up);
    });

    test('reset 뒤 상태 초기화, repIndex 1부터', () {
      final counter = _pushUp();
      _feed(counter, repAngleSequence(reps: 3));
      _feed(counter, repAngleSequence(reps: 1, bottom: 130), startMs: 5000);
      expect(counter.count, 3);
      expect(counter.partialCount, 1);

      counter.reset();
      expect(counter.count, 0);
      expect(counter.partialCount, 0);
      expect(counter.phase, RepPhase.unknown);

      final events = _feed(counter, [
        90,
        90,
        100,
        130,
        150,
        170,
        ...repAngleSequence(reps: 1),
      ], startMs: 10000);
      final reps = events.whereType<RepEvent>().toList();
      expect(events, hasLength(1));
      expect(reps.single.repIndex, 1);
      expect(counter.count, 1);
    });
  });
}
