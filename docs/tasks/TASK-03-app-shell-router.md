# TASK-03: 앱 뼈대(라우터, 테마, 앱 위젯)

- 상태: 대기
- 선행 Task: TASK-02
- 실행 방식: 순차
- 실행 방식 근거: 라우팅은 공유 파일이고 이후 화면 Task가 모두 기댄다
- Spec 출처: 5장 화면 목록(경로), 8장(세로 고정)

## 왜 이렇게 나눴나
모든 경로를 자리표시 화면으로 먼저 등록해 둔다. 이후 화면 Task는 `router.dart`에서 자기 경로의 builder만 실제 화면으로 바꾼다.

## 기능 범위 (Spec 발췌)
| 화면 | 경로 |
|---|---|
| 홈 | `/` |
| 촬영 가이드 | `/workout/:type/setup` |
| 운동 | `/workout/:type` |
| 운동 결과 | `/workout/result` |
| 로그인 | `/login` |
| 회원가입 | `/signup` |
| 기록 목록 | `/history` |
| 기록 상세 | `/history/:id` |
| 프로필 | `/profile` |
| 개발자 메뉴 | `/dev` (디버그 빌드만) |

- 릴리스 빌드에는 개발자 메뉴가 없다(F-14 인수 조건 일부).

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `AppEnv` | `app/lib/app/env.dart` | `class AppEnv { const AppEnv({required String apiBaseUrl, required String sentryDsn, required bool isRelease}); factory AppEnv.fromEnvironment(); void validate(); }` (validate는 isRelease이고 apiBaseUrl이 `https://`로 시작하지 않으면 `StateError`) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `AppRoutes` | `app/lib/app/routes.dart` | `abstract final class AppRoutes` 상수 `home = '/'`, `login = '/login'`, `signup = '/signup'`, `history = '/history'`, `historyDetail = '/history/:id'`, `profile = '/profile'`, `dev = '/dev'`, `workoutResult = '/workout/result'`, `workoutSetup = '/workout/:type/setup'`, `workout = '/workout/:type'`, 함수 `static String workoutSetupPath(String type)`, `static String workoutPath(String type)`, `static String historyDetailPath(String id)` | 화면 Task 전체 |
| `buildRouter` | `app/lib/app/router.dart` | `GoRouter buildRouter({required bool enableDevMenu, Listenable? refreshListenable, GoRouterRedirect? redirect})` (enableDevMenu가 false면 `/dev` 경로 자체를 등록하지 않음) | TASK-25, 29, 30, 36, 37, 40, 41, 42, 44, 46, 47 |
| `routerProvider` | `app/lib/app/router.dart` | `final routerProvider = Provider<GoRouter>(...)` (기본 `buildRouter(enableDevMenu: kDebugMode)`) | TASK-37 |
| `PlaceholderScreen` | `app/lib/app/placeholder_screen.dart` | `class PlaceholderScreen extends StatelessWidget { const PlaceholderScreen({required String title}); }` | 화면 Task(교체 대상) |
| 없는 경로 화면 | `app/lib/app/router.dart` | errorBuilder가 '페이지를 찾을 수 없어요' 텍스트 표시 | TASK-25, 46 |
| `AtheleoApp` | `app/lib/app/app.dart` | `class AtheleoApp extends ConsumerWidget` (`MaterialApp.router`, `routerProvider` 사용) | TASK-48 |

## 범위
- `/workout/result`는 `/workout/:type`보다 먼저 등록해 `result`가 type으로 잡히지 않게 함
- `main.dart`: `WidgetsFlutterBinding.ensureInitialized()`, 세로 고정(`SystemChrome.setPreferredOrientations`), `AppEnv.fromEnvironment().validate()`, `ProviderScope(child: AtheleoApp())`
- 기본 테마(Material 3, 한국어 텍스트가 잘 보이는 기본 글꼴)

## 범위 밖 (건드리지 않음)
- 실제 화면, 인증 redirect(TASK-37), Sentry(TASK-48)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 홈 경로 | `buildRouter(enableDevMenu: true)`로 앱 띄우기 | `/`에서 PlaceholderScreen 표시 |
| result 경로 우선 | `/workout/result`로 이동 | 결과 자리표시 화면(제목에 '결과')이 보이고 운동 화면이 아님 |
| type 경로 | `AppRoutes.workoutPath('squat')`로 이동 | 운동 자리표시 화면 |
| 릴리스에는 개발자 메뉴 없음 (F-14) | `buildRouter(enableDevMenu: false)`에서 `/dev` 이동 | '페이지를 찾을 수 없어요' |
| 디버그에는 개발자 메뉴 있음 | `enableDevMenu: true`에서 `/dev` | 개발자 메뉴 자리표시 화면 |
| 경로 함수 | `workoutSetupPath('push_up')`, `historyDetailPath('abc')` | `/workout/push_up/setup`, `/history/abc` |

## 바뀔 것으로 예상되는 파일
- `app/lib/app/routes.dart`, `app/lib/app/router.dart`, `app/lib/app/app.dart`, `app/lib/app/placeholder_screen.dart`, `app/lib/main.dart`
- `app/test/app/router_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음(TASK-01 smoke 테스트는 `AtheleoApp` 기준으로 고쳐도 됨)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때
- 새 외부 서비스나 새 환경 변수가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)

- (오케스트레이터 보충, QA-TASK-02) 앱 시작 시 `AppEnv.fromEnvironment().validate()`를 반드시 호출한다(`isRelease`는 `fromEnvironment`가 정한다). 이 호출이 빠지면 릴리스 빌드의 http 주소 차단이 작동하지 않는다. 호출 여부를 확인하는 테스트(예: 시작 함수가 잘못된 설정에서 StateError를 내는지)를 "먼저 작성할 테스트"에 포함한다.
