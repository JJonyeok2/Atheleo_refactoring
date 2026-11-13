# TASK-55: 자동 동기화 실행 시점과 guest 기록 귀속

- 상태: 대기
- 선행 Task: TASK-03, TASK-35, TASK-39, TASK-54
- 실행 방식: 순차
- 실행 방식 근거: 앱 진입점(`main.dart`)을 고치고 인증 상태 변화에 묶이는 공유 서비스
- Spec 출처: F-11 (3장, 4장 정상 흐름 계정 2번, 자동 동기화 실행 시점, 7장 로컬 기록 소유 규칙, 9장 인수 조건 F-11)

## 왜 이렇게 나눴나
동기화 한 회차의 처리(TASK-39)와 "언제 회차를 시작하는가"를 나눴다. 기록 화면을 열지 않아도 동기화되려면 서비스가 앱 시작 직후 만들어져야 하므로 진입점 연결도 여기서 한다.

## 기능 범위 (Spec 발췌)
- 실행 시점: 앱 시작 직후(특정 화면을 열지 않아도), 로그인 직후, 네트워크 복구 시, 운동 기록 저장 시(저장 시점은 TASK-40)
- 비로그인 상태에서는 동기화하지 않는다.
- 로그인하면 로컬 DB의 guest 기록을 그 계정 소유로 바꾸고 동기화 대상에 넣는다.
- 인수 조건(F-11): 네트워크 복구 후 기록 화면을 열지 않아도 자동으로 "동기화됨"이 된다. 앱을 새로 켜기만 해도 미동기화 기록이 올라간다. 비로그인으로 운동한 기록은 로그인 직후 그 계정 기록 목록에 보이고 동기화된다.
- 이 Task에서 정하는 규칙:
  - `SyncService.start()`: 인증 상태와 네트워크 상태를 구독한다
  - 인증 상태가 signedIn(userId 있음)으로 바뀔 때마다(앱 시작 복원, 로그인 모두): `claimGuestSessions(userId)` 후 `syncPending()`
  - `onlineChanges`에서 true가 오면 `syncPending()`(비로그인이면 TASK-39 규칙대로 아무것도 안 함)
  - `syncServiceProvider`는 생성될 때 `start()`를 부른다
  - 앱 시작 직후 생성: `AppStartup` 위젯이 initState에서 `syncServiceProvider`를 읽는다. `main.dart`의 bootstrap은 `run(ProviderScope(child: AppStartup(child: AtheleoApp())))`으로 띄운다. `bootstrap({AppEnv? env, void Function(Widget app) run})` 시그니처와 "validate가 run보다 먼저" 순서는 그대로

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `SyncService`, `syncServiceProvider` | `app/lib/features/history/application/sync_service.dart` | `class SyncService { SyncService(Ref ref); Future<void> syncPending(); Future<void> retryFailed(String clientId); void dispose(); }` (TASK-39 구현) |
| `NetworkStatus`, `networkStatusProvider` | `app/lib/core/network/network_status.dart` | `abstract class NetworkStatus { Stream<bool> get onlineChanges; Future<bool> isOnline(); }` |
| `WorkoutLocalRepository.claimGuestSessions` | `app/lib/features/history/data/workout_local_repository.dart` | `Future<int> claimGuestSessions(int userId)` |
| `authControllerProvider`, `AuthState`, `AuthStatus` | `app/lib/features/auth/application/auth_controller.dart` | `enum AuthStatus { unknown, signedOut, signedIn }`, `class AuthState { const AuthState({required AuthStatus status, int? userId, AuthUser? user}); }` |
| `AtheleoApp`, `bootstrap` | `app/lib/app/app.dart`, `app/lib/main.dart` | `class AtheleoApp extends ConsumerWidget`, `Future<void> bootstrap({AppEnv? env, void Function(Widget app) run = runApp})` (TASK-03 완료, 시그니처 유지) |
| `InMemoryTokenStorage`, `FakeHttpAdapter`, `FakeResponse` | `app/test/support/` | 테스트에서만 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SyncService.start` | `app/lib/features/history/application/sync_service.dart` | `void start()` (위 구독, 두 번 불러도 한 번만 구독) | (provider 내부) |
| `syncServiceProvider` | 같은 파일 | 생성 시 `start()`, dispose 시 구독 해제 | TASK-40, 41 |
| `AppStartup` | `app/lib/app/app_startup.dart` | `class AppStartup extends ConsumerStatefulWidget { const AppStartup({super.key, required Widget child}); }` (initState에서 syncServiceProvider 생성, child를 그대로 그림) | TASK-48 |

## 범위
- `start()` 구독, provider 생성 시 start, `AppStartup`, `main.dart`의 run 위젯 감싸기

## 범위 밖 (건드리지 않음)
- 회차 처리 규칙(TASK-39), 저장 직후 동기화(TASK-40), Sentry 초기화(TASK-48), `app.dart`(AtheleoApp 내용)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 앱 시작만으로 동기화 (F-11) | 토큰과 userId 7 저장, 7의 pending 1건, 가짜 서버 201 → ProviderContainer에서 syncServiceProvider만 읽음(화면 없음) | 복원 뒤 upload 1회, synced |
| 로그인 직후 귀속과 동기화 (F-11) | signedOut에서 guest 기록 1건 → login(user id 7), 가짜 서버 201 | 그 기록 user_id 7, synced |
| 네트워크 복구 (F-11) | signedIn, 오프라인으로 pending 남은 1건 → 가짜 NetworkStatus가 true 발행 | synced |
| 비로그인은 그대로 | signedOut, guest 1건, 네트워크 복구 | upload 0회, guest 그대로 |
| AppStartup이 서비스 생성 | `ProviderScope(overrides: [syncServiceProvider 가짜], child: AppStartup(child: SizedBox()))` pump | 가짜 서비스가 만들어지고 start 1회 |
| bootstrap 순서 유지 | 기존 `test/smoke_test.dart`의 bootstrap 테스트 2건 + run이 받은 위젯 확인 | 둘 다 통과, run이 받은 위젯 트리에 `AppStartup`이 있음 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/history/application/sync_service.dart`
- `app/lib/app/app_startup.dart`
- `app/lib/main.dart`
- `app/test/features/history/application/sync_triggers_test.dart`
- `app/test/smoke_test.dart`(run 위젯 확인 1건 추가)

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트(특히 bootstrap 2건, TASK-39)가 깨지지 않음
- [ ] F-11 자동 동기화, guest 귀속 인수 조건(로직) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- bootstrap 시그니처를 바꿔야 할 때
- 앱이 꺼져 있을 때 동기화(WorkManager 등)가 필요하다고 판단될 때(Spec 밖)

## 추가 발췌 (오케스트레이터가 보충)
