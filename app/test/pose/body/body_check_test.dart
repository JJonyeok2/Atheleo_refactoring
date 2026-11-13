import 'package:atheleo/pose/body/body_check.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_clip.dart';

PoseFrame _squat({double lean = 15, double width = 0.05}) =>
    buildSyntheticFrame(
      SyntheticPose(
        exercise: ExerciseType.squat,
        torsoLeanDeg: lean,
        shoulderWidthRatio: width,
      ),
    );

PoseFrame _pushUp({double tilt = 0, BodySide side = BodySide.left}) =>
    buildSyntheticFrame(
      SyntheticPose(
        exercise: ExerciseType.pushUp,
        bodyTiltDeg: tilt,
        visibleSide: side,
      ),
    );

PoseFrame _edit(
  PoseFrame f,
  Map<int, PoseLandmark> changes, {
  double aspectRatio = 1.0,
}) => PoseFrame(
  timestampMs: f.timestampMs,
  aspectRatio: aspectRatio,
  landmarks: [for (var i = 0; i < LandmarkIndex.count; i++) changes[i] ?? f[i]],
);

PoseFrame _all(double x, double y, double v) => PoseFrame(
  timestampMs: 0,
  landmarks: List.filled(
    LandmarkIndex.count,
    PoseLandmark(x: x, y: y, z: 0, visibility: v),
  ),
);

/// 중심 (cx, cy), 한 변 size인 사각형 모양의 사람.
PoseFrame _person(double cx, double cy, double size) {
  final lm = [
    for (var i = 0; i < LandmarkIndex.count; i++)
      PoseLandmark(
        x: cx + (i.isEven ? -size / 2 : size / 2),
        y: cy + (i < 16 ? -size / 2 : size / 2),
        z: 0,
        visibility: 0.9,
      ),
  ];
  return PoseFrame(timestampMs: 0, landmarks: lm);
}

void main() {
  group('isFullBodyVisible / isFrontFacing', () {
    test('측면 전신', () {
      for (final f in [_squat(), _pushUp()]) {
        expect(isFullBodyVisible(f), isTrue);
        expect(isFrontFacing(f), isFalse);
      }
    });

    test('정면 판정 (F-07)', () {
      expect(isFrontFacing(_squat(width: 0.7)), isTrue);
      expect(isFrontFacing(_squat(width: 0.7), ratioThreshold: 0.8), isFalse);
    });

    test('전신 아님', () {
      final f = _squat();
      const low = PoseLandmark(x: 0.45, y: 1.2, z: 0, visibility: 0.95);
      final cut = _edit(f, {
        LandmarkIndex.leftAnkle: low,
        LandmarkIndex.rightAnkle: low,
      });
      expect(isFullBodyVisible(cut), isFalse);
      expect(isFullBodyVisible(_all(0.5, 0.5, 0.2)), isFalse);
    });

    test('노이즈 입력에서 예외 없이 false', () {
      const nan = PoseLandmark(x: double.nan, y: 0.5, z: 0, visibility: 0.9);
      const inf = PoseLandmark(
        x: 0.5,
        y: double.infinity,
        z: 0,
        visibility: 0.9,
      );
      final f = _squat();
      for (final bad in [nan, inf]) {
        final g = _edit(f, {
          LandmarkIndex.nose: bad,
          LandmarkIndex.leftKnee: bad,
          LandmarkIndex.rightKnee: bad,
        });
        expect(isFullBodyVisible(g), isFalse);
      }
      // 어깨 중점-골반 중점 거리 0, 좌표 NaN이면 정면 아님.
      expect(isFrontFacing(_all(0.5, 0.5, 0.9)), isFalse);
      final g = _edit(f, {
        LandmarkIndex.leftShoulder: nan,
        LandmarkIndex.rightShoulder: nan,
      });
      expect(isFrontFacing(g), isFalse);
    });

    test('visibility 낮은 코는 전신 아님', () {
      final f = _squat();
      final weak = PoseLandmark(
        x: f[LandmarkIndex.nose].x,
        y: f[LandmarkIndex.nose].y,
        z: 0,
        visibility: 0.3,
      );
      expect(isFullBodyVisible(_edit(f, {LandmarkIndex.nose: weak})), isFalse);
    });
  });

  group('selectPrimaryPose', () {
    test('여러 사람 중 중앙 큰 사람', () {
      final edgeBig = _person(0.12, 0.5, 0.2);
      final centerBig = _person(0.5, 0.5, 0.18);
      final centerSmall = _person(0.5, 0.5, 0.05);
      expect(
        identical(
          selectPrimaryPose([edgeBig, centerSmall, centerBig]),
          centerBig,
        ),
        isTrue,
      );
    });

    test('빈 목록이면 null', () {
      expect(selectPrimaryPose([]), isNull);
    });

    test('유한하지 않은 좌표는 무시, 전부 그러면 null', () {
      final bad = PoseFrame(
        timestampMs: 0,
        landmarks: List.filled(
          LandmarkIndex.count,
          const PoseLandmark(x: double.nan, y: 0.5, z: 0, visibility: 0.9),
        ),
      );
      final good = _person(0.5, 0.5, 0.1);
      expect(identical(selectPrimaryPose([bad, good]), good), isTrue);
      expect(selectPrimaryPose([bad]), isNull);
    });
  });

  group('passesPostureGate', () {
    test('푸쉬업 게이트 (F-03)', () {
      final cases = {0.0: true, 25.0: true, 45.0: false, 90.0: false};
      for (final MapEntry(key: tilt, value: expected) in cases.entries) {
        expect(
          passesPostureGate(_pushUp(tilt: tilt), ExerciseType.pushUp),
          expected,
          reason: 'tilt $tilt',
        );
      }
    });

    test('스쿼트 게이트 (F-07)', () {
      final cases = {15.0: true, 30.0: true, 45.0: false};
      for (final MapEntry(key: lean, value: expected) in cases.entries) {
        expect(
          passesPostureGate(_squat(lean: lean), ExerciseType.squat),
          expected,
          reason: 'lean $lean',
        );
      }
    });

    test('게이트 측정 쪽 지정', () {
      final f = _pushUp();
      expect(
        passesPostureGate(f, ExerciseType.pushUp, side: BodySide.right),
        isFalse,
      );
      expect(
        passesPostureGate(f, ExerciseType.pushUp, side: BodySide.left),
        isTrue,
      );
      expect(
        passesPostureGate(
          _pushUp(side: BodySide.right),
          ExerciseType.pushUp,
          side: BodySide.right,
        ),
        isTrue,
      );
    });

    test('게이트 기준값 주입', () {
      final f = _pushUp(tilt: 40);
      expect(passesPostureGate(f, ExerciseType.pushUp), isFalse);
      expect(passesPostureGate(f, ExerciseType.pushUp, maxDeg: 45), isTrue);
    });

    test('노이즈 입력은 false, 예외 없음', () {
      expect(
        passesPostureGate(_all(0.5, 0.5, 0.9), ExerciseType.squat),
        isFalse,
      );
      expect(
        passesPostureGate(_all(0.5, 0.5, 0.9), ExerciseType.pushUp),
        isFalse,
      );
      expect(
        passesPostureGate(_all(0.5, 0.5, 0.1), ExerciseType.pushUp),
        isFalse,
      );
      const nan = PoseLandmark(x: double.nan, y: 0.5, z: 0, visibility: 0.9);
      final g = _edit(_squat(), {
        LandmarkIndex.leftShoulder: nan,
        LandmarkIndex.rightShoulder: nan,
      });
      expect(
        passesPostureGate(g, ExerciseType.squat, side: BodySide.left),
        isFalse,
      );
      expect(passesPostureGate(g, ExerciseType.squat), isFalse);
    });

    test('aspectRatio를 x에 곱해 기울기를 잰다', () {
      // 푸쉬업: 어깨 (0.2,0.4) -> 발목 (0.8,0.8), 비율 1이면 약 33.7도, 3이면 약 12.5도
      final base = _pushUp();
      PoseLandmark p(double x, double y) =>
          PoseLandmark(x: x, y: y, z: 0, visibility: 0.95);
      final changes = {
        LandmarkIndex.leftShoulder: p(0.2, 0.4),
        LandmarkIndex.leftAnkle: p(0.8, 0.8),
      };
      expect(
        passesPostureGate(_edit(base, changes), ExerciseType.pushUp),
        isFalse,
      );
      expect(
        passesPostureGate(
          _edit(base, changes, aspectRatio: 3),
          ExerciseType.pushUp,
        ),
        isTrue,
      );
    });
  });
}
