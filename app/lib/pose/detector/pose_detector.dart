// [파일] 자세 감지기 계약: PoseModel, PoseCameraInfo, PoseDetectionResult,
//   PoseDetector 추상 클래스, 앱 전체 공유 poseDetectorProvider.
// [Spec] F-01, F-07, F-08 / [Task] TASK-19
// [의존] 없음 (환경 변수 사용 안 함)

import 'package:atheleo/pose/detector/platform_pose_detector.dart';
import 'package:atheleo/pose/landmarks/pose_landmark.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 자세 추정 모델. [name]이 채널로 보내는 값이다.
enum PoseModel {
  /// 기본 모델.
  full,

  /// 저사양 기기용 가벼운 모델.
  lite,
}

/// 감지기가 연 카메라 미리보기 정보.
///
/// [width], [height]는 회전 후 세로 화면 기준 미리보기 프레임 크기다.
@immutable
class PoseCameraInfo {
  /// 텍스처 id와 프레임 크기로 만든다.
  const new({
    required this.textureId,
    required this.width,
    required this.height,
  });

  /// 미리보기 `Texture` 위젯에 넘길 id.
  final int textureId;

  /// 프레임 너비(px).
  final int width;

  /// 프레임 높이(px).
  final int height;

  /// 너비 / 높이.
  double get aspectRatio => width / height;

  @override
  bool operator ==(Object other) =>
      other is PoseCameraInfo &&
      other.textureId == textureId &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(textureId, width, height);

  @override
  String toString() => 'PoseCameraInfo($textureId, ${width}x$height)';
}

/// 한 번의 추론 결과. 사람이 없으면 [poses]가 빈 목록이다.
class PoseDetectionResult {
  /// 프레임 시각, 사람별 랜드마크, 추론 시간으로 만든다.
  const new({
    required this.timestampMs,
    required this.poses,
    required this.inferenceMs,
  });

  /// 프레임 시각(ms). 판정 분석에서만 쓴다.
  final int timestampMs;

  /// 사람마다 33개 랜드마크 한 프레임.
  final List<PoseFrame> poses;

  /// 추론에 걸린 시간(ms).
  final int inferenceMs;
}

/// 카메라와 자세 추정 세션을 다루는 감지기.
abstract class PoseDetector {
  /// 추론 결과 스트림(broadcast). 추론 실패는 스트림 오류로 온다.
  Stream<PoseDetectionResult> get results;

  /// 카메라와 감지를 시작한다. 이미 실행 중이면 카메라를 다시 열지 않고
  /// 같은 [PoseCameraInfo]를 돌려준다.
  Future<PoseCameraInfo> start({PoseModel model = PoseModel.full});

  /// 카메라와 감지를 멈춘다.
  Future<void> stop();

  /// 추론 모델을 바꾼다.
  Future<void> setModel(PoseModel model);

  /// 감지기가 켜져 있는지.
  bool get isRunning;
}

/// 앱 전체에서 하나만 쓰는 감지기.
final poseDetectorProvider = Provider<PoseDetector>(
  (ref) => PlatformPoseDetector(),
);

// [QA] 2026-11-13 PASS
// [보안] 채널로는 랜드마크만 받는다(영상 없음). 입력 검증은 PlatformPoseDetector.
// [유지보수] PoseDetectionResult.poses는 const 생성자라 복사하지 않는다(받은 목록
//   그대로, 구독자끼리 공유). 감지기는 앱 전체 하나라 stop 소유권은 화면 쪽
//   규칙(TASK-25 운동 화면 전환 시 stop 안 함, TASK-27 dispose 시 stop)에 기댄다.
