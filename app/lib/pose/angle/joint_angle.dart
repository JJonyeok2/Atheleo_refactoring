// [파일] 관절 각도(팔꿈치, 무릎, 골반) 계산과 신뢰도 기반 좌우 자동 선택
//   (순수 함수, 상태 없음).
// [Spec] F-02 관절 각도 / [Task] TASK-05
// [의존] 없음 (환경 변수 사용 안 함)

import 'dart:math' as math;

import 'package:atheleo/pose/landmarks/pose_landmark.dart';

/// `vertex`를 꼭짓점으로 하는 a-vertex-c 2D 각도(도, 0~180).
///
/// x에 [aspectRatio](이미지 너비/높이)를 곱해 정규화 좌표의 비율 왜곡을 보정한다.
/// 한쪽 벡터 길이가 0이거나 계산 결과가 유한하지 않으면 0을 돌려준다.
double angleDeg(
  PoseLandmark a,
  PoseLandmark vertex,
  PoseLandmark c, {
  double aspectRatio = 1.0,
}) {
  final ax = (a.x - vertex.x) * aspectRatio;
  final ay = a.y - vertex.y;
  final cx = (c.x - vertex.x) * aspectRatio;
  final cy = c.y - vertex.y;

  final lengths = math.sqrt(ax * ax + ay * ay) * math.sqrt(cx * cx + cy * cy);
  if (lengths == 0 || !lengths.isFinite) return 0;

  final cosine = ((ax * cx + ay * cy) / lengths).clamp(-1.0, 1.0);
  final degrees = math.acos(cosine) * 180 / math.pi;
  return degrees.isFinite ? degrees : 0;
}

/// 한쪽(좌/우) 몸의 관절 각도와 그쪽 6개 점의 평균 visibility.
class SideAngles {
  /// 한쪽 각도 묶음을 만든다.
  const new({
    required this.side,
    required this.elbow,
    required this.knee,
    required this.hip,
    required this.visibility,
  });

  /// 각도를 계산한 쪽.
  final BodySide side;

  /// 어깨-팔꿈치-손목 각도.
  final double elbow;

  /// 골반-무릎-발목 각도.
  final double knee;

  /// 어깨-골반-무릎 각도.
  final double hip;

  /// 어깨, 팔꿈치, 손목, 골반, 무릎, 발목 visibility 평균.
  final double visibility;
}

/// [frame]에서 [side] 쪽의 팔꿈치, 무릎, 골반 각도를 계산한다.
SideAngles anglesForSide(PoseFrame frame, BodySide side) {
  final isLeft = side == BodySide.left;
  final shoulder =
      frame[isLeft ? LandmarkIndex.leftShoulder : LandmarkIndex.rightShoulder];
  final elbow =
      frame[isLeft ? LandmarkIndex.leftElbow : LandmarkIndex.rightElbow];
  final wrist =
      frame[isLeft ? LandmarkIndex.leftWrist : LandmarkIndex.rightWrist];
  final hip = frame[isLeft ? LandmarkIndex.leftHip : LandmarkIndex.rightHip];
  final knee = frame[isLeft ? LandmarkIndex.leftKnee : LandmarkIndex.rightKnee];
  final ankle =
      frame[isLeft ? LandmarkIndex.leftAnkle : LandmarkIndex.rightAnkle];

  final ratio = frame.aspectRatio;
  final points = [shoulder, elbow, wrist, hip, knee, ankle];
  final visibility =
      points.fold<double>(0, (sum, p) => sum + p.visibility) / points.length;

  return SideAngles(
    side: side,
    elbow: angleDeg(shoulder, elbow, wrist, aspectRatio: ratio),
    knee: angleDeg(hip, knee, ankle, aspectRatio: ratio),
    hip: angleDeg(shoulder, hip, knee, aspectRatio: ratio),
    visibility: visibility,
  );
}

/// 평균 visibility가 높은 쪽의 각도를 고른다.
///
/// 같으면 left, 양쪽 모두 [minVisibility] 미만이면 null.
SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5}) {
  final left = anglesForSide(frame, BodySide.left);
  final right = anglesForSide(frame, BodySide.right);
  final best = right.visibility > left.visibility ? right : left;
  return best.visibility >= minVisibility ? best : null;
}

// [QA] 2026-11-09 PASS
// [보안] 외부 입력 없음. NaN/Infinity 좌표는 angleDeg에서 0, NaN visibility는
//   selectSide에서 null로 떨어져 예외가 나지 않음. aspectRatio 0 이하는 막지 않음
//   (TASK-04/19 파싱 쪽 책임).
// [유지보수] "길이 0이면 0"은 실제 0도(완전히 접힌 관절)와 구분되지 않는다.
//   하류(TASK-09, 15)에서 0을 정상 각도로 쓰면 이동 평균을 끌어내려 최저 각도가
//   왜곡될 수 있음(QA-TASK-05 위험 추적 참고). 반환형을 double?로 바꿀 경우
//   SideAngles와 TASK-06, 09, 13, 15 계약이 함께 바뀐다.
