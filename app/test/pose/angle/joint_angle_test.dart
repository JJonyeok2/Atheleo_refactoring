import 'package:atheleo/pose/angle/joint_angle.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter_test/flutter_test.dart';

PoseLandmark _p(double x, double y, {double visibility = 1.0}) =>
    PoseLandmark(x: x, y: y, z: 0, visibility: visibility);

/// 33개 점을 기본값(visibility 0)으로 채우고 필요한 점만 덮어쓴다.
PoseFrame _frame(Map<int, PoseLandmark> points, {double aspectRatio = 1.0}) {
  final landmarks = List<PoseLandmark>.generate(
    LandmarkIndex.count,
    (i) => points[i] ?? _p(0.5, 0.5, visibility: 0),
  );
  return PoseFrame(
    timestampMs: 0,
    landmarks: landmarks,
    aspectRatio: aspectRatio,
  );
}

/// 한쪽 6개 점을 팔을 편 자세로 배치한다(어깨-팔꿈치-손목 수직 일직선).
Map<int, PoseLandmark> _straightArmSide(BodySide side, double visibility) {
  final isLeft = side == BodySide.left;
  final x = isLeft ? 0.4 : 0.6;
  return {
    isLeft ? LandmarkIndex.leftShoulder : LandmarkIndex.rightShoulder: _p(
      x,
      0.2,
      visibility: visibility,
    ),
    isLeft ? LandmarkIndex.leftElbow : LandmarkIndex.rightElbow: _p(
      x,
      0.35,
      visibility: visibility,
    ),
    isLeft ? LandmarkIndex.leftWrist : LandmarkIndex.rightWrist: _p(
      x,
      0.5,
      visibility: visibility,
    ),
    isLeft ? LandmarkIndex.leftHip : LandmarkIndex.rightHip: _p(
      x,
      0.55,
      visibility: visibility,
    ),
    isLeft ? LandmarkIndex.leftKnee : LandmarkIndex.rightKnee: _p(
      x,
      0.75,
      visibility: visibility,
    ),
    isLeft ? LandmarkIndex.leftAnkle : LandmarkIndex.rightAnkle: _p(
      x,
      0.95,
      visibility: visibility,
    ),
  };
}

void main() {
  group('angleDeg', () {
    test('직각', () {
      expect(angleDeg(_p(0, 0), _p(0, 1), _p(1, 1)), closeTo(90, 0.01));
    });

    test('일직선', () {
      expect(angleDeg(_p(0, 0), _p(0.5, 0.5), _p(1, 1)), closeTo(180, 0.01));
    });

    test('길이 0이면 0', () {
      expect(angleDeg(_p(0.3, 0.3), _p(0.3, 0.3), _p(1, 1)), 0);
    });

    test('aspectRatio 반영: 정규화 좌표 직각이 aspect 2.0에서 90이 아님', () {
      final a = _p(0, 0);
      final v = _p(0.5, 0.5);
      final c = _p(1, 0);
      expect(angleDeg(a, v, c), closeTo(90, 0.01));
      final corrected = angleDeg(a, v, c, aspectRatio: 2);
      // 벡터 (-1, -0.5), (1, -0.5) 사이 각도 = acos(-0.6) ≈ 126.87
      expect(corrected, closeTo(126.87, 0.5));
    });

    test('결과는 0~180 범위', () {
      final angle = angleDeg(_p(0, 0), _p(0.5, 0.5), _p(0.1, 0.9));
      expect(angle, inInclusiveRange(0, 180));
    });
  });

  group('anglesForSide', () {
    test('지정한 쪽의 팔꿈치, 무릎, 골반 각도와 평균 visibility', () {
      final frame = _frame(_straightArmSide(BodySide.right, 0.8));
      final angles = anglesForSide(frame, BodySide.right);
      expect(angles.side, BodySide.right);
      expect(angles.elbow, closeTo(180, 0.5));
      expect(angles.knee, closeTo(180, 0.5));
      expect(angles.hip, closeTo(180, 0.5));
      expect(angles.visibility, closeTo(0.8, 1e-9));
    });
  });

  group('selectSide', () {
    test('팔을 편 프레임 (F-02): 팔꿈치 160도 이상', () {
      final frame = _frame(_straightArmSide(BodySide.left, 0.9));
      final selected = selectSide(frame);
      expect(selected, isNotNull);
      expect(selected!.side, BodySide.left);
      expect(selected.elbow, greaterThanOrEqualTo(160));
    });

    test('가려진 쪽 무시 (F-02): 오른쪽 선택', () {
      final frame = _frame({
        ..._straightArmSide(BodySide.left, 0.1),
        ..._straightArmSide(BodySide.right, 0.9),
      });
      expect(selectSide(frame)!.side, BodySide.right);
    });

    test('둘 다 가려짐: null', () {
      final frame = _frame({
        ..._straightArmSide(BodySide.left, 0.2),
        ..._straightArmSide(BodySide.right, 0.2),
      });
      expect(selectSide(frame), isNull);
    });

    test('신뢰도가 같으면 left', () {
      final frame = _frame({
        ..._straightArmSide(BodySide.left, 0.7),
        ..._straightArmSide(BodySide.right, 0.7),
      });
      expect(selectSide(frame)!.side, BodySide.left);
    });

    test('minVisibility 기준 조정', () {
      final frame = _frame(_straightArmSide(BodySide.left, 0.4));
      expect(selectSide(frame), isNull);
      expect(selectSide(frame, minVisibility: 0.3)!.side, BodySide.left);
    });
  });
}
