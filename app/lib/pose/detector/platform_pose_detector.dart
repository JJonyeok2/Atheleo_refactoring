// [파일] MethodChannel `atheleo/pose`, EventChannel `atheleo/pose/results`로
//   Kotlin 감지기와 통신하는 PoseDetector 구현. 호출 직렬화, 이벤트 파싱/검증.
// [Spec] F-01, F-07, F-08 / [Task] TASK-19
// [의존] 네이티브 채널(TASK-20, 21). 환경 변수 사용 안 함

import 'dart:async';

import 'package:atheleo/pose/detector/pose_detector.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter/services.dart';

/// 네이티브(Kotlin) 감지기와 `atheleo/pose` 채널로 통신하는 [PoseDetector].
///
/// start, stop, setModel은 호출 순서대로 하나씩 처리한다.
class PlatformPoseDetector implements PoseDetector {
  /// 채널은 테스트에서만 바꾼다.
  new({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _method = methodChannel ?? const MethodChannel('atheleo/pose'),
      _events = eventChannel ?? const EventChannel('atheleo/pose/results');

  final MethodChannel _method;
  final EventChannel _events;

  /// 앞선 호출이 끝난 뒤 다음 호출을 시작하기 위한 꼬리.
  Future<void> _tail = Future.value();
  PoseCameraInfo? _camera;
  PoseModel? _model;

  @override
  late final Stream<PoseDetectionResult> results = _events
      .receiveBroadcastStream()
      .transform(
        StreamTransformer<Object?, PoseDetectionResult>.fromHandlers(
          handleData: _handleEvent,
        ),
      );

  @override
  bool get isRunning => _camera != null;

  @override
  Future<PoseCameraInfo> start({PoseModel model = PoseModel.full}) =>
      _serial(() async {
        final running = _camera;
        if (running != null) {
          if (model != _model) await _sendModel(model);
          return running;
        }
        final reply = await _method.invokeMethod<Object?>('start', {
          'model': model.name,
        });
        final PoseCameraInfo camera;
        try {
          camera = _parseCamera(reply);
        } on FormatException {
          await _stopQuietly();
          rethrow;
        }
        _model = model;
        return _camera = camera;
      });

  @override
  Future<void> stop() => _serial(() async {
    try {
      await _method.invokeMethod<void>('stop');
    } finally {
      _camera = null;
    }
  });

  @override
  Future<void> setModel(PoseModel model) => _serial(() => _sendModel(model));

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> _sendModel(PoseModel model) async {
    await _method.invokeMethod<void>('setModel', {'model': model.name});
    _model = model;
  }

  /// 응답이 잘못돼 쓸 수 없는 카메라를 닫는다. 실패해도 원래 오류를 우선한다.
  Future<void> _stopQuietly() async {
    try {
      await _method.invokeMethod<void>('stop');
    } on Exception {
      // 형식 오류를 그대로 알리는 것이 우선이라 정리 실패는 무시한다.
    }
  }

  static PoseCameraInfo _parseCamera(Object? reply) {
    if (reply is! Map) {
      throw FormatException('start 응답이 Map이 아님', reply);
    }
    final camera = PoseCameraInfo(
      textureId: _int(reply, 'textureId'),
      width: _int(reply, 'width'),
      height: _int(reply, 'height'),
    );
    if (camera.width <= 0 || camera.height <= 0) {
      throw FormatException('start 응답의 프레임 크기가 0 이하', reply);
    }
    return camera;
  }

  static void _handleEvent(Object? event, EventSink<PoseDetectionResult> sink) {
    try {
      final result = _parseEvent(event);
      if (result != null) sink.add(result);
    } on FormatException catch (e) {
      sink.addError(e);
    }
  }

  /// 형식이 틀리면 [FormatException]. 0 이하 크기나 모든 사람이 비유한 좌표면 null(버림).
  static PoseDetectionResult? _parseEvent(Object? event) {
    if (event is! Map) throw FormatException('이벤트가 Map이 아님', event);
    final t = _int(event, 't');
    final inferenceMs = _int(event, 'inferenceMs');
    final width = _int(event, 'width');
    final height = _int(event, 'height');
    final poses = event['poses'];
    if (poses is! List) throw FormatException('poses가 목록이 아님', event);

    final people = [for (final person in poses) _parsePerson(person)];
    if (width <= 0 || height <= 0) return null;
    // 비유한 좌표가 있는 사람만 버린다. 원래 있던 사람이 모두 빠지면 이벤트를 버린다.
    final valid = [
      for (final p in people)
        if (p.every(_isFinite)) p,
    ];
    if (people.isNotEmpty && valid.isEmpty) return null;

    final aspectRatio = width / height;
    return PoseDetectionResult(
      timestampMs: t,
      inferenceMs: inferenceMs,
      poses: List.unmodifiable([
        for (final landmarks in valid)
          PoseFrame(
            timestampMs: t,
            landmarks: landmarks,
            aspectRatio: aspectRatio,
          ),
      ]),
    );
  }

  static List<PoseLandmark> _parsePerson(Object? person) {
    if (person is! List || person.length != LandmarkIndex.count) {
      throw FormatException('사람마다 점이 ${LandmarkIndex.count}개여야 함', person);
    }
    return [for (final point in person) _parsePoint(point)];
  }

  static PoseLandmark _parsePoint(Object? point) {
    if (point is! List || point.length != 4 || point.any((v) => v is! num)) {
      throw FormatException('점은 숫자 4개 [x, y, z, v]여야 함', point);
    }
    final [x, y, z, v] = [for (final n in point.cast<num>()) n.toDouble()];
    return PoseLandmark(x: x, y: y, z: z, visibility: v);
  }

  static bool _isFinite(PoseLandmark l) =>
      l.x.isFinite && l.y.isFinite && l.z.isFinite && l.visibility.isFinite;

  static int _int(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException('$key가 정수가 아님', map);
    return value;
  }
}

// [QA] 2026-11-13 PASS
// [보안] 응답, 이벤트의 타입, 점 개수를 검사하고 형식 오류는 FormatException.
//   NaN/Infinity 좌표는 해당 사람만 버리고(모두 빠지면 이벤트 버림), 0 이하
//   크기는 이벤트 전체를 조용히 버린다. poses는 수정 불가 목록.
// [유지보수] 정수 필드(t, inferenceMs, width, height, textureId)는 int만 받는다.
//   Kotlin이 Double을 보내면 모든 이벤트가 오류가 되므로 TASK-20, 21에서 타입 고정.
// [변경 반영] 2026-11-13 NaN 사람 단위 버림, poses unmodifiable (TASK-19 재작업)
