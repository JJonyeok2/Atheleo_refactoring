import 'dart:convert';
import 'dart:io';

import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/landmark_clip.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturePath = 'test/fixtures/clips/minimal_clip.json';

Map<String, dynamic> _validJson({int points = 33}) => <String, dynamic>{
  'id': 'clip-1',
  'exercise': 'squat',
  'label': 'test',
  'fps': 30,
  'frames': [
    {
      't': 0,
      'lm': List.generate(points, (i) => [0.1 * (i % 10), 0.5, 0.0, 1.0]),
    },
  ],
};

PoseLandmark _point() =>
    const PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: 1);

void main() {
  group('LandmarkClip', () {
    test('픽스처 읽기: frames 2개, 각 33개 점, exercise pushUp', () {
      final clip = LandmarkClip.parse(File(_fixturePath).readAsStringSync());

      expect(clip.frames, hasLength(2));
      for (final frame in clip.frames) {
        expect(frame.landmarks, hasLength(LandmarkIndex.count));
      }
      expect(clip.exercise, ExerciseType.pushUp);
      expect(clip.frames.first.aspectRatio, 0.5625);
      expect(clip.frames[1].timestampMs, 33);
    });

    test('왕복 직렬화: id, label, fps, 첫 프레임 좌표가 같음', () {
      final clip = LandmarkClip.parse(File(_fixturePath).readAsStringSync());
      final again = LandmarkClip.parse(clip.encode());

      expect(again.id, clip.id);
      expect(again.label, clip.label);
      expect(again.fps, clip.fps);
      expect(again.exercise, clip.exercise);
      expect(again.frames, hasLength(clip.frames.length));
      expect(again.frames.first.aspectRatio, clip.frames.first.aspectRatio);
      for (var i = 0; i < LandmarkIndex.count; i++) {
        final a = clip.frames.first[i];
        final b = again.frames.first[i];
        expect(b.x, a.x);
        expect(b.y, a.y);
        expect(b.z, a.z);
        expect(b.visibility, a.visibility);
      }
    });

    test('점 개수 오류: lm 길이 32면 FormatException', () {
      expect(
        () => LandmarkClip.fromJson(_validJson(points: 32)),
        throwsFormatException,
      );
    });

    test('모르는 운동: exercise lunge면 FormatException', () {
      final json = _validJson()..['exercise'] = 'lunge';
      expect(() => LandmarkClip.parse(jsonEncode(json)), throwsFormatException);
    });

    test('aspect 기본값: aspect 없으면 모든 프레임 aspectRatio 1.0', () {
      final clip = LandmarkClip.fromJson(_validJson());
      expect(clip.frames, isNotEmpty);
      for (final frame in clip.frames) {
        expect(frame.aspectRatio, 1.0);
      }
    });

    test('형식 오류: JSON이 아니거나 필드 타입이 틀리면 FormatException', () {
      expect(() => LandmarkClip.parse('not json'), throwsFormatException);
      expect(() => LandmarkClip.parse('[]'), throwsFormatException);
      final badFps = _validJson()..['fps'] = 'thirty';
      expect(() => LandmarkClip.fromJson(badFps), throwsFormatException);
    });
  });

  group('PoseFrame', () {
    test('landmarks 10개로 생성하면 ArgumentError', () {
      expect(
        () => PoseFrame(
          timestampMs: 0,
          landmarks: List.generate(10, (_) => _point()),
        ),
        throwsArgumentError,
      );
    });

    test('33개면 생성되고 인덱스로 접근, aspectRatio 기본 1.0', () {
      final frame = PoseFrame(
        timestampMs: 5,
        landmarks: List.generate(LandmarkIndex.count, (_) => _point()),
      );
      expect(frame[LandmarkIndex.rightHeel].x, 0.5);
      expect(frame.aspectRatio, 1.0);
    });
  });

  group('LandmarkIndex', () {
    test('MediaPipe 인덱스 값', () {
      expect(LandmarkIndex.nose, 0);
      expect(LandmarkIndex.leftShoulder, 11);
      expect(LandmarkIndex.rightShoulder, 12);
      expect(LandmarkIndex.leftElbow, 13);
      expect(LandmarkIndex.rightElbow, 14);
      expect(LandmarkIndex.leftWrist, 15);
      expect(LandmarkIndex.rightWrist, 16);
      expect(LandmarkIndex.leftHip, 23);
      expect(LandmarkIndex.rightHip, 24);
      expect(LandmarkIndex.leftKnee, 25);
      expect(LandmarkIndex.rightKnee, 26);
      expect(LandmarkIndex.leftAnkle, 27);
      expect(LandmarkIndex.rightAnkle, 28);
      expect(LandmarkIndex.leftHeel, 29);
      expect(LandmarkIndex.rightHeel, 30);
      expect(LandmarkIndex.leftFootIndex, 31);
      expect(LandmarkIndex.rightFootIndex, 32);
      expect(LandmarkIndex.count, 33);
      expect(BodySide.values, [BodySide.left, BodySide.right]);
    });
  });

  group('ExerciseType', () {
    test('fromCode와 label', () {
      expect(ExerciseType.fromCode('squat'), ExerciseType.squat);
      expect(ExerciseType.fromCode('push_up'), ExerciseType.pushUp);
      expect(ExerciseType.pushUp.label, '푸쉬업');
      expect(ExerciseType.squat.label, '스쿼트');
      expect(ExerciseType.pushUp.code, 'push_up');
      expect(() => ExerciseType.fromCode('lunge'), throwsArgumentError);
    });
  });
}
