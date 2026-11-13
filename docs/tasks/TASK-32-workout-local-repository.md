# TASK-32: 운동 기록 로컬 저장소(소유자별 저장과 조회)

- 상태: 대기
- 선행 Task: TASK-17, TASK-31
- 실행 방식: 순차
- 실행 방식 근거: DB 접근 계층, 동기화와 기록 화면이 기댐
- Spec 출처: F-11, F-12 (3장, 4장 정상 흐름 운동 9번, 계정 3번, 7장 로컬 기록 소유 규칙, 8장 보안)

## 왜 이렇게 나눴나
화면과 동기화가 drift 테이블을 직접 만지지 않도록 `WorkoutSummary` 단위로 저장하고 읽는 저장소를 둔다. guest 귀속과 동기화 실패 횟수는 TASK-54에서 같은 파일에 더한다.

## 기능 범위 (Spec 발췌)
- 결과는 로그인 여부와 관계없이 로컬 DB에 저장한다. 로그인 상태면 그 사용자 소유로, 비로그인이면 소유자 없음(guest)으로 저장
- 조회(기록 목록, 상세, 홈 요약)와 동기화는 현재 사용자 id 소유 기록만 대상으로 한다. 비로그인 상태에서는 guest 기록만 보인다
- 로컬 기록은 소유자별로 구분하며, 다른 계정의 기록을 조회하거나 동기화하지 않는다
- 기록 화면: 날짜별 세션 목록(동기화 상태 표시), 세션 상세(세트별 횟수, 반복별 점수, 오류 빈도)
- 이 Task에서 정하는 규칙:
  - `userId` 인자가 null이면 guest(`user_id IS NULL`)를 뜻한다
  - 같은 clientId를 다시 저장하면 아무것도 하지 않음(중복 저장 방지)
  - 목록은 startedAt 최신순, `from`/`to`는 startedAt 기준 [from, to) 범위
  - 저장 직후 상태는 pending, syncAttempts 0
  - `findSummary`는 소유자가 다르면 null
  - `pendingSummaries`는 그 사용자 소유이고 pending인 것만(guest는 동기화하지 않음)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `AppDatabase`, 테이블 | `app/lib/core/storage/app_database.dart` | `class AppDatabase extends _$AppDatabase { AppDatabase(QueryExecutor executor); }`, `WorkoutSessions`(userId nullable, syncStatus, syncAttempts, lastError 포함), `WorkoutSets`, `RepRecords` (TASK-31 계약 그대로) |
| `appDatabaseProvider` | 같은 파일 | `final appDatabaseProvider = Provider<AppDatabase>(...)` |
| `SyncStatus` | `app/lib/features/history/domain/sync_status.dart` | `enum SyncStatus { pending, synced, failed, rejected }`, `code`, `label`, `static SyncStatus fromCode(String code)` |
| `WorkoutSummary`, `SetSummary` | `app/lib/features/workout/domain/workout_summary.dart` | `class SetSummary { const SetSummary({required int setIndex, required int targetReps, required int restSec, required List<RepResult> reps, int partialReps = 0}); int get doneReps; int get avgScore; }`, `class WorkoutSummary { const WorkoutSummary({required String clientId, required ExerciseType exercise, required RoutineLevel level, required DateTime startedAt, required DateTime endedAt, required List<SetSummary> sets}); int get totalReps; int get totalPartialReps; int get avgScore; List<MapEntry<PoseErrorCode, int>> get topErrors; }` |
| `RepResult`, `PoseErrorCode`, `ExerciseType`, `RoutineLevel` | 각 파일 | `PoseErrorCode.fromCode`, `ExerciseType.fromCode`, `RoutineLevel.code` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SessionListItem` | `app/lib/features/history/data/workout_local_repository.dart` | `class SessionListItem { const SessionListItem({required String clientId, required ExerciseType exercise, required DateTime startedAt, required int totalReps, required int avgScore, required SyncStatus syncStatus}); }` | TASK-41, 47 |
| `WorkoutLocalRepository` | 같은 파일 | `class WorkoutLocalRepository { WorkoutLocalRepository(AppDatabase db); Future<void> saveSummary(WorkoutSummary summary, {required int? userId}); Stream<List<SessionListItem>> watchSessions({required int? userId, DateTime? from, DateTime? to}); Future<WorkoutSummary?> findSummary(String clientId, {required int? userId}); Future<SyncStatus?> statusOf(String clientId); Stream<SyncStatus?> watchStatus(String clientId); Future<List<WorkoutSummary>> pendingSummaries({required int userId}); Future<void> markSynced(String clientId); Future<void> markRejected(String clientId, String reason); }` | TASK-39, 40, 41, 42, 47, 54 |
| `workoutLocalRepositoryProvider` | 같은 파일 | `final workoutLocalRepositoryProvider = Provider<WorkoutLocalRepository>(...)` | TASK-39, 40, 41, 42, 47 |

## 범위
- 위 저장소. 저장은 한 트랜잭션

## 범위 밖 (건드리지 않음)
- guest 귀속, 5xx 시도 횟수와 failed, 수동 재시도(TASK-54), 서버 업로드(TASK-38, 39), 화면

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 저장 후 상세 복원 (F-12) | 2세트 요약(partialReps 0, 2) saveSummary(userId: 7) → findSummary(userId: 7) | 세트별 doneReps, partialReps, 반복 점수, 오류 코드가 같음 |
| 미동기화로 시작 (F-11) | 저장 후 watchSessions(userId: 7) 첫 값 | syncStatus pending |
| 중복 저장 무시 | 같은 요약 두 번 저장 | 세션 1건 |
| 상태 변경 반영 (F-11) | markSynced / markRejected | 목록 스트림과 watchStatus가 synced / rejected로 바뀜 |
| 소유자 구분 (F-12) | userId 7 기록 1건, 8 기록 1건, guest 1건 | watchSessions(userId: 7)은 7의 것만, (userId: null)은 guest만, findSummary(7의 clientId, userId: 8)은 null |
| 대기 목록 | 7의 pending 2건, 7의 synced 1건, 8의 pending 1건, guest pending 1건 | pendingSummaries(userId: 7) 2건 |
| 날짜 범위와 정렬 | 3일에 걸친 세션, from/to 지정 | 범위 안만, 최신순 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/history/data/workout_local_repository.dart`
- `app/test/features/history/data/workout_local_repository_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때(특히 스키마 변경이 필요할 때)
- `WorkoutSummary`를 DB 값만으로 복원할 수 없을 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 저장, 목록, 상세, 대기 목록에 소유자(`userId`, null은 guest) 인자 추가, `watchStatus` 추가. 소유자 구분 테스트 추가
- guest 귀속, 시도 횟수, 수동 재시도는 TASK-54로 분리
