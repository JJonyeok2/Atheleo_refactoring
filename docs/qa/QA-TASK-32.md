# QA-TASK-32

- 검토일: 2026-11-13
- 판정: PASS (권고 3건, 오케스트레이터 결정 필요 1건)
- 검증: 대상 파일만 `dart format`(변경 0), `flutter analyze`(0건), `flutter test test/features/history/data/workout_local_repository_test.dart`(17건 통과). TASK-34 Impl이 병렬 진행 중이라 전체 analyze/test는 돌리지 않았고, 이 Task 파일 기준으로 판단함. TASK-34 파일은 건드리지 않음.

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/features/history/data/workout_local_repository.dart` | 헤더는 Impl이 작성(규칙 충족), 푸터 추가함 | |
| `app/test/features/history/data/workout_local_repository_test.dart` | 해당 없음(테스트 파일) | 17건 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | `_validate` (222~239) | 점수 0~100, partialReps 0 이상, setIndex·repIndex 1 이상. 트랜잭션 전에 검사해 아무것도 쓰지 않음(테스트로 행 수 0 확인) |
| XSS 등 출력 처리 | 해당 없음 | | 화면 없음. drift 매개변수 바인딩만 사용, 문자열 SQL 없음 |
| 인증 / 인가(소유자 규칙) | 통과 | `_ownedBy` (211), 120~131, 152~155, 175~183 | 목록, 상세, 대기 목록 모두 소유자로 거름. guest는 `user_id IS NULL`, 대기 목록은 `int userId`라 guest 제외. 테스트: 7/8/guest 목록 분리, 7의 clientId를 8과 guest로 상세 조회 시 null, guest 기록을 7로 조회 시 null, 다른 소유자의 clientId 재저장 시 기존 기록 유지 |
| 인가(상태 API) | 권고 | 160~209 | `statusOf`, `watchStatus`, `markSynced`, `markRejected`는 계약상 clientId만 받아 소유자를 보지 않음. 노출되는 것은 상태값뿐이고 clientId는 uuid라 위험 낮음. 소비 Task(39, 40, 42, 54)는 자기 소유 clientId만 넘길 것 |
| 시크릿 하드코딩 | 통과 | | 없음 |
| 로그의 민감 정보 | 통과 | 199 | 로그 출력 없음. lastError에 토큰·개인정보 금지를 doc 주석으로 명시 |
| 새 의존성 | 통과 | | 없음 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | 187~209 | markSynced/markRejected 구조가 비슷하지만 짧아 허용 |
| 함수 길이 | 권고 | `saveSummary` 58~112 | 약 55줄. 세트·반복 삽입을 `_insertSet`으로 빼면 50줄 미만 |
| 이름 | 통과 | | |
| 죽은 코드 | 통과 | | |
| 테스트가 인수 조건을 검증하는가 | 통과 | 테스트 전체 | Red 표 7개 모두 있고, 값 검증 6건, 롤백 1건, 모르는 syncStatus 1건, 없는 clientId 1건, 다른 소유자 중복 1건 추가 |

## Impl이 정한 동작 평가
| 동작 | 평가 |
|---|---|
| 같은 clientId는 소유자와 상관없이 무시 | 수용. clientId는 uuid라 다른 사용자 간 충돌은 사실상 없음. 스키마도 `clientId unique`라 다른 처리는 불가. 소유자 덮어쓰기를 막는 쪽이라 안전함 |
| 검증은 트랜잭션 전 | 수용. 순수 검사라 DB를 열 필요 없음 |
| markSynced가 lastError 비움 | 수용. 성공 후 이전 오류가 남지 않는 것이 자연스러움 |
| markRejected가 syncAttempts 미변경 | 수용. 시도 횟수는 TASK-54 범위(5xx) |
| 없는 clientId mark는 조용히 무시 | 수용. 동기화 중 삭제된 기록에 대해 예외를 내지 않음. 테스트 있음 |
| pendingSummaries startedAt 오름차순 | 수용. 계약에 순서 규정 없고 오래된 것부터 올리는 것이 합리적 |
| 모르는 syncStatus는 failed, 대기 목록 제외 | 수용. Task 규칙 그대로. 단 TASK-54 수동 재시도가 failed를 대상으로 하면 이 행도 재시도 대상이 됨을 TASK-54에서 알고 있을 것 |
| 반복 없는 세트 복원 | 수용. 세트 행이 있으면 reps 빈 목록으로 복원됨 |
| watch 스트림 갱신 범위 | 수용. drift `watch()`는 drift API의 insert/update/delete 모두에 반응하므로 저장, 삭제, 귀속(update) 시에도 갱신됨. 단 `customStatement`로 쓰면 전파되지 않으므로 TASK-54 귀속은 drift update 또는 `customUpdate(updates: {workoutSessions})`를 써야 함. 저장 시점 갱신 자체를 검증하는 테스트는 없음(권고) |
| 모르는 exercise / routineLevel / 오류 코드는 예외 | 아래 "오케스트레이터 결정 필요" 참고 |

## 오케스트레이터 결정 필요 (차단 아님)
- 모르는 exercise 코드는 `watchSessions` 매핑(137)에서, 모르는 routineLevel(279, `firstWhere` StateError)과 오류 코드(269)는 `_load`에서 예외가 나서 한 행 때문에 기록 목록 스트림 전체, 상세, `pendingSummaries`(해당 사용자 동기화 전체)가 깨진다.
- FIX로 보지 않은 이유: Task의 명시 규칙은 syncStatus에만 적용되고, 이 열들은 이 저장소가 enum code로만 쓰므로 정상 흐름에서는 생기지 않는다(앱 다운그레이드, DB 손상 때만). 또 `SessionListItem.exercise`가 non-null 계약이라 "행을 건너뛸지, 오류 코드만 버릴지" 같은 정책이 필요하고 이는 Impl이 정할 일이 아니다.
- 권고안: 목록과 대기 목록은 해석 못 하는 행을 건너뛰고(대기 목록은 그 행을 failed로 표시하는 방안도 가능), 모르는 오류 코드는 그 코드만 버리며, 모르는 routineLevel은 예외 대신 건너뛰기. 기록 화면(TASK-41)이나 동기화(TASK-39) 전에 후속 보강 Task로 넣을지 결정 필요.

## 계약 대조 (소비 Task 39, 40, 41, 42, 47, 54)
- `SessionListItem`, `WorkoutLocalRepository`의 모든 메서드 시그니처, `workoutLocalRepositoryProvider` 모두 Task 파일 표와 일치. 생성자는 프로젝트 관례인 `new(...)` 문법이며 `WorkoutLocalRepository(db)`로 호출됨(테스트로 확인).

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
