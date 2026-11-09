# TASK-21: MediaPipe Pose Landmarker 연결(Kotlin, EventChannel)

- 상태: 대기
- 선행 Task: TASK-20
- 실행 방식: 순차
- 실행 방식 근거: 네이티브 추론과 실기기 확인이 필요한 기반 작업
- Spec 출처: F-01 (3장, 4장 예외 흐름 여러 사람과 저사양, 8장 성능, 9장 인수 조건)

## 왜 이렇게 나눴나
카메라 프레임을 MediaPipe에 넣고 결과를 TASK-19에서 정한 이벤트 형식으로 Dart에 보내는 조각이다. 모델 전환(full/lite)의 실제 동작도 여기서 만든다. 언제 전환할지는 TASK-26, 28이 정한다.

## 기능 범위 (Spec 발췌)
- MediaPipe Pose Landmarker(full, 저사양은 lite)로 33개 랜드마크와 3D 좌표 추출
- 여러 사람이 잡힐 때: 화면 중앙에 가장 크게 잡힌 1명만 추적(고르는 건 Dart의 `selectPrimaryPose`. 여기서는 최대 2명까지 보냄)
- 추론이 느릴 때: 추론 프레임을 건너뛴다(추론 중 들어온 프레임은 버림, CameraX `STRATEGY_KEEP_ONLY_LATEST`)
- 카메라 영상은 저장하거나 전송하지 않는다.
- 성능 목표: 중급 기기 추론 20fps 이상
- 인수 조건(F-01): 운동 화면에서 전신이 보이게 서면, 1초 안에 33개 점의 스켈레톤이 몸에 맞게 그려진다(그리기는 TASK-22, 29. 여기서는 좌표가 미리보기와 같은 방향인지 확인).

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `CameraController` | `app/android/app/src/main/kotlin/com/atheleo/app/pose/CameraController.kt` | `class CameraController(context: Context, lifecycleOwner: LifecycleOwner, textureRegistry: TextureRegistry) { fun start(analyzer: ImageAnalysis.Analyzer?): Long; fun stop() }` (start는 textureId 반환, analyzer가 null이면 미리보기만) |
| `PoseChannelHandler` | `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseChannelHandler.kt` | `class PoseChannelHandler(...) : MethodChannel.MethodCallHandler` (`start`, `stop` 처리. `setModel`은 이 Task에서 `result.success(null)`만) |
| 채널 계약 | TASK-19 | MethodChannel `atheleo/pose`(`start` `{"model"}` → textureId, `stop`, `setModel` `{"model": "full"\|"lite"}`), EventChannel `atheleo/pose/results` 이벤트 `{"t": int(ms), "inferenceMs": int, "width": int, "height": int, "poses": [[[x, y, z, v] × 33], ...]}`, 추론 실패는 오류 code `"INFERENCE_FAILED"` |
| `PoseModel` | `app/lib/pose/detector/pose_detector.dart` | `enum PoseModel { full, lite }` (`name`이 채널 값) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| 채널 동작 | 위 채널 계약 | `setModel`이 실제로 모델을 바꾸고, 결과 이벤트가 계약 형식으로 나옴 | TASK-25, 27, 46 |
| 모델 파일 | `app/android/app/src/main/assets/pose_landmarker_full.task`, `pose_landmarker_lite.task` | Google 공식 배포 파일. 받는 방법은 `app/android/README-models.md`에 적음 | 사용자 |

## 범위
- `PoseLandmarkerHelper.kt`: `RunningMode.LIVE_STREAM`, `numPoses = 2`, 결과 콜백에서 이벤트 맵 생성
- 좌표는 미리보기와 같은 방향(세로, 전면 카메라 좌우 반전 포함)으로 정규화해서 보냄
- `PoseChannelHandler`에 `setModel` 실제 구현, EventChannel 등록
- `build.gradle.kts`에 `com.google.mediapipe:tasks-vision` 추가, `.task` 파일 압축 제외(`noCompress`)

## 범위 밖 (건드리지 않음)
- Dart 파일, 전환 기준(TASK-26, 28), 화면

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| Dart 계약 테스트 유지 | `flutter test test/pose/detector/` | TASK-19 테스트(가짜 채널) 모두 통과 |
| 이벤트 변환 단위 테스트(JVM) | `app/android/app/src/test/.../PoseEventMapperTest.kt`: 가짜 랜드마크 33개 1명 | 맵에 `t`, `inferenceMs`, `width`, `height`, `poses[0]` 길이 33 |
| 좌우 반전 | x 0.2인 점, 전면 카메라 | 0.8로 변환 |
| 빌드 | `flutter build apk --debug` | 성공 |

### 실기기 수동 확인 항목 (Q-02 기기)
| 항목 | 방법 | 기대 결과 |
|---|---|---|
| 1초 안 스켈레톤 (F-01) | 임시 디버그 화면 또는 TASK-29 이후 운동 화면에서 전신으로 섬 | 1초 안에 점 33개가 몸 위치에 맞게 보임 |
| 추론 속도 | 로그의 `inferenceMs` 10초 평균 | full 20fps 이상(중급 기기), 결과 기록 |
| lite 전환 | `setModel lite` 호출 | 오류 없이 결과가 계속 나오고 `inferenceMs` 감소 |
| 두 사람 | 두 명이 화면에 섬 | poses 2개 |

## 바뀔 것으로 예상되는 파일
- `app/android/app/build.gradle.kts`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseLandmarkerHelper.kt`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseChannelHandler.kt`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseEventMapper.kt`
- `app/android/app/src/test/kotlin/com/atheleo/app/pose/PoseEventMapperTest.kt`
- (모델 파일 2개와 `README-models.md`는 개수에서 제외)

## 완료 조건
- [ ] 위 테스트와 빌드 통과
- [ ] 실기기 수동 확인 항목을 QA 보고서에 체크리스트로 남김(기기 없으면 "미확인" 표시)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 이벤트 형식을 바꿔야 할 때(TASK-19 계약 변경)
- 모델 파일을 받을 수 없을 때(네트워크 제한)

## 추가 발췌 (오케스트레이터가 보충)
