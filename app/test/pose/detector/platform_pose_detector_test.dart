// 자세 추정 채널 계약(Dart 쪽)과 가짜 감지기 테스트 (TASK-19).
import 'dart:async';

import 'package:atheleo/pose/detector/platform_pose_detector.dart';
import 'package:atheleo/pose/detector/pose_detector.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_pose_detector.dart';

const _method = MethodChannel('atheleo/pose');
const _event = EventChannel('atheleo/pose/results');

const _camera = <String, Object?>{'textureId': 7, 'width': 720, 'height': 1280};

/// i번 점이 (i/100, i/200, -i/10, 0.9)인 33점 한 명.
List<List<Object?>> _pose({int count = LandmarkIndex.count}) => [
  for (var i = 0; i < count; i++) [i / 100, i / 200, -i / 10, 0.9],
];

Map<String, Object?> _eventOf({
  List<List<List<Object?>>>? poses,
  Object? width = 720,
  Object? height = 1280,
  int t = 1000,
}) => {
  't': t,
  'inferenceMs': 12,
  'width': width,
  'height': height,
  'poses': poses ?? [_pose()],
};

TestDefaultBinaryMessengerBinding get _binding =>
    TestDefaultBinaryMessengerBinding.instance;

/// `atheleo/pose` 가짜 응답을 건다. 받은 호출은 [log]에 쌓인다.
void _mockMethod(
  List<MethodCall> log, {
  Future<Object?> Function(MethodCall call)? onCall,
}) {
  _binding.defaultBinaryMessenger.setMockMethodCallHandler(_method, (
    call,
  ) async {
    log.add(call);
    if (onCall != null) return await onCall(call);
    return call.method == 'start' ? _camera : null;
  });
}

/// 결과 스트림을 끝까지 모은다. [emit]은 가짜 플랫폼 쪽에서 이벤트를 보낸다.
Future<({List<PoseDetectionResult> data, List<Object> errors})> _collect(
  PoseDetector detector,
  void Function(MockStreamHandlerEventSink sink) emit,
) async {
  _binding.defaultBinaryMessenger.setMockStreamHandler(
    _event,
    MockStreamHandler.inline(
      onListen: (_, sink) {
        emit(sink);
        sink.endOfStream();
      },
    ),
  );
  final data = <PoseDetectionResult>[];
  final errors = <Object>[];
  final done = Completer<void>();
  detector.results.listen(data.add, onError: errors.add, onDone: done.complete);
  await done.future;
  return (data: data, errors: errors);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    _binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(_method, null)
      ..setMockStreamHandler(_event, null);
  });

  group('PoseCameraInfo', () {
    test('aspectRatio와 동등성', () {
      const a = PoseCameraInfo(textureId: 7, width: 720, height: 1280);
      expect(a.aspectRatio, closeTo(0.5625, 1e-9));
      expect(a, const PoseCameraInfo(textureId: 7, width: 720, height: 1280));
      expect(
        a.hashCode,
        const PoseCameraInfo(textureId: 7, width: 720, height: 1280).hashCode,
      );
      expect(
        a == const PoseCameraInfo(textureId: 8, width: 720, height: 1280),
        isFalse,
      );
    });

    test('PoseModel name이 채널 값', () {
      expect(PoseModel.full.name, 'full');
      expect(PoseModel.lite.name, 'lite');
    });
  });

  group('start', () {
    test('start 호출 계약', () async {
      final log = <MethodCall>[];
      _mockMethod(log);
      final d = PlatformPoseDetector();
      expect(d.isRunning, isFalse);

      final info = await d.start(model: PoseModel.lite);

      expect(log.single.method, 'start');
      expect(log.single.arguments, {'model': 'lite'});
      expect(
        info,
        const PoseCameraInfo(textureId: 7, width: 720, height: 1280),
      );
      expect(info.aspectRatio, closeTo(0.5625, 1e-9));
      expect(d.isRunning, isTrue);
    });

    test('기본 모델은 full', () async {
      final log = <MethodCall>[];
      _mockMethod(log);
      await PlatformPoseDetector().start();
      expect(log.single.arguments, {'model': 'full'});
    });

    for (final (name, reply) in <(String, Object?)>[
      ('옛 형식 int', 7),
      ('null', null),
      ('width 누락', {'textureId': 7, 'height': 1280}),
      ('textureId 문자열', {'textureId': '7', 'width': 720, 'height': 1280}),
      ('width 0', {'textureId': 7, 'width': 0, 'height': 1280}),
      ('height 음수', {'textureId': 7, 'width': 720, 'height': -1}),
    ]) {
      test('start 응답 형식 오류: $name → FormatException, 정리용 stop', () async {
        final log = <MethodCall>[];
        _mockMethod(
          log,
          onCall: (call) async => call.method == 'start' ? reply : null,
        );
        final d = PlatformPoseDetector();

        await expectLater(d.start(), throwsFormatException);

        expect(d.isRunning, isFalse);
        expect(log.map((c) => c.method), ['start', 'stop']);
      });
    }

    test('채널 오류는 그대로 전달, 이후 start는 다시 시도', () async {
      final log = <MethodCall>[];
      var fail = true;
      _mockMethod(
        log,
        onCall: (call) async {
          if (call.method == 'start' && fail) {
            fail = false;
            throw PlatformException(code: 'CAMERA_FAILED');
          }
          return call.method == 'start' ? _camera : null;
        },
      );
      final d = PlatformPoseDetector();

      await expectLater(
        d.start(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'CAMERA_FAILED',
          ),
        ),
      );
      expect(d.isRunning, isFalse);

      final info = await d.start();
      expect(info.textureId, 7);
      expect(d.isRunning, isTrue);
    });

    test('실행 중 start는 채널을 다시 부르지 않고 같은 값', () async {
      final log = <MethodCall>[];
      _mockMethod(log);
      final d = PlatformPoseDetector();

      final a = await d.start();
      final b = await d.start();

      expect(b, a);
      expect(log.map((c) => c.method), ['start']);
    });

    test('실행 중 다른 모델로 start → 모델만 바꿈', () async {
      final log = <MethodCall>[];
      _mockMethod(log);
      final d = PlatformPoseDetector();

      final a = await d.start();
      final b = await d.start(model: PoseModel.lite);

      expect(b, a);
      expect(log.map((c) => c.method), ['start', 'setModel']);
      expect(log.last.arguments, {'model': 'lite'});
    });

    test('동시에 start 두 번 → 채널 start 한 번, 같은 값', () async {
      final log = <MethodCall>[];
      _mockMethod(log);
      final d = PlatformPoseDetector();

      final results = await Future.wait([d.start(), d.start()]);

      expect(results[0], results[1]);
      expect(log.map((c) => c.method), ['start']);
    });

    test('start 진행 중 stop → 순서대로 처리, 끝나면 멈춤', () async {
      final log = <MethodCall>[];
      final gate = Completer<void>();
      _mockMethod(
        log,
        onCall: (call) async {
          if (call.method == 'start') {
            await gate.future;
            return _camera;
          }
          return null;
        },
      );
      final d = PlatformPoseDetector();

      final starting = d.start();
      final stopping = d.stop();
      gate.complete();

      expect((await starting).textureId, 7);
      await stopping;
      expect(log.map((c) => c.method), ['start', 'stop']);
      expect(d.isRunning, isFalse);
    });

    test('stop 진행 중 start → stop 뒤 카메라를 새로 연다', () async {
      final log = <MethodCall>[];
      final gate = Completer<void>();
      _mockMethod(
        log,
        onCall: (call) async {
          if (call.method == 'stop') await gate.future;
          return call.method == 'start' ? _camera : null;
        },
      );
      final d = PlatformPoseDetector();
      await d.start();

      final stopping = d.stop();
      final starting = d.start();
      gate.complete();
      await stopping;
      await starting;

      expect(log.map((c) => c.method), ['start', 'stop', 'start']);
      expect(d.isRunning, isTrue);
    });
  });

  group('setModel, stop', () {
    test('메서드 이름과 인자가 계약대로, stop 뒤 isRunning false', () async {
      final log = <MethodCall>[];
      _mockMethod(log);
      final d = PlatformPoseDetector();
      await d.start();

      await d.setModel(PoseModel.lite);
      await d.stop();

      expect(log.map((c) => c.method), ['start', 'setModel', 'stop']);
      expect(log[1].arguments, {'model': 'lite'});
      expect(log[2].arguments, isNull);
      expect(d.isRunning, isFalse);
    });

    test('setModel 뒤 같은 모델 start는 setModel을 다시 부르지 않음', () async {
      final log = <MethodCall>[];
      _mockMethod(log);
      final d = PlatformPoseDetector();
      await d.start();
      await d.setModel(PoseModel.lite);

      await d.start(model: PoseModel.lite);

      expect(log.map((c) => c.method), ['start', 'setModel']);
    });

    test('stop 채널 오류 → 오류 전달, isRunning false', () async {
      final log = <MethodCall>[];
      _mockMethod(
        log,
        onCall: (call) async {
          if (call.method == 'stop') throw PlatformException(code: 'X');
          return call.method == 'start' ? _camera : null;
        },
      );
      final d = PlatformPoseDetector();
      await d.start();

      await expectLater(d.stop(), throwsA(isA<PlatformException>()));
      expect(d.isRunning, isFalse);
    });
  });

  group('results', () {
    test('broadcast이고 구독자 둘이어도 플랫폼 listen은 한 번', () async {
      var listens = 0;
      _binding.defaultBinaryMessenger.setMockStreamHandler(
        _event,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            listens++;
            sink.success(_eventOf());
          },
        ),
      );
      final d = PlatformPoseDetector();
      expect(d.results.isBroadcast, isTrue);

      final a = d.results.first;
      final b = d.results.first;
      final both = await Future.wait([a, b]);

      expect(both[0].timestampMs, 1000);
      expect(both[1].timestampMs, 1000);
      expect(listens, 1);
    });

    test('이벤트 파싱 (F-01): 좌표를 뒤집지 않고 그대로', () async {
      final r = await _collect(
        PlatformPoseDetector(),
        (s) => s.success(_eventOf(t: 1234)),
      );

      expect(r.errors, isEmpty);
      final result = r.data.single;
      expect(result.timestampMs, 1234);
      expect(result.inferenceMs, 12);
      final frame = result.poses.single;
      expect(frame.landmarks, hasLength(33));
      expect(frame.timestampMs, 1234);
      expect(frame.aspectRatio, closeTo(0.5625, 1e-9));
      final p = frame[LandmarkIndex.leftShoulder];
      expect(p.x, 11 / 100);
      expect(p.y, 11 / 200);
      expect(p.z, -11 / 10);
      expect(p.visibility, 0.9);
    });

    test('정수 좌표도 받는다', () async {
      final pose = [
        for (var i = 0; i < 33; i++) [0, 1, 0, 1],
      ];
      final r = await _collect(
        PlatformPoseDetector(),
        (s) => s.success(_eventOf(poses: [pose])),
      );
      expect(r.errors, isEmpty);
      expect(r.data.single.poses.single[0].y, 1.0);
    });

    test('여러 명이면 사람마다 PoseFrame', () async {
      final r = await _collect(
        PlatformPoseDetector(),
        (s) => s.success(_eventOf(poses: [_pose(), _pose()])),
      );
      expect(r.data.single.poses, hasLength(2));
    });

    test('사람 없음 → poses 빈 목록, 오류 없음', () async {
      final r = await _collect(
        PlatformPoseDetector(),
        (s) => s.success(_eventOf(poses: [])),
      );
      expect(r.errors, isEmpty);
      expect(r.data.single.poses, isEmpty);
    });

    test('점 32개 → 스트림 오류 FormatException, 다음 프레임은 계속', () async {
      final r = await _collect(PlatformPoseDetector(), (s) {
        s
          ..success(_eventOf(poses: [_pose(count: 32)]))
          ..success(_eventOf(t: 2000));
      });
      expect(r.errors.single, isA<FormatException>());
      expect(r.data.single.timestampMs, 2000);
    });

    for (final (name, Object? event) in <(String, Object?)>[
      ('Map이 아님', 'hello'),
      ('null', null),
      ('t 누락', {..._eventOf()}..remove('t')),
      ('inferenceMs 실수', {..._eventOf(), 'inferenceMs': 1.5}),
      ('width 누락', {..._eventOf()}..remove('width')),
      ('poses 누락', {..._eventOf()}..remove('poses')),
      ('poses가 목록 아님', {..._eventOf(), 'poses': 'x'}),
      (
        '사람이 목록 아님',
        {
          ..._eventOf(),
          'poses': [1],
        },
      ),
      (
        '점 값 3개',
        {
          ..._eventOf(),
          'poses': [
            [
              for (var i = 0; i < 33; i++) [0.1, 0.2, 0.3],
            ],
          ],
        },
      ),
      (
        '점 값이 문자열',
        {
          ..._eventOf(),
          'poses': [
            [
              for (var i = 0; i < 33; i++) ['a', 0.2, 0.3, 0.4],
            ],
          ],
        },
      ),
    ]) {
      test('잘못된 이벤트 형식: $name → FormatException', () async {
        final r = await _collect(
          PlatformPoseDetector(),
          (s) => s.success(event),
        );
        expect(r.data, isEmpty);
        expect(r.errors.single, isA<FormatException>());
      });
    }

    for (final (name, Object? event) in <(String, Object?)>[
      (
        'x NaN',
        {
          ..._eventOf(),
          'poses': [
            [
              [double.nan, 0.1, 0.1, 0.1],
              ..._pose().skip(1),
            ],
          ],
        },
      ),
      (
        'visibility Infinity',
        {
          ..._eventOf(),
          'poses': [
            [
              ..._pose().take(32),
              [0.1, 0.1, 0.1, double.infinity],
            ],
          ],
        },
      ),
      (
        'z -Infinity',
        {
          ..._eventOf(),
          'poses': [
            [
              [0.1, 0.1, double.negativeInfinity, 0.1],
              ..._pose().skip(1),
            ],
          ],
        },
      ),
      ('width 0', _eventOf(width: 0)),
      ('height 0', _eventOf(height: 0)),
      ('width 음수', _eventOf(width: -720)),
      ('width, height 모두 음수', _eventOf(width: -720, height: -1280)),
    ]) {
      test('$name → 프레임을 조용히 버리고 다음 프레임을 받음', () async {
        final r = await _collect(PlatformPoseDetector(), (s) {
          s
            ..success(event)
            ..success(_eventOf(t: 2000));
        });
        expect(r.errors, isEmpty);
        expect(r.data.single.timestampMs, 2000);
      });
    }

    List<List<Object?>> nanPerson() => [
      [double.nan, 0.1, 0.1, 0.1],
      ..._pose().skip(1),
    ];

    test('2명 중 1명만 NaN이면 나머지 1명 프레임이 나옴', () async {
      final r = await _collect(
        PlatformPoseDetector(),
        (s) => s.success(_eventOf(poses: [nanPerson(), _pose()])),
      );
      expect(r.errors, isEmpty);
      expect(r.data.single.poses, hasLength(1));
      expect(r.data.single.poses.single.landmarks[1].x, closeTo(0.01, 1e-9));
    });

    test('2명 모두 NaN이면 이벤트 없음(오류도 아님)', () async {
      final r = await _collect(
        PlatformPoseDetector(),
        (s) => s.success(_eventOf(poses: [nanPerson(), nanPerson()])),
      );
      expect(r.errors, isEmpty);
      expect(r.data, isEmpty);
    });

    test('poses 목록은 수정할 수 없음', () async {
      final r = await _collect(
        PlatformPoseDetector(),
        (s) => s.success(_eventOf()),
      );
      expect(() => r.data.single.poses.clear(), throwsUnsupportedError);
    });

    test('추론 실패 전달', () async {
      final r = await _collect(
        PlatformPoseDetector(),
        (s) => s.error(code: 'INFERENCE_FAILED', message: 'boom'),
      );
      expect(r.data, isEmpty);
      expect(
        r.errors.single,
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'INFERENCE_FAILED',
        ),
      );
    });
  });

  group('poseDetectorProvider', () {
    test('PlatformPoseDetector 하나를 앱 전체에서 공유', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final a = container.read(poseDetectorProvider);
      expect(a, isA<PlatformPoseDetector>());
      expect(container.read(poseDetectorProvider), same(a));
    });
  });

  group('FakePoseDetector', () {
    const result = PoseDetectionResult(
      timestampMs: 5,
      poses: [],
      inferenceMs: 3,
    );

    test('start 두 번, emit 후 listen 2개', () async {
      final fake = FakePoseDetector();

      final a = await fake.start();
      final b = await fake.start();

      expect(a, const PoseCameraInfo(textureId: 1, width: 720, height: 1280));
      expect(b, a);
      expect(fake.calls, ['start:full', 'start:full']);
      expect(fake.isRunning, isTrue);
      expect(fake.results.isBroadcast, isTrue);

      final first = fake.results.first;
      final second = fake.results.first;
      fake.emit(result);
      expect(await first, same(result));
      expect(await second, same(result));
    });

    test('setModel, stop 기록과 currentModel', () async {
      const camera = PoseCameraInfo(textureId: 3, width: 480, height: 640);
      final fake = FakePoseDetector(camera: camera);
      expect(fake.currentModel, isNull);

      expect(await fake.start(model: PoseModel.lite), camera);
      expect(fake.currentModel, PoseModel.lite);
      await fake.setModel(PoseModel.full);
      expect(fake.currentModel, PoseModel.full);
      await fake.stop();

      expect(fake.calls, ['start:lite', 'setModel:full', 'stop']);
      expect(fake.isRunning, isFalse);
    });

    test('emitError는 스트림 오류', () async {
      final fake = FakePoseDetector();
      final error = PlatformException(code: 'INFERENCE_FAILED');
      final next = fake.results.first;
      fake.emitError(error);
      await expectLater(next, throwsA(same(error)));
    });
  });
}
