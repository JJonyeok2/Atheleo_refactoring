# TASK-17: 운동 결과 요약 모델

- 상태: 대기
- 선행 Task: TASK-10, TASK-12, TASK-15
- 실행 방식: 병렬 (그룹: G4)
- 실행 방식 근거: `app/lib/features/workout/domain/workout_summary.dart`만 새로 만듦. 세션 컨트롤러 타입에 기대지 않고 `List<List<RepResult>>`만 받음
- Spec 출처: F-05(세트 점수 평균), 4장 정상 흐름 7번(결과 화면 값), 7장 WorkoutSession, WorkoutSet, RepRecord

## 왜 이렇게 나눴나
결과 화면, 로컬 저장, 서버 업로드가 모두 같은 "운동 한 번의 결과" 모양을 쓰도록 한곳에서 정의한다.

## 기능 범위 (Spec 발췌)
- 결과 화면: 총 횟수, 평균 점수, 반복별 점수, 자주 나온 오류, 부분 반복 횟수(따로 표시)
- 세트 점수는 평균. 부분 반복은 점수가 없고 평균에 넣지 않는다
- WorkoutSession: client_id(uuid), exercise(push_up, squat), started_at, ended_at, routine_level, total_reps, avg_score
- WorkoutSet: set_index(1부터), target_reps, done_reps, partial_reps(0 이상, 부분 반복 수), rest_sec
- RepRecord: rep_index, score(0~100), min_angle, duration_ms, errors(오류 코드 목록)
- 이 Task에서 정하는 규칙:
  - avgScore = 모든 반복 점수 평균(반올림), 반복이 없으면 0
  - 반복과 부분 반복이 모두 0개인 세트는 요약에서 뺀다. set_index는 남은 세트 순서대로 1부터 다시 매기지 않고 원래 번호 유지
  - topErrors = 오류 코드별 횟수, 많은 순, 같으면 `PoseErrorCode` 선언 순서
  - targetReps, restSec는 계획 값 그대로
  - totalPartialReps = 세트별 partialReps 합

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `RoutinePlan`, `RoutineLevel` | `app/lib/features/routine/domain/routine_plan.dart` | `class RoutinePlan { const RoutinePlan({required ExerciseType exercise, required RoutineLevel level, required int targetReps, required int sets, required int restSec, required int minScore}); }`, `enum RoutineLevel { advanced, intermediate, beginner }` |
| `RepResult` | `app/lib/pose/analyzer/rep_analyzer.dart` | `final class RepResult extends AnalyzerOutput { const RepResult({required int repIndex, required int score, required double minAngle, required int durationMs, required List<PoseErrorCode> errors}); }` |
| `PoseErrorCode` | `app/lib/pose/judge/pose_error.dart` | `enum PoseErrorCode { puShallow, puHipSag, puHipPike, sqShallow, sqTorsoLean, sqHeelLift }` |
| `averageScore` | `app/lib/pose/score/rep_score.dart` | `int averageScore(Iterable<int> scores)` (반올림, 비면 0) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SetSummary` | `app/lib/features/workout/domain/workout_summary.dart` | `class SetSummary { const SetSummary({required int setIndex, required int targetReps, required int restSec, required List<RepResult> reps, int partialReps = 0}); int get doneReps; int get avgScore; }` | TASK-30, 32, 38, 42 |
| `WorkoutSummary` | 같은 파일 | `class WorkoutSummary { const WorkoutSummary({required String clientId, required ExerciseType exercise, required RoutineLevel level, required DateTime startedAt, required DateTime endedAt, required List<SetSummary> sets}); int get totalReps; int get totalPartialReps; int get avgScore; List<MapEntry<PoseErrorCode, int>> get topErrors; }` | TASK-27, 30, 32, 38, 40, 42 |
| `buildSummary` | 같은 파일 | `WorkoutSummary buildSummary({required String clientId, required RoutinePlan plan, required DateTime startedAt, required DateTime endedAt, required List<List<RepResult>> sets, List<int> partialsPerSet = const []})` (sets[0]이 1세트, partialsPerSet이 짧으면 나머지는 0) | TASK-27 |

## 범위
- 위 모델과 함수

## 범위 밖 (건드리지 않음)
- 저장, 업로드 형식(TASK-32, 38), 화면(TASK-30)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 총 횟수와 평균 | 1세트 [100, 75], 2세트 [80] | totalReps 3, avgScore 85 |
| 세트 평균 (F-05) | SetSummary reps 점수 [100, 75] | avgScore 88 (87.5 반올림) |
| 빈 세트 제외 | sets [[3개], [], []], partialsPerSet [0, 2, 0] | sets 길이 2, setIndex 1, 2 (2세트는 부분 반복만 있음) |
| 부분 반복 합계 | partialsPerSet [1, 2] | 세트별 partialReps 1, 2, totalPartialReps 3, avgScore에 영향 없음 |
| 자주 나온 오류 | 오류 [sqShallow, sqShallow, sqTorsoLean] 분포 | topErrors 첫 항목 sqShallow 2 |
| 반복 없음 | sets [[]] | totalReps 0, avgScore 0, topErrors 빈 목록 |
| 계획 값 반영 | 중급 스쿼트 계획 | 모든 SetSummary targetReps 15, restSec 45, level intermediate |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/domain/workout_summary.dart`
- `app/test/features/workout/domain/workout_summary_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
