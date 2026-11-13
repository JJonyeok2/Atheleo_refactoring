// [파일] 랜드마크 투영 함수와 스켈레톤 오버레이 위젯.
// [Spec] F-01, F-07 / [Task] TASK-22
// [의존] pose/landmarks/pose_landmark.dart (환경 변수 사용 안 함)

import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter/material.dart';

/// MediaPipe 공식 POSE_CONNECTIONS(35개).
const List<(int, int)> kPoseConnections = [
  (0, 1), (1, 2), (2, 3), (3, 7), //
  (0, 4), (4, 5), (5, 6), (6, 8),
  (9, 10),
  (11, 12), (11, 13), (13, 15), (15, 17), (15, 19), (15, 21), (17, 19),
  (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20),
  (11, 23), (12, 24), (23, 24),
  (23, 25), (24, 26), (25, 27), (26, 28),
  (27, 29), (28, 30), (29, 31), (30, 32), (27, 31), (28, 32),
];

/// 랜드마크를 [size] 안의 화면 좌표로 바꾼다. 길이 33.
///
/// 좌표는 이미 미리보기와 같은 방향이므로 뒤집거나 돌리지 않는다.
/// 가시성이 [minVisibility] 미만이거나 좌표, 가시성이 유한하지 않은 점은 null.
List<Offset?> projectLandmarks(
  PoseFrame frame,
  Size size, {
  double minVisibility = 0.5,
}) {
  return [
    for (final p in frame.landmarks)
      if (p.x.isFinite && p.y.isFinite && p.visibility >= minVisibility)
        Offset(p.x * size.width, p.y * size.height)
      else
        null,
  ];
}

/// 스켈레톤을 부모 크기에 꽉 채워 그린다. [frame]이 null이면 아무것도 그리지 않는다.
class SkeletonOverlay extends StatelessWidget {
  /// [frame]의 스켈레톤을 [color]로 그린다.
  const new({required this.frame, super.key, this.color = Colors.white});

  /// 그릴 프레임(없으면 빈 화면).
  final PoseFrame? frame;

  /// 선과 점 색.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _SkeletonPainter(frame: frame, color: color),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  const new({required this.frame, required this.color});

  final PoseFrame? frame;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final current = frame;
    if (current == null) {
      return;
    }
    final points = projectLandmarks(current, size);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in kPoseConnections) {
      final start = points[a];
      final end = points[b];
      if (start != null && end != null) {
        canvas.drawLine(start, end, linePaint);
      }
    }
    final dotPaint = Paint()..color = color;
    for (final point in points) {
      if (point != null) {
        canvas.drawCircle(point, 4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.color != color;
}

// [QA] 2026-11-13 PASS
// [보안] 외부 입력은 PoseFrame 좌표뿐이며 비유한 값과 낮은 가시성은 null로 걸러 그리지 않음. 시크릿, 로그 없음.
// [유지보수] 0~1 범위를 벗어난 좌표는 클리핑하지 않아 상자 밖에 그려질 수 있음(필요하면 부모 TASK-25에서 ClipRect).
// [유지보수] Size.infinite를 쓰므로 부모 제약이 무한이면 크기 오류가 남. 반드시 유한한 비율 상자 안에 둘 것.
