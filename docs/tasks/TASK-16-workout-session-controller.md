# TASK-16: 세트와 휴식 세션 컨트롤러

- 상태: 대기
- 선행 Task: TASK-10, TASK-15
- 실행 방식: 병렬 (그룹: G4)
- 실행 방식 근거: `app/lib/features/workout/domain/workout_session_controller.dart`만 새로 만듦. TASK-17, 22와 파일이 겹치지 않고 서로 결과에 의존하지 않음
- Spec 출처: F-08 (3장, 4장 정상 흐름 6~7번, 9장 인수 조건)

## 왜 이렇게 나눴나
"반복 결과가 들어오면 세트와 휴식이 어떻게 바뀌는가"만 다루는 순수 상태 머신이다. 시간은 인자로 받아 카메라, 타이머 없이 테스트한다.

## 기능 범위 (Spec 발췌)
- 목표 횟수 달성 시 세트 증가, 휴식 카운트다운, 다음 세트 안내
- 정상 흐름: 목표 횟수 달성 → "세트 완료, N초 쉬세요" → 휴식 카운트다운 → "다음 세트를 시작하세요" / 마지막 세트 종료 또는 사용자가 종료 → 결과
- 인수 조건(F-08): 목표 10회 루틴에서 10회를 채우면 세트가 2로 바뀌고 휴식 카운트다운이 나오며, 끝나면 다음 세트 음성이 나온다(음성 문구는 TASK-18, 여기서는 `NextSetStarted` 이벤트).
- 이 Task에서 정하는 규칙:
  - 휴식 중, 일시정지 중, 종료 후에 들어온 반복은 무시(빈 목록 반환)
  - 세트 완료 시 currentSet을 바로 다음 번호로 올리고 phase는 resting, repsInSet 0
  - 마지막 세트 완료 시 휴식 없이 `WorkoutFinished`, phase finished
  - 휴식 남은 초 = 올림((휴식 끝 시각 − now) / 1000). 0이 되면 `NextSetStarted`
  - pause/resume: 일시정지된 시간만큼 휴식 끝 시각을 뒤로 민다. resume은 일시정지 전 phase로 돌아감
  - sets[0]이 1세트. 진행 중인 세트도 sets에 들어 있음

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `RoutinePlan` | `app/lib/features/routine/domain/routine_plan.dart` | `class RoutinePlan { const RoutinePlan({required ExerciseType exercise, required RoutineLevel level, required int targetReps, required int sets, required int restSec, required int minScore}); }` (값 비교 가능하게 `==` 구현) |
| `RepResult` | `app/lib/pose/analyzer/rep_analyzer.dart` | `class RepResult { const RepResult({required int repIndex, required int score, required double minAngle, required int durationMs, required List<PoseErrorCode> errors}); }` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutPhase` | `app/lib/features/workout/domain/workout_session_controller.dart` | `enum WorkoutPhase { exercising, resting, paused, finished }` | TASK-26, 28 |
| `WorkoutSessionState` | 같은 파일 | `class WorkoutSessionState { const WorkoutSessionState({required WorkoutPhase phase, required int currentSet, required int totalSets, required int targetReps, required int repsInSet, required int restRemainingSec, required List<List<RepResult>> sets}); }` | TASK-26, 28 |
| `WorkoutEvent` 계열 | 같은 파일 | `sealed class WorkoutEvent`, `final class RepCounted extends WorkoutEvent { const RepCounted(this.rep, this.repsInSet); final RepResult rep; final int repsInSet; }`, `final class SetCompleted extends WorkoutEvent { const SetCompleted(this.setIndex, this.restSec); final int setIndex; final int restSec; }`, `final class NextSetStarted extends WorkoutEvent { const NextSetStarted(this.setIndex); final int setIndex; }`, `final class WorkoutFinished extends WorkoutEvent { const WorkoutFinished(); }` | TASK-18, 26 |
| `WorkoutSessionController` | 같은 파일 | `class WorkoutSessionController { WorkoutSessionController(RoutinePlan plan); WorkoutSessionState get state; List<WorkoutEvent> onRep(RepResult rep, int nowMs); List<WorkoutEvent> tick(int nowMs); List<WorkoutEvent> skipRest(int nowMs); void pause(int nowMs); void resume(int nowMs); List<WorkoutEvent> finish(int nowMs); }` | TASK-26 |

## 범위
- 위 상태 머신

## 범위 밖 (건드리지 않음)
- 음성 문구(TASK-18), 타이머와 화면(TASK-26, 28), 결과 요약(TASK-17)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 10회 채우면 2세트와 휴식 (F-08) | targetReps 10, sets 3, restSec 30 계획에 onRep 10번 | 10번째에 `[RepCounted, SetCompleted(1, 30)]`, currentSet 2, phase resting, restRemainingSec 30 |
| 휴식 카운트다운 (F-08) | 세트 완료 시각 + 10초에 tick | restRemainingSec 20, 이벤트 없음 |
| 휴식 끝나면 다음 세트 (F-08) | + 30초에 tick | `[NextSetStarted(2)]`, phase exercising |
| 휴식 중 반복 무시 | resting 중 onRep | 빈 목록, repsInSet 0 |
| 마지막 세트 완료 | 3세트 모두 채움 | 마지막에 `WorkoutFinished`, phase finished, sets 길이 3 |
| 건너뛰기 | resting 중 skipRest | `[NextSetStarted(2)]` |
| 일시정지 중 휴식 멈춤 | resting 5초 시점 pause, 20초 뒤 resume, 그 뒤 25초 지나 tick | NextSetStarted |
| 중간 종료 | 1세트 4회에서 finish | `[WorkoutFinished]`, sets[0] 길이 4 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/domain/workout_session_controller.dart`
- `app/test/features/workout/domain/workout_session_controller_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-08 인수 조건(로직 부분) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
