// [파일] 테스트용 합성 랜드마크 클립 생성기 (각도 값에서 2D 측면 골격을 순방향으로
//   배치). 테스트 전용, app/lib에서 쓰지 않음.
// [Spec] 8장 테스트 가능성, F-02 / [Task] TASK-06
// [의존] 없음 (환경 변수 사용 안 함)

import 'dart:math' as math;

import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/landmark_clip.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';

/// 푸쉬업에서 골반이 어깨-발목 선의 아래(처짐) 또는 위(들림)에 있는지.
/// 이미지 좌표에서 아래는 y가 큼.
enum HipOffset {
  /// 선 아래(허리 처짐).
  below,

  /// 선 위(엉덩이 들림).
  above,
}

/// 합성 프레임 한 장의 자세 값.
///
/// 운동별 반영 값: kneeDeg, torsoLeanDeg, heelLiftRatio는 스쿼트만, elbowDeg는
/// 두 운동 모두, bodyLineDeg, bodyTiltDeg, hipOffset은 푸쉬업만 반영하고 다른
/// 운동의 값은 무시한다. hipOffset의 위/아래는 bodyTiltDeg 90 미만에서만 정의된다.
///
/// pushUp은 엎드린 자세, squat은 선 자세다. [bodyTiltDeg]는 푸쉬업 어깨-발목
/// 선과 수평선 사이 각도, [torsoLeanDeg]는 스쿼트 골반에서 어깨로 가는 선과
/// 수직선 사이 각도, [heelLiftRatio]는 뒤꿈치가 뜬 높이 / 정강이 길이,
/// [shoulderWidthRatio]는 좌우 어깨 x 거리 / 몸통 길이다.
class SyntheticPose {
  /// 자세를 만든다.
  const new({
    required this.exercise,
    this.elbowDeg = 170,
    this.kneeDeg = 170,
    this.bodyLineDeg = 180,
    this.hipOffset = HipOffset.below,
    this.bodyTiltDeg = 0,
    this.torsoLeanDeg = 15,
    this.heelLiftRatio = 0,
    this.shoulderWidthRatio = 0.05,
    this.visibleSide = BodySide.left,
    this.hiddenVisibility = 0.1,
  });

  /// 운동 종류.
  final ExerciseType exercise;

  /// 어깨-팔꿈치-손목 각도.
  final double elbowDeg;

  /// 골반-무릎-발목 각도(스쿼트에서만 반영).
  final double kneeDeg;

  /// 어깨-골반-발목 각도(푸쉬업에서만 반영).
  final double bodyLineDeg;

  /// bodyLineDeg가 180 미만일 때 골반 위치.
  final HipOffset hipOffset;

  /// 푸쉬업 몸통 기울기(0 수평, 90 서 있음).
  final double bodyTiltDeg;

  /// 스쿼트 상체 기울기(수직선 기준).
  final double torsoLeanDeg;

  /// 스쿼트 뒤꿈치 상승 비율.
  final double heelLiftRatio;

  /// 좌우 어깨 x 거리 / 몸통 길이.
  final double shoulderWidthRatio;

  /// 잘 보이는 쪽.
  final BodySide visibleSide;

  /// 반대쪽 visibility.
  final double hiddenVisibility;
}

typedef _P = ({double x, double y});

/// 한쪽 몸의 뼈대 점(로컬 좌표, 이미지 좌표계: 아래가 y 양수).
typedef _Body = ({
  _P shoulder,
  _P hip,
  _P knee,
  _P ankle,
  _P heel,
  _P toe,
  _P armDown,
});

/// 몸통, 정강이 등 한 마디 길이(로컬 단위).
const double _seg = 0.3;
const double _arm = 0.15;

/// 머리 길이: 어깨에서 몸통 방향으로 [_seg]만큼 더 간 곳이 코다.
const double _headLength = _seg;
const double _visibleVisibility = 0.95;

// 운동별 고정 축척과 고정 기준점(발목이 화면의 이 위치에 온다). 프레임마다
// 경계 상자를 다시 재지 않으므로 시작 자세 대비 이동량을 잴 수 있다. 값은
// 계약의 값 범위 끝 조합(kneeDeg 60~180, torsoLeanDeg 0~60, heelLiftRatio 0~0.3,
// bodyTiltDeg 0~90, bodyLineDeg 120~180, shoulderWidthRatio 0~0.8)에서도 모든
// 점이 0~1 안에 들도록 골랐다(테스트로 확인).
const double _scaleSquat = 0.75;
const _P _anchorSquat = (x: 0.45, y: 0.93);
const double _scalePushUp = 0.75;
const _P _anchorPushUp = (x: 0.7, y: 0.7);

double _rad(double deg) => deg * math.pi / 180;

_P _add(_P a, _P b) => (x: a.x + b.x, y: a.y + b.y);

_P _sub(_P a, _P b) => (x: a.x - b.x, y: a.y - b.y);

_P _scale(_P a, double k) => (x: a.x * k, y: a.y * k);

double _length(_P a) => math.sqrt(a.x * a.x + a.y * a.y);

_P _rotate(_P v, double deg) {
  final c = math.cos(_rad(deg));
  final s = math.sin(_rad(deg));
  return (x: v.x * c - v.y * s, y: v.x * s + v.y * c);
}

/// 푸쉬업(엎드린 자세): 어깨를 원점으로 두고 bodyTiltDeg, bodyLineDeg, hipOffset 반영.
_Body _pushUpBody(SyntheticPose pose) {
  final t = _rad(pose.bodyTiltDeg);
  final dir = (x: math.cos(t), y: math.sin(t));
  final normal = (x: -math.sin(t), y: math.cos(t)); // 아래쪽 수직
  final half = _rad(pose.bodyLineDeg) / 2;
  final dist = 2 * _seg * math.sin(half);
  const shoulder = (x: 0.0, y: 0.0);
  final ankle = _add(shoulder, _scale(dir, dist));
  final sign = pose.hipOffset == HipOffset.below ? 1.0 : -1.0;
  final hip = _add(
    _add(shoulder, _scale(dir, dist / 2)),
    _scale(normal, sign * _seg * math.cos(half)),
  );
  return (
    shoulder: shoulder,
    hip: hip,
    knee: _scale(_add(hip, ankle), 0.5),
    ankle: ankle,
    heel: _add(ankle, _scale(dir, 0.03)),
    toe: _add(ankle, _scale(dir, 0.08)),
    armDown: normal,
  );
}

/// 스쿼트(선 자세): 발목을 원점으로 두고 kneeDeg, torsoLeanDeg, heelLiftRatio 반영.
_Body _squatBody(SyntheticPose pose) {
  const ankle = (x: 0.0, y: 0.0);
  const knee = (x: 0.0, y: -_seg);
  final k = _rad(pose.kneeDeg);
  final hip = _add(knee, _scale((x: -math.sin(k), y: math.cos(k)), _seg));
  final lean = _rad(pose.torsoLeanDeg);
  final shoulder = _add(
    hip,
    _scale((x: math.sin(lean), y: -math.cos(lean)), _seg),
  );
  const toe = (x: 0.12, y: 0.05);
  // 뒤꿈치는 발목 기준 고정 위치에서 heelLiftRatio × 정강이 길이만큼만 올린다.
  final heel = (x: -0.03, y: toe.y - pose.heelLiftRatio * _seg);
  return (
    shoulder: shoulder,
    hip: hip,
    knee: knee,
    ankle: ankle,
    heel: heel,
    toe: toe,
    armDown: (x: 0.0, y: 1.0),
  );
}

/// 한쪽 몸의 점들(인덱스는 왼쪽 기준, 오른쪽은 +1)을 로컬 좌표로 배치한다.
Map<int, _P> _localSkeleton(SyntheticPose pose) {
  final body = pose.exercise == ExerciseType.pushUp
      ? _pushUpBody(pose)
      : _squatBody(pose);
  final shoulder = body.shoulder;
  final elbow = _add(shoulder, _scale(body.armDown, _arm));
  final wrist = _add(
    elbow,
    _scale(_rotate(_scale(body.armDown, -1), pose.elbowDeg), _arm),
  );
  final trunk = _sub(shoulder, body.hip);
  final head = _add(shoulder, _scale(trunk, _headLength / _length(trunk)));

  return {
    LandmarkIndex.nose: head,
    LandmarkIndex.leftShoulder: shoulder,
    LandmarkIndex.leftElbow: elbow,
    LandmarkIndex.leftWrist: wrist,
    17: wrist, // 왼쪽 새끼손가락(pinky)
    19: wrist, // 왼쪽 검지(index)
    21: wrist, // 왼쪽 엄지(thumb)
    LandmarkIndex.leftHip: body.hip,
    LandmarkIndex.leftKnee: body.knee,
    LandmarkIndex.leftAnkle: body.ankle,
    LandmarkIndex.leftHeel: body.heel,
    LandmarkIndex.leftFootIndex: body.toe,
  };
}

/// 로컬 점을 운동별 고정 축척과 고정 기준점(발목)에 맞춰 화면 좌표로 옮긴다.
_P Function(_P) _toScreen(Map<int, _P> local, ExerciseType exercise) {
  final isPushUp = exercise == ExerciseType.pushUp;
  final k = isPushUp ? _scalePushUp : _scaleSquat;
  final anchor = isPushUp ? _anchorPushUp : _anchorSquat;
  final ankle = local[LandmarkIndex.leftAnkle]!;
  return (p) => _add(anchor, _scale(_sub(p, ankle), k));
}

/// [pose]로 33개 랜드마크 프레임을 만든다(측면, aspectRatio 1.0, z 0).
///
/// 보이는 쪽 visibility 0.95, 반대쪽은 hiddenVisibility. 반대쪽 점은 보이는 쪽
/// 점을 x로 shoulderWidthRatio × 몸통(어깨-골반) 길이만큼 옮긴 위치다.
///
/// 같은 운동이면 프레임 사이 축척과 기준점(발목 위치)이 고정되어, 시작 자세 대비
/// 뒤꿈치 상승 같은 이동량을 잴 수 있다.
///
/// 자세 값 반영 운동: kneeDeg, torsoLeanDeg, heelLiftRatio는 스쿼트만, bodyLineDeg,
/// bodyTiltDeg, hipOffset은 푸쉬업만 반영하고 다른 운동에서는 무시한다. elbowDeg는
/// 두 운동 모두 반영한다. hipOffset의 위/아래는 bodyTiltDeg 90 미만에서만 정의된다.
PoseFrame buildSyntheticFrame(SyntheticPose pose, {int timestampMs = 0}) {
  final local = _localSkeleton(pose);
  final torso = _length(
    _sub(local[LandmarkIndex.leftShoulder]!, local[LandmarkIndex.leftHip]!),
  );
  final shift = pose.shoulderWidthRatio * torso;
  final toScreen = _toScreen(local, pose.exercise);
  final k = pose.exercise == ExerciseType.pushUp ? _scalePushUp : _scaleSquat;

  final visibleIsLeft = pose.visibleSide == BodySide.left;
  final landmarks = List<PoseLandmark>.filled(
    LandmarkIndex.count,
    const PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: 0),
  );
  PoseLandmark make(_P p, double dxExtra, double visibility) {
    final s = toScreen(p);
    return PoseLandmark(
      x: s.x + dxExtra * k,
      y: s.y,
      z: 0,
      visibility: visibility,
    );
  }

  for (final entry in local.entries) {
    final i = entry.key;
    if (i == LandmarkIndex.nose) {
      landmarks[i] = make(entry.value, 0, _visibleVisibility);
      continue;
    }
    landmarks[i] = visibleIsLeft
        ? make(entry.value, 0, _visibleVisibility)
        : make(entry.value, shift, pose.hiddenVisibility);
    landmarks[i + 1] = visibleIsLeft
        ? make(entry.value, shift, pose.hiddenVisibility)
        : make(entry.value, 0, _visibleVisibility);
  }
  // 얼굴 1~10은 코와 같은 위치.
  for (var i = 1; i <= 10; i++) {
    landmarks[i] = landmarks[LandmarkIndex.nose];
  }
  return PoseFrame(timestampMs: timestampMs, landmarks: landmarks);
}

/// [reps]번 반복하는 각도 시퀀스. 앞뒤 [padFrames]만큼 [top]을 유지하고, 반복마다
/// top → bottom → top 코사인 곡선을 [framesPerRep] 프레임으로 그린다.
List<double> repAngleSequence({
  required int reps,
  double top = 170,
  double bottom = 80,
  int framesPerRep = 30,
  int padFrames = 10,
}) {
  return [
    for (var i = 0; i < padFrames; i++) top,
    for (var r = 0; r < reps; r++)
      for (var j = 0; j < framesPerRep; j++)
        top -
            (top - bottom) * (1 - math.cos(2 * math.pi * j / framesPerRep)) / 2,
    for (var i = 0; i < padFrames; i++) top,
  ];
}

/// [primaryAngles]로 합성 클립을 만든다. 푸쉬업이면 팔꿈치, 스쿼트면 무릎 각도.
/// [poseFor]가 없으면 기본 [SyntheticPose]에 그 각도만 넣는다.
LandmarkClip buildSyntheticClip({
  required ExerciseType exercise,
  required List<double> primaryAngles,
  int fps = 30,
  String label = 'synthetic',
  SyntheticPose Function(int frameIndex, double angle)? poseFor,
}) {
  SyntheticPose defaultPose(int i, double angle) =>
      exercise == ExerciseType.pushUp
      ? SyntheticPose(exercise: exercise, elbowDeg: angle)
      : SyntheticPose(exercise: exercise, kneeDeg: angle);
  final build = poseFor ?? defaultPose;
  return LandmarkClip(
    id: 'synthetic-${exercise.code}',
    exercise: exercise,
    label: label,
    fps: fps,
    frames: [
      for (var i = 0; i < primaryAngles.length; i++)
        buildSyntheticFrame(
          build(i, primaryAngles[i]),
          timestampMs: i * 1000 ~/ fps,
        ),
    ],
  );
}
