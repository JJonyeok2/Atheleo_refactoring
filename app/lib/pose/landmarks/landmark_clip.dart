// [파일] 녹화 랜드마크 클립과 JSON 직렬화/역직렬화
//   (로컬 전용, 서버로 보내지 않음).
// [Spec] 7장 LandmarkClip, 8장 테스트 가능성 / [Task] TASK-04
// [의존] 없음 (환경 변수 사용 안 함)

import 'dart:convert';

import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';

/// 녹화된 랜드마크 클립(로컬 전용, 서버로 보내지 않음).
///
/// JSON 형식:
/// `{"id", "exercise": "push_up"|"squat", "label", "fps",
///   "aspect"(생략 시 1.0), "frames": [{"t": ms, "lm": [[x, y, z, v] x 33]}]}`
class LandmarkClip {
  /// 클립을 만든다.
  const new({
    required this.id,
    required this.exercise,
    required this.label,
    required this.fps,
    required this.frames,
  });

  /// JSON 맵에서 읽는다. 형식이 틀리면 [FormatException].
  factory fromJson(Map<String, dynamic> json) {
    final exerciseCode = _field<String>(json, 'exercise');
    final known = ExerciseType.values.map((type) => type.code);
    if (!known.contains(exerciseCode)) {
      throw FormatException('알 수 없는 운동: $exerciseCode');
    }
    final exercise = ExerciseType.fromCode(exerciseCode);
    final aspect = _optionalNum(json, 'aspect')?.toDouble() ?? 1.0;
    final rawFrames = _field<List<dynamic>>(json, 'frames');
    return LandmarkClip(
      id: _field<String>(json, 'id'),
      exercise: exercise,
      label: _field<String>(json, 'label'),
      fps: _field<int>(json, 'fps'),
      frames: [for (final f in rawFrames) _frameFromJson(f, aspect)],
    );
  }

  /// JSON 문자열에서 읽는다. 형식이 틀리면 [FormatException].
  // 계약상 static 메서드로 둔다(TASK-04 내보내는 것).
  // ignore: prefer_constructors_over_static_methods
  static LandmarkClip parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('클립 JSON 최상위는 객체여야 함');
    }
    return LandmarkClip.fromJson(decoded);
  }

  /// 클립 id(uuid).
  final String id;

  /// 운동 종류.
  final ExerciseType exercise;

  /// 사람이 붙인 이름.
  final String label;

  /// 초당 프레임 수.
  final int fps;

  /// 프레임 목록.
  final List<PoseFrame> frames;

  /// JSON 맵으로 바꾼다. aspect는 첫 프레임 값을 쓴다(없으면 1.0).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'exercise': exercise.code,
    'label': label,
    'fps': fps,
    'aspect': frames.isEmpty ? 1.0 : frames.first.aspectRatio,
    'frames': [
      for (final frame in frames)
        <String, dynamic>{
          't': frame.timestampMs,
          'lm': [
            for (final p in frame.landmarks) [p.x, p.y, p.z, p.visibility],
          ],
        },
    ],
  };

  /// JSON 문자열로 바꾼다.
  String encode() => jsonEncode(toJson());

  static PoseFrame _frameFromJson(Object? raw, double aspect) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('frame은 객체여야 함');
    }
    final points = _field<List<dynamic>>(raw, 'lm');
    if (points.length != LandmarkIndex.count) {
      throw FormatException(
        'lm은 ${LandmarkIndex.count}개여야 함 (현재 ${points.length}개)',
      );
    }
    return PoseFrame(
      timestampMs: _field<int>(raw, 't'),
      landmarks: [for (final p in points) _landmarkFromJson(p)],
      aspectRatio: aspect,
    );
  }

  static PoseLandmark _landmarkFromJson(Object? raw) {
    if (raw is! List<dynamic> ||
        raw.length != 4 ||
        raw.any((value) => value is! num)) {
      throw const FormatException('랜드마크는 숫자 4개 [x, y, z, v]여야 함');
    }
    final v = raw.cast<num>();
    return PoseLandmark(
      x: v[0].toDouble(),
      y: v[1].toDouble(),
      z: v[2].toDouble(),
      visibility: v[3].toDouble(),
    );
  }

  static T _field<T>(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! T) {
      throw FormatException('필드 "$key" 형식이 틀림: $value');
    }
    return value;
  }

  static num? _optionalNum(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num) {
      throw FormatException('필드 "$key"는 숫자여야 함: $value');
    }
    return value;
  }
}

// [QA] 2026-11-09 PASS
// [보안] 형식 오류는 FormatException. 값 범위는 보지 않음: 1e400(Infinity),
//   fps 0 이하, aspect 0 이하가 통과하고, Infinity가 든 클립은 encode에서
//   JsonUnsupportedObjectError. 입력 크기 제한 없음(로컬 개발자 파일 전제).
// [유지보수] fps, t는 int만 허용(30.0 거부). Dart encode는 정수를 30으로
//   쓰므로 자체 왕복은 안전. aspect는 클립 최상위 하나뿐이라 프레임별 값이
//   다르면 toJson에서 첫 프레임 값으로 통일됨(세로 고정 전제).
