# TASK-48: Sentry 연결

- 상태: 대기
- 선행 Task: TASK-02, TASK-03, TASK-28, TASK-39, TASK-47, TASK-55
- 실행 방식: 순차
- 실행 방식 근거: 앱 진입점(main.dart)과 공유 provider를 바꾸는 마지막 연결 작업, 새 외부 서비스
- Spec 출처: 8장 모니터링, 보안

## 왜 이렇게 나눴나
지금까지 `ErrorReporter` 인터페이스로만 보고하던 것을 실제 Sentry로 보낸다. 마지막에 두어 앞 Task 테스트가 외부 서비스 없이 돌게 했다.

## 기능 범위 (Spec 발췌)
- 앱은 sentry_flutter. 추론 실패(tag 'inference_failed'), 동기화 거절(rejected, 'sync_rejected'), 동기화 실패(failed, 'sync_failed'), 비정상 종료를 보고한다. 개인 식별 정보는 보내지 않는다.
- Sentry DSN은 `--dart-define`이나 `.env`로 분리, Git에는 예시 파일만
- 카메라 영상과 랜드마크는 기기 밖으로 보내지 않는다.
- 이 Task에서 정하는 규칙:
  - DSN이 비어 있으면 Sentry를 켜지 않고 `NoopErrorReporter` 유지(로컬 개발 기본)
  - `SentryFlutter.init`: `sendDefaultPii = false`, `environment`는 릴리스면 'production', 아니면 'development'
  - `beforeSend`에서 user의 id, email, username, ip 제거, extra/context에서 키 이름에 `email`, `password`, `token`, `nickname`, `landmark`, `user_id`가 들어간 항목 제거
  - 비정상 종료: `runZonedGuarded` 대신 sentry_flutter 기본 처리(`appRunner`) 사용
  - `report`의 tag는 Sentry tag `kind`로 붙임

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ErrorReporter`, `NoopErrorReporter`, `errorReporterProvider` | `app/lib/core/monitoring/error_reporter.dart` | `abstract class ErrorReporter { Future<void> report(Object error, StackTrace? stackTrace, {String? tag, Map<String, Object?> context = const {}}); }`, `final errorReporterProvider = Provider<ErrorReporter>(...)` (기본값 `NoopErrorReporter`) |
| `AppEnv`, `appEnvProvider` | `app/lib/app/env.dart` | `class AppEnv { const AppEnv({required String apiBaseUrl, required String sentryDsn, required bool isRelease}); factory AppEnv.fromEnvironment(); void validate(); }` |
| `AtheleoApp` | `app/lib/app/app.dart` | `class AtheleoApp extends ConsumerWidget` (`MaterialApp.router`, `routerProvider` 사용) |
| `AppStartup`, `bootstrap` | `app/lib/app/app_startup.dart`, `app/lib/main.dart` | `class AppStartup extends ConsumerStatefulWidget { const AppStartup({super.key, required Widget child}); }`, `Future<void> bootstrap({AppEnv? env, void Function(Widget app) run = runApp})` (run에 `ProviderScope(child: AppStartup(child: AtheleoApp()))`를 넘김, TASK-55. Sentry override를 넣어도 이 구조와 "validate가 run보다 먼저" 순서는 유지) |
| `.env.example` | `app/.env.example` | 키 `API_BASE_URL`, `SENTRY_DSN` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SentryErrorReporter` | `app/lib/core/monitoring/sentry_error_reporter.dart` | `class SentryErrorReporter implements ErrorReporter { SentryErrorReporter({Hub? hub}); }` | (main) |
| `scrubEvent` | 같은 파일 | `SentryEvent? scrubEvent(SentryEvent event, Hint hint)` | (main) |

## 범위
- 위 클래스, `main.dart`에서 DSN 있을 때 Sentry 초기화와 `errorReporterProvider` override

## 범위 밖 (건드리지 않음)
- 서버 sentry-sdk(Q-01 해결 후 서버 Task), Sentry 프로젝트 생성(사용자)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 개인 정보 제거 | user(id, email, username, ip) + extra `{'client_id': 'x', 'email': 'a@b.c', 'token': 't', 'user_id': 7}` 이벤트를 scrubEvent | user 개인 정보 없음, extra에 client_id만 남음 |
| 랜드마크 제거 | extra `{'landmarks': [...]}` | 제거됨 |
| tag 전달 | 가짜 Hub로 `report(e, st, tag: 'sync_rejected')` | captureException 1회, tag `kind=sync_rejected` |
| DSN 없으면 끔 | sentryDsn '' 일 때 main의 provider override 결정 함수 | `NoopErrorReporter` |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/monitoring/sentry_error_reporter.dart`
- `app/lib/main.dart`
- `app/test/core/monitoring/sentry_error_reporter_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] DSN이 코드, 커밋에 들어가지 않음(`scripts/check-secrets.sh`로 확인)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- DSN 외에 새 환경 변수(예: auth token, 소스맵 업로드)가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)

- (오케스트레이터 보충, QA-TASK-03) Sentry 초기화는 `app/lib/main.dart`의 `bootstrap` 안에 붙이되, `AppEnv.fromEnvironment().validate()`가 `run`(runApp)보다 먼저 실행되는 현재 순서를 유지한다. 기존 bootstrap 테스트 2건이 계속 통과해야 한다.

## 2026-11-13 설계 검토 반영
- 보고 대상에 동기화 실패(failed, 'sync_failed') 추가, 사용자 id도 지우는 항목에 추가
- `main.dart`가 TASK-55에서 `AppStartup`으로 감싸졌으므로 그 구조를 유지. 선행 Task에 TASK-02, 03, 55 추가
