import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_clip.dart';

/// 프레임을 차례로 넣으며 나온 출력과 매 프레임 뒤 측정 쪽을 돌려준다.
({List<AnalyzerOutput> outputs, List<BodySide?> sides}) _run(
  RepAnalyzer analyzer,
  Iterable<PoseFrame> frames,
) {
  final outputs = <AnalyzerOutput>[];
  final sides = <BodySide?>[];
  for (final frame in frames) {
    final output = analyzer.addFrame(frame);
    if (output != null) outputs.add(output);
    sides.add(analyzer.side);
  }
  return (outputs: outputs, sides: sides);
}

RepAnalyzer _pushUp({int sideSwitchAfterMs = 500, double gateMaxDeg = 30}) =>
    RepAnalyzer(
      exercise: ExerciseType.pushUp,
      sideSwitchAfterMs: sideSwitchAfterMs,
      gateMaxDeg: gateMaxDeg,
    );

/// 푸쉬업 클립. [visibleFor]가 프레임마다 잘 보이는 쪽을 정한다(기본 left).
List<PoseFrame> _pushUpFrames(
  List<double> angles, {
  BodySide Function(int frameIndex)? visibleFor,
  double bodyTiltDeg = 0,
  double Function(int frameIndex)? tiltFor,
  double hiddenVisibility = 0.1,
}) => buildSyntheticClip(
  exercise: ExerciseType.pushUp,
  primaryAngles: angles,
  poseFor: (i, angle) => SyntheticPose(
    exercise: ExerciseType.pushUp,
    elbowDeg: angle,
    bodyTiltDeg: tiltFor?.call(i) ?? bodyTiltDeg,
    visibleSide: visibleFor?.call(i) ?? BodySide.left,
    hiddenVisibility: hiddenVisibility,
  ),
).frames;

/// 스쿼트 클립. [leanFor], [heelFor]는 (프레임 번호, 무릎 각도)로 값을 정한다.
List<PoseFrame> _squatFrames(
  List<double> angles, {
  double Function(int frameIndex, double angle)? leanFor,
  double Function(int frameIndex, double angle)? heelFor,
}) => buildSyntheticClip(
  exercise: ExerciseType.squat,
  primaryAngles: angles,
  poseFor: (i, angle) => SyntheticPose(
    exercise: ExerciseType.squat,
    kneeDeg: angle,
    torsoLeanDeg: leanFor?.call(i, angle) ?? 15,
    heelLiftRatio: heelFor?.call(i, angle) ?? 0,
  ),
).frames;

List<RepResult> _reps(List<AnalyzerOutput> outputs) =>
    outputs.whereType<RepResult>().toList();

/// 왼쪽 6개 점(어깨, 팔꿈치, 손목, 골반, 무릎, 발목)의 visibility만 [visibility]로 바꾼 프레임.
PoseFrame _leftVisibility(PoseFrame frame, double visibility) {
  const leftPoints = {
    LandmarkIndex.leftShoulder,
    LandmarkIndex.leftElbow,
    LandmarkIndex.leftWrist,
    LandmarkIndex.leftHip,
    LandmarkIndex.leftKnee,
    LandmarkIndex.leftAnkle,
  };
  return PoseFrame(
    timestampMs: frame.timestampMs,
    aspectRatio: frame.aspectRatio,
    landmarks: [
      for (var i = 0; i < frame.landmarks.length; i++)
        if (leftPoints.contains(i))
          PoseLandmark(
            x: frame.landmarks[i].x,
            y: frame.landmarks[i].y,
            z: frame.landmarks[i].z,
            visibility: visibility,
          )
        else
          frame.landmarks[i],
    ],
  );
}

/// 모든 점의 visibility를 [visibility]로 바꾼 프레임.
PoseFrame _allVisibility(PoseFrame frame, double visibility) => PoseFrame(
  timestampMs: frame.timestampMs,
  aspectRatio: frame.aspectRatio,
  landmarks: [
    for (final p in frame.landmarks)
      PoseLandmark(x: p.x, y: p.y, z: p.z, visibility: visibility),
  ],
);

/// [index] 점의 x를 NaN으로 바꾼 프레임.
PoseFrame _nanX(PoseFrame frame, int index) => PoseFrame(
  timestampMs: frame.timestampMs,
  aspectRatio: frame.aspectRatio,
  landmarks: [
    for (var i = 0; i < frame.landmarks.length; i++)
      if (i == index)
        PoseLandmark(
          x: double.nan,
          y: frame.landmarks[i].y,
          z: frame.landmarks[i].z,
          visibility: frame.landmarks[i].visibility,
        )
      else
        frame.landmarks[i],
  ],
);

/// 시각만 바꾼 프레임.
PoseFrame _at(PoseFrame frame, int timestampMs) => PoseFrame(
  timestampMs: timestampMs,
  aspectRatio: frame.aspectRatio,
  landmarks: frame.landmarks,
);

/// 10회 클립에서 반복 r(0부터)의 꼭대기 프레임 번호. 앞 패딩 10프레임.
int _repTop(int r) => 10 + 30 * r;

/// 170도 10프레임 -> [frames]프레임 동안 80도까지 직선 하강 -> 같은 길이로 상승
/// -> 170도 10프레임. 이동 평균 없이(창 1ms) 쓰면 첫 145도 미만 프레임이 하강 시작.
List<double> _squatRep({int frames = 22}) => [
  for (var i = 0; i < 10; i++) 170,
  for (var i = 1; i <= frames; i++) 170 - 90 * i / frames,
  for (var i = frames - 1; i >= 0; i--) 170 - 90 * i / frames,
  for (var i = 0; i < 10; i++) 170,
];

void main() {
  group('측정 쪽 유지 (F-02)', () {
    test('0.3초 흔들림은 유지: 9프레임만 오른쪽이 보여도 왼쪽, 10회', () {
      final frames = _pushUpFrames(
        repAngleSequence(reps: 10),
        visibleFor: (i) => i >= 1 && i <= 9 ? BodySide.right : BodySide.left,
      );
      final analyzer = _pushUp();
      final run = _run(analyzer, frames);

      expect(run.sides, everyElement(BodySide.left));
      expect(analyzer.count, 10);
    });

    test('0.5초 이상이면 전환: 떨어진 지 500ms 프레임부터 오른쪽, 이후 반복 셈', () {
      final frames = _pushUpFrames(
        repAngleSequence(reps: 10),
        visibleFor: (i) => i >= 10 ? BodySide.right : BodySide.left,
      );
      final analyzer = _pushUp();
      final run = _run(analyzer, frames);

      // 프레임 10(333ms)부터 떨어짐, 500ms 뒤인 프레임 25(833ms)에서 전환.
      expect(frames[25].timestampMs - frames[10].timestampMs, 500);
      expect(run.sides.sublist(0, 25), everyElement(BodySide.left));
      expect(run.sides.sublist(25), everyElement(BodySide.right));
      // 첫 반복은 하강 구간 일부를 잃어도 0.5초를 넘겨 오른쪽 각도로 이어서 센다.
      expect(analyzer.count, 10);
      expect(_reps(run.outputs).map((r) => r.repIndex), [
        for (var i = 1; i <= 10; i++) i,
      ]);
    });

    test('떨어졌다 정상 프레임이 오면 시간 기록을 지움: 9프레임씩 두 번은 유지', () {
      final frames = _pushUpFrames(
        repAngleSequence(reps: 2, padFrames: 30),
        visibleFor: (i) => (i >= 1 && i <= 9) || (i >= 11 && i <= 19)
            ? BodySide.right
            : BodySide.left,
      );
      final run = _run(_pushUp(), frames);

      expect(run.sides, everyElement(BodySide.left));
    });

    test('sideSwitchAfterMs를 200으로 주면 0.3초 흔들림에도 전환', () {
      final frames = _pushUpFrames(
        repAngleSequence(reps: 1),
        visibleFor: (i) => i >= 1 && i <= 9 ? BodySide.right : BodySide.left,
      );
      final run = _run(_pushUp(sideSwitchAfterMs: 200), frames);

      // 프레임 1(33ms)부터 떨어짐, 프레임 7(233ms)에서 전환.
      expect(run.sides.sublist(0, 7), everyElement(BodySide.left));
      expect(run.sides[7], BodySide.right);
    });

    test('세트 시작 때 다시 결정: reset 직후 null, 오른쪽만 보이면 오른쪽', () {
      final analyzer = _pushUp();
      expect(analyzer.side, isNull);

      _run(analyzer, _pushUpFrames([170, 170, 170]));
      expect(analyzer.side, BodySide.left);

      analyzer.reset();
      expect(analyzer.side, isNull);

      _run(analyzer, _pushUpFrames([170], visibleFor: (_) => BodySide.right));
      expect(analyzer.side, BodySide.right);
    });
  });

  group('측정 쪽 노이즈 입력', () {
    test('반복 상승 구간에서 왼쪽만 0.4초 잠깐 사라짐: 왼쪽 유지, 10회', () {
      // 최저점을 지난 뒤(DOWN 도달 뒤)라 그 반복도 인정된다.
      final frames = _pushUpFrames(repAngleSequence(reps: 10));
      for (var i = _repTop(4) + 17; i <= _repTop(4) + 28; i++) {
        frames[i] = _leftVisibility(frames[i], 0.2);
      }
      final analyzer = _pushUp();
      final run = _run(analyzer, frames);

      expect(run.sides, everyElement(BodySide.left));
      expect(analyzer.count, 10);
    });

    test('양쪽 모두 낮은 visibility 1초: 전환 없음, 그 반복만 빠지고 9회', () {
      final frames = _pushUpFrames(repAngleSequence(reps: 10));
      for (var i = _repTop(5); i < _repTop(6); i++) {
        frames[i] = _allVisibility(frames[i], 0.1);
      }
      final analyzer = _pushUp();
      final run = _run(analyzer, frames);

      expect(run.sides, everyElement(BodySide.left));
      expect(analyzer.count, 9);
    });

    test('비유한 좌표 0.6초: 반대쪽이 안 보이면 유지, 보이면 500ms에 전환', () {
      List<PoseFrame> withNanElbow(double hiddenVisibility) {
        final frames = _pushUpFrames(
          repAngleSequence(reps: 10, padFrames: 30),
          hiddenVisibility: hiddenVisibility,
        );
        for (var i = 1; i <= 18; i++) {
          frames[i] = _nanX(frames[i], LandmarkIndex.leftElbow);
        }
        return frames;
      }

      final hidden = _pushUp();
      final hiddenRun = _run(hidden, withNanElbow(0.1));
      expect(hiddenRun.sides, everyElement(BodySide.left));
      expect(hidden.count, 10);

      final shown = _pushUp();
      final shownRun = _run(shown, withNanElbow(0.9));
      // 프레임 1(33ms)부터 떨어짐, 프레임 16(533ms)에서 전환.
      expect(shownRun.sides.sublist(0, 16), everyElement(BodySide.left));
      expect(shownRun.sides.sublist(16), everyElement(BodySide.right));
      expect(shown.count, 10);
    });

    test('프레임 끊김: 떨어진 뒤 0.5초 넘게 프레임이 없으면 다음 프레임에서 전환', () {
      final frames = _pushUpFrames(
        repAngleSequence(reps: 10),
        visibleFor: (i) => i >= 10 ? BodySide.right : BodySide.left,
      );
      final dropped = [...frames.sublist(0, 11), ...frames.sublist(26)];
      final run = _run(_pushUp(), dropped);

      // 프레임 10(333ms)에서 떨어지고 다음 프레임은 26(866ms).
      expect(run.sides.sublist(0, 11), everyElement(BodySide.left));
      expect(run.sides[11], BodySide.right);
    });
  });

  group('자세 게이트 (F-03, F-07)', () {
    test('서 있는 푸쉬업(몸통 90도): count 0, 출력 없음', () {
      final analyzer = _pushUp();
      final run = _run(
        analyzer,
        _pushUpFrames(repAngleSequence(reps: 10), bodyTiltDeg: 90),
      );

      expect(run.outputs, isEmpty);
      expect(analyzer.count, 0);
      expect(analyzer.lastAngle, isNull);
    });

    test('엎드린 푸쉬업은 그대로 10회', () {
      final analyzer = _pushUp();
      _run(analyzer, _pushUpFrames(repAngleSequence(reps: 10)));

      expect(analyzer.count, 10);
    });

    test('반복 중 몇 프레임만 기울어지면 그 프레임만 건너뛰고 10회', () {
      final analyzer = _pushUp();
      final frames = _pushUpFrames(
        repAngleSequence(reps: 10),
        tiltFor: (i) => i >= _repTop(3) + 10 && i < _repTop(3) + 15 ? 60 : 0,
      );
      _run(analyzer, frames);

      expect(analyzer.count, 10);
    });

    test('gateMaxDeg를 95로 주면 서 있는 푸쉬업도 센다', () {
      final analyzer = _pushUp(gateMaxDeg: 95);
      _run(
        analyzer,
        _pushUpFrames(repAngleSequence(reps: 10), bodyTiltDeg: 90),
      );

      expect(analyzer.count, 10);
    });

    test('스쿼트 처음 UP 게이트: 상체 45도면 0회, 처음 15도면 최저점 40도여도 3회', () {
      final angles = repAngleSequence(reps: 3, framesPerRep: 45);

      final leaning = RepAnalyzer(exercise: ExerciseType.squat);
      _run(leaning, _squatFrames(angles, leanFor: (_, _) => 45));
      expect(leaning.count, 0);
      expect(leaning.side, BodySide.left);

      final upright = RepAnalyzer(exercise: ExerciseType.squat);
      _run(
        upright,
        _squatFrames(
          angles,
          leanFor: (_, angle) => 15 + 25 * (170 - angle) / 90,
        ),
      );
      expect(upright.count, 3);
    });
  });

  group('판정 프레임 범위 (하강 직전 UP 프레임부터)', () {
    test('무릎이 굽는 만큼 서서히 뜨는 뒤꿈치(최대 0.15)는 sqHeelLift', () {
      // 3초 반복. 하강 시작 프레임을 기준으로 재면 이미 뜬 만큼 빠져 0.1 아래가 된다.
      final analyzer = RepAnalyzer(exercise: ExerciseType.squat);
      final run = _run(
        analyzer,
        _squatFrames(
          repAngleSequence(reps: 3, framesPerRep: 90),
          heelFor: (_, angle) => 0.15 * (170 - angle) / 90,
        ),
      );

      final reps = _reps(run.outputs);
      expect(reps, hasLength(3));
      for (final rep in reps) {
        expect(rep.errors, contains(PoseErrorCode.sqHeelLift));
      }
    });

    test('첫 판정 프레임은 하강 직전 UP 프레임: 그 프레임만 뒤꿈치가 바닥', () {
      final angles = _squatRep();
      final descent = angles.indexWhere((a) => a < 145);
      final preDescent = descent - 1;
      final analyzer = RepAnalyzer(
        exercise: ExerciseType.squat,
        smoothingWindowMs: 1,
      );
      // 하강 직전 UP 프레임만 0, 나머지는 모두 0.12 떠 있다. 첫 판정 프레임이 그
      // 프레임일 때만 0.12 상승이 잡히고, 더 앞이나 뒤에서 시작하면 0이다.
      final run = _run(
        analyzer,
        _squatFrames(angles, heelFor: (i, _) => i == preDescent ? 0 : 0.12),
      );

      final rep = _reps(run.outputs).single;
      expect(rep.errors, [PoseErrorCode.sqHeelLift]);
    });

    test('같은 시각 프레임: 하강 프레임이 직전 UP 프레임과 같은 시각이어도 판정에 포함', () {
      final angles = _squatRep();
      final descent = angles.indexWhere((a) => a < 145);
      final preDescent = descent - 1;
      final frames = _squatFrames(
        angles,
        heelFor: (i, _) => i == preDescent ? 0 : 0.12,
      );
      frames[descent] = _at(frames[descent], frames[preDescent].timestampMs);
      final analyzer = RepAnalyzer(
        exercise: ExerciseType.squat,
        smoothingWindowMs: 1,
      );
      final run = _run(analyzer, frames);

      final rep = _reps(run.outputs).single;
      expect(rep.errors, [PoseErrorCode.sqHeelLift]);
      expect(analyzer.count, 1);
    });
  });
}
