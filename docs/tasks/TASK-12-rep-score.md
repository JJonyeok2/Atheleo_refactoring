# TASK-12: 반복 점수와 점수 등급

- 상태: 대기
- 선행 Task: TASK-09
- 실행 방식: 병렬 (그룹: G3)
- 실행 방식 근거: `app/lib/pose/score/`만 새로 만드는 순수 함수, TASK-13, 26과 파일이 겹치지 않음
- Spec 출처: F-05 (3장, 7장 반복 점수 계산, 9장 인수 조건), F-07(점수 색상 기준)

## 왜 이렇게 나눴나
점수 계산과 "점수 → 색 등급" 변환을 순수 함수로 둔다. 화면(TASK-23)은 등급만 받아 색을 칠한다.

## 기능 범위 (Spec 발췌)
- 반복 1회 종료 시 0~100점, 세트 점수는 평균
- 100점에서 시작해 오류 코드마다 감점: 깊이 부족 -25(`PU_SHALLOW`, `SQ_SHALLOW`), 허리 처짐 -30(`PU_HIP_SAG`), 엉덩이 들림 -20(`PU_HIP_PIKE`), 상체 숙임 -20(`SQ_TORSO_LEAN`), 뒤꿈치 들림 -15(`SQ_HEEL_LIFT`)
- 부분 반복은 점수를 매기지 않고 세트 평균에도 넣지 않는다(이 함수로 오지 않음)
- 1회 시간이 3초를 넘으면 -5(템포 저하), 0점 아래로 내려가지 않음
- 점수 색상: 85 이상 초록, 60 이상 노랑, 그 아래 빨강
- 인수 조건(F-05): 오류 없는 반복은 100점, 깊이 부족 반복은 75점으로 기록되고, 화면 점수 색이 기준대로 바뀐다(색은 등급으로 확인).
- 평균은 반올림 정수, 빈 목록은 0

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `PoseErrorCode` | `app/lib/pose/judge/pose_error.dart` | `enum PoseErrorCode { puShallow, puHipSag, puHipPike, sqShallow, sqTorsoLean, sqHeelLift }`, 필드 `final String code`(위 표 코드), `final String voiceMessage`, `final String label`(짧은 이름), `static PoseErrorCode fromCode(String code)`(모르는 값은 `ArgumentError`) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `scoreRep` | `app/lib/pose/score/rep_score.dart` | `int scoreRep({required List<PoseErrorCode> errors, required int durationMs})` | TASK-15 |
| `averageScore` | 같은 파일 | `int averageScore(Iterable<int> scores)` (반올림, 비면 0) | TASK-17 |
| `ScoreGrade` | 같은 파일 | `enum ScoreGrade { good, fair, poor }` | TASK-23 |
| `gradeFor` | 같은 파일 | `ScoreGrade gradeFor(int score)` (85 이상 good, 60 이상 fair, 나머지 poor) | TASK-23, 30 |

## 범위
- 위 함수

## 범위 밖 (건드리지 않음)
- 색상 값과 위젯(TASK-23)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 오류 없음 (F-05) | errors [], 1500ms | 100 |
| 깊이 부족 (F-05) | [sqShallow], 1500ms | 75 |
| 여러 오류 합산 | [puShallow, puHipSag], 1500ms / [puHipPike], 1500ms | 45 / 80 |
| 템포 저하 | [], 3001ms / 3000ms | 95 / 100 |
| 스쿼트 감점 | [sqShallow, sqTorsoLean, sqHeelLift], 4000ms | 35 |
| 0점 하한 | 감점 합이 100을 넘는 목록(같은 코드 반복 포함) | 0 |
| 등급 경계 (F-05, F-07) | gradeFor 85, 84, 60, 59 | good, fair, fair, poor |
| 평균 | averageScore([100, 75, 80]), [] | 85, 0 |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/score/rep_score.dart`
- `app/test/pose/score/rep_score_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-05 인수 조건 충족(점수와 등급)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
