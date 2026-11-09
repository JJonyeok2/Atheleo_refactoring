# TASK-20: Android 카메라 미리보기(CameraX → Flutter 텍스처)

- 상태: 대기
- 선행 Task: TASK-19
- 실행 방식: 순차
- 실행 방식 근거: 네이티브 설정(Gradle, MainActivity)과 실기기 확인이 필요한 기반 작업
- Spec 출처: F-01 (8장 기술 구성, 성능, 보안)

## 왜 이렇게 나눴나
MediaPipe를 붙이기 전에 "카메라 미리보기가 Flutter 화면에 뜨고 채널 start/stop이 동작"하는 것까지만 만든다. 추론은 TASK-21.

## 기능 범위 (Spec 발췌)
- 카메라 미리보기는 원본 프레임레이트 유지
- 카메라 영상은 저장하거나 전송하지 않는다.
- 세로 화면 고정, Android 8.0(API 26) 이상
- 이 Task에서 정하는 것: 전면 카메라 사용(사용자가 화면을 보며 운동), 미리보기 해상도는 CameraX 기본(16:9 우선)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| 채널 계약 | TASK-19 | MethodChannel `atheleo/pose`: `start` 인자 `{"model": "full"\|"lite"}` → 반환 `int` textureId, `stop` → null, `setModel` 인자 `{"model": "full"\|"lite"}` → null |
| Android 패키지 | `app/android/app/build.gradle.kts` | `applicationId = "com.atheleo.app"`, `minSdk = 26`, Kotlin 경로 `app/android/app/src/main/kotlin/com/atheleo/app/` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `CameraController` | `app/android/app/src/main/kotlin/com/atheleo/app/pose/CameraController.kt` | `class CameraController(context: Context, lifecycleOwner: LifecycleOwner, textureRegistry: TextureRegistry) { fun start(analyzer: ImageAnalysis.Analyzer?): Long; fun stop() }` (start는 textureId 반환, analyzer가 null이면 미리보기만) | TASK-21 |
| `PoseChannelHandler` | `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseChannelHandler.kt` | `class PoseChannelHandler(...) : MethodChannel.MethodCallHandler` (`start`, `stop` 처리. `setModel`은 이 Task에서 `result.success(null)`만) | TASK-21 |

## 범위
- `build.gradle.kts`에 CameraX(camera-core, camera-camera2, camera-lifecycle) 의존성
- `MainActivity.kt`에서 채널 등록
- 카메라 권한이 없을 때 `start`는 `PlatformException(code: "NO_CAMERA_PERMISSION")`

## 범위 밖 (건드리지 않음)
- MediaPipe, EventChannel(TASK-21), Dart 파일, 권한 요청 UI(TASK-25)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| Dart 계약 테스트 유지 | `flutter test test/pose/detector/` | TASK-19 테스트(가짜 채널) 모두 통과 |
| 빌드 | `flutter build apk --debug` | 성공 |

### 실기기 수동 확인 항목 (사용자 또는 verify-agent가 확인, Q-02 기기)
| 항목 | 방법 | 기대 결과 |
|---|---|---|
| 미리보기 표시 | 임시 디버그 화면에서 `start` 후 `Texture(textureId)` | 전면 카메라 영상이 세로로 바르게 보임 |
| stop | stop 호출 | 카메라 사용 표시등 꺼짐 |
| 권한 없음 | 설정에서 권한 끔 후 start | `NO_CAMERA_PERMISSION` 오류 |

## 바뀔 것으로 예상되는 파일
- `app/android/app/build.gradle.kts`
- `app/android/app/src/main/kotlin/com/atheleo/app/MainActivity.kt`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/CameraController.kt`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseChannelHandler.kt`

## 완료 조건
- [ ] 위 테스트와 빌드 통과
- [ ] 실기기 수동 확인 항목을 체크리스트로 QA 보고서에 남김(기기 없으면 "미확인"으로 표시하고 진행)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- Flutter 텍스처로 CameraX 미리보기를 붙일 수 없어 채널 계약(textureId 반환)을 바꿔야 할 때

## 추가 발췌 (오케스트레이터가 보충)
