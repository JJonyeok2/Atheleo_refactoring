# TASK-32: 운동 기록 로컬 저장소

- 상태: 대기
- 선행 Task: TASK-17, TASK-31
- 실행 방식: 순차
- 실행 방식 근거: DB 접근 계층, 동기화와 기록 화면이 기댐
- Spec 출처: F-11, F-12 (3장, 4장 정상 흐름 기록, 7장)

## 왜 이렇게 나눴나
화면과 동기화가 drift 테이블을 직접 만지지 않도록 `WorkoutSummary` 단위로 저장하고 읽는 저장소를 둔다.

## 기능 범위 (Spec 발췌)
- 운동 기록을 로컬 DB에 먼저 저장 후 서버 동기화
- 기록 화면: 날짜별 세션 목록(미동기화 표시), 세션 상세(세트별 횟수, 반복별 점수, 오류 빈도)
- 이 Task에서 정하는 규칙:
  - 같은 clientId를 다시 저장하면 아무것도 하지 않음(중복 저장 방지)
  - 목록은 startedAt 최신순
  - `from`/`to`는 startedAt 기준 [from, to) 범위
  - 저장 직후 상태는 pending

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `AppDatabase`, 테이블 | `app/lib/core/storage/app_database.dart` | `class AppDatabase extends _$AppDatabase { AppDatabase(QueryExecutor executor); }`, `WorkoutSessions`, `WorkoutSets`, `RepRecords` (TASK-31 계약 그대로) |
| `appDatabaseProvider` | 같은 파일 | `final appDatabaseProvider = Provider<AppDatabase>(...)` |
| `SyncStatus` | `app/lib/features/history/domain/sync_status.dart` | `enum SyncStatus { pending, synced, rejected }`, `code`, `label`, `static SyncStatus fromCode(String code)` |
| `WorkoutSummary`, `SetSummary` | `app/lib/features/workout/domain/workout_summary.dart` | `class SetSummary { const SetSummary({required int setIndex, required int targetReps, required int restSec, required List<RepResult> reps, int partialReps = 0}); int get doneReps; int get avgScore; }`, `class WorkoutSummary { const WorkoutSummary({required String clientId, required ExerciseType exercise, required RoutineLevel level, required DateTime startedAt, required DateTime endedAt, required List<SetSummary> sets}); int get totalReps; int get totalPartialReps; int get avgScore; List<MapEntry<PoseErrorCode, int>> get topErrors; }` |
| `RepResult`, `PoseErrorCode`, `ExerciseType`, `RoutineLevel` | 각 파일 | `PoseErrorCode.fromCode`, `ExerciseType.fromCode`, `RoutineLevel.code` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SessionListItem` | `app/lib/features/history/data/workout_local_repository.dart` | `class SessionListItem { const SessionListItem({required String clientId, required ExerciseType exercise, required DateTime startedAt, required int totalReps, required int avgScore, required SyncStatus syncStatus}); }` | TASK-41, 47 |
| `WorkoutLocalRepository` | 같은 파일 | `class WorkoutLocalRepository { WorkoutLocalRepository(AppDatabase db); Future<void> saveSummary(WorkoutSummary summary); Stream<List<SessionListItem>> watchSessions({DateTime? from, DateTime? to}); Future<WorkoutSummary?> findSummary(String clientId); Future<SyncStatus?> statusOf(String clientId); Future<List<WorkoutSummary>> pendingSummaries(); Future<void> markSynced(String clientId); Future<void> markRejected(String clientId, String reason); }` | TASK-39, 40, 41, 42, 47 |
| `workoutLocalRepositoryProvider` | 같은 파일 | `final workoutLocalRepositoryProvider = Provider<WorkoutLocalRepository>(...)` | TASK-39, 40, 41, 42, 47 |

## 범위
- 위 저장소. 저장은 한 트랜잭션

## 범위 밖 (건드리지 않음)
- 서버 업로드(TASK-38, 39), 화면

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 저장 후 상세 복원 (F-12) | 2세트 요약(partialReps 0, 2) saveSummary → findSummary | 세트별 doneReps, partialReps, 반복 점수, 오류 코드가 같음 |
| 미동기화로 시작 (F-11) | 저장 후 watchSessions 첫 값 | syncStatus pending |
| 중복 저장 무시 | 같은 요약 두 번 저장 | 세션 1건 |
| 상태 변경 반영 (F-11) | markSynced / markRejected | 목록 스트림의 syncStatus가 synced / rejected로 바뀜 |
| 대기 목록 | pending 2건, synced 1건 | pendingSummaries 2건 |
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
