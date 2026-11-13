// [파일] 전신 인식, 정면 판정, 주 인물 선택, 운동별 자세 게이트(순수 함수).
// [Spec] F-07 촬영 가이드, F-03 자세 게이트 / [Task] TASK-13
// [의존] pose/landmarks, pose/angle (환경 변수 사용 안 함)

import 'dart:math' as math;

import 'package:atheleo/pose/angle/joint_angle.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';

/// 경계 값 비교의 부동소수 오차 허용치(도).
const double _degEpsilon = 1e-6;

bool _finite(PoseLandmark p) => p.x.isFinite && p.y.isFinite;

bool _inUnitBox(PoseLandmark p) =>
    _finite(p) && p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1;

/// [side] 쪽의 (어깨, 골반, 무릎, 발목).
List<PoseLandmark> _sideBody(PoseFrame frame, BodySide side) {
  final left = side == BodySide.left;
  return [
    frame[left ? LandmarkIndex.leftShoulder : LandmarkIndex.rightShoulder],
    frame[left ? LandmarkIndex.leftHip : LandmarkIndex.rightHip],
    frame[left ? LandmarkIndex.leftKnee : LandmarkIndex.rightKnee],
    frame[left ? LandmarkIndex.leftAnkle : LandmarkIndex.rightAnkle],
  ];
}

/// nose와 [selectSide]로 고른 쪽의 어깨, 골반, 무릎, 발목이 모두
/// visibility [minVisibility] 이상이고 x, y가 0~1 안이면 true.
bool isFullBodyVisible(PoseFrame frame, {double minVisibility = 0.5}) {
  final chosen = selectSide(frame, minVisibility: minVisibility);
  if (chosen == null) return false;
  final points = [frame[LandmarkIndex.nose], ..._sideBody(frame, chosen.side)];
  return points.every((p) => p.visibility >= minVisibility && _inUnitBox(p));
}

/// (좌우 어깨 x 거리 x aspectRatio) / (어깨 중점-골반 중점 거리)가
/// [ratioThreshold]를 넘으면 정면.
///
/// 계산할 수 없으면(좌표가 유한하지 않거나 몸통 길이 0) false.
bool isFrontFacing(PoseFrame frame, {double ratioThreshold = 0.35}) {
  final ls = frame[LandmarkIndex.leftShoulder];
  final rs = frame[LandmarkIndex.rightShoulder];
  final lh = frame[LandmarkIndex.leftHip];
  final rh = frame[LandmarkIndex.rightHip];
  final width = (ls.x - rs.x).abs() * frame.aspectRatio;
  final torsoX = ((ls.x + rs.x) - (lh.x + rh.x)) / 2 * frame.aspectRatio;
  final torsoY = ((ls.y + rs.y) - (lh.y + rh.y)) / 2;
  final torso = math.sqrt(torsoX * torsoX + torsoY * torsoY);
  if (!width.isFinite || !torso.isFinite || torso == 0) return false;
  return width / torso > ratioThreshold;
}

/// 경계 상자 면적 x (1 - 상자 중심과 (0.5, 0.5) 거리)가 가장 큰 사람.
///
/// 유한하지 않은 좌표의 점은 무시하고, 쓸 수 있는 점이 없는 사람은 후보에서
/// 뺀다. 빈 목록이거나 후보가 없으면 null.
PoseFrame? selectPrimaryPose(List<PoseFrame> poses) {
  PoseFrame? best;
  var bestScore = double.negativeInfinity;
  for (final pose in poses) {
    final score = _primaryScore(pose);
    if (score != null && score > bestScore) {
      best = pose;
      bestScore = score;
    }
  }
  return best;
}

double? _primaryScore(PoseFrame pose) {
  double? minX;
  double? maxX;
  double? minY;
  double? maxY;
  for (final p in pose.landmarks) {
    if (!_finite(p)) continue;
    minX = minX == null ? p.x : math.min(minX, p.x);
    maxX = maxX == null ? p.x : math.max(maxX, p.x);
    minY = minY == null ? p.y : math.min(minY, p.y);
    maxY = maxY == null ? p.y : math.max(maxY, p.y);
  }
  if (minX == null || maxX == null || minY == null || maxY == null) return null;
  final area = (maxX - minX) * (maxY - minY);
  final dx = (minX + maxX) / 2 - 0.5;
  final dy = (minY + maxY) / 2 - 0.5;
  final score = area * (1 - math.sqrt(dx * dx + dy * dy));
  return score.isFinite ? score : null;
}

/// 운동별 자세 게이트. 기울기가 [maxDeg] 이하이면 true.
///
/// 푸쉬업은 어깨->발목 선과 수평선 사이 각도(0~90), 스쿼트는 골반->어깨 선과
/// 수직 위쪽 사이 각도(0~180)를 잰다. x에는 aspectRatio를 곱한다.
/// [side]가 없으면 [selectSide]로 고른 쪽. 고를 수 없거나 그쪽 점의 평균
/// visibility가 0.5 미만이거나 좌표가 유한하지 않으면 false.
///
/// [maxDeg] 기본값 30은 실기기 보정 대상(Spec Q-05).
bool passesPostureGate(
  PoseFrame frame,
  ExerciseType exercise, {
  BodySide? side,
  double maxDeg = 30,
}) {
  final BodySide target;
  if (side != null) {
    target = side;
    if (anglesForSide(frame, side).visibility < 0.5) return false;
  } else {
    final chosen = selectSide(frame);
    if (chosen == null) return false;
    target = chosen.side;
  }
  final body = _sideBody(frame, target);
  final shoulder = body[0];
  final hip = body[1];
  final ankle = body[3];

  final double tilt;
  switch (exercise) {
    case ExerciseType.pushUp:
      final dx = (ankle.x - shoulder.x) * frame.aspectRatio;
      final dy = ankle.y - shoulder.y;
      if (!_usable(dx, dy)) return false;
      tilt = math.atan2(dy.abs(), dx.abs()) * 180 / math.pi;
    case ExerciseType.squat:
      final dx = (shoulder.x - hip.x) * frame.aspectRatio;
      final dy = shoulder.y - hip.y;
      if (!_usable(dx, dy)) return false;
      final cosine = (-dy / math.sqrt(dx * dx + dy * dy)).clamp(-1.0, 1.0);
      tilt = math.acos(cosine) * 180 / math.pi;
  }
  return tilt.isFinite && tilt <= maxDeg + _degEpsilon;
}

/// 벡터가 유한하고 길이가 0이 아니면 true.
bool _usable(double dx, double dy) {
  final length = math.sqrt(dx * dx + dy * dy);
  return length.isFinite && length > 0;
}

// [QA] 2026-11-13 PASS
// [보안] 외부 입력은 PoseFrame 좌표뿐. NaN, Infinity, 길이 0 벡터는 모두 false 또는
//   후보 제외로 처리해 예외나 0도가 하류로 흐르지 않음. aspectRatio 0 이하는 막지
//   않음(TASK-04/19 파싱 쪽 책임, joint_angle.dart와 같은 방침).
// [유지보수] 게이트의 visibility 기준 0.5가 하드코딩됨(selectSide 기본값과 같은 값).
//   side 지정 경로는 6점 평균 visibility만 보고, selectSide 경로는 세 점 묶음 길이 0까지
//   거르므로 지정 경로가 조금 더 관대함(게이트에 필요한 벡터는 _usable로 따로 검사).
//   isFrontFacing은 visibility를 보지 않음, 호출 쪽(TASK-14)이 isFullBodyVisible과 함께 쓸 것.
//   경계 비교 허용오차 _degEpsilon(1e-6도)은 스쿼트 30도 경계 테스트를 위해 둔 값.
