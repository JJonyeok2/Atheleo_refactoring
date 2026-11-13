# TASK-20: Android 카메라 미리보기(CameraX → Flutter 텍스처, 화면 꺼짐 방지)

- 상태: 대기
- 선행 Task: TASK-19
- 실행 방식: 순차
- 실행 방식 근거: 네이티브 설정(Gradle, MainActivity)과 실기기 확인이 필요한 기반 작업
- Spec 출처: F-01, F-07, F-08 (4장 정상 흐름 3~4번, 8장 기술 구성, 성능, 보안, 9장 인수 조건 F-01, F-07, F-08)

## 왜 이렇게 나눴나
MediaPipe를 붙이기 전에 "카메라 미리보기가 바른 방향으로 Flutter 화면에 뜨고 채널 start/stop이 동작"하는 것까지만 만든다. 추론은 TASK-21.

## 기능 범위 (Spec 발췌)
- 카메라 미리보기는 원본 프레임레이트 유지, 실제 프레임 비율 유지
- 촬영 가이드에서 운동 화면으로 넘어갈 때 카메라를 멈추거나 다시 열지 않는다
- 전면 카메라 좌우 반전과 회전이 스켈레톤과 일치
- 운동 세션 동안 화면 꺼짐 방지(세션 종료 시 해제)
- 카메라 영상은 저장하거나 전송하지 않는다.
- 세로 화면 고정, Android 8.0(API 26) 이상
- 인수 조건:
  - F-01: 촬영 가이드에서 운동 화면으로 넘어갈 때 미리보기가 검게 끊기지 않고 카메라가 다시 열리지 않는다.
  - F-07: 전면 카메라에서 오른팔을 들면 화면과 스켈레톤이 같은 쪽 팔을 같은 위치에 그린다.
  - F-08: 촬영 가이드부터 휴식까지 손대지 않고 5분이 지나도 화면이 꺼지지 않으며, 결과 화면으로 나가면 화면 꺼짐 방지가 풀린다.
- 이 Task에서 정하는 것:
  - 전면 카메라 사용(사용자가 화면을 보며 운동), 미리보기 해상도는 CameraX 기본(16:9 우선)
  - 미리보기 텍스처는 세로로 회전하고 전면 카메라는 좌우 반전해 내보낸다(거울처럼 보임). 회전, 반전은 Kotlin에서 끝내고 Dart는 하지 않는다
  - `start` 반환 width, height는 회전 후 세로 기준 크기(예: 720 × 1280)
  - 이미 실행 중에 `start`가 오면 카메라를 다시 바인딩하지 않고 같은 textureId, width, height를 돌려준다
  - `start` 성공 시 액티비티 창에 `FLAG_KEEP_SCREEN_ON`을 켜고 `stop` 시 끈다(감지기가 켜져 있는 동안이 운동 세션)
  - 카메라 권한이 없을 때 `start`는 `PlatformException(code: "NO_CAMERA_PERMISSION")`

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| 채널 계약 | TASK-19 | MethodChannel `atheleo/pose`: `start` 인자 `{"model": "full"\|"lite"}` → 반환 `{"textureId": int, "width": int, "height": int}`(실행 중이면 같은 값), `stop` → null, `setModel` 인자 `{"model": "full"\|"lite"}` → null. 화면 꺼짐 방지는 start에서 켜고 stop에서 끔 |
| Android 패키지 | `app/android/app/build.gradle.kts` | `applicationId = "com.atheleo.app"`, `minSdk = 26`, Kotlin 경로 `app/android/app/src/main/kotlin/com/atheleo/app/` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `CameraStartInfo` | `app/android/app/src/main/kotlin/com/atheleo/app/pose/CameraController.kt` | `data class CameraStartInfo(val textureId: Long, val width: Int, val height: Int) { fun toMap(): Map<String, Any> }` (`{"textureId", "width", "height"}`) | TASK-21 |
| `CameraController` | 같은 파일 | `class CameraController(context: Context, lifecycleOwner: LifecycleOwner, textureRegistry: TextureRegistry) { fun start(analyzer: ImageAnalysis.Analyzer?): CameraStartInfo; fun stop(); val isRunning: Boolean; val isFrontCamera: Boolean }` (실행 중 start는 같은 CameraStartInfo, analyzer가 null이면 미리보기만) | TASK-21 |
| `PoseChannelHandler` | `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseChannelHandler.kt` | `class PoseChannelHandler(activity: Activity, camera: CameraController) : MethodChannel.MethodCallHandler` (`start`는 `CameraStartInfo.toMap()`과 화면 꺼짐 방지 켜기, `stop`은 끄기. `setModel`은 이 Task에서 `result.success(null)`만) | TASK-21 |

## 범위
- `build.gradle.kts`에 CameraX(camera-core, camera-camera2, camera-lifecycle) 의존성
- `MainActivity.kt`에서 채널 등록
- 위 클래스

## 범위 밖 (건드리지 않음)
- MediaPipe, EventChannel(TASK-21), 모델 파일(TASK-50), Dart 파일, 권한 요청 UI(TASK-25)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| Dart 계약 테스트 유지 | `flutter test test/pose/detector/` | TASK-19 테스트(가짜 채널) 모두 통과 |
| 시작 정보 변환(JVM) | `app/android/app/src/test/kotlin/com/atheleo/app/pose/CameraStartInfoTest.kt`: `CameraStartInfo(3, 720, 1280).toMap()` | `{"textureId": 3, "width": 720, "height": 1280}` |
| 빌드 | `flutter build apk --debug` | 성공 |

### 실기기 수동 확인 항목 (사용자 또는 verify-agent가 확인, Q-02 기기)
| 항목 | 방법 | 기대 결과 |
|---|---|---|
| 미리보기 방향과 반전 (F-07) | 임시 디버그 화면에서 `start` 후 `Texture(textureId)`, 오른팔 들기 | 세로로 바르게, 거울처럼(화면 오른쪽 팔이 올라감) 보임 |
| 두 번 start (F-01) | start 두 번 호출 | 같은 textureId, 미리보기가 끊기지 않음 |
| 화면 꺼짐 방지 (F-08) | start 후 5분 손대지 않음 / stop 후 기기 화면 꺼짐 시간 경과 | 꺼지지 않음 / 꺼짐 |
| stop | stop 호출 | 카메라 사용 표시등 꺼짐 |
| 권한 없음 | 설정에서 권한 끔 후 start | `NO_CAMERA_PERMISSION` 오류 |

## 바뀔 것으로 예상되는 파일
- `app/android/app/build.gradle.kts`
- `app/android/app/src/main/kotlin/com/atheleo/app/MainActivity.kt`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/CameraController.kt`
- `app/android/app/src/main/kotlin/com/atheleo/app/pose/PoseChannelHandler.kt`
- `app/android/app/src/test/kotlin/com/atheleo/app/pose/CameraStartInfoTest.kt`

## 완료 조건
- [ ] 위 테스트와 빌드 통과
- [ ] 실기기 수동 확인 항목을 체크리스트로 QA 보고서에 남김(기기 없으면 "미확인"으로 표시하고 진행)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- Flutter 텍스처로 CameraX 미리보기를 붙일 수 없어 채널 계약(textureId 반환)을 바꿔야 할 때
- 텍스처를 Kotlin에서 회전, 반전할 수 없어 Dart에서 뒤집어야 할 때(TASK-19, 22 계약 변경)

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- start 반환을 `CameraStartInfo`(textureId, width, height) 맵으로, 실행 중 start는 같은 값(카메라 유지)
- 텍스처 회전과 전면 좌우 반전을 Kotlin 책임으로, `FLAG_KEEP_SCREEN_ON`을 start/stop에 묶음. JVM 테스트와 수동 확인 항목 추가
- (TASK-19 QA 반영) 네이티브 `start`는 이미 실행 중이면 카메라를 다시 열지 않고 같은 `{textureId, width, height}`(Int)를 돌려주며 모델이 다르면 모델만 바꾼다. `stop`은 실행 중이 아니어도 오류 없이 null. `setModel`은 실행 중이 아니면 다음 start용으로 저장. 회전과 전면 좌우 반전은 텍스처와 좌표에 똑같이 적용.
- (TASK-33 QA 반영, 오케스트레이터 결정) AndroidManifest의 application에 `android:allowBackup="false"`를 명시한다. 암호화 저장소는 백업 복원 시 복호화가 실패하고, 기록은 서버에 백업되므로 기기 백업을 끈다. 기존 매니페스트 검사 테스트(app/test/android_manifest_test.dart)에 이 속성 확인을 추가한다.
