import 'package:atheleo/features/workout/widgets/skeleton_overlay.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PoseFrame _frame({
  double x = 0.5,
  double y = 0.25,
  double visibility = 0.9,
  Map<int, PoseLandmark> overrides = const {},
}) {
  return PoseFrame(
    timestampMs: 0,
    landmarks: [
      for (var i = 0; i < LandmarkIndex.count; i++)
        overrides[i] ?? PoseLandmark(x: x, y: y, z: 0, visibility: visibility),
    ],
  );
}

void main() {
  group('projectLandmarks', () {
    test('33개 점 투영 (F-01)', () {
      final points = projectLandmarks(_frame(), const Size(400, 800));
      expect(points.length, 33);
      expect(points.every((p) => p != null), isTrue);
      expect(points.first, const Offset(200, 200));
    });

    test('안 보이는 점 제외', () {
      final points = projectLandmarks(
        _frame(
          overrides: {
            LandmarkIndex.leftWrist: const PoseLandmark(
              x: 0.5,
              y: 0.5,
              z: 0,
              visibility: 0.1,
            ),
          },
        ),
        const Size(400, 800),
      );
      expect(points[LandmarkIndex.leftWrist], isNull);
      expect(points[LandmarkIndex.rightWrist], isNotNull);
    });

    test('반전하지 않음 (F-07)', () {
      final points = projectLandmarks(
        _frame(
          overrides: {
            LandmarkIndex.rightWrist: const PoseLandmark(
              x: 0.2,
              y: 0.5,
              z: 0,
              visibility: 0.9,
            ),
          },
        ),
        const Size(400, 800),
      );
      expect(points[LandmarkIndex.rightWrist]!.dx, closeTo(80, 1e-9));
    });

    test('가시성 경계 0.5는 보임, 직전 값은 안 보임', () {
      final at = projectLandmarks(_frame(visibility: 0.5), const Size(10, 10));
      final below = projectLandmarks(
        _frame(visibility: 0.49),
        const Size(10, 10),
      );
      expect(at.every((p) => p != null), isTrue);
      expect(below.every((p) => p == null), isTrue);
    });

    test('minVisibility 인자를 따른다', () {
      final points = projectLandmarks(
        _frame(visibility: 0.7),
        const Size(10, 10),
        minVisibility: 0.8,
      );
      expect(points.every((p) => p == null), isTrue);
    });

    test('비유한 좌표(NaN, 무한대)는 null', () {
      final points = projectLandmarks(
        _frame(
          overrides: {
            0: const PoseLandmark(x: double.nan, y: 0.5, z: 0, visibility: 0.9),
            1: const PoseLandmark(
              x: 0.5,
              y: double.infinity,
              z: 0,
              visibility: 0.9,
            ),
            2: const PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: double.nan),
          },
        ),
        const Size(400, 800),
      );
      expect(points[0], isNull);
      expect(points[1], isNull);
      expect(points[2], isNull);
      expect(points[3], isNotNull);
    });

    test('화면 비율이 달라도 너비/높이에 비례한다', () {
      final wide = projectLandmarks(_frame(), const Size(800, 400));
      expect(wide.first, const Offset(400, 100));
    });

    test('크기가 0이어도 길이 33으로 예외 없음', () {
      final points = projectLandmarks(_frame(), Size.zero);
      expect(points.length, 33);
    });
  });

  group('kPoseConnections', () {
    test('연결선 개수', () {
      expect(kPoseConnections.length, 35);
    });

    test('모든 인덱스가 0~32 범위', () {
      for (final (a, b) in kPoseConnections) {
        expect(a, inInclusiveRange(0, 32));
        expect(b, inInclusiveRange(0, 32));
      }
    });
  });

  group('SkeletonOverlay', () {
    Future<void> pump(WidgetTester tester, PoseFrame? frame, Size size) {
      return tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: SkeletonOverlay(frame: frame),
            ),
          ),
        ),
      );
    }

    testWidgets('위젯 렌더: CustomPaint 하나, 부모를 꽉 채움', (tester) async {
      await pump(tester, _frame(), const Size(200, 300));
      expect(
        find.descendant(
          of: find.byType(SkeletonOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(SkeletonOverlay)),
        const Size(200, 300),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('null 프레임', (tester) async {
      await pump(tester, null, const Size(200, 300));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(SkeletonOverlay)),
        const Size(200, 300),
      );
    });

    testWidgets('노이즈 입력(사람 없음, 비유한, 낮은 visibility)에도 예외 없음', (tester) async {
      await pump(tester, _frame(visibility: 0), const Size(200, 300));
      expect(tester.takeException(), isNull);
      await pump(
        tester,
        _frame(x: double.nan, y: double.infinity),
        const Size(200, 300),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('화면 비율이 달라도 예외 없음', (tester) async {
      await pump(tester, _frame(), const Size(400, 100));
      expect(tester.takeException(), isNull);
      await pump(tester, _frame(), Size.zero);
      expect(tester.takeException(), isNull);
    });
  });
}
