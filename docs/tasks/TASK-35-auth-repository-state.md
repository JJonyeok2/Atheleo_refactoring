# TASK-35: 인증 저장소와 로그인 상태(현재 사용자 id 포함)

- 상태: 대기
- 선행 Task: TASK-33, TASK-34
- 실행 방식: 순차
- 실행 방식 근거: 인증 상태는 라우팅, 저장, 동기화, 프로필이 모두 기대는 공유 상태
- Spec 출처: F-10 (3장, 4장 정상 흐름 계정 1번, 5번, 6장, 7장 로컬 기록 소유 규칙, 9장 인수 조건)

## 왜 이렇게 나눴나
서버 호출(저장소)과 앱 전체 로그인 상태(Notifier), "지금 기록의 주인이 누구인가"(현재 사용자 id)를 함께 만든다. 서버는 가짜 어댑터로 대신한다(Q-01 미해결).

## 기능 범위 (Spec 발췌)
| 메서드 | 경로 | 요청 | 응답 | 에러 |
|---|---|---|---|---|
| POST | `/api/auth/signup/` | email, password, nickname | 201, user | 400 중복 이메일, 형식 오류 |
| POST | `/api/auth/login/` | email, password | access, refresh, user(id 포함) | 401 |
| GET | `/api/users/me/` | (인증) | user, profile | 401 |

- 운동은 로그인 없이 가능
- 회원가입 또는 로그인 → 토큰과 사용자 id는 암호화 저장소에 저장
- 로그아웃해도 로컬 기록은 지우지 않는다.
- 조회와 동기화는 현재 사용자 id 소유 기록만 대상으로 한다(비로그인이면 guest)
- 인수 조건(F-10): 로그인 후 앱을 껐다 켜도 로그인 상태와 사용자 id가 유지되고, access 만료 시 자동 갱신된다.
- 이 Task에서 정하는 규칙:
  - user JSON: `{"id": int, "email": str, "nickname": str}`. `/api/users/me/` 응답은 `{"user": {...}, "profile": {...}}`(Q-01 확정 전 가정)
  - 로그인 성공 시 토큰 write와 `writeUserId(user.id)`
  - 회원가입 성공 후 같은 정보로 바로 로그인
  - 400 응답 문구는 본문 `detail` 또는 첫 필드 오류의 첫 문장, 없으면 '입력 내용을 확인해 주세요'
  - `restore()`: 토큰이나 사용자 id가 없으면 토큰을 지우고 signedOut. 있으면 `/api/users/me/`로 확인. 네트워크 오류면 토큰을 지우지 않고 signedIn(userId는 저장된 값, user 없음)
  - `SessionEvents.expired`를 받으면 signedOut(로컬 기록은 그대로)
  - `logout()`: 토큰과 사용자 id만 지움(로컬 DB는 건드리지 않음)
  - 현재 사용자 id: signedIn이면 `AuthState.userId`, signedOut이나 unknown이면 null(guest)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `apiClientProvider`, `ApiErrorKind`, `classifyError` | `app/lib/core/network/api_client.dart` | `final apiClientProvider = Provider<Dio>(...)`, `enum ApiErrorKind { network, server, badRequest, unauthorized, forbidden, notFound, conflict, tooManyRequests, clientError, unknown }`, `ApiErrorKind classifyError(Object error)` |
| `SessionEvents`, `sessionEventsProvider` | `app/lib/core/network/session_events.dart` | `class SessionEvents { Stream<void> get expired; void notifyExpired(); void dispose(); }` |
| `TokenStorage`, `AuthTokens`, `tokenStorageProvider` | `app/lib/core/storage/token_storage.dart` | `abstract class TokenStorage { Future<AuthTokens?> read(); Future<void> write(AuthTokens tokens); Future<int?> readUserId(); Future<void> writeUserId(int userId); Future<void> clear(); }` |
| `FakeHttpAdapter`, `FakeResponse`, `InMemoryTokenStorage` | `app/test/support/` | TASK-33, 34 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `AuthUser` | `app/lib/features/auth/data/auth_repository.dart` | `class AuthUser { const AuthUser({required int id, required String email, required String nickname}); factory AuthUser.fromJson(Map<String, dynamic> json); }` | TASK-43 |
| `AuthException`, `AuthErrorKind` | 같은 파일 | `enum AuthErrorKind { invalidCredentials, rejected, network, unknown }`, `class AuthException implements Exception { const AuthException(this.kind, [this.message]); final AuthErrorKind kind; final String? message; }` | TASK-36 |
| `AuthRepository` | 같은 파일 | `abstract class AuthRepository { Future<AuthUser> login({required String email, required String password}); Future<void> signup({required String email, required String password, required String nickname}); Future<AuthUser?> currentUser(); Future<int?> storedUserId(); Future<void> logout(); }` | (내부) |
| `authRepositoryProvider` | 같은 파일 | `final authRepositoryProvider = Provider<AuthRepository>(...)` (`ApiAuthRepository`) | (내부) |
| `AuthStatus`, `AuthState` | `app/lib/features/auth/application/auth_controller.dart` | `enum AuthStatus { unknown, signedOut, signedIn }`, `class AuthState { const AuthState({required AuthStatus status, int? userId, AuthUser? user}); }` (signedIn이면 userId가 있음) | TASK-37, 39, 40, 41, 43, 47, 55 |
| `AuthController` | 같은 파일 | `class AuthController extends Notifier<AuthState> { Future<void> restore(); Future<void> login({required String email, required String password}); Future<void> signup({required String email, required String password, required String nickname}); Future<void> logout(); }` (실패는 `AuthException` throw) | TASK-36, 40, 44 |
| `authControllerProvider` | 같은 파일 | `final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);` (build에서 restore 시작, 초기 status unknown) | TASK-36, 37, 39, 40, 41, 43, 44, 47, 55 |
| `currentUserIdProvider` | 같은 파일 | `final currentUserIdProvider = Provider<int?>(...)` (signedIn이면 userId, 아니면 null = guest) | TASK-39, 40, 41, 42, 47 |

## 범위
- 위 저장소와 컨트롤러, provider

## 범위 밖 (건드리지 않음)
- 화면, 라우팅(TASK-36, 37), 프로필 필드(TASK-43), guest 기록 귀속(TASK-55)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 로그인 | 가짜 서버 login 200(user id 7) | signedIn, userId 7, user 닉네임, 저장소에 토큰과 사용자 id 7, currentUserIdProvider 7 |
| 재시작 후 유지 (F-10) | 토큰과 userId 7이 든 InMemoryTokenStorage로 새 ProviderContainer, `/api/users/me/` 200 | restore 후 signedIn, userId 7 |
| 재시작 시 access 만료 (F-10) | me 첫 응답 401, refresh 200, 재시도 200 | signedIn, userId 7 |
| 재시작 시 오프라인 | 토큰과 userId 7, me가 네트워크 오류 | signedIn, userId 7, user null, 토큰 유지 |
| 잘못된 비밀번호 | login 401 | `AuthException(invalidCredentials)`, signedOut, currentUserIdProvider null |
| 중복 이메일 | signup 400 `{"email": ["이미 가입된 이메일이에요."]}` | `AuthException(rejected, '이미 가입된 이메일이에요.')` |
| 회원가입 후 자동 로그인 | signup 201, login 200 | signedIn |
| 만료 신호와 로그아웃 | signedIn에서 `notifyExpired()` / 다시 로그인 후 logout | 둘 다 signedOut, currentUserIdProvider null / 토큰과 사용자 id 삭제 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/auth/data/auth_repository.dart`
- `app/lib/features/auth/application/auth_controller.dart`
- `app/test/features/auth/auth_controller_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-10 인수 조건(로직) 충족
- [ ] 비밀번호를 로그, 상태에 남기지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 서버 응답 형식이 확정되어(Q-01) 위 가정과 다를 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 사용자 id 저장과 복원, `AuthState.userId`, `currentUserIdProvider`(비로그인은 guest = null), `AuthRepository.storedUserId` 추가
- 로그아웃과 만료가 로컬 기록을 지우지 않음을 명시. 테스트: 오프라인 재시작 추가, 만료와 로그아웃 합침. 선행 Task에 TASK-33 명시
