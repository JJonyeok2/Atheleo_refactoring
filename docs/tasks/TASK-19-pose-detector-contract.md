# TASK-19: 자세 추정 플랫폼 채널 계약(Dart 쪽)

- 상태: 대기
- 선행 Task: TASK-04
- 실행 방식: 순차
- 실행 방식 근거: Dart와 Kotlin 사이 계약을 정하는 기반 작업, 설계 판단 필요
- Spec 출처: F-01 (3장, 8장 기술 구성, 4장 예외 흐름 저사양)

## 왜 이렇게 나눴나
Kotlin 구현(TASK-20, 21)보다 Dart 쪽 계약과 가짜 구현을 먼저 만든다. 그러면 화면과 뷰모델은 실기기 없이 가짜 감지기로 개발, 테스트할 수 있다.

## 기능 범위 (Spec 발췌)
- MediaPipe Pose Landmarker(full, 저사양은 lite)로 33개 랜드마크와 3D 좌표 추출
- 카메라 영상은 저장하거나 전송하지 않는다(채널로는 랜드마크만 보낸다)
- 채널 계약(이 Task에서 확정, Kotlin Task가 그대로 따름):
  - MethodChannel `atheleo/pose`
    - `start` 인자 `{"model": "full"|"lite"}` → 반환 `int` textureId (카메라 미리보기 Flutter 텍스처)
    - `stop` 인자 없음 → null
    - `setModel` 인자 `{"model": "full"|"lite"}` → null
  - EventChannel `atheleo/pose/results`
    - 이벤트: `{"t": int(ms), "inferenceMs": int, "width": int, "height": int, "poses": [[[x, y, z, v] × 33], ...]}` (사람 없으면 poses 빈 목록, 좌표는 세로 화면 기준 정규화)
    - 추론 실패: 스트림 오류 `PlatformException(code: "INFERENCE_FAILED")`
  - 각 `PoseFrame.aspectRatio` = width / height

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `PoseLandmark`, `PoseFrame` | `app/lib/pose/landmarks/pose_landmark.dart` | `class PoseLandmark { const PoseLandmark({required double x, required double y, required double z, required double visibility}); }`, `class PoseFrame { PoseFrame({required int timestampMs, required List<PoseLandmark> landmarks, double aspectRatio = 1.0}); PoseLandmark operator [](int index); }` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `PoseModel` | `app/lib/pose/detector/pose_detector.dart` | `enum PoseModel { full, lite }` (`name`이 채널 값) | TASK-21, 28 |
| `PoseDetectionResult` | 같은 파일 | `class PoseDetectionResult { const PoseDetectionResult({required int timestampMs, required List<PoseFrame> poses, required int inferenceMs}); }` | TASK-25, 27, 45, 46 |
| `PoseDetector` | 같은 파일 | `abstract class PoseDetector { Stream<PoseDetectionResult> get results; Future<int> start({PoseModel model = PoseModel.full}); Future<void> stop(); Future<void> setModel(PoseModel model); }` | TASK-25, 27, 45, 46 |
| `poseDetectorProvider` | 같은 파일 | `final poseDetectorProvider = Provider<PoseDetector>((ref) => PlatformPoseDetector());` | TASK-25, 27, 46 |
| `PlatformPoseDetector` | `app/lib/pose/detector/platform_pose_detector.dart` | `class PlatformPoseDetector implements PoseDetector { PlatformPoseDetector({MethodChannel? methodChannel, EventChannel? eventChannel}); }` (위 채널 계약) | TASK-20, 21 |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | `class FakePoseDetector implements PoseDetector { void emit(PoseDetectionResult result); void emitError(Object error); List<String> get calls; PoseModel? get currentModel; }` (start는 textureId 1 반환, calls에 'start:full' 형식 기록) | TASK-25, 27, 28, 45, 46 |

## 범위
- 위 인터페이스, 채널 구현, 가짜 구현

## 범위 밖 (건드리지 않음)
- Kotlin 코드(TASK-20, 21), 화면

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| start 호출 계약 | `TestDefaultBinaryMessengerBinding`으로 `atheleo/pose` 가짜 응답 7 | `start(model: lite)`가 인자 `{"model":"lite"}`로 호출되고 7 반환 |
| 이벤트 파싱 (F-01) | 33개 점 1명, width 720, height 1280 이벤트 | `PoseDetectionResult.poses` 1개, 점 33개, aspectRatio 0.5625 |
| 사람 없음 | poses 빈 목록 | poses 빈 목록, 오류 없음 |
| 점 개수 오류 | 32개 점 | 스트림 오류 `FormatException` |
| 추론 실패 전달 | `PlatformException(code: 'INFERENCE_FAILED')` | 스트림 오류로 같은 code 전달 |
| setModel, stop | 각각 호출 | 메서드 이름과 인자가 계약대로 |
| 가짜 감지기 | `FakePoseDetector.emit` 후 listen | 같은 결과 수신, calls 기록 |

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
