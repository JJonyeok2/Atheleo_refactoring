# TASK-52: 휴식, 일시정지 중 분석 중단과 분석기 초기화

- 상태: 대기
- 선행 Task: TASK-27
- 실행 방식: 순차
- 실행 방식 근거: TASK-27과 같은 컨트롤러 파일을 고침. TASK-28이 이 재개 경로에 기댐
- Spec 출처: F-03, F-08 (4장 정상 흐름 7번, 7장 횟수 판정 기준, 9장 인수 조건 F-03, F-08)

## 왜 이렇게 나눴나
정상 흐름(TASK-27)이 통과한 뒤 "언제 분석기에 프레임을 넣지 않고, 언제 초기화하는가"만 더한다. 같은 규칙을 사용자 재개와 자동 재개(TASK-28)가 함께 쓰도록 재개 경로를 하나로 만든다.

## 기능 범위 (Spec 발췌)
- 목표 횟수 달성 → 휴식 카운트다운(분석 중단) → "다음 세트를 시작하세요" → 분석기 초기화 후 다음 세트(측정 쪽 다시 결정, 반복 번호 1부터)
- 휴식과 일시정지 중에는 분석기에 프레임을 넣지 않는다.
- 처음 UP에 도달하기 전의 움직임은 세지 않는다. 다음 세트 시작과 일시정지 재개 때 분석기 상태를 초기화하고 이 규칙을 다시 적용한다.
- RepRecord.rep_index는 세트 안에서 1부터
- 인수 조건:
  - F-08: 휴식 중 팔을 굽혔다 펴도 횟수가 오르지 않는다.
  - F-03: 휴식 뒤 다음 세트 첫 반복의 rep_index는 1이고, 재개 직후 처음 UP 전 움직임은 세지 않는다.
- 이 Task에서 정하는 규칙:
  - 세션 phase가 exercising일 때만 `analyzer.addFrame`을 부른다. resting, paused, finished에서는 state.frame(스켈레톤 표시)만 갱신한다
  - `NextSetStarted` 이벤트가 나오면(tick, skipRest 모두) `analyzer.reset()`
  - `resume()`: `session.resume(nowMs)` 후 `analyzer.reset()`. 다른 Task의 재개(사람이 돌아옴, 이어서 하기)도 이 메서드를 거친다

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `WorkoutController`, `workoutControllerProvider`, `WorkoutViewState` | `app/lib/features/workout/application/` | `class WorkoutController extends AutoDisposeFamilyNotifier<WorkoutViewState, ExerciseType> { Future<void> start(); void skipRest(); void pause(); void resume(); Future<void> finish(); }` (TASK-27 구현) |
| `RepAnalyzer` | `app/lib/pose/analyzer/rep_analyzer.dart` | `void reset();` (이동 평균, 횟수, 측정 쪽 초기화. 이후 repIndex 1부터, 처음 UP 전 무시) |
| `WorkoutPhase`, `NextSetStarted` | `app/lib/features/workout/domain/workout_session_controller.dart` | `enum WorkoutPhase { exercising, resting, paused, finished }`, `final class NextSetStarted extends WorkoutEvent { const NextSetStarted(this.setIndex); final int setIndex; }` |
| `clockProvider` | `app/lib/core/clock.dart` | `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);` |
| `FakePoseDetector`, `buildSyntheticClip`, `repAngleSequence` | `app/test/support/` | TASK-06, 19 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutController.resume` | `app/lib/features/workout/application/workout_controller.dart` | `void resume()` (세션 재개 + `analyzer.reset()`. 재개는 모두 이 경로) | TASK-28, 53 |
| 분석 투입 규칙 | 같은 파일 | phase가 exercising일 때만 분석기에 프레임을 넣음 | TASK-28 |

## 범위
- 위 규칙을 컨트롤러에 추가

## 범위 밖 (건드리지 않음)
- 사람 미검출, 백그라운드, lite 전환(TASK-28), 화면(TASK-29, 53), 분석기 내부(TASK-15, 49)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 휴식 중 프레임 미투입 (F-08) | 1세트를 채워 resting으로 만든 뒤 반복 3회 합성 프레임 emit | RepCounted 없음, TTS '1회' 없음, repsInSet 0, state.frame은 갱신됨 |
| 다음 세트 rep_index 1 (F-03) | 휴식이 끝나 NextSetStarted 뒤 팔꿈치 90에서 시작하는 동작 → 정상 1회 emit | 90에서 시작한 동작은 세지 않음, 2세트 첫 RepResult.repIndex 1 |
| 일시정지와 재개 (F-03) | 반복 중 pause() → 반복 2회 emit → resume() → 90에서 시작하는 동작 → 정상 1회 | 일시정지 중 횟수 변화 없음, 재개 직후 동작은 세지 않음, 다음 반복은 셈 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/application/workout_controller.dart`
- `app/test/features/workout/application/workout_controller_analysis_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] TASK-27 테스트가 깨지지 않음
- [ ] F-03(재개, 다음 세트), F-08(휴식 중 횟수) 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- TASK-27 계약을 바꿔야 할 때

## 추가 발췌 (오케스트레이터가 보충)
