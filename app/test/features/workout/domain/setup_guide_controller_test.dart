import 'package:atheleo/features/workout/domain/setup_guide_controller.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/synthetic_clip.dart';

const _pushUpDistance = '휴대폰을 옆에 세우고 측면에서 약 2m 이상 떨어져 주세요. 전신이 화면에 들어와야 해요.';
const _squatDistance = '휴대폰을 옆에 세우고 측면에서 약 2m 떨어져 주세요. 전신이 화면에 들어와야 해요.';
const _pushUpPosture = '엎드려 팔을 편 자세를 잡아 주세요';
const _squatPosture = '똑바로 서서 무릎을 펴 주세요';
const _noPersonText = '카메라 앞에 서 주세요';
const _frontText = '옆으로 서 주세요';
const _holdText = '그대로 유지하세요';
const _startText = '시작';

const _pushUpReady = SyntheticPose(exercise: ExerciseType.pushUp);
const _squatReady = SyntheticPose(exercise: ExerciseType.squat);
const _pushUpFront = SyntheticPose(
  exercise: ExerciseType.pushUp,
  shoulderWidthRatio: 0.7,
);

PoseFrame _frame(SyntheticPose pose, int t) =>
    buildSyntheticFrame(pose, timestampMs: t);

/// [frame]의 [indices] 점을 [change]로 바꾼 새 프레임.
PoseFrame _modify(
  PoseFrame frame,
  Iterable<int> indices,
  PoseLandmark Function(PoseLandmark) change,
) {
  final targets = indices.toSet();
  return PoseFrame(
    timestampMs: frame.timestampMs,
    aspectRatio: frame.aspectRatio,
    landmarks: [
      for (var i = 0; i < frame.landmarks.length; i++)
        if (targets.contains(i)) change(frame[i]) else frame[i],
    ],
  );
}

/// 양쪽 발목을 화면 아래 밖(y 1.2)으로 옮긴다.
PoseFrame _anklesOffScreen(PoseFrame frame) => _modify(frame, [
  LandmarkIndex.leftAnkle,
  LandmarkIndex.rightAnkle,
], (p) => PoseLandmark(x: p.x, y: 1.2, z: p.z, visibility: p.visibility));

SetupGuideState _state(SetupGuideStatus status, String message, [int? n]) =>
    SetupGuideState(status: status, message: message, countdown: n);

/// fromMs부터 toMs까지 30fps로 [pose] 프레임을 넣고 (시각, 상태)를 모은다.
List<(int, SetupGuideState)> _feed(
  SetupGuideController c,
  SyntheticPose pose, {
  required int fromMs,
  required int toMs,
}) {
  final out = <(int, SetupGuideState)>[];
  for (var i = 0; fromMs + i * 1000 ~/ 30 <= toMs; i++) {
    final t = fromMs + i * 1000 ~/ 30;
    out.add((t, c.update(_frame(pose, t), t)));
  }
  return out;
}

void main() {
  group('운동별 문구 (F-07)', () {
    test('setupGuideTextsFor는 Spec 문구 그대로', () {
      final push = setupGuideTextsFor(ExerciseType.pushUp);
      final squat = setupGuideTextsFor(ExerciseType.squat);
      expect(push.distanceHint, _pushUpDistance);
      expect(push.postureHint, _pushUpPosture);
      expect(squat.distanceHint, _squatDistance);
      expect(squat.postureHint, _squatPosture);
    });

    test('발목이 화면 밖이면 notFullBody, 그 운동의 distanceHint', () {
      final push = SetupGuideController(exercise: ExerciseType.pushUp);
      final squat = SetupGuideController(exercise: ExerciseType.squat);
      expect(
        push.update(_anklesOffScreen(_frame(_pushUpReady, 0)), 0),
        _state(SetupGuideStatus.notFullBody, _pushUpDistance),
      );
      expect(
        squat.update(_anklesOffScreen(_frame(_squatReady, 0)), 0),
        _state(SetupGuideStatus.notFullBody, _squatDistance),
      );
    });
  });

  test('정면 안내 (F-07): shoulderWidthRatio 0.7이면 frontFacing', () {
    final push = SetupGuideController(exercise: ExerciseType.pushUp);
    final squat = SetupGuideController(exercise: ExerciseType.squat);
    expect(
      push.update(_frame(_pushUpFront, 0), 0),
      _state(SetupGuideStatus.frontFacing, _frontText),
    );
    const squatFront = SyntheticPose(
      exercise: ExerciseType.squat,
      shoulderWidthRatio: 0.7,
    );
    expect(
      squat.update(_frame(squatFront, 0), 0),
      _state(SetupGuideStatus.frontFacing, _frontText),
    );
  });

  test('서 있는 푸쉬업 (F-07): bodyTiltDeg 90이면 notInPosture', () {
    final c = SetupGuideController(exercise: ExerciseType.pushUp);
    const standing = SyntheticPose(
      exercise: ExerciseType.pushUp,
      bodyTiltDeg: 90,
    );
    expect(
      c.update(_frame(standing, 0), 0),
      _state(SetupGuideStatus.notInPosture, _pushUpPosture),
    );
  });

  test('스쿼트 게이트 (F-07): torsoLeanDeg 45는 notInPosture, 20은 holding', () {
    final c = SetupGuideController(exercise: ExerciseType.squat);
    const leaning = SyntheticPose(
      exercise: ExerciseType.squat,
      torsoLeanDeg: 45,
    );
    const upright = SyntheticPose(
      exercise: ExerciseType.squat,
      torsoLeanDeg: 20,
    );
    expect(
      c.update(_frame(leaning, 0), 0),
      _state(SetupGuideStatus.notInPosture, _squatPosture),
    );
    expect(
      c.update(_frame(upright, 33), 33),
      _state(SetupGuideStatus.holding, _holdText),
    );
  });

  group('기준 관절 160도', () {
    test('푸쉬업 팔꿈치 150이면 notInPosture, 165면 holding', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      const bent = SyntheticPose(exercise: ExerciseType.pushUp, elbowDeg: 150);
      const straight = SyntheticPose(
        exercise: ExerciseType.pushUp,
        elbowDeg: 165,
      );
      expect(
        c.update(_frame(bent, 0), 0).status,
        SetupGuideStatus.notInPosture,
      );
      expect(
        c.update(_frame(straight, 33), 33).status,
        SetupGuideStatus.holding,
      );
    });

    test('스쿼트 무릎 120이면 notInPosture', () {
      final c = SetupGuideController(exercise: ExerciseType.squat);
      const squatting = SyntheticPose(
        exercise: ExerciseType.squat,
        kneeDeg: 120,
      );
      expect(
        c.update(_frame(squatting, 0), 0),
        _state(SetupGuideStatus.notInPosture, _squatPosture),
      );
    });

    test('오른쪽이 보이는 프레임도 selectSide로 고른 쪽 각도를 쓴다', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      const rightBent = SyntheticPose(
        exercise: ExerciseType.pushUp,
        elbowDeg: 150,
        visibleSide: BodySide.right,
      );
      const rightStraight = SyntheticPose(
        exercise: ExerciseType.pushUp,
        visibleSide: BodySide.right,
      );
      expect(
        c.update(_frame(rightBent, 0), 0).status,
        SetupGuideStatus.notInPosture,
      );
      expect(
        c.update(_frame(rightStraight, 33), 33).status,
        SetupGuideStatus.holding,
      );
    });
  });

  test('준비 조건 2초 후 카운트다운 (F-07)', () {
    final c = SetupGuideController(exercise: ExerciseType.pushUp);
    final states = _feed(c, _pushUpReady, fromMs: 0, toMs: 2000);
    for (final (t, s) in states) {
      if (t < 2000) {
        expect(s, _state(SetupGuideStatus.holding, _holdText), reason: '$t');
      }
    }
    expect(states.last.$1, 2000);
    expect(states.last.$2, _state(SetupGuideStatus.countdown, '3', 3));
    expect(c.state, states.last.$2);
  });

  test('카운트다운 진행: 3→2→1, 5000ms 이후 ready "시작"', () {
    final c = SetupGuideController(exercise: ExerciseType.pushUp);
    final states = _feed(c, _pushUpReady, fromMs: 0, toMs: 5100);
    SetupGuideState at(int ms) => states.lastWhere((e) => e.$1 <= ms).$2;
    expect(at(2999), _state(SetupGuideStatus.countdown, '3', 3));
    expect(at(3000), _state(SetupGuideStatus.countdown, '2', 2));
    expect(at(3999), _state(SetupGuideStatus.countdown, '2', 2));
    expect(at(4000), _state(SetupGuideStatus.countdown, '1', 1));
    expect(at(4999), _state(SetupGuideStatus.countdown, '1', 1));
    expect(at(5000), _state(SetupGuideStatus.ready, _startText));
    expect(states.last.$2, _state(SetupGuideStatus.ready, _startText));
    final seen = states.map((e) => e.$2.countdown).whereType<int>().toSet();
    expect(seen, {3, 2, 1});
  });

  test('중간에 깨짐: 정면 프레임을 거치면 2초를 새로 잰다', () {
    final c = SetupGuideController(exercise: ExerciseType.pushUp);
    _feed(c, _pushUpReady, fromMs: 0, toMs: 1500);
    expect(
      c.update(_frame(_pushUpFront, 1533), 1533),
      _state(SetupGuideStatus.frontFacing, _frontText),
    );
    final again = _feed(c, _pushUpReady, fromMs: 1566, toMs: 3566);
    for (final (t, s) in again) {
      if (t < 3566) expect(s.status, SetupGuideStatus.holding, reason: '$t');
    }
    expect(again.last.$2, _state(SetupGuideStatus.countdown, '3', 3));
  });

  test('카운트다운 중 깨지면 그 상태로, 다시 holding부터', () {
    final c = SetupGuideController(exercise: ExerciseType.squat);
    _feed(c, _squatReady, fromMs: 0, toMs: 3500);
    expect(c.state.status, SetupGuideStatus.countdown);
    const leaning = SyntheticPose(
      exercise: ExerciseType.squat,
      torsoLeanDeg: 45,
    );
    expect(
      c.update(_frame(leaning, 3533), 3533),
      _state(SetupGuideStatus.notInPosture, _squatPosture),
    );
    expect(
      c.update(_frame(_squatReady, 3566), 3566),
      _state(SetupGuideStatus.holding, _holdText),
    );
  });

  group('사람 없음과 ready 유지', () {
    test('update(null, t)이면 noPerson', () {
      final c = SetupGuideController(exercise: ExerciseType.squat);
      expect(
        c.update(null, 0),
        _state(SetupGuideStatus.noPerson, _noPersonText),
      );
    });

    test('ready 후에는 null, 정면, 깨진 프레임이 와도 ready', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      _feed(c, _pushUpReady, fromMs: 0, toMs: 5000);
      final ready = _state(SetupGuideStatus.ready, _startText);
      expect(c.state, ready);
      expect(c.update(null, 5033), ready);
      expect(c.update(_frame(_pushUpFront, 5066), 5066), ready);
      expect(
        c.update(_anklesOffScreen(_frame(_pushUpReady, 5100)), 5100),
        ready,
      );
    });
  });

  group('노이즈 입력', () {
    test('holding 중 프레임이 끊기면(null) noPerson, 이후 2초를 새로 잰다', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      _feed(c, _pushUpReady, fromMs: 0, toMs: 1900);
      expect(c.update(null, 1933).status, SetupGuideStatus.noPerson);
      expect(
        c.update(_frame(_pushUpReady, 2000), 2000).status,
        SetupGuideStatus.holding,
      );
      _feed(c, _pushUpReady, fromMs: 2000, toMs: 3900);
      expect(
        c.update(_frame(_pushUpReady, 3999), 3999).status,
        SetupGuideStatus.holding,
      );
      expect(
        c.update(_frame(_pushUpReady, 4000), 4000).status,
        SetupGuideStatus.countdown,
      );
    });

    test('낮은 visibility면 notFullBody', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      final dim = _modify(
        _frame(_pushUpReady, 0),
        List.generate(LandmarkIndex.count, (i) => i),
        (p) => PoseLandmark(x: p.x, y: p.y, z: p.z, visibility: 0.3),
      );
      expect(
        c.update(dim, 0),
        _state(SetupGuideStatus.notFullBody, _pushUpDistance),
      );
    });

    test('정면이어도 visibility가 낮으면 notFullBody가 먼저', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      final dimFront = _modify(
        _frame(_pushUpFront, 0),
        List.generate(LandmarkIndex.count, (i) => i),
        (p) => PoseLandmark(x: p.x, y: p.y, z: p.z, visibility: 0.2),
      );
      expect(c.update(dimFront, 0).status, SetupGuideStatus.notFullBody);
    });

    test('NaN, Infinity 좌표면 notFullBody(예외 없음)', () {
      final c = SetupGuideController(exercise: ExerciseType.squat);
      final nan = _modify(
        _frame(_squatReady, 0),
        [LandmarkIndex.leftShoulder, LandmarkIndex.rightShoulder],
        (p) => PoseLandmark(
          x: double.nan,
          y: p.y,
          z: p.z,
          visibility: p.visibility,
        ),
      );
      final inf = _modify(
        _frame(_squatReady, 33),
        [LandmarkIndex.leftKnee, LandmarkIndex.rightKnee],
        (p) => PoseLandmark(
          x: p.x,
          y: double.infinity,
          z: p.z,
          visibility: p.visibility,
        ),
      );
      expect(c.update(nan, 0).status, SetupGuideStatus.notFullBody);
      expect(c.update(inf, 33).status, SetupGuideStatus.notFullBody);
    });

    test('모든 점이 한 곳에 모인 프레임이면 notFullBody', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      final collapsed = _modify(
        _frame(_pushUpReady, 0),
        List.generate(LandmarkIndex.count, (i) => i),
        (p) => const PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: 0.9),
      );
      expect(c.update(collapsed, 0).status, SetupGuideStatus.notFullBody);
    });

    test('시각이 뒤로 가면 그 시각부터 다시 잰다', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      _feed(c, _pushUpReady, fromMs: 1000, toMs: 2500);
      expect(
        c.update(_frame(_pushUpReady, 500), 500).status,
        SetupGuideStatus.holding,
      );
      _feed(c, _pushUpReady, fromMs: 500, toMs: 2400);
      expect(
        c.update(_frame(_pushUpReady, 2499), 2499).status,
        SetupGuideStatus.holding,
      );
      expect(
        c.update(_frame(_pushUpReady, 2500), 2500).status,
        SetupGuideStatus.countdown,
      );
    });
  });

  test('stableFor, countdownSec 주입', () {
    final c = SetupGuideController(
      exercise: ExerciseType.squat,
      stableFor: const Duration(seconds: 1),
      countdownSec: 2,
    );
    final states = _feed(c, _squatReady, fromMs: 0, toMs: 3000);
    SetupGuideState at(int ms) => states.lastWhere((e) => e.$1 <= ms).$2;
    expect(at(999).status, SetupGuideStatus.holding);
    expect(at(1000), _state(SetupGuideStatus.countdown, '2', 2));
    expect(at(2000), _state(SetupGuideStatus.countdown, '1', 1));
    expect(at(3000), _state(SetupGuideStatus.ready, _startText));
  });

  test('reset하면 ready에서도 처음 상태로 돌아가 다시 잰다', () {
    final c = SetupGuideController(exercise: ExerciseType.pushUp);
    expect(c.state, _state(SetupGuideStatus.noPerson, _noPersonText));
    _feed(c, _pushUpReady, fromMs: 0, toMs: 5000);
    expect(c.state.status, SetupGuideStatus.ready);
    c.reset();
    expect(c.state, _state(SetupGuideStatus.noPerson, _noPersonText));
    expect(
      c.update(_frame(_pushUpReady, 6000), 6000).status,
      SetupGuideStatus.holding,
    );
    expect(
      c.update(_frame(_pushUpReady, 7999), 7999).status,
      SetupGuideStatus.holding,
    );
  });

  test('SetupGuideState는 값으로 비교한다', () {
    expect(
      _state(SetupGuideStatus.countdown, '3', 3),
      _state(SetupGuideStatus.countdown, '3', 3),
    );
    expect(
      _state(SetupGuideStatus.countdown, '3', 3).hashCode,
      _state(SetupGuideStatus.countdown, '3', 3).hashCode,
    );
    expect(
      _state(SetupGuideStatus.countdown, '3', 3),
      isNot(_state(SetupGuideStatus.countdown, '2', 2)),
    );
    expect(
      _state(SetupGuideStatus.holding, _holdText),
      isNot(_state(SetupGuideStatus.notInPosture, _holdText)),
    );
  });

  group('프레임 간격 상한 (QA FIX)', () {
    test('holding 중 10초 공백 뒤 첫 프레임은 holding, 그 시각부터 다시 잰다', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp)
        ..update(_frame(_pushUpReady, 0), 0)
        ..update(_frame(_pushUpReady, 1000), 1000);
      final s = c.update(_frame(_pushUpReady, 11000), 11000);
      expect(s, _state(SetupGuideStatus.holding, _holdText));
      _feed(c, _pushUpReady, fromMs: 11000, toMs: 12900);
      expect(
        c.update(_frame(_pushUpReady, 13000), 13000).status,
        SetupGuideStatus.countdown,
      );
    });

    test('countdown 중 600ms 공백 뒤 첫 프레임은 holding', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp);
      _feed(c, _pushUpReady, fromMs: 0, toMs: 2400);
      expect(c.state.status, SetupGuideStatus.countdown);
      final s = c.update(_frame(_pushUpReady, 3000), 3000);
      expect(s, _state(SetupGuideStatus.holding, _holdText));
    });

    test('정확히 500ms 간격은 이어서 잰다', () {
      final c = SetupGuideController(exercise: ExerciseType.pushUp)
        ..update(_frame(_pushUpReady, 0), 0)
        ..update(_frame(_pushUpReady, 500), 500)
        ..update(_frame(_pushUpReady, 1000), 1000)
        ..update(_frame(_pushUpReady, 1500), 1500);
      expect(
        c.update(_frame(_pushUpReady, 2000), 2000),
        _state(SetupGuideStatus.countdown, '3', 3),
      );
    });

    test('maxFrameGap을 주입할 수 있고 reset은 직전 시각을 비운다', () {
      final c = SetupGuideController(
        exercise: ExerciseType.pushUp,
        maxFrameGap: const Duration(seconds: 5),
      )..update(_frame(_pushUpReady, 0), 0);
      expect(
        c.update(_frame(_pushUpReady, 3000), 3000).status,
        SetupGuideStatus.countdown,
      );
      final d = SetupGuideController(exercise: ExerciseType.pushUp)
        ..update(_frame(_pushUpReady, 0), 0)
        ..reset()
        ..update(_frame(_pushUpReady, 10000), 10000);
      expect(
        d.update(_frame(_pushUpReady, 10400), 10400).status,
        SetupGuideStatus.holding,
      );
    });
  });
}
