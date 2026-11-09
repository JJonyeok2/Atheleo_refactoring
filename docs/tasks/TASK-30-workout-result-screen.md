# TASK-30: 운동 결과 화면(표시만)

- 상태: 대기
- 선행 Task: TASK-23, TASK-27
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정
- Spec 출처: F-05 (4장 정상 흐름 7번, 5장 운동 결과 화면)

## 왜 이렇게 나눴나
결과를 보여 주는 부분만 먼저 만든다. 로그인 여부에 따른 저장과 안내는 계정과 DB가 준비된 뒤 TASK-40에서 더한다.

## 기능 범위 (Spec 발췌)
- 결과 화면: 총 횟수, 평균 점수, 반복별 점수 그래프, 자주 나온 오류
- 이 Task에서 정하는 것:
  - 반복별 점수 그래프는 외부 라이브러리 없이 막대(높이 = 점수, 색 = `scoreColor(gradeFor(score))`)
  - 자주 나온 오류는 상위 3개, `'${label} ${count}회'`
  - 요약이 없으면(직접 주소로 들어옴) '표시할 결과가 없어요' + 홈 버튼
  - 하단 '홈으로' 버튼. 저장 영역은 빈 자리(`SizedBox` 키 `result-save-slot`)로 남김

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `lastWorkoutSummaryProvider` | `app/lib/features/workout/application/workout_controller.dart` | `final lastWorkoutSummaryProvider = NotifierProvider<LastWorkoutSummaryNotifier, WorkoutSummary?>(LastWorkoutSummaryNotifier.new);` |
| `WorkoutSummary`, `SetSummary` | `app/lib/features/workout/domain/workout_summary.dart` | `class WorkoutSummary { ...; int get totalReps; int get avgScore; List<MapEntry<PoseErrorCode, int>> get topErrors; }`, `class SetSummary { ...; List<RepResult> reps; int get doneReps; int get avgScore; }` (TASK-17 계약 그대로) |
| `ScoreBadge`, `scoreColor` | `app/lib/features/workout/widgets/score_badge.dart` | TASK-23 계약 그대로 |
| `gradeFor` | `app/lib/pose/score/rep_score.dart` | `ScoreGrade gradeFor(int score)` |
| `AppRoutes` | `app/lib/app/routes.dart` | `workoutResult = '/workout/result'`, `home = '/'` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutResultScreen` | `app/lib/features/workout/presentation/workout_result_screen.dart` | `class WorkoutResultScreen extends ConsumerWidget { const WorkoutResultScreen({super.key, Widget? saveSlot}); }` (saveSlot이 null이면 키 `result-save-slot`인 빈 자리) | TASK-40 |
| `RepScoreChart` | `app/lib/features/workout/widgets/rep_score_chart.dart` | `class RepScoreChart extends StatelessWidget { const RepScoreChart({super.key, required List<int> scores}); }` | TASK-42 |

## 범위
- 화면, 막대 그래프 위젯, 라우터 result 경로 builder 교체

## 범위 밖 (건드리지 않음)
- 저장, 로그인 안내(TASK-40)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 총 횟수와 평균 | 요약 override(반복 점수 100, 75, 80) | '3회', `ScoreBadge(score: 85)` |
| 반복별 막대 | 같은 요약 | 막대 3개, 두 번째 막대 색이 fair 색 |
| 자주 나온 오류 | sqShallow 2, sqTorsoLean 1 | '깊이 부족 2회', '상체 숙임 1회' 순서 |
| 요약 없음 | override null | '표시할 결과가 없어요' |
| 홈으로 | 버튼 탭 | 경로 `/` |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/presentation/workout_result_screen.dart`
- `app/lib/features/workout/widgets/rep_score_chart.dart`
- `app/lib/app/router.dart`
- `app/test/features/workout/presentation/workout_result_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
