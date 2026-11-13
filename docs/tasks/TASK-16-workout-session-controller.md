# TASK-16: 세트와 휴식 세션 컨트롤러

- 상태: 대기
- 선행 Task: TASK-10, TASK-15
- 실행 방식: 병렬 (그룹: G4)
- 실행 방식 근거: `app/lib/features/workout/domain/workout_session_controller.dart`만 새로 만듦. TASK-17, 22와 파일이 겹치지 않고 서로 결과에 의존하지 않음
- Spec 출처: F-08, F-06 (3장, 4장 정상 흐름 7~8번, 7장 시간 기준, 9장 인수 조건)

## 왜 이렇게 나눴나
"반복 결과가 들어오면 세트와 휴식이 어떻게 바뀌는가"만 다루는 순수 상태 머신이다. 시간은 인자로 받아 카메라, 타이머 없이 테스트한다.

## 기능 범위 (Spec 발췌)
- 목표 횟수 달성 시 세트 증가, 휴식 카운트다운, 다음 세트 안내
- 부분 반복은 세트 횟수와 점수에 넣지 않고, 세트별 부분 반복 수(partial_reps, 0 이상)만 누적한다. 음성 "더 내려가세요"는 TASK-18
- 정상 흐름: 목표 횟수 달성 → "세트 완료, N초 쉬세요" → 휴식 카운트다운 → 휴식 종료 3초 전 음성 안내 → "다음 세트를 시작하세요" / 마지막 세트 종료 또는 사용자가 종료 → 결과
- 시간 기준: 세션 시간(세트, 휴식 카운트다운, 일시정지)은 앱 시계 하나로 잰다. 프레임 타임스탬프는 판정 분석에서만 쓴다.
- 인수 조건(F-08): 목표 10회 루틴에서 10회를 채우면 세트가 2로 바뀌고 휴식 카운트다운이 나오며, 끝나면 다음 세트 음성이 나온다(음성 문구는 TASK-18, 여기서는 `NextSetStarted` 이벤트). F-06: 휴식이 3초 남았을 때 안내 음성이 나온다(여기서는 `RestEndingSoon` 이벤트).
- 이 Task에서 정하는 규칙:
  - 모든 `nowMs`는 앱 시계(밀리초) 값이다. 프레임 타임스탬프를 넣지 않는다(호출하는 TASK-27 책임)
  - 휴식 중, 일시정지 중, 종료 후에 들어온 반복과 부분 반복은 무시(빈 목록 반환)
  - 세트 완료 시 currentSet을 바로 다음 번호로 올리고 phase는 resting, repsInSet 0
  - 마지막 세트 완료 시 휴식 없이 `WorkoutFinished`, phase finished
  - 휴식 남은 초 = 올림((휴식 끝 시각 − now) / 1000). 0이 되면 `NextSetStarted`
  - 휴식 중 tick에서 남은 초가 처음으로 3 이하(0 초과)가 되면 `RestEndingSoon(남은 초)`를 그 휴식에서 한 번만 낸다. skipRest로 끝난 휴식에서는 내지 않는다
  - pause/resume: 일시정지된 시간만큼 휴식 끝 시각을 뒤로 민다. resume은 일시정지 전 phase로 돌아감
  - sets[0]이 1세트. 진행 중인 세트도 sets에 들어 있음. partialsPerSet은 sets와 길이가 같음

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `RoutinePlan` | `app/lib/features/routine/domain/routine_plan.dart` | `class RoutinePlan { const RoutinePlan({required ExerciseType exercise, required RoutineLevel level, required int targetReps, required int sets, required int restSec, required int minScore}); }` (값 비교 가능하게 `==` 구현) |
| `RepResult` | `app/lib/pose/analyzer/rep_analyzer.dart` | `final class RepResult extends AnalyzerOutput { const RepResult({required int repIndex, required int score, required double minAngle, required int durationMs, required List<PoseErrorCode> errors}); }` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutPhase` | `app/lib/features/workout/domain/workout_session_controller.dart` | `enum WorkoutPhase { exercising, resting, paused, finished }` | TASK-27, 28, 29, 52, 53 |
| `WorkoutSessionState` | 같은 파일 | `class WorkoutSessionState { const WorkoutSessionState({required WorkoutPhase phase, required int currentSet, required int totalSets, required int targetReps, required int repsInSet, required int restRemainingSec, required List<List<RepResult>> sets, required List<int> partialsPerSet}); }` | TASK-27, 29 |
| `WorkoutEvent` 계열 | 같은 파일 | `sealed class WorkoutEvent`, `final class RepCounted extends WorkoutEvent { const RepCounted(this.rep, this.repsInSet); final RepResult rep; final int repsInSet; }`, `final class SetCompleted extends WorkoutEvent { const SetCompleted(this.setIndex, this.restSec); final int setIndex; final int restSec; }`, `final class RestEndingSoon extends WorkoutEvent { const RestEndingSoon(this.remainingSec); final int remainingSec; }`, `final class NextSetStarted extends WorkoutEvent { const NextSetStarted(this.setIndex); final int setIndex; }`, `final class WorkoutFinished extends WorkoutEvent { const WorkoutFinished(); }`, `final class PartialRepNoticed extends WorkoutEvent { const PartialRepNoticed(this.partialsInSet); final int partialsInSet; }` | TASK-18, 27, 52 |
| `WorkoutSessionController` | 같은 파일 | `class WorkoutSessionController { WorkoutSessionController(RoutinePlan plan); WorkoutSessionState get state; List<WorkoutEvent> onRep(RepResult rep, int nowMs); List<WorkoutEvent> onPartialRep(int nowMs); List<WorkoutEvent> tick(int nowMs); List<WorkoutEvent> skipRest(int nowMs); void pause(int nowMs); void resume(int nowMs); List<WorkoutEvent> finish(int nowMs); }` (nowMs는 앱 시계) | TASK-27 |

## 범위
- 위 상태 머신

## 범위 밖 (건드리지 않음)
- 음성 문구(TASK-18), 타이머, 시계, 분석기 초기화(TASK-27, 52), 화면(TASK-29), 결과 요약(TASK-17)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 10회 채우면 2세트와 휴식 (F-08) | targetReps 10, sets 3, restSec 30 계획에 onRep 10번 | 10번째에 `[RepCounted, SetCompleted(1, 30)]`, currentSet 2, phase resting, restRemainingSec 30 |
| 휴식 카운트다운과 다음 세트 (F-08) | 세트 완료 시각 + 10초, + 30초에 tick | 10초: restRemainingSec 20, 이벤트 없음 / 30초: `[NextSetStarted(2)]`, phase exercising |
| 휴식 종료 3초 전 (F-06) | 세트 완료 시각 + 26초, + 27초, + 28초에 tick | 26초: 이벤트 없음 / 27초: `[RestEndingSoon(3)]` / 28초: 이벤트 없음(한 번만) |
| 부분 반복 누적 | exercising 중 onPartialRep 2번, 그 사이 onRep 1번 | `[PartialRepNoticed(1)]`, `[PartialRepNoticed(2)]`, repsInSet 1, partialsPerSet[0] 2 |
| 휴식 중 무시 | resting 중 onRep, onPartialRep | 둘 다 빈 목록, repsInSet 0, partialsPerSet[1] 0 |
| 건너뛰기 | resting 중 skipRest | `[NextSetStarted(2)]`, 이후 tick에서 RestEndingSoon 없음 |
| 일시정지 중 휴식 멈춤 | resting 5초 시점 pause, 20초 뒤 resume, 그 뒤 25초 지나 tick | NextSetStarted |
| 종료 | 3세트 모두 채움 / 1세트 4회에서 finish | 마지막에 `WorkoutFinished`, phase finished, sets 길이 3 / `[WorkoutFinished]`, sets[0] 길이 4 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/domain/workout_session_controller.dart`
- `app/test/features/workout/domain/workout_session_controller_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-08 인수 조건(로직 부분), F-06 휴식 종료 3초 전(이벤트) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- `RestEndingSoon` 이벤트 추가(휴식 종료 3초 전, 한 번), `nowMs`가 앱 시계 값임을 명시. 테스트: 3초 전 행 추가, 종료 두 행 합침
