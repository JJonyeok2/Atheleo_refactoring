# TASK-01: Flutter 프로젝트 생성과 의존성

- 상태: 대기
- 선행 Task: 없음
- 실행 방식: 순차
- 실행 방식 근거: 모든 Task가 기대는 기반 작업(설정, 의존성 파일)
- Spec 출처: 8장 비기능 요구사항(플랫폼, 기술 구성, 검증 도구)

## 왜 이렇게 나눴나
이후 Task가 `pubspec.yaml`을 건드리지 않도록 필요한 의존성을 여기서 한 번에 넣는다. 공유 설정 파일 충돌을 막기 위한 첫 조각이다.

## 기능 범위 (Spec 발췌)
- 플랫폼: Android 8.0(API 26) 이상, 세로 화면 고정. iOS는 범위 밖.
- 기술 구성: Flutter, Riverpod, go_router, MediaPipe Tasks(Kotlin 플랫폼 채널), flutter_tts, drift(로컬 DB), flutter_secure_storage, dio
- 릴리스 빌드는 HTTPS만 허용한다.
- 린트: `flutter analyze` + very_good_analysis 규칙. 단위 테스트: `flutter test`.

## 연결 범위

### 받아 쓰는 것
없음

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| 패키지 이름 | `app/pubspec.yaml` | `name: atheleo` (import는 `package:atheleo/...`) | 전체 |
| Android 패키지 | `app/android/app/build.gradle.kts` | `applicationId = "com.atheleo.app"`, `minSdk = 26`, Kotlin 경로 `app/android/app/src/main/kotlin/com/atheleo/app/` | TASK-20, 21 |
| 의존성 | `app/pubspec.yaml` | dependencies: flutter_riverpod(^2.6.1), go_router, flutter_tts, drift, drift_flutter, sqlite3_flutter_libs, path_provider, path, flutter_secure_storage, dio, connectivity_plus, sentry_flutter, permission_handler, uuid, intl / dev_dependencies: flutter_test, very_good_analysis, build_runner, drift_dev, fake_async | 전체 |
| 실행 명령 | `app/` | `flutter test`, `flutter analyze` 가 `app/`에서 통과 | 전체 |

## 범위
- `app/` 폴더에 `flutter create --platforms=android --org com.atheleo --project-name atheleo` 로 생성(생성 직후 applicationId가 `com.atheleo.app`이 되도록 맞춤)
- minSdk 26, 세로 고정(`android:screenOrientation="portrait"`)
- main 매니페스트에 `<uses-permission android:name="android.permission.CAMERA"/>` 추가(권한 요청 화면은 TASK-26)
- main 매니페스트 `android:usesCleartextTraffic="false"`, debug 매니페스트(`src/debug/AndroidManifest.xml`)에서만 `true`로 덮어씀(로컬 서버 접속용)
- 위 의존성 추가. `flutter_riverpod`는 2.x 최신(^2.6.1)으로 고정하고 코드 생성(riverpod_generator)은 쓰지 않음. 상태는 `Notifier`/`NotifierProvider`/`Provider`로만 만든다
- `analysis_options.yaml`에 `include: package:very_good_analysis/analysis_options.yaml`
- 기본 카운터 예제 제거, `lib/main.dart`는 빈 `MaterialApp` 수준으로 둠(TASK-03에서 교체)

## 범위 밖 (건드리지 않음)
- 라우터, 환경 설정, 화면(TASK-02, 03)
- CameraX Gradle 의존성(TASK-20), MediaPipe Gradle 의존성과 모델 파일(TASK-21)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| `app/test/smoke_test.dart` 앱이 빌드됨 | `main.dart`의 루트 위젯을 `pumpWidget` | 예외 없이 `MaterialApp`이 하나 존재 |
| 의존성 import 확인 | 같은 파일에서 `flutter_riverpod`, `go_router`, `dio`, `drift` import | 컴파일 성공 |
| 린트 통과 | `flutter analyze` | 오류 0건 |

## 바뀔 것으로 예상되는 파일
- `app/pubspec.yaml`
- `app/analysis_options.yaml`
- `app/android/app/build.gradle.kts`
- `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/src/debug/AndroidManifest.xml`
- `app/lib/main.dart`, `app/test/smoke_test.dart`
- (`flutter create`가 만든 나머지 파일은 개수에서 제외)

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] `flutter analyze` 오류 0건
- [ ] 기능 범위의 플랫폼 조건(minSdk 26, 세로 고정, 릴리스 cleartext 금지) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 의존성 버전 충돌로 위 목록 중 하나를 빼야 할 때
- Flutter SDK나 Android SDK가 설치되어 있지 않을 때
- 새 외부 서비스나 새 환경 변수가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)
