# QA-TASK-31

- 검토일: 2026-11-13
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/core/storage/app_database.dart` | 헤더 있음(Impl), 푸터 추가함 | 테이블 3개, `AppDatabase`, `appDatabaseProvider` |
| `app/lib/features/history/domain/sync_status.dart` | 헤더 있음(Impl), 푸터 추가함 | `SyncStatus` enum |
| `app/lib/core/storage/app_database.g.dart` | 달지 않음(생성물) | 커밋 대상. `dart run build_runner build` 재실행 결과 lib/test 전체 md5 변화 없음(생성물 최신) |
| `app/test/core/storage/app_database_test.dart` | 달지 않음(테스트) | 9건 통과 |

## 계약 대조 (내보내는 것)
| 항목 | 결과 | 설명 |
|---|---|---|
| `WorkoutSessions` | 일치 | id 자동, clientId text UNIQUE, userId int nullable + 인덱스 `workout_sessions_user_id`, exercise, startedAt/endedAt dateTime, routineLevel text, totalReps/avgScore int, syncStatus text 기본 'pending', syncAttempts int 기본 0, lastError text nullable |
| `WorkoutSets` | 일치 | sessionId → workout_sessions(id) ON DELETE CASCADE, setIndex, targetReps, doneReps, partialReps 기본 0, restSec |
| `RepRecords` | 일치 | setId → workout_sets(id) ON DELETE CASCADE, repIndex, score, minAngle real, durationMs, errors text |
| `AppDatabase` | 일치 | `new(super.e)`는 위치 인자 `QueryExecutor` 하나라 `AppDatabase(QueryExecutor executor)` 계약과 호출부 호환. `beforeOpen`에서 `PRAGMA foreign_keys = ON` |
| `appDatabaseProvider` | 일치 | `driftDatabase(name: 'atheleo')`, `ref.onDispose(db.close)` |
| `SyncStatus` | 일치 | 값 4개, code/label('미동기화', '동기화됨', '실패', '거절'), `fromCode` 모르는 값 `ArgumentError` |
| 소비 Task(32, 39, 40, 41, 42, 54) 받아 쓰는 것 표 | 일치 | 컬럼, enum 이름과 라벨 모두 맞음. TASK-54 계약에는 스키마 변경이 없음 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과(권고 있음) | `app_database.dart` 테이블 정의 | 점수 0~100, partialReps 0 이상 같은 값 범위를 DB CHECK로 걸지 않음. Task 발췌 "이 Task에서 정하는 것"에 DB 제약 요구가 없고 값은 도메인 계산 결과(`WorkoutSummary`)에서 오므로 허용. TASK-32 저장 경로에서 검증 또는 테스트할 것을 권고 |
| SQL 인젝션 | 통과 | `app_database.dart:113` | `customStatement`는 고정 PRAGMA 문자열만 사용. 나머지는 drift 쿼리 빌더 |
| XSS 등 출력 처리 | 해당 없음 | | |
| 인증 / 인가 | 해당 없음 | | 소유자 필터는 TASK-32, 54 범위 |
| 시크릿 하드코딩 | 통과 | | DB 이름 'atheleo'만 있음 |
| 로그의 민감 정보 | 통과 | | `logStatements` 미사용 |
| 새 의존성 | 없음 | `app/pubspec.yaml` | drift 등은 TASK-01에서 추가됨 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | | |
| 함수 길이 | 통과 | | |
| 이름 | 통과 | | 생성자 인자 이름 `e`는 위치 인자라 외부 영향 없음 |
| 죽은 코드 | 통과 | | |
| 테스트가 인수 조건을 검증하는가 | 통과 | `app_database_test.dart` | Red 표 6건 모두 대응. 추가로 schemaVersion, FK 위반, 인덱스 존재 확인 |
| 마이그레이션 | 권고 | `app_database.dart:108` | schemaVersion 1, onCreate 기본(createAll). 현재 TASK-32, 54 계약에는 스키마 변경이 없어 올릴 필요 없음. 이후 컬럼/테이블이 바뀌면 개발 기기에 이미 v1 DB가 있을 수 있으므로 버전을 올리고 onUpgrade를 함께 추가할 것(배포 후에는 필수) |

## 참고 메모 (FIX 아님)
- drift 기본 설정이라 DateTime은 초 단위 정수로 저장됨(밀리초 손실). 시작/종료 시각 비교, 정렬에는 문제 없음.
- `syncStatus`는 text라 잘못된 코드가 들어가면 `SyncStatus.fromCode`가 예외를 던짐. TASK-32에서 쓰기는 `SyncStatus.code`만 쓰고, 읽기 실패 처리 방침을 정할 것.
- `lastError`에는 서버 거절 사유가 들어감. TASK-39, 54에서 토큰, 개인 정보를 넣지 않도록 주의.

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
