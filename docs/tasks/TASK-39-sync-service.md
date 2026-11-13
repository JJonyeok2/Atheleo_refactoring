# TASK-39: 동기화 서비스(오류별 처리와 수동 재시도)

- 상태: 대기
- 선행 Task: TASK-02, TASK-35, TASK-38, TASK-54
- 실행 방식: 순차
- 실행 방식 근거: 로컬 DB 상태를 바꾸고 여러 화면이 기대는 공유 서비스
- Spec 출처: F-11, F-12 (3장, 4장 자동 동기화, 예외 흐름 네트워크, 8장 모니터링, 9장 인수 조건)

## 왜 이렇게 나눴나
대기 중인 기록을 한 회차 올리고 결과에 따라 로컬 상태를 바꾸는 부분만 다룬다. 언제 회차를 시작하는지(앱 시작, 로그인, 네트워크 복구)와 guest 귀속은 TASK-55에서 더한다.

## 기능 범위 (Spec 발췌)
- 대상: 현재 로그인 사용자 소유이고 상태가 `pending`인 기록만. 비로그인 상태에서는 동기화하지 않는다.

| 결과 | 처리 | 기록 상태 |
|---|---|---|
| 201, 409(중복 client_id) | 저장 성공으로 처리 | `synced` |
| 네트워크 오류 | 이번 회차 즉시 중단, 다음 회차에 다시 시도 | `pending` 유지 |
| 5xx | 그 기록만 건너뛰고 다음 기록 진행, 시도 횟수 1 증가 | 5회 미만이면 `pending`, 5회 도달 시 `failed`(자동 재시도 중단) |
| 400, 403, 404, 413, 422 등 재시도 불가 4xx | 거절, Sentry 보고 | `rejected`(자동 재시도 안 함) |
| 401 | refresh 갱신 시도, 실패하면 이번 회차 중단하고 로그인 필요 상태로 표시 | `pending` 유지 |
| 429 | 이번 회차 중단, 다음 회차에 다시 시도 | `pending` 유지 |

- 기록별 시도 횟수 5회 상한은 5xx만 센다. 네트워크 오류, 401, 429는 그 회차만 멈추고 세지 않는다
- 기록 화면에서 `failed` 기록은 수동 재시도할 수 있다. 수동 재시도는 시도 횟수를 0으로 되돌리고 `pending`으로 바꾼 뒤 즉시 동기화한다.
- 모니터링: 동기화 거절(rejected), 동기화 실패(failed)를 보고한다. 개인 식별 정보는 보내지 않는다.
- 인수 조건(F-11): 서버가 400(또는 403, 404, 413, 422)을 주면 "거절"로 표시되고 다시 시도하지 않는다. 서버가 5xx를 주면 그 기록만 건너뛰고 다음 기록은 올라가며, 5회 연속 5xx면 "실패"로 표시되고 자동 재시도가 멈춘다. F-12: "실패" 기록의 재시도 버튼을 누르면 다시 동기화를 시도한다.
- 이 Task에서 정하는 규칙:
  - `syncPending()`: `currentUserIdProvider`가 null이면 아무것도 안 함. 아니면 `pendingSummaries(userId: 그 id)`를 차례로 업로드. 동시에 한 번만(실행 중 호출은 같은 Future 반환)
  - 401(`UploadNeedsLogin`)의 "로그인 필요 상태"는 인터셉터가 낸 만료 신호로 인증 상태가 signedOut이 되는 것으로 나타난다(여기서 따로 상태를 두지 않음)
  - 보고: 거절은 `errorReporter.report(..., tag: 'sync_rejected', context: {'client_id': clientId})`, failed가 된 순간 `tag: 'sync_failed'`, context는 client_id와 HTTP 코드만. 이메일, 닉네임, 사용자 id는 넣지 않음

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `WorkoutLocalRepository`, `workoutLocalRepositoryProvider` | `app/lib/features/history/data/workout_local_repository.dart` | `Future<List<WorkoutSummary>> pendingSummaries({required int userId}); Future<void> markSynced(String clientId); Future<void> markRejected(String clientId, String reason); Future<SyncStatus> recordServerFailure(String clientId, String reason, {int maxAttempts = 5}); Future<void> retryFailed(String clientId);` |
| `WorkoutRemoteApi`, `UploadOutcome` 계열, `workoutRemoteApiProvider` | `app/lib/features/history/data/workout_remote_api.dart` | `abstract class WorkoutRemoteApi { Future<UploadOutcome> upload(WorkoutSummary summary); }`, `UploadSynced()`, `UploadRejected(reason)`, `UploadServerError(statusCode)`, `UploadRetryLater(kind)`, `UploadNeedsLogin()` |
| `currentUserIdProvider` | `app/lib/features/auth/application/auth_controller.dart` | `final currentUserIdProvider = Provider<int?>(...)` (signedIn이면 userId, 아니면 null) |
| `SyncStatus` | `app/lib/features/history/domain/sync_status.dart` | `enum SyncStatus { pending, synced, failed, rejected }` |
| `ErrorReporter`, `errorReporterProvider` | `app/lib/core/monitoring/error_reporter.dart` | `Future<void> report(Object error, StackTrace? stackTrace, {String? tag, Map<String, Object?> context = const {}})` |
| 의존성 | `app/pubspec.yaml` | connectivity_plus 이미 추가됨 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `NetworkStatus` | `app/lib/core/network/network_status.dart` | `abstract class NetworkStatus { Stream<bool> get onlineChanges; Future<bool> isOnline(); }` | TASK-40, 55 |
| `networkStatusProvider` | 같은 파일 | `final networkStatusProvider = Provider<NetworkStatus>(...)` (connectivity_plus 구현) | TASK-40, 55 |
| `SyncService` | `app/lib/features/history/application/sync_service.dart` | `class SyncService { SyncService(Ref ref); Future<void> syncPending(); Future<void> retryFailed(String clientId); void dispose(); }` (retryFailed는 저장소 retryFailed 후 syncPending) | TASK-40, 41, 55 |
| `syncServiceProvider` | 같은 파일 | `final syncServiceProvider = Provider<SyncService>(...)` (dispose 시 해제) | TASK-40, 41, 55 |

## 범위
- 위 클래스

## 범위 밖 (건드리지 않음)
- 회차 시작 시점(앱 시작, 로그인, 네트워크 복구)과 guest 귀속(TASK-55), 저장 직후 호출(TASK-40), 화면 표시(TASK-40, 41), Sentry 실제 연결(TASK-48)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 네트워크 오류와 429는 회차 중단 (F-11) | pending 3건 중 2번째가 RetryLater(network) / RetryLater(tooManyRequests) | 1번째 synced, 2번째 pending(시도 횟수 0), 3번째 upload 호출 안 됨 |
| 5xx는 건너뛰고 다음 진행 (F-11) | pending 2건, 1번째 ServerError(503), 2번째 Synced | 1번째 pending(시도 1), 2번째 synced |
| 5회 5xx면 실패와 보고 (F-11) | 같은 기록이 매번 ServerError로 syncPending 5번 | 5번째 뒤 failed, 'sync_failed' 보고 1건, 6번째 syncPending에서 upload 0회 |
| 거절과 보고 (F-11) | 원격 Rejected('bad') | rejected, 'sync_rejected' 1건(context에 client_id만), 다음 syncPending에서 upload 0회 |
| 401은 회차 중단 | pending 2건 중 1번째가 NeedsLogin | 둘 다 pending, 2번째 upload 호출 안 됨 |
| 비로그인은 동기화 안 함 | currentUserIdProvider null, guest pending 1건 | upload 0회 |
| 동시 호출 하나로 | syncPending 두 번 연달아 | upload 호출이 건마다 1회 |
| 수동 재시도 (F-12) | failed 기록 retryFailed, 원격 Synced | upload 1회, synced |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/network/network_status.dart`
- `app/lib/features/history/application/sync_service.dart`
- `app/test/features/history/application/sync_service_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-11(오류별 처리), F-12(수동 재시도) 인수 조건(로직) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 앱이 꺼져 있을 때 동기화(WorkManager 등)가 필요하다고 판단될 때(Spec 밖)

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 오류별 처리(네트워크와 429 중단, 5xx 건너뛰기와 5회 failed, 4xx 거절, 401 중단), 현재 사용자 소유만, `retryFailed` 추가, 'sync_failed' 보고
- 회차 시작 시점과 guest 귀속은 TASK-55로 분리(`start()` 삭제). 내보내기 표에 `networkStatusProvider`를 따로 적음
