# TASK-37: 인증 가드와 토큰 만료 이동

- 상태: 대기
- 선행 Task: TASK-03, TASK-34, TASK-35, TASK-36
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일)와 인증 상태를 묶는 보안 작업
- Spec 출처: F-10, F-12 (3장, 4장 예외 흐름 토큰 만료, 7장 로컬 기록 소유 규칙, 9장 인수 조건 F-10)

## 왜 이렇게 나눴나
"어느 화면이 로그인을 요구하는가"와 "만료되면 어디로 가는가"를 라우터 한곳에 모은다. 운동 세션 중인지는 현재 경로로 판단해 운동 컨트롤러에 기대지 않는다.

## 기능 범위 (Spec 발췌)
- 운동은 로그인 없이 가능. 비로그인 상태의 기록 화면에는 guest 기록만 보인다(기록 화면은 로그인 없이 열림)
- 토큰 만료: refresh로 갱신 시도. 실패했을 때
  - 운동 세션 중(촬영 가이드, 운동, 휴식): 화면을 옮기지 않고 운동을 계속한다. 결과 화면에서 저장, 동기화할 때 "로그인이 필요합니다" 안내(needLogin 흐름, TASK-40)를 보여 주고, 기록은 로컬에 그대로 남는다.
  - 운동 세션 밖의 화면: 로그인 화면으로 이동
- 인수 조건(F-10): 운동 중 refresh까지 만료되면 운동 화면이 그대로 유지되고, 결과 화면에서 "로그인이 필요합니다" 안내가 나온다. 운동 세션 밖 화면에서 refresh가 만료되면 로그인 화면으로 이동한다.
- 이 Task에서 정하는 규칙:
  - 로그인 필요 경로: `/profile`만(기록 `/history`, `/history/:id`는 guest 기록을 보여 주므로 로그인 불필요)
  - status unknown(복원 중)일 때는 redirect하지 않음
  - signedOut이고 로그인 필요 경로면 `AppRoutes.loginLocation(from: 현재 경로)`
  - signedIn인데 `/login`, `/signup`이면 `/`
  - 운동 경로: `/workout/`으로 시작하는 경로(촬영 가이드, 운동, 결과)
  - `SessionEvents.expired`를 받았을 때: 현재 경로가 운동 경로이거나 `/login`, `/signup`이면 이동하지 않음. 그 밖이면 `AppRoutes.loginLocation(from: 현재 경로)`로 이동
  - 만료로 운동을 끝내거나 감지기를 멈추지 않는다
  - 사용자가 직접 로그아웃하면 만료 이동은 하지 않고 redirect 규칙만 적용(로그인 필요 경로에 있으면 이동)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `buildRouter`, `routerProvider` | `app/lib/app/router.dart` | `GoRouter buildRouter({required bool enableDevMenu, Listenable? refreshListenable, GoRouterRedirect? redirect})`, `final routerProvider = Provider<GoRouter>(...)` |
| `AppRoutes.loginLocation` | `app/lib/app/routes.dart` | `static String loginLocation({String? from})` (`/login?from=<인코딩된 경로>`) |
| `authControllerProvider`, `AuthState`, `AuthStatus` | `app/lib/features/auth/application/auth_controller.dart` | `enum AuthStatus { unknown, signedOut, signedIn }`, `class AuthState { const AuthState({required AuthStatus status, int? userId, AuthUser? user}); }` |
| `SessionEvents`, `sessionEventsProvider` | `app/lib/core/network/session_events.dart` | `class SessionEvents { Stream<void> get expired; void notifyExpired(); void dispose(); }` |
| `InMemoryTokenStorage`, `FakeHttpAdapter` | `app/test/support/` | 테스트에서만 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `authRedirect` | `app/lib/app/auth_redirect.dart` | `String? authRedirect({required AuthStatus status, required Uri location})` (순수 함수) | (라우터) |
| `kProtectedPaths` | 같은 파일 | `const List<String> kProtectedPaths = ['/profile'];` (접두어 비교) | (내부) |
| `isWorkoutSessionPath` | 같은 파일 | `bool isWorkoutSessionPath(Uri location)` (`/workout/`으로 시작하면 true) | (내부) |
| `expiryRedirect` | 같은 파일 | `String? expiryRedirect(Uri location)` (만료 시 이동할 곳, 이동 안 하면 null) | (내부) |
| `AuthRefreshListenable` | 같은 파일 | `class AuthRefreshListenable extends ChangeNotifier { AuthRefreshListenable(Ref ref); }` | (라우터) |

## 범위
- 위 함수와 Listenable, `routerProvider`에서 redirect, refreshListenable 연결, 만료 신호 구독과 이동

## 범위 밖 (건드리지 않음)
- 화면 내용, 토큰 갱신 로직(TASK-34), 결과 화면의 로그인 안내(TASK-40), 운동 컨트롤러

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 운동과 기록은 로그인 없이 | signedOut, `/workout/squat/setup` / `/history` | 둘 다 redirect null |
| 프로필은 로그인 요구 | signedOut, `/profile` | `/login?from=%2Fprofile` |
| 복원 중 대기 | unknown, `/profile` | null |
| 로그인 상태에서 로그인 화면 | signedIn, `/login` | `/` |
| 운동 밖 화면에서 만료 (F-10) | signedIn으로 `/history`에 있다가 `notifyExpired()` | 경로 `/login?from=%2Fhistory` |
| 운동 중 만료는 이동 없음 (F-10) | `/workout/squat`, `/workout/squat/setup`, `/workout/result`에서 각각 `notifyExpired()` | 경로 그대로 |
| 만료 이동 판단 함수 | `expiryRedirect`에 `/`, `/workout/push_up`, `/login` | `/login?from=%2F`, null, null |

## 바뀔 것으로 예상되는 파일
- `app/lib/app/auth_redirect.dart`
- `app/lib/app/router.dart`
- `app/test/app/auth_redirect_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-10 만료 이동 인수 조건(라우팅 부분) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- `buildRouter` 계약을 바꿔야 할 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영(D3, D4)
- 운동 세션 중(`/workout/...`, 결과 화면 포함) 만료 시 이동하지 않고 운동을 끝내지도 않음. 운동 밖 화면은 로그인으로 이동
- `/history`는 guest 기록을 보여 주므로 로그인 필요 경로에서 뺌(`kProtectedPaths = ['/profile']`)
- `activeWorkoutProvider`, `workoutControllerProvider` 의존 삭제, 선행 Task를 TASK-27 대신 TASK-03, 34로. `isWorkoutSessionPath`, `expiryRedirect` 추가
