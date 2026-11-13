// 합성 클립 생성기 테스트 (TASK-06).
import 'dart:math' as math;

import 'package:atheleo/pose/angle/joint_angle.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/landmark_clip.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_clip.dart';

double _deg(double dx, double dy) => math.atan2(dy, dx) * 180 / math.pi;

void _expectInUnit(PoseFrame f) {
  for (final p in f.landmarks) {
    expect(p.x, inInclusiveRange(0, 1));
    expect(p.y, inInclusiveRange(0, 1));
  }
}

void main() {
  const L = LandmarkIndex.leftShoulder;

  test('관절 각도 재현', () {
    final push = buildSyntheticFrame(
      const SyntheticPose(exercise: ExerciseType.pushUp, elbowDeg: 90),
    );
    expect(selectSide(push)!.elbow, closeTo(90, 1));
    final squat = buildSyntheticFrame(
      const SyntheticPose(exercise: ExerciseType.squat, kneeDeg: 75),
    );
    expect(selectSide(squat)!.knee, closeTo(75, 1));
  });

  test('F-02 클립: 편 팔 160도 이상, 가려진 쪽이 있어도 보이는 쪽 선택', () {
    final clip = buildSyntheticClip(
      exercise: ExerciseType.pushUp,
      primaryAngles: repAngleSequence(reps: 2),
    );
    expect(selectSide(clip.frames.first)!.elbow, greaterThanOrEqualTo(160));
    final right = buildSyntheticClip(
      exercise: ExerciseType.pushUp,
      primaryAngles: repAngleSequence(reps: 2),
      poseFor: (i, a) => SyntheticPose(
        exercise: ExerciseType.pushUp,
        elbowDeg: a,
        visibleSide: BodySide.right,
        hiddenVisibility: 0.05,
      ),
    );
    for (final f in right.frames) {
      expect(selectSide(f)!.side, BodySide.right);
    }
  });

  test('몸통 각도와 처짐 방향', () {
    for (final offset in HipOffset.values) {
      final f = buildSyntheticFrame(
        SyntheticPose(
          exercise: ExerciseType.pushUp,
          bodyLineDeg: 140,
          hipOffset: offset,
        ),
      );
      final s = f[LandmarkIndex.leftShoulder];
      final h = f[LandmarkIndex.leftHip];
      final a = f[LandmarkIndex.leftAnkle];
      expect(angleDeg(s, h, a), closeTo(140, 1));
      final lineY = s.y + (h.x - s.x) * (a.y - s.y) / (a.x - s.x);
      if (offset == HipOffset.below) {
        expect(h.y, greaterThan(lineY));
      } else {
        expect(h.y, lessThan(lineY));
      }
    }
  });

  test('푸쉬업 몸통 기울기', () {
    for (final tilt in [0.0, 60.0, 90.0]) {
      final f = buildSyntheticFrame(
        SyntheticPose(exercise: ExerciseType.pushUp, bodyTiltDeg: tilt),
      );
      final s = f[LandmarkIndex.leftShoulder];
      final a = f[LandmarkIndex.leftAnkle];
      final angle = _deg((a.x - s.x).abs(), (a.y - s.y).abs());
      expect(angle, closeTo(tilt, 1));
      _expectInUnit(f);
    }
  });

  test('스쿼트 상체 기울기와 뒤꿈치', () {
    final lean = buildSyntheticFrame(
      const SyntheticPose(exercise: ExerciseType.squat, torsoLeanDeg: 45),
    );
    final h = lean[LandmarkIndex.leftHip];
    final s = lean[L];
    final fromVertical = _deg((s.y - h.y).abs(), (s.x - h.x).abs());
    expect(fromVertical, closeTo(45, 1));
    expect(s.y, lessThan(h.y));

    final lift = buildSyntheticFrame(
      const SyntheticPose(exercise: ExerciseType.squat, heelLiftRatio: 0.2),
    );
    final knee = lift[LandmarkIndex.leftKnee];
    final ankle = lift[LandmarkIndex.leftAnkle];
    final shin = math.sqrt(
      math.pow(knee.x - ankle.x, 2) + math.pow(knee.y - ankle.y, 2),
    );
    final ratio =
        (lift[LandmarkIndex.leftFootIndex].y - lift[LandmarkIndex.leftHeel].y) /
        shin;
    expect(ratio, closeTo(0.2, 0.02));
    _expectInUnit(lift);
  });

  test('정면 흉내', () {
    final f = buildSyntheticFrame(
      const SyntheticPose(
        exercise: ExerciseType.squat,
        shoulderWidthRatio: 0.7,
      ),
    );
    final l = f[LandmarkIndex.leftShoulder];
    final r = f[LandmarkIndex.rightShoulder];
    final hip = f[LandmarkIndex.leftHip];
    final torso = math.sqrt(
      math.pow(l.x - hip.x, 2) + math.pow(l.y - hip.y, 2),
    );
    expect((l.x - r.x).abs() / torso, closeTo(0.7, 0.02));
    _expectInUnit(f);
  });

  test('반복 시퀀스와 프레임별 자세', () {
    final seq = repAngleSequence(reps: 10);
    expect(seq.length, 320);
    expect(seq.where((v) => (v - 80).abs() <= 0.5).length, 10);
    expect(seq.first, 170);
    expect(seq.last, 170);

    final clip = buildSyntheticClip(
      exercise: ExerciseType.pushUp,
      primaryAngles: seq,
      poseFor: (i, a) => SyntheticPose(
        exercise: ExerciseType.pushUp,
        elbowDeg: a,
        visibleSide: i < 5 ? BodySide.left : BodySide.right,
      ),
    );
    expect(clip.frames[3].timestampMs, 3 * 1000 ~/ 30);
    for (var i = 0; i < 10; i++) {
      expect(
        selectSide(clip.frames[i])!.side,
        i < 5 ? BodySide.left : BodySide.right,
      );
    }
  });

  test('모든 각도에서 selectSide가 non-null', () {
    for (final ex in ExerciseType.values) {
      for (final deg in [30.0, 80.0, 120.0, 170.0, 180.0]) {
        final f = buildSyntheticFrame(
          SyntheticPose(exercise: ex, elbowDeg: deg, kneeDeg: deg),
        );
        expect(selectSide(f), isNotNull);
      }
    }
  });

  test('JSON 왕복', () {
    final clip = buildSyntheticClip(
      exercise: ExerciseType.squat,
      primaryAngles: repAngleSequence(reps: 1),
    );
    final back = LandmarkClip.parse(clip.encode());
    expect(back.frames.length, clip.frames.length);
    expect(back.frames.first[L].x, clip.frames.first[L].x);
    expect(back.frames.first[L].y, clip.frames.first[L].y);
  });

  group('프레임 사이 고정 좌표계(시작 자세 대비 측정)', () {
    PoseFrame sq({
      double knee = 170,
      double lean = 15,
      double heel = 0,
      double width = 0.05,
    }) => buildSyntheticFrame(
      SyntheticPose(
        exercise: ExerciseType.squat,
        kneeDeg: knee,
        torsoLeanDeg: lean,
        heelLiftRatio: heel,
        shoulderWidthRatio: width,
      ),
    );

    double shin(PoseFrame f) {
      final k = f[LandmarkIndex.leftKnee];
      final a = f[LandmarkIndex.leftAnkle];
      return math.sqrt(math.pow(k.x - a.x, 2) + math.pow(k.y - a.y, 2));
    }

    double lift(PoseFrame start, PoseFrame f) =>
        (start[LandmarkIndex.leftHeel].y - f[LandmarkIndex.leftHeel].y) /
        shin(start);

    test('heelLiftRatio 0이면 무릎, 상체 기울기가 바뀌어도 상승 0', () {
      final start = sq();
      expect(lift(start, sq(knee: 80)), closeTo(0, 0.02));
      expect(lift(start, sq(knee: 80, lean: 60)), closeTo(0, 0.02));
    });

    test('heelLiftRatio 0.05, 0.2가 시작 대비 그대로 나옴', () {
      final start = sq();
      expect(lift(start, sq(knee: 80, heel: 0.05)), closeTo(0.05, 0.02));
      expect(lift(start, sq(knee: 80, heel: 0.2)), closeTo(0.2, 0.02));
    });

    test('같은 운동이면 프레임 사이 정강이 길이가 같음', () {
      final base = shin(sq());
      for (final k in [60.0, 80.0, 120.0, 180.0]) {
        expect(shin(sq(knee: k, lean: 60, heel: 0.3)), closeTo(base, 1e-9));
      }
    });

    test('값 범위 끝 조합에서도 모든 점 0~1 안', () {
      for (final knee in [60.0, 180.0]) {
        for (final lean in [0.0, 60.0]) {
          for (final heel in [0.0, 0.3]) {
            for (final w in [0.05, 0.8]) {
              _expectInUnit(sq(knee: knee, lean: lean, heel: heel, width: w));
            }
          }
        }
      }
      for (final tilt in [0.0, 45.0, 90.0]) {
        for (final line in [120.0, 180.0]) {
          for (final elbow in [30.0, 180.0]) {
            for (final off in HipOffset.values) {
              for (final side in BodySide.values) {
                for (final w in [0.05, 0.8]) {
                  _expectInUnit(
                    buildSyntheticFrame(
                      SyntheticPose(
                        exercise: ExerciseType.pushUp,
                        bodyTiltDeg: tilt,
                        bodyLineDeg: line,
                        elbowDeg: elbow,
                        hipOffset: off,
                        visibleSide: side,
                        shoulderWidthRatio: w,
                      ),
                    ),
                  );
                }
              }
            }
          }
        }
      }
    });
  });
}
