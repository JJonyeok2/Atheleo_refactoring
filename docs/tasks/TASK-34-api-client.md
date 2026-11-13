# TASK-34: API 클라이언트(토큰 첨부, 자동 갱신, 오류 분류)

- 상태: 대기
- 선행 Task: TASK-02, TASK-33
- 실행 방식: 순차
- 실행 방식 근거: 인증 기반 작업, 모든 서버 호출이 기댐
- Spec 출처: F-10, F-11 (4장 예외 흐름 토큰 만료, 자동 동기화 표, 6장 API 목록, 9장 인수 조건 F-10)

## 왜 이렇게 나눴나
토큰 첨부와 refresh를 한곳(dio 인터셉터)에 모은다. 서버가 아직 없으므로(Q-01) 경로별 응답을 정해 주는 가짜 어댑터를 함께 만들어 이후 Task의 "가짜 서버"로 쓴다. 동기화가 오류 종류별로 다르게 처리하므로 분류도 여기서 정한다.

## 기능 범위 (Spec 발췌)
| 메서드 | 경로 | 요청 | 응답 | 에러 |
|---|---|---|---|---|
| POST | `/api/auth/refresh/` | refresh | access | 401 |

- 토큰 만료: refresh로 갱신 시도. 실패하면 만료 신호만 낸다(화면 이동 여부는 TASK-37이 운동 세션 여부로 정함)
- 동기화가 구분해야 하는 응답: 네트워크 오류, 5xx, 400, 401, 403, 404, 409, 413, 422, 429(처리 방식은 TASK-38, 39)
- 인수 조건(F-10): access 만료 시 자동 갱신된다.
- 이 Task에서 정하는 규칙:
  - 요청에 `Authorization: Bearer <access>` 첨부. `options.extra['auth'] == false`면 첨부하지 않음
  - 인증 요청이 401이면 refresh 1번 → 새 access 저장(refresh와 사용자 id는 유지) → 원래 요청 1번 재시도
  - 동시에 여러 요청이 401이면 refresh는 한 번만
  - refresh 실패(401, 토큰 없음) → `TokenStorage.clear()`, `SessionEvents.notifyExpired()`, 원래 오류 전달
  - 타임아웃: 연결 10초, 응답 15초
  - 오류 분류: 연결 실패, 타임아웃 → network / 5xx → server / 400 → badRequest / 401 → unauthorized / 403 → forbidden / 404 → notFound / 409 → conflict / 429 → tooManyRequests / 그 밖의 4xx(413, 422 등) → clientError / 나머지 → unknown

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `AppEnv`, `appEnvProvider` | `app/lib/app/env.dart` | `class AppEnv { ...apiBaseUrl... }`, `final appEnvProvider = Provider<AppEnv>(...)` |
| `AuthTokens`, `TokenStorage`, `tokenStorageProvider` | `app/lib/core/storage/token_storage.dart` | `abstract class TokenStorage { Future<AuthTokens?> read(); Future<void> write(AuthTokens tokens); Future<int?> readUserId(); Future<void> writeUserId(int userId); Future<void> clear(); }` (write는 사용자 id를 건드리지 않음) |
| `InMemoryTokenStorage` | `app/test/support/in_memory_token_storage.dart` | `class InMemoryTokenStorage implements TokenStorage { InMemoryTokenStorage([AuthTokens? initial, int? userId]); AuthTokens? get current; int? get currentUserId; }` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SessionEvents` | `app/lib/core/network/session_events.dart` | `class SessionEvents { Stream<void> get expired; void notifyExpired(); void dispose(); }` (expired는 broadcast) | TASK-35, 37 |
| `sessionEventsProvider` | 같은 파일 | `final sessionEventsProvider = Provider<SessionEvents>(...)` (dispose 시 `dispose()`) | TASK-35, 37 |
| `buildApiClient` | `app/lib/core/network/api_client.dart` | `Dio buildApiClient({required String baseUrl, required TokenStorage tokens, required SessionEvents events, HttpClientAdapter? adapter})` | (provider 내부, 테스트) |
| `apiClientProvider` | 같은 파일 | `final apiClientProvider = Provider<Dio>(...)` | TASK-35, 38, 43 |
| `ApiErrorKind` | 같은 파일 | `enum ApiErrorKind { network, server, badRequest, unauthorized, forbidden, notFound, conflict, tooManyRequests, clientError, unknown }` | TASK-35, 38, 43 |
| `classifyError` | 같은 파일 | `ApiErrorKind classifyError(Object error)` (위 분류 규칙) | TASK-35, 38, 43 |
| `FakeHttpAdapter` | `app/test/support/fake_http_adapter.dart` | `class FakeHttpAdapter implements HttpClientAdapter { void on(String method, String path, FakeResponse Function(RequestOptions request) responder); void failNetwork(bool value); List<RequestOptions> get requests; }` (등록 안 된 경로는 404) | TASK-35, 38, 43, 55 |
| `FakeResponse` | 같은 파일 | `class FakeResponse { const FakeResponse(this.statusCode, [this.body]); final int statusCode; final Object? body; }` | TASK-35, 38, 43, 55 |

## 범위
- 위 클래스와 인터셉터

## 범위 밖 (건드리지 않음)
- 로그인, 화면 이동(TASK-35, 37), 응답별 동기화 처리(TASK-38, 39)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 토큰 첨부 | 토큰 저장 후 GET `/api/users/me/` | 헤더 `Bearer a1` |
| 첨부 제외 | `extra: {'auth': false}` | Authorization 헤더 없음 |
| access 만료 자동 갱신 (F-10) | 첫 요청 401, refresh 200 `{access: a2}` | 재시도 성공, 저장소 access a2, refresh와 사용자 id 유지 |
| refresh 한 번만 | 동시에 3개 요청이 401 | refresh 요청 1번, 3개 모두 성공 |
| refresh 실패 | refresh 401 | 토큰과 사용자 id 삭제, expired 1번, 원래 요청은 오류 |
| 오류 분류 | 네트워크 실패, 503, 400, 403, 409, 413, 422, 429 | network, server, badRequest, forbidden, conflict, clientError, clientError, tooManyRequests |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/network/session_events.dart`
- `app/lib/core/network/api_client.dart`
- `app/test/support/fake_http_adapter.dart`
- `app/test/core/network/api_client_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] 토큰을 로그에 남기지 않음(LogInterceptor를 쓰면 헤더 제외)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 새 외부 서비스나 새 환경 변수가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- `ApiErrorKind`에 forbidden, tooManyRequests, clientError 추가(동기화 오류별 처리용), 분류 테스트 확장
- refresh 실패 시 사용자 id도 함께 삭제(`clear`), 만료 시 화면 이동은 TASK-37 판단으로 명시
- 내보내기 표에 `sessionEventsProvider`, `FakeResponse`를 따로 적음
