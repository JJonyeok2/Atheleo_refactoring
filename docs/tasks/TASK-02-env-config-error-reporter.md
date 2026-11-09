# TASK-02: 환경 설정과 오류 보고 인터페이스

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 순차
- 실행 방식 근거: 설정과 공유 인터페이스(여러 Task가 기대는 기반)
- Spec 출처: 8장 보안(설정 분리, HTTPS), 모니터링

## 왜 이렇게 나눴나
서버 주소와 Sentry DSN을 코드에 박지 않고 `--dart-define`으로 받는 통로, 그리고 Sentry를 나중에 붙일 수 있게 오류 보고 인터페이스만 먼저 만든다. Sentry 실제 연결은 TASK-48.

## 기능 범위 (Spec 발췌)
- 서버 주소, Sentry DSN 같은 설정은 `--dart-define`이나 `.env`로 분리하고 Git에는 예시 파일만 올린다.
- 릴리스 빌드는 HTTPS만 허용한다.
- 추론 실패, 동기화 400, 비정상 종료를 보고한다. 개인 식별 정보는 보내지 않는다.

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| 패키지 이름 | `app/pubspec.yaml` | `name: atheleo` (import는 `package:atheleo/...`) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `AppEnv` | `app/lib/app/env.dart` | `class AppEnv { const AppEnv({required String apiBaseUrl, required String sentryDsn, required bool isRelease}); factory AppEnv.fromEnvironment(); void validate(); }` (validate는 isRelease이고 apiBaseUrl이 `https://`로 시작하지 않으면 `StateError`) | TASK-03, 34, 48 |
| `appEnvProvider` | `app/lib/app/env.dart` | `final appEnvProvider = Provider<AppEnv>(...)` | TASK-34, 48 |
| `ErrorReporter` | `app/lib/core/monitoring/error_reporter.dart` | `abstract class ErrorReporter { Future<void> report(Object error, StackTrace? stackTrace, {String? tag, Map<String, Object?> context = const {}}); }` | TASK-28, 39, 48 |
| `NoopErrorReporter` | 같은 파일 | `class NoopErrorReporter implements ErrorReporter` (아무것도 안 함) | TASK-48 |
| `errorReporterProvider` | 같은 파일 | `final errorReporterProvider = Provider<ErrorReporter>(...)` (기본값 `NoopErrorReporter`) | TASK-28, 39, 48 |
| `.env.example` | `app/.env.example` | 키: `API_BASE_URL`, `SENTRY_DSN` (값은 비움). 실행: `flutter run --dart-define-from-file=.env` | 사용자 |

## 범위
- `AppEnv.fromEnvironment()`: `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000')`, `String.fromEnvironment('SENTRY_DSN')`, `isRelease: kReleaseMode`
- `.env.example` 작성. `.env`는 이미 루트 `.gitignore`에 있으므로 `.gitignore`는 건드리지 않음

## 범위 밖 (건드리지 않음)
- `main.dart`에서 validate 호출(TASK-03), Sentry 초기화(TASK-48)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 릴리스에서 http 거부 | `AppEnv(apiBaseUrl: 'http://a.com', sentryDsn: '', isRelease: true).validate()` | `StateError` |
| 릴리스에서 https 허용 | `https://a.com`, isRelease true | 예외 없음 |
| 디버그에서 http 허용 | `http://10.0.2.2:8000`, isRelease false | 예외 없음 |
| 기본값 | `AppEnv.fromEnvironment()` (define 없음) | apiBaseUrl `http://10.0.2.2:8000`, sentryDsn `''` |
| 기본 오류 보고기 | `ProviderContainer().read(errorReporterProvider)` | `NoopErrorReporter`이고 `report` 호출 시 예외 없음 |

## 바뀔 것으로 예상되는 파일
- `app/lib/app/env.dart`
- `app/lib/core/monitoring/error_reporter.dart`
- `app/.env.example`
- `app/test/app/env_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] 기능 범위의 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 기능 범위와 연결 범위만으로 판단할 수 없는 정보가 필요할 때
- 새 외부 서비스나 새 환경 변수가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)
