# TASK-54: 기록 guest 귀속과 동기화 실패 횟수

- 상태: 대기
- 선행 Task: TASK-32
- 실행 방식: 순차
- 실행 방식 근거: TASK-32와 같은 저장소 파일을 고치고, 동기화(TASK-39, 55)와 기록 화면(TASK-41)이 기댐
- Spec 출처: F-11, F-12 (4장 정상 흐름 계정 2번, 자동 동기화 표, 7장 로컬 기록 소유 규칙, 9장 인수 조건)

## 왜 이렇게 나눴나
저장소 기본 기능(TASK-32)과 "소유자가 바뀌거나 상태가 실패로 넘어가는 규칙"을 나눠 Task 하나의 테스트가 8건을 넘지 않게 했다.

## 기능 범위 (Spec 발췌)
- 로그인하면 guest 기록 전부를 그 사용자 id로 바꾸고 `pending`으로 동기화 대상에 넣는다.
- 5xx: 그 기록만 건너뛰고 다음 기록 진행, 시도 횟수 1 증가. 5회 미만이면 `pending`, 5회 도달 시 `failed`(자동 재시도 중단)
- 기록별 시도 횟수 5회 상한은 서버 오류(5xx)만 센다.
- 기록 화면에서 `failed` 기록은 수동 재시도할 수 있다. 수동 재시도는 시도 횟수를 0으로 되돌리고 `pending`으로 바꾼다(즉시 동기화는 TASK-39)
- 인수 조건:
  - F-11: 5회 연속 5xx면 "실패"로 표시되고 자동 재시도가 멈춘다. 비로그인으로 운동한 기록은 로그인 직후 그 계정 기록 목록에 보인다.
  - F-12: "실패" 기록의 재시도 버튼을 누르면 다시 동기화를 시도한다(상태 되돌리기 부분).
- 이 Task에서 정하는 규칙:
  - `claimGuestSessions(userId)`: `user_id IS NULL`인 모든 세션을 userId로 바꾸고 syncStatus pending, syncAttempts 0. 바꾼 개수 반환
  - `recordServerFailure(clientId, reason)`: syncAttempts + 1, lastError = reason. 결과가 maxAttempts 이상이면 failed, 아니면 pending. 바뀐 상태 반환
  - `retryFailed(clientId)`: failed인 것만 pending, syncAttempts 0, lastError null. 아니면 아무것도 안 함

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `WorkoutLocalRepository` | `app/lib/features/history/data/workout_local_repository.dart` | TASK-32 계약: `Future<void> saveSummary(WorkoutSummary summary, {required int? userId}); Stream<List<SessionListItem>> watchSessions({required int? userId, DateTime? from, DateTime? to}); Future<SyncStatus?> statusOf(String clientId); Future<List<WorkoutSummary>> pendingSummaries({required int userId});` 등 |
| 테이블 | `app/lib/core/storage/app_database.dart` | `WorkoutSessions`(userId nullable, syncStatus, syncAttempts 기본 0, lastError nullable) |
| `SyncStatus` | `app/lib/features/history/domain/sync_status.dart` | `enum SyncStatus { pending, synced, failed, rejected }` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutLocalRepository.claimGuestSessions` | `app/lib/features/history/data/workout_local_repository.dart` | `Future<int> claimGuestSessions(int userId)` | TASK-55 |
| `WorkoutLocalRepository.recordServerFailure` | 같은 파일 | `Future<SyncStatus> recordServerFailure(String clientId, String reason, {int maxAttempts = 5})` | TASK-39 |
| `WorkoutLocalRepository.retryFailed` | 같은 파일 | `Future<void> retryFailed(String clientId)` | TASK-39 |

## 범위
- 위 메서드 3개

## 범위 밖 (건드리지 않음)
- 언제 귀속하고 언제 재시도하는지(TASK-39, 55), 화면(TASK-41)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| guest 귀속 (F-11) | guest 2건, userId 8 기록 1건 → claimGuestSessions(7) | 반환 2, watchSessions(userId: 7) 2건 pending, guest 0건, 8의 기록 그대로 |
| 5xx 횟수 상한 (F-11) | 7의 pending 1건에 recordServerFailure 4번 / 5번째 | 4번째까지 pending, pendingSummaries에 포함 / failed, pendingSummaries에서 빠짐, lastError가 마지막 사유 |
| 수동 재시도 상태 (F-12) | failed 기록 retryFailed / synced 기록 retryFailed | pending, 다시 pendingSummaries에 포함, 그 뒤 recordServerFailure 1번이면 아직 pending / synced 그대로 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/history/data/workout_local_repository.dart`
- `app/test/features/history/data/workout_local_repository_sync_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] TASK-32 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때(특히 스키마 변경)
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
