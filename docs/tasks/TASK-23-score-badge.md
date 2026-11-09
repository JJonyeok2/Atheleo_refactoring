# TASK-23: 점수 배지 위젯(숫자와 색)

- 상태: 대기
- 선행 Task: TASK-03, TASK-12
- 실행 방식: 병렬 (그룹: G5)
- 실행 방식 근거: `app/lib/features/workout/widgets/score_badge.dart`만 새로 만듦. TASK-18, 24와 파일이 겹치지 않음
- Spec 출처: F-05, F-07 (9장 인수 조건 F-05), 8장 접근성

## 왜 이렇게 나눴나
운동 화면, 결과 화면, 기록 상세가 같은 점수 표시를 쓰도록 위젯 하나로 만든다.

## 기능 범위 (Spec 발췌)
- 점수 색상: 85 이상 초록, 60 이상 노랑, 그 아래 빨강
- 점수는 색상만이 아니라 숫자로도 표시한다.
- 인수 조건(F-05): 화면 점수 색이 기준대로 바뀐다.
- 이 Task에서 정하는 색: good `Color(0xFF2E7D32)`, fair `Color(0xFFF9A825)`, poor `Color(0xFFC62828)`. 점수가 없으면 '-'와 회색

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ScoreGrade` | `app/lib/pose/score/rep_score.dart` | `enum ScoreGrade { good, fair, poor }` |
| `gradeFor` | 같은 파일 | `ScoreGrade gradeFor(int score)` (85 이상 good, 60 이상 fair, 나머지 poor) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `scoreColor` | `app/lib/features/workout/widgets/score_badge.dart` | `Color scoreColor(ScoreGrade grade)` | TASK-29, 30 |
| `ScoreBadge` | 같은 파일 | `class ScoreBadge extends StatelessWidget { const ScoreBadge({super.key, required int? score, double size = 64}); }` (배경색은 `scoreColor`, 가운데 숫자, Semantics 라벨 '점수 N점') | TASK-29, 30, 42 |

## 범위
- 위 함수와 위젯

## 범위 밖 (건드리지 않음)
- 섬광 애니메이션(TASK-29)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 100점 초록 (F-05) | `ScoreBadge(score: 100)` | 텍스트 '100', 배경 good 색 |
| 75점 노랑 (F-05) | score 75 | '75', fair 색 |
| 59점 빨강 | score 59 | '59', poor 색 |
| 점수 없음 | score null | '-', 회색 |
| 접근성 라벨 | score 85 | Semantics 라벨 '점수 85점' |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/widgets/score_badge.dart`
- `app/test/features/workout/widgets/score_badge_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-05 인수 조건(색) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
