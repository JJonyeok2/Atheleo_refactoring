# TASK-39: 동기화 서비스(재시도 큐)

- 상태: 대기
- 선행 Task: TASK-32, TASK-35, TASK-38
- 실행 방식: 순차
- 실행 방식 근거: 로컬 DB 상태를 바꾸고 여러 화면이 기대는 공유 서비스
- Spec 출처: F-11 (3장, 4장 예외 흐름 네트워크, 서버 400, 8장 모니터링, 9장 인수 조건)

## 왜 이렇게 나눴나
대기 중인 기록을 올리고 결과에 따라 로컬 상태를 바꾸는 반복 작업이다. 네트워크 감시는 인터페이스로 감싸 테스트한다.

## 기능 범위 (Spec 발췌)
- 로컬 DB에 먼저 저장 후 서버 동기화. 5xx와 네트워크 오류만 재시도
- 네트워크가 끊겼을 때: 기록을 로컬에 저장하고 "나중에 자동으로 동기화됩니다" 표시, 연결 복구 시 재시도
- 서버가 400을 돌려줄 때: 해당 기록은 재시도 목록에서 제외하고 Sentry에 보고(개인 식별 정보 제외)
- 인수 조건(F-11): 비행기 모드에서 운동을 마치면 기록 목록에 "미동기화"로 보이고, 네트워크 복구 후 자동으로 "동기화됨"이 된다. 서버가 400을 주면 "저장 실패"로 표시되고 다시 시도하지 않는다.
- 이 Task에서 정하는 규칙:
  - `syncPending()`은 로그인 상태(signedIn)에서만 실행, 동시에 한 번만(실행 중 호출은 같은 Future 반환)
  - 실행 시점: 앱 시작 후 로그인 확인, 로그인 성공, 네트워크 복구, 저장 직후(TASK-40)
  - 한 번 실행에서 `UploadRetryLater`가 나오면 그 회차는 멈춤(남은 기록은 다음 회차)
  - 400 보고: `errorReporter.report(..., tag: 'sync_rejected', context: {'client_id': clientId})`. 이메일, 닉네임은 넣지 않음

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `WorkoutLocalRepository`, `workoutLocalRepositoryProvider` | `app/lib/features/history/data/workout_local_repository.dart` | `Future<List<WorkoutSummary>> pendingSummaries(); Future<void> markSynced(String clientId); Future<void> markRejected(String clientId, String reason);` |
| `WorkoutRemoteApi`, `UploadOutcome` 계열, `workoutRemoteApiProvider` | `app/lib/features/history/data/workout_remote_api.dart` | `abstract class WorkoutRemoteApi { Future<UploadOutcome> upload(WorkoutSummary summary); }`, `UploadSynced`, `UploadRejected(reason)`, `UploadRetryLater(kind)` |
| `authControllerProvider`, `AuthStatus` | `app/lib/features/auth/application/auth_controller.dart` | `enum AuthStatus { unknown, signedOut, signedIn }` |
| `ErrorReporter`, `errorReporterProvider` | `app/lib/core/monitoring/error_reporter.dart` | `Future<void> report(Object error, StackTrace? stackTrace, {String? tag, Map<String, Object?> context = const {}})` |
| 의존성 | `app/pubspec.yaml` | connectivity_plus 이미 추가됨 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `NetworkStatus` | `app/lib/core/network/network_status.dart` | `abstract class NetworkStatus { Stream<bool> get onlineChanges; Future<bool> isOnline(); }`, `final networkStatusProvider = Provider<NetworkStatus>(...)` (connectivity_plus 구현) | TASK-40 |
| `SyncService` | `app/lib/features/history/application/sync_service.dart` | `class SyncService { SyncService(Ref ref); Future<void> syncPending(); void start(); void dispose(); }` (start는 네트워크 복구, 로그인 이벤트 구독) | TASK-40, 41 |
| `syncServiceProvider` | 같은 파일 | `final syncServiceProvider = Provider<SyncService>(...)` (생성 시 start, dispose 시 해제) | TASK-40, 41 |

## 범위
- 위 클래스

## 범위 밖 (건드리지 않음)
- 화면 표시(TASK-40, 41), Sentry 실제 연결(TASK-48)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 오프라인이면 미동기화 유지 (F-11) | pending 1건, 가짜 원격 RetryLater(network) | 상태 pending |
| 복구 후 동기화됨 (F-11) | 가짜 NetworkStatus가 true 발행, 원격 Synced | 상태 synced |
| 400은 저장 실패, 재시도 없음 (F-11) | 원격 Rejected | rejected, 가짜 보고기에 'sync_rejected' 1건, 다음 syncPending에서 upload 호출 0회 |
| 409도 동기화됨 | 원격 Synced(409를 가정) | synced |
| 로그아웃 상태 | signedOut | upload 호출 0회 |
| 재시도에서 멈춤 | pending 3건 중 2번째가 RetryLater | 1번째 synced, 3번째 호출 안 됨 |
| 동시 호출 하나로 | syncPending 두 번 연달아 | upload 호출이 건마다 1회 |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/network/network_status.dart`
- `app/lib/features/history/application/sync_service.dart`
- `app/test/features/history/application/sync_service_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-11 인수 조건(로직) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 앱이 꺼져 있을 때 동기화(WorkManager 등)가 필요하다고 판단될 때(Spec 밖)

## 추가 발췌 (오케스트레이터가 보충)
