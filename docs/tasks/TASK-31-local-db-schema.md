# TASK-31: 로컬 DB 스키마(drift)

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 순차
- 실행 방식 근거: DB 스키마(마이그레이션 기준점), 저장, 동기화, 기록 화면이 모두 기댐
- Spec 출처: F-11, F-12 (3장, 7장 WorkoutSession, WorkoutSet, RepRecord, 로컬 기록 소유 규칙)

## 왜 이렇게 나눴나
테이블 정의와 동기화 상태 enum만 먼저 만든다. 요약 객체 저장과 조회, 소유자 규칙 적용은 TASK-32, 54.

## 기능 범위 (Spec 발췌)
- 로컬 DB에 소유자(사용자 id 또는 guest)와 함께 먼저 저장 후 서버로 백업 동기화
- WorkoutSession: client_id(uuid, 유일), user_id(int?, 로컬 DB에서 null이면 guest), exercise(push_up, squat), started_at, ended_at, routine_level, total_reps, avg_score, sync_status(pending, synced, failed, rejected), sync_attempts(int). sync_status, sync_attempts는 앱 로컬 전용
- WorkoutSet: session_id, set_index(1부터), target_reps, done_reps, partial_reps(0 이상, 부분 반복 수), rest_sec
- RepRecord: set_id, rep_index(세트 안에서 1부터), score(0~100), min_angle(float), duration_ms, errors(오류 코드 목록)
- 기록 목록 화면의 동기화 상태 표시: 미동기화, 동기화됨, 실패, 거절
- 이 Task에서 정하는 것:
  - errors는 쉼표로 이은 문자열 컬럼(`'PU_SHALLOW,PU_HIP_SAG'`, 없으면 빈 문자열)
  - 세션 삭제 시 세트, 반복은 함께 삭제(FK cascade, `PRAGMA foreign_keys = ON`)
  - 세션에 `lastError`(nullable text) 컬럼: 마지막 동기화 실패 사유
  - `userId`에 인덱스(소유자별 조회용)
  - `schemaVersion = 1`(아직 배포 전이므로 마이그레이션 없이 1에서 시작)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| 의존성 | `app/pubspec.yaml` | drift, drift_flutter, sqlite3_flutter_libs, build_runner, drift_dev 이미 추가됨 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SyncStatus` | `app/lib/features/history/domain/sync_status.dart` | `enum SyncStatus { pending, synced, failed, rejected }`, 필드 `final String code`('pending', 'synced', 'failed', 'rejected'), `final String label`('미동기화', '동기화됨', '실패', '거절'), `static SyncStatus fromCode(String code)`(모르는 값은 `ArgumentError`) | TASK-32, 39, 40, 41, 54 |
| 테이블 | `app/lib/core/storage/app_database.dart` | `WorkoutSessions`(id int 자동, clientId text unique, userId int nullable 인덱스, exercise text, startedAt dateTime, endedAt dateTime, routineLevel text, totalReps int, avgScore int, syncStatus text 기본 'pending', syncAttempts int 기본 0, lastError text nullable), `WorkoutSets`(id, sessionId → WorkoutSessions.id cascade, setIndex, targetReps, doneReps, partialReps int 기본 0, restSec), `RepRecords`(id, setId → WorkoutSets.id cascade, repIndex, score, minAngle real, durationMs, errors text) | TASK-32, 54 |
| `AppDatabase` | 같은 파일 | `@DriftDatabase(tables: [WorkoutSessions, WorkoutSets, RepRecords]) class AppDatabase extends _$AppDatabase { AppDatabase(QueryExecutor executor); }` | TASK-32 |
| `appDatabaseProvider` | 같은 파일 | `final appDatabaseProvider = Provider<AppDatabase>(...)` (`driftDatabase(name: 'atheleo')`, dispose 시 close) | TASK-32 |

## 범위
- 테이블, DB 클래스, 생성 코드(`app_database.g.dart`, 개수에서 제외)

## 범위 밖 (건드리지 않음)
- 요약 저장, 조회, 소유자 필터, 시도 횟수 규칙(TASK-32, 54)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 세션, 세트, 반복 저장과 조회 | `AppDatabase(NativeDatabase.memory())`에 1세션(userId 7) 2세트(partialReps 0, 2) 3반복 insert | 같은 값으로 조회 |
| 기본값 | syncStatus, syncAttempts, userId 없이 insert | 'pending', 0, null(guest) |
| client_id 유일 | 같은 clientId 두 번 insert | 예외 |
| cascade 삭제 | 세션 삭제 | 세트, 반복 0건 |
| 소유자별 조회 | userId 7 두 건, 8 한 건, null 한 건 | `userId = 7` 2건, `userId IS NULL` 1건 |
| SyncStatus 코드 | `SyncStatus.fromCode('failed').label`, `fromCode('rejected').label`, `fromCode('x')` | '실패', '거절', `ArgumentError` |

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

## 2026-11-13 설계 검토 반영
- `userId`(nullable, guest), `syncAttempts`, `SyncStatus.failed` 추가, 라벨을 '미동기화, 동기화됨, 실패, 거절'로 변경(rejected는 '저장 실패' → '거절')
