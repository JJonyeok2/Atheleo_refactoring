# TASK-19: 자세 추정 플랫폼 채널 계약(Dart 쪽)

- 상태: 대기
- 선행 Task: TASK-04
- 실행 방식: 순차
- 실행 방식 근거: Dart와 Kotlin 사이 계약을 정하는 기반 작업, 설계 판단 필요
- Spec 출처: F-01, F-07, F-08 (3장, 4장 정상 흐름 3~4번, 8장 기술 구성, 성능, 4장 예외 흐름 저사양)

## 왜 이렇게 나눴나
Kotlin 구현(TASK-20, 21)보다 Dart 쪽 계약과 가짜 구현을 먼저 만든다. 그러면 화면과 뷰모델은 실기기 없이 가짜 감지기로 개발, 테스트할 수 있다.

## 기능 범위 (Spec 발췌)
- MediaPipe Pose Landmarker(full, 저사양은 lite)로 33개 랜드마크와 3D 좌표 추출
- 촬영 가이드에서 운동 화면으로 넘어갈 때 같은 카메라, 감지 세션을 이어 쓴다. 카메라를 멈추거나 다시 열지 않는다
- 미리보기는 실제 프레임 비율 유지, 전면 카메라 좌우 반전과 회전이 스켈레톤과 일치
- 운동 세션 동안 화면 꺼짐 방지(세션 종료 시 해제)
- 카메라 영상은 저장하거나 전송하지 않는다(채널로는 랜드마크만 보낸다)
- 채널 계약(이 Task에서 확정, Kotlin Task가 그대로 따름):
  - MethodChannel `atheleo/pose`
    - `start` 인자 `{"model": "full"|"lite"}` → 반환 `{"textureId": int, "width": int, "height": int}`. width, height는 회전 후 세로 화면 기준 미리보기 프레임 크기. 이미 실행 중이면 카메라를 다시 열지 않고 같은 값을 돌려준다(model이 다르면 모델만 바꿈)
    - `stop` 인자 없음 → null
    - `setModel` 인자 `{"model": "full"|"lite"}` → null
    - 화면 꺼짐 방지: Kotlin이 `start` 성공 시 켜고 `stop` 시 끈다(운동 세션 = 감지기가 켜져 있는 동안)
  - EventChannel `atheleo/pose/results`
    - 이벤트: `{"t": int(ms), "inferenceMs": int, "width": int, "height": int, "poses": [[[x, y, z, v] × 33], ...]}` (사람 없으면 poses 빈 목록)
    - 좌표와 미리보기 텍스처는 Kotlin이 이미 세로로 회전하고, 전면 카메라는 좌우 반전까지 적용한 같은 방향이다. Dart는 돌리거나 뒤집지 않는다
    - 추론 실패: 스트림 오류 `PlatformException(code: "INFERENCE_FAILED")`
  - 각 `PoseFrame.aspectRatio` = width / height
  - 프레임 시각 `t`는 판정 분석에서만 쓴다(세션 시간에는 앱 시계를 씀, TASK-27)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `PoseLandmark`, `PoseFrame` | `app/lib/pose/landmarks/pose_landmark.dart` | `class PoseLandmark { const PoseLandmark({required double x, required double y, required double z, required double visibility}); }`, `class PoseFrame { PoseFrame({required int timestampMs, required List<PoseLandmark> landmarks, double aspectRatio = 1.0}); PoseLandmark operator [](int index); }` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `PoseModel` | `app/lib/pose/detector/pose_detector.dart` | `enum PoseModel { full, lite }` (`name`이 채널 값) | TASK-21, 28 |
| `PoseCameraInfo` | 같은 파일 | `class PoseCameraInfo { const PoseCameraInfo({required int textureId, required int width, required int height}); double get aspectRatio; }` (`==` 구현, aspectRatio = width / height) | TASK-25, 27, 29, 46 |
| `PoseDetectionResult` | 같은 파일 | `class PoseDetectionResult { const PoseDetectionResult({required int timestampMs, required List<PoseFrame> poses, required int inferenceMs}); }` | TASK-25, 27, 45, 46 |
| `PoseDetector` | 같은 파일 | `abstract class PoseDetector { Stream<PoseDetectionResult> get results; Future<PoseCameraInfo> start({PoseModel model = PoseModel.full}); Future<void> stop(); Future<void> setModel(PoseModel model); bool get isRunning; }` (results는 broadcast. 실행 중 start는 같은 PoseCameraInfo) | TASK-25, 27, 45, 46 |
| `poseDetectorProvider` | 같은 파일 | `final poseDetectorProvider = Provider<PoseDetector>((ref) => PlatformPoseDetector());` (앱 전체에서 하나) | TASK-25, 27, 46 |
| `PlatformPoseDetector` | `app/lib/pose/detector/platform_pose_detector.dart` | `class PlatformPoseDetector implements PoseDetector { PlatformPoseDetector({MethodChannel? methodChannel, EventChannel? eventChannel}); }` (위 채널 계약) | TASK-20, 21 |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | `class FakePoseDetector implements PoseDetector { FakePoseDetector({PoseCameraInfo camera = const PoseCameraInfo(textureId: 1, width: 720, height: 1280)}); void emit(PoseDetectionResult result); void emitError(Object error); List<String> get calls; PoseModel? get currentModel; }` (start는 camera 반환, 실행 중이면 같은 값. calls에 'start:full', 'stop', 'setModel:lite' 형식 기록) | TASK-25, 27, 28, 45, 46, 51, 52 |

## 범위
- 위 인터페이스, 채널 구현, 가짜 구현

## 범위 밖 (건드리지 않음)
- Kotlin 코드(TASK-20, 21), 화면

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| start 호출 계약 | `TestDefaultBinaryMessengerBinding`으로 `atheleo/pose` 가짜 응답 `{"textureId": 7, "width": 720, "height": 1280}` | `start(model: lite)`가 인자 `{"model":"lite"}`로 호출되고 `PoseCameraInfo(7, 720, 1280)`, aspectRatio 0.5625, isRunning true |
| start 응답 형식 오류 | 가짜 응답이 int 7(옛 형식)이나 width 누락 | `FormatException` |
| 이벤트 파싱 (F-01) | 33개 점 1명, width 720, height 1280 이벤트 | `PoseDetectionResult.poses` 1개, 점 33개, aspectRatio 0.5625, 좌표를 뒤집지 않고 그대로 |
| 사람 없음과 점 개수 오류 | poses 빈 목록 / 32개 점 | poses 빈 목록, 오류 없음 / 스트림 오류 `FormatException` |
| 추론 실패 전달 | `PlatformException(code: 'INFERENCE_FAILED')` | 스트림 오류로 같은 code 전달 |
| setModel, stop | 각각 호출 | 메서드 이름과 인자가 계약대로, stop 뒤 isRunning false |
| 가짜 감지기 | `FakePoseDetector` start 두 번, emit 후 listen 2개 | 두 start 모두 같은 camera, calls ['start:full', 'start:full'], 두 구독자 모두 같은 결과 수신 |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/detector/pose_detector.dart`
- `app/lib/pose/detector/platform_pose_detector.dart`
- `app/test/support/fake_pose_detector.dart`
- `app/test/pose/detector/platform_pose_detector_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 채널 계약을 바꿔야 할 이유가 생길 때(Kotlin Task 전에 보고)

## 추가 발췌 (오케스트레이터가 보충)
- (QA-TASK-05, 차단 아님) 채널에서 받은 좌표(x, y, z, visibility)가 NaN/Infinity이거나 aspectRatio(width / height)가 0 이하인 프레임은 버리고 다음 프레임을 기다린다. 버린 프레임은 스트림 오류로 내보내지 않는다.

## 2026-11-13 설계 검토 반영
- `start` 반환을 `PoseCameraInfo`(textureId, width, height)로 변경, 실행 중 start는 같은 값(카메라 유지), `isRunning` 추가, results broadcast
- 회전과 전면 좌우 반전, 화면 꺼짐 방지는 Kotlin 책임으로 채널 계약에 명시
