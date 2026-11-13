// [파일] 반복 1회의 프레임으로 자세 오류 코드를 고르는 순수 함수.
// [Spec] F-04 / [Task] TASK-09
// [의존] pose/angle/joint_angle.dart (환경 변수 사용 안 함)

import 'dart:math' as math;

import 'package:atheleo/pose/angle/joint_angle.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:atheleo/pose/rep/rep_counter.dart';

/// 판정 기준값. 기본값은 Spec 표의 초기값.
class ErrorThresholds {
  /// 기준값을 만든다.
  const new({
    this.depthDeg = 90,
    this.bodyLineDeg = 160,
    this.torsoLeanDeg = 45,
    this.heelLiftRatio = 0.1,
  });

  /// 최저 각도가 이 값보다 크면 깊이 부족.
  final double depthDeg;

  /// 어깨-골반-발목 각도 중앙값이 이 값 미만이면 처짐/들림.
  final double bodyLineDeg;

  /// 최저점 상체 기울기가 이 값보다 크면 상체 숙임.
  /// 실기기 보정 대상(Spec Q-05).
  final double torsoLeanDeg;

  /// 뒤꿈치 상승량 / 정강이 길이가 이 값 이상이면 뒤꿈치 들림.
  final double heelLiftRatio;
}

/// 횟수로 인정된 반복 [rep] 하나의 [repFrames]에서 자세 오류를 판정한다.
///
/// [exercise]에 맞는 코드만, [PoseErrorCode] 선언 순서대로 돌려준다.
/// 깊이 부족은 [RepEvent.minAngle]만 본다.
List<PoseErrorCode> judgeRep({
  required ExerciseType exercise,
  required List<PoseFrame> repFrames,
  required RepEvent rep,
  ErrorThresholds thresholds = const ErrorThresholds(),
}) {
  switch (exercise) {
    case ExerciseType.pushUp:
      final body = _bodyLineError(repFrames, thresholds);
      return [
        if (rep.minAngle > thresholds.depthDeg) PoseErrorCode.puShallow,
        ?body,
      ];
    case ExerciseType.squat:
      return [
        if (rep.minAngle > thresholds.depthDeg) PoseErrorCode.sqShallow,
        if (_torsoLean(repFrames, rep.bottomMs) > thresholds.torsoLeanDeg)
          PoseErrorCode.sqTorsoLean,
        if (_heelLift(repFrames) >= thresholds.heelLiftRatio)
          PoseErrorCode.sqHeelLift,
      ];
  }
}

({
  PoseLandmark shoulder,
  PoseLandmark hip,
  PoseLandmark ankle,
  PoseLandmark knee,
})
_points(PoseFrame frame, BodySide side) {
  final left = side == BodySide.left;
  return (
    shoulder:
        frame[left ? LandmarkIndex.leftShoulder : LandmarkIndex.rightShoulder],
    hip: frame[left ? LandmarkIndex.leftHip : LandmarkIndex.rightHip],
    knee: frame[left ? LandmarkIndex.leftKnee : LandmarkIndex.rightKnee],
    ankle: frame[left ? LandmarkIndex.leftAnkle : LandmarkIndex.rightAnkle],
  );
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// 어깨-골반-발목 각도 중앙값이 기준 미만이면 처짐/들림 중 하나.
PoseErrorCode? _bodyLineError(List<PoseFrame> frames, ErrorThresholds t) {
  final angles = <double>[];
  var below = 0;
  var above = 0;
  for (final frame in frames) {
    final side = selectSide(frame);
    if (side == null) continue;
    final p = _points(frame, side.side);
    angles.add(
      angleDeg(p.shoulder, p.hip, p.ankle, aspectRatio: frame.aspectRatio),
    );
    // 어깨->발목과 어깨->골반의 외적에 어깨->발목 x 부호를 곱해 좌우 방향을 맞춘다.
    final vx = (p.ankle.x - p.shoulder.x) * frame.aspectRatio;
    final vy = p.ankle.y - p.shoulder.y;
    final hx = (p.hip.x - p.shoulder.x) * frame.aspectRatio;
    final hy = p.hip.y - p.shoulder.y;
    final signed = (vx * hy - vy * hx) * (vx < 0 ? -1 : 1);
    if (signed > 0) {
      below++;
    } else if (signed < 0) {
      above++;
    }
  }
  if (angles.isEmpty || _median(angles) >= t.bodyLineDeg) return null;
  if (below > above) return PoseErrorCode.puHipSag;
  if (above > below) return PoseErrorCode.puHipPike;
  return null;
}

/// 상체 기울기(골반->어깨와 수직 위쪽 사이 각도). 판정 불가면 0.
double _leanOf(PoseFrame frame, BodySide side) {
  final p = _points(frame, side);
  final dx = (p.shoulder.x - p.hip.x) * frame.aspectRatio;
  final dy = p.hip.y - p.shoulder.y; // 위쪽이 양수
  if (dx == 0 && dy == 0) return 0;
  return math.atan2(dx.abs(), dy) * 180 / math.pi;
}

/// 고를 수 있는 프레임 중 [bottomMs]에 가장 가까운 프레임과 그 앞뒤 고를 수 있는
/// 프레임(최대 3개)의 상체 기울기 중앙값. 고를 수 있는 프레임이 없으면 0.
double _torsoLean(List<PoseFrame> frames, int bottomMs) {
  final leans = <double>[];
  var nearestIdx = 0;
  var nearestGap = -1;
  for (final frame in frames) {
    final side = selectSide(frame);
    if (side == null) continue;
    leans.add(_leanOf(frame, side.side));
    final gap = (frame.timestampMs - bottomMs).abs();
    if (nearestGap < 0 || gap < nearestGap) {
      nearestGap = gap;
      nearestIdx = leans.length - 1;
    }
  }
  if (leans.isEmpty) return 0;
  final from = math.max(0, nearestIdx - 1);
  final to = math.min(leans.length, nearestIdx + 2);
  return _median(leans.sublist(from, to));
}

/// 뒤꿈치 랜드마크 visibility 하한. 실기기 보정 대상(Spec Q-05).
const double _minHeelVisibility = 0.5;

bool _heelUsable(PoseLandmark heel) =>
    heel.x.isFinite &&
    heel.y.isFinite &&
    heel.visibility >= _minHeelVisibility;

/// 시작 프레임 대비 뒤꿈치 상승량의 3프레임 이동 중앙값 최댓값 / 시작 정강이 길이.
///
/// 시작 프레임은 고를 수 있고 그 쪽 뒤꿈치 좌표가 유한하며 visibility가 하한
/// 이상인 첫 프레임이고 좌우도 그 쪽으로 고정한다. 조건에 안 맞거나 다른 쪽이
/// 골라지는 프레임은 건너뛴다.
double _heelLift(List<PoseFrame> frames) {
  PoseFrame? start;
  BodySide? side;
  var heelIndex = LandmarkIndex.leftHeel;
  for (final frame in frames) {
    final selected = selectSide(frame);
    if (selected == null) continue;
    final index = selected.side == BodySide.left
        ? LandmarkIndex.leftHeel
        : LandmarkIndex.rightHeel;
    if (!_heelUsable(frame[index])) continue;
    start = frame;
    side = selected.side;
    heelIndex = index;
    break;
  }
  if (start == null || side == null) return 0;
  final p = _points(start, side);
  final shin = math.sqrt(
    math.pow((p.knee.x - p.ankle.x) * start.aspectRatio, 2) +
        math.pow(p.knee.y - p.ankle.y, 2),
  );
  if (shin == 0 || !shin.isFinite) return 0;
  final startY = start[heelIndex].y;
  final rises = <double>[];
  for (final frame in frames) {
    if (selectSide(frame)?.side != side) continue;
    final heel = frame[heelIndex];
    if (!_heelUsable(heel)) continue;
    rises.add(startY - heel.y);
  }
  if (rises.isEmpty) return 0;
  if (rises.length < 3) return rises.reduce(math.min) / shin;
  var best = -double.infinity;
  for (var i = 0; i + 3 <= rises.length; i++) {
    best = math.max(best, _median(rises.sublist(i, i + 3)));
  }
  return math.max(best, 0) / shin;
}

// [QA] 2026-11-13 PASS (docs/qa/QA-TASK-09.md, 2차 재검토)
// [보안] 외부 입력, 시크릿, 로그 없음. 순수 함수.
// [유지보수] 기준값은 Q-05 실측 후 ErrorThresholds로 조정.
// [FIX 반영] 2026-11-13 뒤꿈치 시작 프레임도 좌표 유한, visibility 하한 검사(2차 FIX).
