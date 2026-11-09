# TASK-37: 인증 가드와 토큰 만료 이동

- 상태: 대기
- 선행 Task: TASK-27, TASK-36
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일)와 인증 상태를 묶는 보안 작업
- Spec 출처: F-10 (3장, 4장 예외 흐름 토큰 만료)

## 왜 이렇게 나눴나
"어느 화면이 로그인을 요구하는가"와 "만료되면 어디로 가는가"를 라우터 redirect 한곳에 모은다.

## 기능 범위 (Spec 발췌)
- 운동은 로그인 없이 가능, 기록 저장 시 로그인 요구
- 토큰 만료: refresh로 갱신 시도, 실패하면 로그인 화면으로 이동(운동 중이면 세션 종료 후 이동)
- 이 Task에서 정하는 규칙:
  - 로그인 필요 경로: `/history`, `/history/:id`, `/profile`
  - status unknown(복원 중)일 때는 redirect하지 않음
  - signedOut이고 로그인 필요 경로면 `AppRoutes.loginLocation(from: 현재 경로)`
  - signedIn인데 `/login`, `/signup`이면 `/`
  - signedIn → signedOut으로 바뀌었고 운동 중(`activeWorkoutProvider`가 null 아님)이면 그 운동의 `finish()`를 먼저 호출한 뒤 `/login`
  - 사용자가 직접 로그아웃한 경우에도 같은 규칙(로그인 필요 경로면 이동)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `buildRouter`, `routerProvider` | `app/lib/app/router.dart` | `GoRouter buildRouter({required bool enableDevMenu, Listenable? refreshListenable, GoRouterRedirect? redirect})`, `final routerProvider = Provider<GoRouter>(...)` |
| `AppRoutes.loginLocation` | `app/lib/app/routes.dart` | `static String loginLocation({String? from})` (`/login?from=<인코딩된 경로>`) |
| `authControllerProvider`, `AuthState`, `AuthStatus` | `app/lib/features/auth/application/auth_controller.dart` | `enum AuthStatus { unknown, signedOut, signedIn }`, `class AuthState { const AuthState({required AuthStatus status, AuthUser? user}); }` |
| `activeWorkoutProvider`, `workoutControllerProvider` | `app/lib/features/workout/application/workout_controller.dart` | `final activeWorkoutProvider = NotifierProvider<ActiveWorkoutNotifier, ExerciseType?>(ActiveWorkoutNotifier.new);`, `Future<void> finish();` |
| `InMemoryTokenStorage`, `FakeHttpAdapter` | `app/test/support/` | 테스트에서만 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `authRedirect` | `app/lib/app/auth_redirect.dart` | `String? authRedirect({required AuthStatus status, required Uri location})` (순수 함수) | (라우터) |
| `kProtectedPaths` | 같은 파일 | `const List<String> kProtectedPaths = ['/history', '/profile'];` (접두어 비교) | (내부) |
| `AuthRefreshListenable` | 같은 파일 | `class AuthRefreshListenable extends ChangeNotifier { AuthRefreshListenable(Ref ref); }` | (라우터) |

## 범위
- 위 함수와 Listenable, `routerProvider`에서 redirect와 refreshListenable 연결, 만료 시 운동 종료 처리

## 범위 밖 (건드리지 않음)
- 화면 내용, 토큰 갱신 로직(TASK-34)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 운동은 로그인 없이 | signedOut, `/workout/squat/setup` | redirect null |
| 기록은 로그인 요구 | signedOut, `/history` | `/login?from=%2Fhistory` |
| 복원 중 대기 | unknown, `/history` | null |
| 로그인 상태에서 로그인 화면 | signedIn, `/login` | `/` |
| 만료 시 로그인으로 (F-10) | signedIn으로 `/history`에 있다가 `SessionEvents.notifyExpired()` | 경로가 `/login?from=...` |
| 운동 중 만료 | activeWorkout squat 상태에서 만료 | 가짜 운동 컨트롤러 finish 1회 후 `/login` |

## 바뀔 것으로 예상되는 파일
- `app/lib/app/auth_redirect.dart`
- `app/lib/app/router.dart`
- `app/test/app/auth_redirect_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- `buildRouter` 계약을 바꿔야 할 때

## 추가 발췌 (오케스트레이터가 보충)
