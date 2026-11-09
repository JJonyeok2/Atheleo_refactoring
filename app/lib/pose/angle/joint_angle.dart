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
/// 같으면 left를 먼저 본다. 먼저 본 쪽이 [minVisibility] 미만이거나 쓸 수 없는
/// 쪽(세 점 묶음 중 벡터 길이 0 또는 유한하지 않은 좌표)이면 다른 쪽을 보고,
/// 둘 다 안 되면 null. `angleDeg`의 0(측정 불가)이 하류로 흘러가지 않게 한다.
SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5}) {
  final left = anglesForSide(frame, BodySide.left);
  final right = anglesForSide(frame, BodySide.right);
  final ordered = right.visibility > left.visibility
      ? [right, left]
      : [left, right];
  for (final candidate in ordered) {
    if (candidate.visibility >= minVisibility &&
        _isMeasurable(frame, candidate.side)) {
      return candidate;
    }
  }
  return null;
}

/// [side] 쪽의 세 점 묶음(어깨-팔꿈치-손목, 골반-무릎-발목, 어깨-골반-무릎,
/// 어깨-골반-발목)이 모두 각도를 정의할 수 있으면 true.
bool _isMeasurable(PoseFrame frame, BodySide side) {
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
  return _isDefined(shoulder, elbow, wrist, ratio) &&
      _isDefined(hip, knee, ankle, ratio) &&
      _isDefined(shoulder, hip, knee, ratio) &&
      _isDefined(shoulder, hip, ankle, ratio);
}

/// a-vertex-c 두 벡터의 길이가 모두 0이 아닌 유한한 값이면 true.
bool _isDefined(
  PoseLandmark a,
  PoseLandmark vertex,
  PoseLandmark c,
  double aspectRatio,
) {
  bool usableLength(PoseLandmark p) {
    final dx = (p.x - vertex.x) * aspectRatio;
    final dy = p.y - vertex.y;
    final length = math.sqrt(dx * dx + dy * dy);
    return length.isFinite && length > 0;
  }

  return usableLength(a) && usableLength(c);
}

// [QA] 2026-11-09 PASS (재검토)
// [보안] 외부 입력 없음. NaN/Infinity 좌표, 길이 0 벡터가 있는 쪽은 selectSide가
//   버리고 다른 쪽 또는 null을 돌려줘 0도가 하류로 흘러가지 않음. NaN visibility도
//   기준 비교에서 걸러짐. aspectRatio 0 이하는 막지 않음(TASK-04/19 파싱 쪽 책임).
// [유지보수] angleDeg, anglesForSide 자체는 여전히 길이 0에서 0을 돌려주므로 직접
//   쓰는 쪽(TASK-06, 09, 13)은 selectSide로 고른 프레임에서만 쓸 것. 좌우 6개 점을
//   꺼내는 코드가 anglesForSide와 _isMeasurable에 중복됨, 손볼 때 헬퍼로 묶을 후보.
