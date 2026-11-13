// [파일] 자세 오류 판정(judgeRep, PoseErrorCode) 테스트.
// [Spec] F-04 / [Task] TASK-09
// [의존] test/support/synthetic_clip.dart

import 'package:atheleo/pose/judge/error_judge.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:atheleo/pose/rep/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_clip.dart';

const _fps = 10;

RepEvent _rep(int frames, double minAngle) => RepEvent(
  repIndex: 1,
  startMs: 0,
  bottomMs: (frames ~/ 2) * 1000 ~/ _fps,
  endMs: (frames - 1) * 1000 ~/ _fps,
  minAngle: minAngle,
);

List<PoseFrame> _frames(int n, SyntheticPose Function(int i) poseFor) => [
  for (var i = 0; i < n; i++)
    buildSyntheticFrame(poseFor(i), timestampMs: i * 1000 ~/ _fps),
];

/// 좌우 반전(x -> 1-x): 몸이 화면 왼쪽을 보는 경우.
PoseFrame _mirror(PoseFrame f) => PoseFrame(
  timestampMs: f.timestampMs,
  aspectRatio: f.aspectRatio,
  landmarks: [
    for (final p in f.landmarks)
      PoseLandmark(x: 1 - p.x, y: p.y, z: p.z, visibility: p.visibility),
  ],
);

/// 랜드마크가 모두 끊긴 프레임(좌표 0, visibility 0).
PoseFrame _dropped(PoseFrame f) => PoseFrame(
  timestampMs: f.timestampMs,
  aspectRatio: f.aspectRatio,
  landmarks: List.filled(
    LandmarkIndex.count,
    const PoseLandmark(x: 0, y: 0, z: 0, visibility: 0),
  ),
);

/// 뒤꿈치(29, 30)만 y를 [dy]만큼 옮기고 visibility를 [vis]로 바꾼다.
PoseFrame _heelNoise(PoseFrame f, {required double dy, required double vis}) {
  final landmarks = [...f.landmarks];
  for (final i in [LandmarkIndex.leftHeel, LandmarkIndex.rightHeel]) {
    final p = landmarks[i];
    landmarks[i] = PoseLandmark(x: p.x, y: p.y + dy, z: p.z, visibility: vis);
  }
  return PoseFrame(
    timestampMs: f.timestampMs,
    aspectRatio: f.aspectRatio,
    landmarks: landmarks,
  );
}

List<PoseFrame> _pushUp(double line, HipOffset offset) => _frames(
  10,
  (_) => SyntheticPose(
    exercise: ExerciseType.pushUp,
    bodyLineDeg: line,
    hipOffset: offset,
  ),
);

List<PoseErrorCode> _judgePushUp(List<PoseFrame> f, double minAngle) =>
    judgeRep(
      exercise: ExerciseType.pushUp,
      repFrames: f,
      rep: _rep(f.length, minAngle),
    );

void main() {
  group('푸쉬업', () {
    test('허리 처짐 (F-04)', () {
      final r = _judgePushUp(_pushUp(140, HipOffset.below), 80);
      expect(r, [PoseErrorCode.puHipSag]);
      expect(r, isNot(contains(PoseErrorCode.puHipPike)));
    });

    test('엉덩이 들림 (F-04)', () {
      final r = _judgePushUp(_pushUp(140, HipOffset.above), 80);
      expect(r, [PoseErrorCode.puHipPike]);
      expect(r, isNot(contains(PoseErrorCode.puHipSag)));
    });

    test('몸이 화면 왼쪽을 봐도 처짐/들림이 바뀌지 않는다', () {
      final sag = _pushUp(140, HipOffset.below).map(_mirror).toList();
      final pike = _pushUp(140, HipOffset.above).map(_mirror).toList();
      expect(_judgePushUp(sag, 80), [PoseErrorCode.puHipSag]);
      expect(_judgePushUp(pike, 80), [PoseErrorCode.puHipPike]);
    });

    test('오른쪽 몸이 보여도 판정된다', () {
      final f = _frames(
        10,
        (_) => const SyntheticPose(
          exercise: ExerciseType.pushUp,
          bodyLineDeg: 140,
          visibleSide: BodySide.right,
        ),
      );
      expect(_judgePushUp(f, 80), [PoseErrorCode.puHipSag]);
    });

    test('깊이 부족 (F-04)', () {
      final f = _pushUp(178, HipOffset.below);
      expect(_judgePushUp(f, 105), [PoseErrorCode.puShallow]);
      expect(_judgePushUp(f, 90), isEmpty);
      expect(_judgePushUp(f, 90.1), [PoseErrorCode.puShallow]);
    });

    test('정상 푸쉬업', () {
      expect(_judgePushUp(_pushUp(178, HipOffset.below), 85), isEmpty);
    });

    test('깊이 부족과 처짐이 함께 나오면 enum 순서대로', () {
      expect(_judgePushUp(_pushUp(140, HipOffset.below), 105), [
        PoseErrorCode.puShallow,
        PoseErrorCode.puHipSag,
      ]);
    });

    test('각도 160 이상이면 오프셋이 있어도 오류 없음', () {
      expect(_judgePushUp(_pushUp(165, HipOffset.below), 85), isEmpty);
    });

    test('판정 가능한 프레임이 없으면 몸 자세 오류는 없다', () {
      final f = [
        PoseFrame(
          timestampMs: 0,
          landmarks: List.filled(
            LandmarkIndex.count,
            const PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: 0),
          ),
        ),
      ];
      expect(_judgePushUp(f, 85), isEmpty);
    });

    test('기준값 주입', () {
      final f = _pushUp(140, HipOffset.below);
      final r = judgeRep(
        exercise: ExerciseType.pushUp,
        repFrames: f,
        rep: _rep(f.length, 100),
        thresholds: const ErrorThresholds(depthDeg: 110, bodyLineDeg: 130),
      );
      expect(r, isEmpty);
    });
  });

  group('스쿼트', () {
    test('상체 숙임', () {
      final f = _frames(
        11,
        (i) => SyntheticPose(
          exercise: ExerciseType.squat,
          kneeDeg: 80,
          torsoLeanDeg: (i >= 4 && i <= 6) ? 60 : 20,
        ),
      );
      final r = judgeRep(
        exercise: ExerciseType.squat,
        repFrames: f,
        rep: _rep(f.length, 80),
      );
      expect(r, [PoseErrorCode.sqTorsoLean]);
    });

    test('상체 기울기는 최저점 주변 3프레임 중앙값으로 본다', () {
      final f = _frames(
        11,
        (i) => SyntheticPose(
          exercise: ExerciseType.squat,
          kneeDeg: 80,
          torsoLeanDeg: i == 2 ? 60 : 20,
        ),
      );
      expect(
        judgeRep(
          exercise: ExerciseType.squat,
          repFrames: f,
          rep: _rep(f.length, 80),
        ),
        isEmpty,
      );
    });

    test('스쿼트 깊이 부족', () {
      final f = _frames(
        11,
        (_) => const SyntheticPose(exercise: ExerciseType.squat, kneeDeg: 100),
      );
      expect(
        judgeRep(
          exercise: ExerciseType.squat,
          repFrames: f,
          rep: _rep(f.length, 100),
        ),
        [PoseErrorCode.sqShallow],
      );
    });

    List<PoseErrorCode> heel(double ratio) {
      final f = _frames(
        11,
        (i) => SyntheticPose(
          exercise: ExerciseType.squat,
          kneeDeg: 80,
          heelLiftRatio: (i >= 4 && i <= 6) ? ratio : 0,
        ),
      );
      return judgeRep(
        exercise: ExerciseType.squat,
        repFrames: f,
        rep: _rep(f.length, 80),
      );
    }

    test('뒤꿈치 들림', () {
      expect(heel(0.2), contains(PoseErrorCode.sqHeelLift));
      expect(heel(0.05), isNot(contains(PoseErrorCode.sqHeelLift)));
    });

    test('운동별 코드 분리: 스쿼트 프레임에 bodyLineDeg 140', () {
      final f = _frames(
        11,
        (_) => const SyntheticPose(
          exercise: ExerciseType.squat,
          kneeDeg: 80,
          bodyLineDeg: 140,
        ),
      );
      final r = judgeRep(
        exercise: ExerciseType.squat,
        repFrames: f,
        rep: _rep(f.length, 80),
      );
      expect(r, isNot(contains(PoseErrorCode.puHipSag)));
      expect(r, isNot(contains(PoseErrorCode.puHipPike)));
      expect(r, isNot(contains(PoseErrorCode.puShallow)));
    });

    test('빈 프레임 목록은 깊이만 본다', () {
      expect(
        judgeRep(
          exercise: ExerciseType.squat,
          repFrames: const [],
          rep: _rep(10, 100),
        ),
        [PoseErrorCode.sqShallow],
      );
    });
  });

  group('끊긴 프레임과 노이즈 (QA FIX)', () {
    List<PoseFrame> squat({
      double Function(int i)? heel,
      double Function(int i)? lean,
    }) => _frames(
      11,
      (i) => SyntheticPose(
        exercise: ExerciseType.squat,
        kneeDeg: 80,
        heelLiftRatio: heel?.call(i) ?? 0,
        torsoLeanDeg: lean?.call(i) ?? 20,
      ),
    );

    List<PoseErrorCode> judgeSquat(List<PoseFrame> f) => judgeRep(
      exercise: ExerciseType.squat,
      repFrames: f,
      rep: _rep(f.length, 80),
    );

    test('(a) 랜드마크가 모두 끊긴 프레임이 섞여도 뒤꿈치 오탐 없음', () {
      final f = squat();
      f[7] = _dropped(f[7]);
      expect(judgeSquat(f), isNot(contains(PoseErrorCode.sqHeelLift)));
    });

    test('(b) 뒤꿈치만 visibility 0.1로 한 프레임 튀어도 오탐 없음', () {
      final f = squat();
      f[6] = _heelNoise(f[6], dy: -0.2, vis: 0.1);
      expect(judgeSquat(f), isNot(contains(PoseErrorCode.sqHeelLift)));
    });

    test('(b2) 뒤꿈치 visibility가 낮은 프레임이 연속이어도 건너뛴다', () {
      final f = squat();
      for (var i = 4; i <= 7; i++) {
        f[i] = _heelNoise(f[i], dy: -0.2, vis: 0.1);
      }
      expect(judgeSquat(f), isNot(contains(PoseErrorCode.sqHeelLift)));
    });

    test('(c) 한 프레임만 뒤꿈치 y가 튀면 오탐 없음, 3프레임 들리면 잡힘', () {
      expect(
        judgeSquat(squat(heel: (i) => i == 5 ? 0.3 : 0)),
        isNot(contains(PoseErrorCode.sqHeelLift)),
      );
      expect(
        judgeSquat(squat(heel: (i) => (i >= 4 && i <= 6) ? 0.3 : 0)),
        contains(PoseErrorCode.sqHeelLift),
      );
    });

    test('(d) 최저점 프레임만 끊겨도 상체 숙임을 잡는다', () {
      final f = squat(lean: (_) => 60);
      f[5] = _dropped(f[5]);
      expect(judgeSquat(f), [PoseErrorCode.sqTorsoLean]);
    });

    test('(e) 처짐/들림 프레임 수가 같으면 오류 없음', () {
      final f = [
        ..._pushUp(140, HipOffset.below).take(5),
        ..._pushUp(140, HipOffset.above).take(5),
      ];
      expect(_judgePushUp(f, 80), isEmpty);
    });

    test('(f) 시작 프레임이 끊겨 있으면 고를 수 있는 첫 프레임이 기준', () {
      final none = squat();
      none[0] = _dropped(none[0]);
      expect(judgeSquat(none), isNot(contains(PoseErrorCode.sqHeelLift)));

      final lifted = squat(heel: (i) => i >= 3 && i <= 5 ? 0.3 : 0);
      lifted[0] = _dropped(lifted[0]);
      lifted[1] = _dropped(lifted[1]);
      expect(judgeSquat(lifted), contains(PoseErrorCode.sqHeelLift));
    });

    test('(g) 첫 프레임 뒤꿈치만 visibility 0.1로 아래로 튀어도 오탐 없음', () {
      final f = squat();
      f[0] = _heelNoise(f[0], dy: 0.2, vis: 0.1);
      expect(judgeSquat(f), isNot(contains(PoseErrorCode.sqHeelLift)));
    });

    test('(h) 첫 프레임 뒤꿈치 좌표가 NaN이어도 3프레임 들림은 검출', () {
      final f = squat(heel: (i) => i >= 3 && i <= 5 ? 0.3 : 0);
      f[0] = _heelNoise(f[0], dy: double.nan, vis: 1);
      expect(judgeSquat(f), contains(PoseErrorCode.sqHeelLift));
    });
  });

  group('PoseErrorCode', () {
    test('코드 문자열', () {
      final c = PoseErrorCode.fromCode('SQ_HEEL_LIFT');
      expect(c, PoseErrorCode.sqHeelLift);
      expect(c.voiceMessage, '뒤꿈치를 바닥에 붙이세요.');
      expect(c.label, '뒤꿈치 들림');
    });

    test('모든 코드가 fromCode로 되돌아온다', () {
      for (final c in PoseErrorCode.values) {
        expect(PoseErrorCode.fromCode(c.code), c);
      }
      expect(PoseErrorCode.puHipSag.code, 'PU_HIP_SAG');
      expect(PoseErrorCode.puShallow.voiceMessage, '조금 더 내려가세요.');
    });

    test('모르는 값은 ArgumentError', () {
      expect(() => PoseErrorCode.fromCode('NOPE'), throwsArgumentError);
    });
  });
}
