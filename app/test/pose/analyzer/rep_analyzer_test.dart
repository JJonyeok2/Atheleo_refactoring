import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:atheleo/pose/judge/error_judge.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/landmark_clip.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:atheleo/pose/rep/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_clip.dart';

/// [frames]를 차례로 넣고 나온 출력을 모두 돌려준다.
List<AnalyzerOutput> _feed(RepAnalyzer analyzer, Iterable<PoseFrame> frames) {
  final outputs = <AnalyzerOutput>[];
  for (final frame in frames) {
    final output = analyzer.addFrame(frame);
    if (output != null) outputs.add(output);
  }
  return outputs;
}

RepAnalyzer _pushUp() => RepAnalyzer(exercise: ExerciseType.pushUp);

List<PoseFrame> _pushUpFrames(List<double> angles, {int fps = 30}) =>
    buildSyntheticClip(
      exercise: ExerciseType.pushUp,
      primaryAngles: angles,
      fps: fps,
    ).frames;

List<RepResult> _reps(List<AnalyzerOutput> outputs) =>
    outputs.whereType<RepResult>().toList();

/// [from]에서 [to]까지 [frames]개 프레임으로 고르게 옮겨 가는 각도(양 끝 포함 안 함).
List<double> _ramp(double from, double to, int frames) => [
  for (var i = 1; i <= frames; i++) from + (to - from) * i / (frames + 1),
];

/// 모든 점의 visibility를 [visibility]로 바꾼 프레임.
PoseFrame _withVisibility(PoseFrame frame, double visibility) => PoseFrame(
  timestampMs: frame.timestampMs,
  aspectRatio: frame.aspectRatio,
  landmarks: [
    for (final p in frame.landmarks)
      PoseLandmark(x: p.x, y: p.y, z: p.z, visibility: visibility),
  ],
);

/// [changes]의 점만 바꾼 프레임.
PoseFrame _replace(PoseFrame frame, Map<int, PoseLandmark> changes) =>
    PoseFrame(
      timestampMs: frame.timestampMs,
      aspectRatio: frame.aspectRatio,
      landmarks: [
        for (var i = 0; i < frame.landmarks.length; i++)
          changes[i] ?? frame.landmarks[i],
      ],
    );

/// 시각만 바꾼 프레임.
PoseFrame _at(PoseFrame frame, int timestampMs) => PoseFrame(
  timestampMs: timestampMs,
  aspectRatio: frame.aspectRatio,
  landmarks: frame.landmarks,
);

/// 10회 클립에서 반복 r(0부터)의 꼭대기(j=0) 프레임 번호. 앞 패딩 10프레임.
int _repTop(int r) => 10 + 30 * r;

void main() {
  group('RepAnalyzer 횟수 (F-03)', () {
    test('푸쉬업 10회, 30fps와 15fps 모두 10회', () {
      final fps30 = _pushUpFrames(repAngleSequence(reps: 10));
      final fps15 = _pushUpFrames(
        repAngleSequence(reps: 10, framesPerRep: 15),
        fps: 15,
      );

      for (final frames in [fps30, fps15]) {
        final analyzer = _pushUp();
        final outputs = _feed(analyzer, frames);
        expect(_reps(outputs), hasLength(10));
        expect(outputs.whereType<PartialRep>(), isEmpty);
        expect(outputs, hasLength(10));
        expect(analyzer.count, 10);
        expect(analyzer.partialCount, 0);
        expect(_reps(outputs).map((r) => r.repIndex), [
          for (var i = 1; i <= 10; i++) i,
        ]);
      }
    });

    test('130도 부분 반복은 PartialRep 1개, 155도 흔들림은 출력 없음', () {
      final partial = _pushUp();
      final partialOut = _feed(
        partial,
        _pushUpFrames(repAngleSequence(reps: 1, bottom: 130)),
      );
      expect(partialOut, hasLength(1));
      final event = partialOut.single as PartialRep;
      expect(event.minAngle, closeTo(130, 1));
      expect(event.endMs, greaterThan(0));
      expect(partial.count, 0);
      expect(partial.partialCount, 1);

      final shake = _pushUp();
      expect(
        _feed(shake, _pushUpFrames(repAngleSequence(reps: 1, bottom: 155))),
        isEmpty,
      );
      expect(shake.count, 0);
      expect(shake.partialCount, 0);
    });

    test('꼭대기 160~165도가 3프레임뿐인 빠른 반복도 합쳐지지 않음', () {
      const cycle = <double>[
        162, 165, 162, 158, 145, 120, 95, 82, //
        80, 80, 80, 80, 80, 80, 80, 80, 80, 80, //
        82, 95, 120, 145, 155, 158,
      ];
      final angles = <double>[
        for (var i = 0; i < 10; i++) 170,
        for (var r = 0; r < 5; r++) ...cycle,
        162,
        165,
        162,
        for (var i = 0; i < 10; i++) 170,
      ];
      final analyzer = _pushUp();
      final outputs = _feed(analyzer, _pushUpFrames(angles));

      expect(_reps(outputs), hasLength(5));
      expect(outputs, hasLength(5));
      expect(analyzer.count, 5);
    });

    test('스쿼트는 무릎 각도로 센다', () {
      final analyzer = RepAnalyzer(exercise: ExerciseType.squat);
      final clip = buildSyntheticClip(
        exercise: ExerciseType.squat,
        // 스쿼트 최소 1회 시간 800ms를 넘도록 1.5초 반복.
        primaryAngles: repAngleSequence(reps: 3, framesPerRep: 45),
      );
      final outputs = _feed(analyzer, clip.frames);

      expect(_reps(outputs), hasLength(3));
      expect(analyzer.count, 3);
      expect(_reps(outputs).first.errors, isEmpty);
      expect(_reps(outputs).first.score, 100);
    });
  });

  group('RepAnalyzer 오류와 점수 (F-04, F-05)', () {
    test('허리 처짐은 puHipSag만, 엉덩이 들림은 puHipPike만', () {
      for (final (offset, code) in [
        (HipOffset.below, PoseErrorCode.puHipSag),
        (HipOffset.above, PoseErrorCode.puHipPike),
      ]) {
        final clip = buildSyntheticClip(
          exercise: ExerciseType.pushUp,
          primaryAngles: repAngleSequence(reps: 3),
          poseFor: (i, angle) => SyntheticPose(
            exercise: ExerciseType.pushUp,
            elbowDeg: angle,
            bodyLineDeg: 140,
            hipOffset: offset,
          ),
        );
        final reps = _reps(_feed(_pushUp(), clip.frames));

        expect(reps, hasLength(3));
        for (final rep in reps) {
          expect(rep.errors, [code]);
        }
      }
    });

    test('최저 105도 1초 반복은 1회, puShallow, 75점', () {
      final analyzer = _pushUp();
      final outputs = _feed(
        analyzer,
        _pushUpFrames(repAngleSequence(reps: 1, bottom: 105)),
      );

      expect(analyzer.count, 1);
      final rep = outputs.single as RepResult;
      expect(rep.repIndex, 1);
      expect(rep.errors, [PoseErrorCode.puShallow]);
      expect(rep.score, 75);
      expect(rep.minAngle, closeTo(105, 1));
      expect(rep.durationMs, inInclusiveRange(600, 1000));
    });

    test('최저 80도 1초 반복은 오류 없이 100점', () {
      final outputs = _feed(
        _pushUp(),
        _pushUpFrames(repAngleSequence(reps: 1)),
      );

      final rep = outputs.single as RepResult;
      expect(rep.errors, isEmpty);
      expect(rep.score, 100);
    });

    test('짧은 최저점(88도 2프레임)은 원시 각도로 기록, 얕게 판정 안 함', () {
      final angles = <double>[
        for (var i = 0; i < 10; i++) 170,
        for (var k = 0; k < 15; k++) 170 - 72 * k / 14,
        95,
        92,
        88,
        88,
        92,
        95,
        for (var k = 14; k >= 0; k--) 170 - 72 * k / 14,
        for (var i = 0; i < 10; i++) 170,
      ];
      final outputs = _feed(_pushUp(), _pushUpFrames(angles));

      final rep = outputs.single as RepResult;
      expect(rep.minAngle, closeTo(88, 0.5));
      expect(rep.errors, isNot(contains(PoseErrorCode.puShallow)));
      expect(rep.score, 100);
    });
  });

  group('RepAnalyzer 빠른 반복과 취소 (F-03)', () {
    test('0.6초 미만 반복은 TooFastRep, count와 partialCount 그대로', () {
      final analyzer = _pushUp();
      final outputs = _feed(
        analyzer,
        _pushUpFrames(repAngleSequence(reps: 1, framesPerRep: 12)),
      );

      expect(outputs, hasLength(1));
      final fast = outputs.single as TooFastRep;
      expect(fast.durationMs, lessThan(600));
      expect(fast.durationMs, greaterThan(0));
      expect(fast.endMs, greaterThan(0));
      expect(analyzer.count, 0);
      expect(analyzer.partialCount, 0);
    });

    test('하강 뒤 11초 정지는 출력 없이 취소, 다음 정상 반복이 repIndex 1', () {
      final angles = <double>[
        for (var i = 0; i < 10; i++) 170,
        ..._ramp(170, 90, 10),
        for (var i = 0; i < 330; i++) 90,
        ..._ramp(90, 170, 10),
        for (var i = 0; i < 10; i++) 170,
        ...repAngleSequence(reps: 1),
      ];
      final analyzer = _pushUp();
      final outputs = _feed(analyzer, _pushUpFrames(angles));

      expect(outputs, hasLength(1));
      expect((outputs.single as RepResult).repIndex, 1);
      expect(analyzer.count, 1);
      expect(analyzer.partialCount, 0);
    });
  });

  group('RepAnalyzer reset (F-03)', () {
    test('reset 뒤 count 0, 90도에서 시작한 동작은 세지 않고 repIndex 1부터', () {
      final analyzer = _pushUp();
      expect(
        _reps(_feed(analyzer, _pushUpFrames(repAngleSequence(reps: 3)))),
        hasLength(3),
      );

      analyzer.reset();
      expect(analyzer.count, 0);
      expect(analyzer.partialCount, 0);
      expect(analyzer.lastAngle, isNull);

      // reset 뒤 시각은 0부터 다시 시작해도 된다.
      final resumed = <double>[
        for (var i = 0; i < 10; i++) 90,
        ..._ramp(90, 170, 15),
        ...repAngleSequence(reps: 1),
      ];
      final outputs = _feed(analyzer, _pushUpFrames(resumed));

      expect(outputs, hasLength(1));
      expect((outputs.single as RepResult).repIndex, 1);
      expect(analyzer.count, 1);
    });

    test('lastAngle은 마지막 이동 평균 각도, 처음엔 null', () {
      final analyzer = _pushUp();
      expect(analyzer.lastAngle, isNull);

      final frames = _pushUpFrames([170, 170, 170, 140]);
      _feed(analyzer, frames);

      // 30fps 4프레임은 모두 150ms 창 안: (170 * 3 + 140) / 4.
      expect(analyzer.lastAngle, closeTo(162.5, 0.01));
    });
  });

  group('RepAnalyzer 노이즈 입력', () {
    test('보이지 않음, 길이 0, 비유한 좌표 프레임은 건너뜀', () {
      final frames = _pushUpFrames(repAngleSequence(reps: 10));
      for (var i = _repTop(3) - 2; i <= _repTop(3) + 2; i++) {
        frames[i] = _withVisibility(frames[i], 0.1);
      }
      for (var i = _repTop(6) - 2; i <= _repTop(6) + 2; i++) {
        frames[i] = _replace(frames[i], {
          LandmarkIndex.leftWrist: frames[i][LandmarkIndex.leftElbow],
        });
      }
      for (var i = _repTop(8) - 2; i <= _repTop(8) + 2; i++) {
        final elbow = frames[i][LandmarkIndex.leftElbow];
        frames[i] = _replace(frames[i], {
          LandmarkIndex.leftElbow: PoseLandmark(
            x: double.nan,
            y: elbow.y,
            z: elbow.z,
            visibility: elbow.visibility,
          ),
        });
      }
      final analyzer = _pushUp();
      final outputs = _feed(analyzer, frames);

      expect(outputs, hasLength(10));
      expect(_reps(outputs), hasLength(10));
      expect(analyzer.count, 10);
      expect(analyzer.partialCount, 0);
    });

    test('사람 없는 프레임만 오면 출력 없음, lastAngle null', () {
      final frames = _pushUpFrames(repAngleSequence(reps: 2));
      final analyzer = _pushUp();
      final outputs = _feed(analyzer, [
        for (final f in frames) _withVisibility(f, 0),
      ]);

      expect(outputs, isEmpty);
      expect(analyzer.count, 0);
      expect(analyzer.lastAngle, isNull);
    });

    test('프레임 끊김(꼭대기, 최저점 구간 누락, 반복 하나를 15fps로)에도 10회', () {
      final frames = _pushUpFrames(repAngleSequence(reps: 10));
      final dropped = <PoseFrame>[
        for (var i = 0; i < frames.length; i++)
          if (!(i >= _repTop(1) - 3 && i < _repTop(1) + 3) &&
              !(i >= _repTop(3) + 12 && i < _repTop(3) + 18) &&
              !(i >= _repTop(6) && i < _repTop(7) && i.isOdd))
            frames[i],
      ];
      final analyzer = _pushUp();
      final outputs = _feed(analyzer, dropped);

      expect(_reps(outputs), hasLength(10));
      expect(outputs, hasLength(10));
    });

    test('한 프레임 튐: 꼭대기 100도, 최저점 20도 한 장', () {
      final angles = repAngleSequence(reps: 10);
      angles[5] = 100;
      angles[_repTop(4) + 15] = 20;
      final analyzer = _pushUp();
      final outputs = _feed(analyzer, _pushUpFrames(angles));

      expect(outputs, hasLength(10));
      final reps = _reps(outputs);
      expect(reps, hasLength(10));
      expect(reps[4].minAngle, greaterThan(75));
    });

    test('시각이 거꾸로 간 프레임은 예외 없이 건너뜀', () {
      final frames = _pushUpFrames(repAngleSequence(reps: 10));
      final withStale = <PoseFrame>[
        for (var i = 0; i < frames.length; i++) ...[
          frames[i],
          if (i == _repTop(2) + 15) _at(frames[_repTop(1)], 0),
        ],
      ];
      final analyzer = _pushUp();
      final outputs = _feed(analyzer, withStale);

      expect(_reps(outputs), hasLength(10));
      expect(outputs, hasLength(10));
    });
  });

  test('생성자 인자: 기준값과 이동 평균 창을 바꿀 수 있다', () {
    final analyzer = RepAnalyzer(
      exercise: ExerciseType.pushUp,
      repThresholds: const RepThresholds(
        upDeg: 160,
        descendDeg: 145,
        downDeg: 120,
        minRepMs: 300,
      ),
      errorThresholds: const ErrorThresholds(depthDeg: 110),
      smoothingWindowMs: 1,
    );
    final outputs = _feed(
      analyzer,
      _pushUpFrames(repAngleSequence(reps: 1, bottom: 105, framesPerRep: 15)),
    );

    final rep = outputs.single as RepResult;
    expect(rep.errors, isEmpty);
    expect(rep.score, 100);
    expect(rep.durationMs, lessThan(600));
  });

  test('JSON 클립 왕복 뒤에도 10회', () {
    final clip = buildSyntheticClip(
      exercise: ExerciseType.pushUp,
      primaryAngles: repAngleSequence(reps: 10),
    );
    final parsed = LandmarkClip.parse(clip.encode());
    final analyzer = _pushUp();
    _feed(analyzer, parsed.frames);

    expect(analyzer.count, 10);
  });
}
