# QA-TASK-12

- 검토일: 2026-11-13
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/pose/score/rep_score.dart` | 헤더는 Impl이 작성(규칙 충족), 푸터 추가함 | 테스트 8건 통과, analyze 0건 |
| `app/test/pose/score/rep_score_test.dart` | 대상 아님(테스트 파일) | Task 표 8건과 1:1 대응 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | `scoreRep` | 입력은 enum 목록과 int뿐. 음수 시간은 템포 감점 없음으로 처리되어 문제 없음 |
| XSS 등 출력 처리 | 해당 없음 |  | 출력은 정수, enum |
| 인증 / 인가 | 해당 없음 |  | 순수 함수 |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 없음 |
| 새 의존성 | 통과 |  | 없음(내부 `pose_error.dart`만) |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 |  | 없음 |
| 함수 길이 | 통과 |  | 모두 10줄 이하 |
| 이름 | 통과 |  | `_maxScore`, `_tempoLimitMs`, `_tempoPenalty`로 상수 분리 |
| 죽은 코드 | 통과 |  | 없음 |
| 테스트가 인수 조건을 검증하는가 | 통과 | 테스트 전체 | F-05 100점/75점, 템포 3000/3001 경계, 등급 85/84/60/59 경계, 평균과 빈 목록 0 모두 검증 |

## 계약 대조 (내보내는 것)
| 이름 | 결과 |
|---|---|
| `int scoreRep({required List<PoseErrorCode> errors, required int durationMs})` | 일치 |
| `int averageScore(Iterable<int> scores)` (반올림, 비면 0) | 일치 |
| `enum ScoreGrade { good, fair, poor }` | 일치 |
| `ScoreGrade gradeFor(int score)` (85 이상 good, 60 이상 fair) | 일치 |

## Impl이 남긴 지점 판단
1. 감점표 Map: `PoseErrorCode`가 늘면 `_penalties[error]!`에서 실행 시 오류. 현재 6개 코드 모두 표에 있어 동작 문제는 없음. TASK-10 routine_table과 같은 기준으로 FIX가 아닌 푸터 메모로 남김. 오류 코드 추가(Spec 변경) 시 switch 식으로 바꿀 것.
2. 템포 `> 3000`: Task "3초를 넘으면 -5"와 테스트(3000ms 100, 3001ms 95)에 맞음.
3. 중복 감점: Task 테스트 "0점 하한 / 감점 합이 100을 넘는 목록(같은 코드 반복 포함) / 0"은 같은 코드 반복을 입력에 넣고 0을 기대한다. 반복을 한 번만 셌다면 같은 코드 반복은 결과를 0으로 만들 수 없으므로(예: `puHipSag` 5회 → 70) 반복마다 감점하는 것이 Task 의도로 읽힘. 현재 구현과 일치. 또한 TASK-09 `judgeRep`은 운동별로 각 코드를 조건 하나당 최대 한 번, 선언 순서로만 내므로(`_bodyLineError`는 처짐/들림 중 하나) 실제 흐름에서 중복은 생기지 않음.
4. `averageScore` 반올림: Dart `round()`는 .5를 0에서 먼 쪽으로 올림. 점수는 0 이상이라 .5는 항상 올림. 계약과 맞음. 다만 `Iterable`을 `isEmpty`, `fold`, `length`로 3번 순회하므로 지연 Iterable이면 재계산됨(푸터 메모, 정확성 문제 없음).
5. 0점 하한: 템포 감점까지 뺀 뒤 0으로 자름. Task와 일치.

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 해당 없음
