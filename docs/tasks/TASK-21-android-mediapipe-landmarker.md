# TASK-21: MediaPipe Pose Landmarker 연결(Kotlin, EventChannel)

- 상태: 대기
- 선행 Task: TASK-20, TASK-50
- 실행 방식: 순차
- 실행 방식 근거: 네이티브 추론과 실기기 확인이 필요한 기반 작업
- Spec 출처: F-01, F-07 (3장, 4장 예외 흐름 여러 사람과 저사양, 8장 성능, 9장 인수 조건)

## 왜 이렇게 나눴나
카메라 프레임을 MediaPipe에 넣고 결과를 TASK-19에서 정한 이벤트 형식으로 Dart에 보내는 조각이다. 모델 전환(full/lite)의 실제 동작도 여기서 만든다. 언제 전환할지는 TASK-26, 28이 정한다.

## 기능 범위 (Spec 발췌)
- MediaPipe Pose Landmarker(full, 저사양은 lite)로 33개 랜드마크와 3D 좌표 추출
- 모델 파일은 저장소에 넣지 않고 다운로드 스크립트와 체크섬 검사로 받는다(TASK-50이 받은 assets 파일을 읽기만 함)
- 여러 사람이 잡힐 때: 화면 중앙에 가장 크게 잡힌 1명만 추적(고르는 건 Dart의 `selectPrimaryPose`. 여기서는 최대 2명까지 보냄)
- 추론이 느릴 때: 추론 프레임을 건너뛴다(추론 중 들어온 프레임은 버림, CameraX `STRATEGY_KEEP_ONLY_LATEST`)
- 전면 카메라 좌우 반전과 회전이 스켈레톤과 일치(좌표는 미리보기 텍스처와 같은 방향)
- 카메라 영상은 저장하거나 전송하지 않는다.
- 성능 목표: 중급 기기 추론 20fps 이상
- 인수 조건(F-01): 운동 화면에서 전신이 보이게 서면, 1초 안에 33개 점의 스켈레톤이 몸에 맞게 그려진다(그리기는 TASK-22, 29. 여기서는 좌표가 미리보기와 같은 방향인지 확인).

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `CameraController`, `CameraStartInfo` | `app/android/app/src/main/kotlin/com/atheleo/app/pose/CameraController.kt` | `data class CameraStartInfo(val textureId: Long, val width: Int, val height: Int) { fun toMap(): Map<String, Any> }`, `class CameraController(context: Context, lifecycleOwner: LifecycleOwner, textureRegistry: TextureRegistry) { fun start(analyzer: ImageAnalysis.Analyzer?): CameraStartInfo; fun stop(); val isRunning: Boolean; val isFrontCamera: Boolean }` (실행 중 start는 같은 CameraStartInfo, analyzer가 null이면 미리보기만) |
| `PoseChannelHandler` | `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseChannelHandler.kt` | `class PoseChannelHandler(activity: Activity, camera: CameraController) : MethodChannel.MethodCallHandler` (`start`는 `CameraStartInfo.toMap()`과 화면 꺼짐 방지 켜기, `stop`은 끄기. `setModel`은 TASK-20에서 `result.success(null)`만) |
| 채널 계약 | TASK-19 | MethodChannel `atheleo/pose`(`start` `{"model"}` → `{"textureId", "width", "height"}`, `stop`, `setModel` `{"model": "full"\|"lite"}`), EventChannel `atheleo/pose/results` 이벤트 `{"t": int(ms), "inferenceMs": int, "width": int, "height": int, "poses": [[[x, y, z, v] × 33], ...]}`(세로 회전, 전면 좌우 반전 적용 좌표), 추론 실패는 오류 code `"INFERENCE_FAILED"` |
| `PoseModel` | `app/lib/pose/detector/pose_detector.dart` | `enum PoseModel { full, lite }` (`name`이 채널 값) |
| 모델 파일 | `app/android/app/src/main/assets/pose_landmarker_full.task`, `pose_landmarker_lite.task` | TASK-50 스크립트로 받은 파일(Git 제외), `verifyPoseModels`가 빌드 전 확인 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| 채널 동작 | 위 채널 계약 | `setModel`이 실제로 모델을 바꾸고, 결과 이벤트가 계약 형식으로 나옴. 실행 중 `start(model)`은 카메라를 다시 열지 않고 모델만 맞춤 | TASK-25, 27, 46 |

## 범위
- `PoseLandmarkerHelper.kt`: `RunningMode.LIVE_STREAM`, `numPoses = 2`, 결과 콜백에서 이벤트 맵 생성
- 좌표는 미리보기와 같은 방향(세로, 전면 카메라 좌우 반전 포함)으로 정규화해서 보냄. 이벤트 width, height는 `CameraStartInfo`와 같은 세로 기준 크기
- `PoseChannelHandler`에 `setModel` 실제 구현, EventChannel 등록
- `build.gradle.kts`에 `com.google.mediapipe:tasks-vision` 추가, `.task` 파일 압축 제외(`noCompress`)

## 범위 밖 (건드리지 않음)
- Dart 파일, 전환 기준(TASK-26, 28), 화면, 모델 파일 받기(TASK-50)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| Dart 계약 테스트 유지 | `flutter test test/pose/detector/` | TASK-19 테스트(가짜 채널) 모두 통과 |
| 이벤트 변환 단위 테스트(JVM) | `app/android/app/src/test/.../PoseEventMapperTest.kt`: 가짜 랜드마크 33개 1명 | 맵에 `t`, `inferenceMs`, `width`, `height`, `poses[0]` 길이 33 |
| 좌우 반전 | x 0.2인 점, 전면 카메라 / 후면 카메라 | 0.8 / 0.2 |
| 세로 기준 크기 | 센서 1280 × 720, 회전 90도 | 이벤트 width 720, height 1280 |
| 빌드 | (모델 파일을 받은 상태) `flutter build apk --debug` | 성공 |

### 실기기 수동 확인 항목 (Q-02 기기)
| 항목 | 방법 | 기대 결과 |
|---|---|---|
| 1초 안 스켈레톤 (F-01) | 임시 디버그 화면 또는 TASK-29 이후 운동 화면에서 전신으로 섬 | 1초 안에 점 33개가 몸 위치에 맞게 보임 |
| 오른팔 일치 (F-07) | 전면 카메라에서 오른팔 들기 | 미리보기와 점이 같은 쪽 같은 위치 |
| 추론 속도 | 로그의 `inferenceMs` 10초 평균 | full 20fps 이상(중급 기기), 결과 기록 |
| lite 전환 | `setModel lite` 호출 | 오류 없이 결과가 계속 나오고 `inferenceMs` 감소 |
| 두 사람 | 두 명이 화면에 섬 | poses 2개 |

## 바뀔 것으로 예상되는 파일
- `app/android/app/build.gradle.kts`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseLandmarkerHelper.kt`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseChannelHandler.kt`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseEventMapper.kt`
- `app/android/app/src/test/kotlin/com/atheleo/app/pose/PoseEventMapperTest.kt`

## 완료 조건
- [ ] 위 테스트와 빌드 통과
- [ ] 실기기 수동 확인 항목을 QA 보고서에 체크리스트로 남김(기기 없으면 "미확인" 표시)
- [ ] 모델 파일이 Git에 올라가지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 이벤트 형식을 바꿔야 할 때(TASK-19 계약 변경)
- 모델 파일이 없을 때(TASK-50 스크립트 실행 필요, 네트워크 제한이면 보고)

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 모델 파일은 TASK-50 스크립트로 받는 것으로 바꾸고 assets 커밋과 `README-models.md`를 범위에서 뺌
- `CameraController.start` 반환(`CameraStartInfo`), 세로 기준 크기, 후면 카메라 반전 없음 테스트 추가
- (TASK-19 QA 반영) 이벤트의 `t`, `inferenceMs`, `width`, `height`와 start 응답의 `textureId`, `width`, `height`는 반드시 Int/Long으로 보낸다(Double 금지: Dart가 int만 받아 모든 이벤트가 형식 오류가 된다). `PoseEventMapperTest`에 이 필드들이 Double이 아님을 확인하는 단언을 넣는다. 사람이 없으면 poses는 빈 목록, 사람마다 점은 정확히 33개 `[x, y, z, v]`.
