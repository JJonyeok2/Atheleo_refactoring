# TASK-31: 로컬 DB 스키마(drift)

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 순차
- 실행 방식 근거: DB 스키마(마이그레이션 기준점), 저장, 동기화, 기록 화면이 모두 기댐
- Spec 출처: F-11 (3장, 7장 WorkoutSession, WorkoutSet, RepRecord)

## 왜 이렇게 나눴나
테이블 정의와 동기화 상태 enum만 먼저 만든다. 요약 객체 저장과 조회는 TASK-32.

## 기능 범위 (Spec 발췌)
- 로컬 DB에 먼저 저장 후 서버 동기화
- WorkoutSession: client_id(uuid, 유일), exercise(push_up, squat), started_at, ended_at, routine_level, total_reps, avg_score, sync_status(pending, synced, rejected, 앱 로컬 전용)
- WorkoutSet: session_id, set_index(1부터), target_reps, done_reps, rest_sec
- RepRecord: set_id, rep_index, score(0~100), min_angle(float), duration_ms, errors(오류 코드 목록)
- 이 Task에서 정하는 것:
  - errors는 쉼표로 이은 문자열 컬럼(`'PU_SHALLOW,PU_HIP_SAG'`, 없으면 빈 문자열)
  - 세션 삭제 시 세트, 반복은 함께 삭제(FK cascade, `PRAGMA foreign_keys = ON`)
  - 세션에 `lastError`(nullable text) 컬럼: 저장 실패 사유
  - `schemaVersion = 1`

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| 의존성 | `app/pubspec.yaml` | drift, drift_flutter, sqlite3_flutter_libs, build_runner, drift_dev 이미 추가됨 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SyncStatus` | `app/lib/features/history/domain/sync_status.dart` | `enum SyncStatus { pending, synced, rejected }`, 필드 `final String code`('pending', 'synced', 'rejected'), `final String label`('미동기화', '동기화됨', '저장 실패'), `static SyncStatus fromCode(String code)` | TASK-32, 41 |
| 테이블 | `app/lib/core/storage/app_database.dart` | `WorkoutSessions`(id int 자동, clientId text unique, exercise text, startedAt dateTime, endedAt dateTime, routineLevel text, totalReps int, avgScore int, syncStatus text 기본 'pending', lastError text nullable), `WorkoutSets`(id, sessionId → WorkoutSessions.id cascade, setIndex, targetReps, doneReps, restSec), `RepRecords`(id, setId → WorkoutSets.id cascade, repIndex, score, minAngle real, durationMs, errors text) | TASK-32 |
| `AppDatabase` | 같은 파일 | `@DriftDatabase(tables: [WorkoutSessions, WorkoutSets, RepRecords]) class AppDatabase extends _$AppDatabase { AppDatabase(QueryExecutor executor); }` | TASK-32 |
| `appDatabaseProvider` | 같은 파일 | `final appDatabaseProvider = Provider<AppDatabase>(...)` (`driftDatabase(name: 'atheleo')`, dispose 시 close) | TASK-32 |

## 범위
- 테이블, DB 클래스, 생성 코드(`app_database.g.dart`, 개수에서 제외)

## 범위 밖 (건드리지 않음)
- 요약 저장, 조회 로직(TASK-32)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 세션, 세트, 반복 저장과 조회 | `AppDatabase(NativeDatabase.memory())`에 1세션 2세트 3반복 insert | 같은 값으로 조회 |
| 기본 동기화 상태 | syncStatus 없이 insert | 'pending' |
| client_id 유일 | 같은 clientId 두 번 insert | 예외 |
| cascade 삭제 | 세션 삭제 | 세트, 반복 0건 |
| SyncStatus 코드 | `SyncStatus.fromCode('rejected').label` | '저장 실패' |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/storage/app_database.dart`
- `app/lib/features/history/domain/sync_status.dart`
- `app/test/core/storage/app_database_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] `dart run build_runner build`로 생성 코드가 최신
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 테스트 환경에서 sqlite 네이티브 라이브러리를 쓸 수 없을 때

## 추가 발췌 (오케스트레이터가 보충)
