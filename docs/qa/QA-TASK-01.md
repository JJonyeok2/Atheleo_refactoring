# QA-TASK-01

- 검토일: 2026-11-09
- 판정: FIX
- 검토 대상 커밋: e3a5cb6 (feat: Flutter 프로젝트 생성 및 기본 설정)
- 재실행 결과: `flutter test` 2건 통과, `flutter analyze` No issues found (헤더/푸터 주석 추가 후 다시 실행해도 동일)

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| app/lib/main.dart | 추가함 | 소스 파일 |
| app/android/app/src/main/kotlin/com/atheleo/app/MainActivity.kt | 추가함 | 소스 파일. 패키지 경로가 계약과 일치 |
| app/test/smoke_test.dart | 제외 | 규칙상 테스트 파일은 달지 않음 |
| app/pubspec.yaml | 제외 | 설정 파일 |
| app/analysis_options.yaml | 제외 | 설정 파일 |
| app/android/app/build.gradle.kts | 제외 | 설정 파일 |
| app/android/app/src/main/AndroidManifest.xml | 제외 | 설정 파일 |
| app/android/app/src/debug/AndroidManifest.xml | 제외 | 설정 파일. Impl이 의도를 적은 한국어 주석이 이미 있음 |
| 그 밖의 flutter create 생성 파일 | 제외 | 자동 생성, 손대지 않음 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 해당 없음 | - | 입력 처리 코드 없음 |
| XSS 등 출력 처리 | 해당 없음 | - | - |
| 인증 / 인가 | 해당 없음 | - | - |
| 시크릿 하드코딩 | 통과 | - | 키, 토큰, DSN 없음 |
| 로그의 민감 정보 | 통과 | - | 로그 출력 없음 |
| 평문 통신(cleartext) | 통과 | src/main/AndroidManifest.xml:6, src/debug/AndroidManifest.xml:9-11 | main은 `false`. debug 소스셋 매니페스트가 main보다 우선순위가 높고 `tools:replace`를 쓰므로 debug 빌드에서만 `true`로 병합된다. release와 profile은 debug 매니페스트를 읽지 않으므로 `false` 유지. 구조상 의도대로이며, 실제 병합 결과는 빌드 미확인 |
| 네트워크 권한 | 문제 | src/main/AndroidManifest.xml | `android.permission.INTERNET`이 debug, profile 매니페스트에만 있고 main에 없다. 플러그인 매니페스트도 확인함: connectivity_plus는 ACCESS_NETWORK_STATE만, sentry_flutter, dio 쪽은 INTERNET을 넣지 않음. 결과적으로 release 빌드는 HTTPS 포함 모든 네트워크 요청이 실패한다. debug에서는 정상이라 이후 Task의 테스트와 사용자 최종 검증(debug 실행)에서 드러나지 않는 위험이 크다. "릴리스 빌드는 HTTPS만 허용"이라는 기능 범위는 릴리스에서 네트워크를 쓴다는 전제이므로 FIX |
| 릴리스 서명 | 참고 | app/android/app/build.gradle.kts:33-37 | flutter create 기본값대로 release가 debug 키로 서명됨. 이 Task 범위 밖이며 배포 전 별도 Task 필요(오케스트레이터 참고) |
| 서명 키, 로컬 파일 제외 | 통과 | app/android/.gitignore, app/.gitignore, 루트 .gitignore | `git check-ignore`로 확인: android/local.properties, key.properties, *.jks, *.keystore, build/, .dart_tool/, android/app/release, android/.gradle 모두 제외됨. 커밋에도 포함되지 않음 |
| 새 의존성 | 참고 | app/pubspec.yaml | Task 계약 목록과 일치, 그 외 추가 없음. 아래 sqlite3_flutter_libs 참고 |

### 의존성 메모
- `sqlite3_flutter_libs: ^0.6.0+eol`: 0.6.0부터 빈 패키지다(README: "no longer does anything", sqlite3 3.x로 옮긴 뒤 제거하라고 안내). 실제 SQLite 네이티브 라이브러리는 `sqlite3 3.5.2`의 build hook(native_toolchain_c, hooks)이 맡는다. `drift_flutter 0.3.1`이 이 패키지를 `^0.6.0+eol`로 직접 의존하므로 pubspec에서 빼도 전이 의존으로 남는다. 보안 위험은 없고 Impl 잘못도 아니다(Task 계약에 이 패키지가 적혀 있음). 다만 계약 목록에서 빼는 것이 맞으므로 **Task 수정 권고**로 남긴다. 또 sqlite3 3.x의 build hook은 빌드 때 네이티브 소스를 받아 컴파일하거나 미리 빌드된 파일을 받을 수 있어, 네트워크가 막힌 이 환경에서는 apk 빌드 실패 원인이 하나 더 있을 수 있다.
- 버전 고정 방식: 모두 캐럿(`^`) 범위 + `pubspec.lock` 커밋. 앱 프로젝트에 맞는 방식이다. `flutter_riverpod`는 lock 기준 2.6.1로 계약(^2.6.1, 2.x)과 일치. go_router는 18.x 메이저.
- `environment: sdk: ^3.13.7`: 설치된 SDK 기준으로 높게 잡혀 있어 다른 개발 환경은 이 버전 이상의 Flutter가 필요하다. 문제는 아니고 README에 적어 둘 후보.

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | - | - |
| 함수 길이 | 통과 | - | - |
| 이름 | 통과 | lib/main.dart | `AtheleoApp`, 패키지 `atheleo`, `com.atheleo.app` 모두 계약대로 |
| 죽은 코드 | 참고 | app/pubspec.yaml:2, 45-46, 55-59 | `description: "A new Flutter project."`, 의존성이 없는데 남은 Cupertino Icons, flutter_lints 템플릿 주석. 동작 영향 없음. 다음에 pubspec을 만질 때 정리 권장(FIX 아님) |
| 최신 문법 | 참고 | lib/main.dart `const new({super.key})` | 새 생성자 문법이라 낯설 수 있으나 analyze 통과, 동작 문제 없음 |
| 테스트가 인수 조건을 검증하는가 | 통과(일부 범위 밖) | app/test/smoke_test.dart | MaterialApp 1개, 예외 없음, 4개 패키지 import 확인. minSdk, 세로 고정, cleartext는 flutter test로 확인할 수 없어 파일 검토로 대신함 |
| "내보내는 것" 계약 | 통과 | pubspec.yaml, build.gradle.kts, kotlin 경로 | `name: atheleo`, `applicationId`/`namespace` = `com.atheleo.app`, `minSdk = 26`, Kotlin 경로 `com/atheleo/app/`, 의존성 목록(dev 포함) 모두 일치 |
| 분석 제외 범위 | 참고 | app/analysis_options.yaml | `android/**`, `build/**` 제외. 적절함 |

## 미확인
- `flutter build apk --debug`: plugins-artifacts.gradle.org 차단으로 빌드하지 못함. 따라서 매니페스트 병합 결과(debug cleartext true, release false), minSdk 26과 플러그인 minSdk 호환, sqlite3 build hook 동작은 실제 빌드로 확인하지 못했다. 네트워크가 되는 환경에서 `flutter build apk --debug`와 `--release` 후 `aapt dump xmltree`(또는 merged manifest)로 확인 필요.

## FIX 항목 (Impl로 회귀)
- [ ] app/android/app/src/main/AndroidManifest.xml:2 — `<uses-permission android:name="android.permission.CAMERA"/>` 아래에 `<uses-permission android:name="android.permission.INTERNET"/>` 추가. 릴리스에서 dio, Sentry의 HTTPS 요청이 가능해야 한다. cleartext 설정은 그대로 둔다. debug, profile 매니페스트의 INTERNET은 중복이지만 남겨도 무해하다.

## Task 수정 권고 (오케스트레이터 판단)
- TASK-01 "내보내는 것"의 의존성 목록에서 `sqlite3_flutter_libs` 제거 검토(EOL 빈 패키지, drift_flutter가 전이로 가져옴).
- 릴리스 서명 설정(현재 debug 키) 담당 Task가 없으면 추가 검토.

## PEER_REVIEW 사유
- 해당 없음
