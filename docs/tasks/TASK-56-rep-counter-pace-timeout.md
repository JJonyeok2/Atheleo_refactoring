# TASK-56: 횟수 상태 머신에 빠른 반복 사건과 최대 반복 시간(10초) 취소 추가

- 상태: 대기
- 선행 Task: TASK-08
- 실행 방식: 순차
- 실행 방식 근거: 완료된 `rep_counter.dart`의 공개 계약(sealed 사건 계층, `RepThresholds`)을 넓히는 기반 작업. 분석기(TASK-15, 49)와 오류 판정(TASK-09)이 이 파일에 기댐
- Spec 출처: F-03 (4장 예외 흐름 "너무 빠른 반복", "반복이 끝나지 않을 때", 7장 횟수 판정 기준 빠른 반복, 최대 반복 시간, 9장 F-03 인수 조건), 2026-11-13 변경 이력 "TASK-08 QA 결정 반영"

## 왜 이렇게 나눴나
TASK-08은 최소 시간보다 짧은 반복을 사건 없이 버렸고, 하강한 채 끝나지 않는 반복을 끊는 규칙이 없었다. 사용자 결정으로 두 규칙이 생겨, 완료된 상태 머신에 사건 두 종류와 임계값 하나만 더하는 조각으로 뗐다. 안내 문구와 화면 표시는 뒤 Task(15, 18, 27, 29)가 이 사건을 받아 처리한다.

## 기능 범위 (Spec 발췌)
- 빠른 반복: UP → DOWN → UP이 완성돼도 하강 시작부터 UP 복귀까지가 최소 1회 시간(푸쉬업 0.6초, 스쿼트 0.8초)보다 짧으면 횟수에 넣지 않고 부분 반복에도 넣지 않는다(점수, 깊이 오류도 기록하지 않음). 대신 "조금 더 천천히" 안내를 한다(안내 자체는 이 Task 밖).
- 최대 반복 시간: 하강 시작 후 10초가 지나도 반복이 끝나지 않으면 그 반복을 취소한다(횟수, 부분 반복 모두 미포함, 점수 없음). 취소 뒤에는 다시 편 자세(UP, 160도 이상)에 도달해야 다음 반복을 시작한다. 최저점에서 몇 초 멈추더라도 10초 안에 끝나면 정상 반복으로 센다. 10초는 초기값이며 보정 대상이다.
- 인수 조건(F-03, 이 Task 부분):
  - 푸쉬업을 0.6초보다 빠르게(스쿼트는 0.8초보다 빠르게) 한 번 하면 횟수와 부분 반복이 오르지 않고 빠른 반복 사건이 나온다.
  - 하강한 채 최저점에서 3초 멈췄다 올라오면 1회로 센다.
  - 하강 시작 후 10초가 지나도 올라오지 않으면 그 반복은 횟수와 부분 반복 어디에도 들어가지 않고, 다시 완전히 편 자세(UP)가 된 뒤의 반복부터 센다.
- 이 Task에서 정하는 규칙:
  - 빠른 반복: DOWN에 닿은 뒤 UP 복귀 프레임에서 `endMs - startMs < minRepMs`이면 `TooFastRepEvent`를 돌려준다. `count`, `partialCount`는 그대로, phase는 up. 다음 정상 반복의 repIndex는 빠른 반복을 건너뛴 번호(예: 첫 정상 반복이면 1)
  - 최소 시간 규칙은 반복에만 적용. 부분 반복은 지금처럼 시간과 관계없이 `PartialRepEvent`
  - 취소: phase가 descending 또는 down인 프레임에서 `timestampMs - startMs > maxRepMs`이면 그 프레임에서 `RepCancelledEvent`를 돌려준다. 이 판단이 UP 복귀 판단보다 먼저다(10초를 넘겨 UP에 온 프레임도 취소). 경과가 정확히 `maxRepMs`인 UP 복귀는 정상 반복
  - 취소하면 보관한 시각, 원시 각도 목록을 비우고 phase를 unknown으로 둔다. 같은 프레임에 unknown 규칙(angle ≥ upDeg면 up)을 그대로 적용한다. `count`, `partialCount`는 그대로
  - `RepThresholds.maxRepMs`는 생성자에서 생략하면 10000. `forExercise`는 푸쉬업, 스쿼트 모두 10000
  - 기존 TASK-08 계약(`RepEvent`, `PartialRepEvent`, `RepPhase`, `RepCounter` 시그니처, reset 규칙, 3프레임 중앙값)은 바꾸지 않는다

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `RepThresholds`, `RepPhase`, `RepCounterEvent`, `RepEvent`, `PartialRepEvent`, `RepCounter` | `app/lib/pose/rep/rep_counter.dart` | TASK-08 구현 그대로(아래 "내보내는 것"으로 넓힘). 지금 코드는 `_finish`에서 최소 시간 미달이면 `null`을 돌려줌 |
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `repAngleSequence` | `app/test/support/synthetic_clip.dart` | `List<double> repAngleSequence({required int reps, double top = 170, double bottom = 80, int framesPerRep = 30, int padFrames = 10})` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `RepThresholds` | `app/lib/pose/rep/rep_counter.dart` | `class RepThresholds { const RepThresholds({required double upDeg, required double descendDeg, required double downDeg, required int minRepMs, int maxRepMs = 10000}); static RepThresholds forExercise(ExerciseType exercise); }` (기본 160, 145, 120, 푸쉬업 600ms, 스쿼트 800ms, maxRepMs 둘 다 10000) | TASK-15 |
| `TooFastRepEvent` | 같은 파일 | `final class TooFastRepEvent extends RepCounterEvent { const TooFastRepEvent({required int startMs, required int endMs}); int get durationMs; }` (DOWN 도달 후 UP 복귀했지만 minRepMs 미만. count, partialCount 미포함) | TASK-15 |
| `RepCancelledEvent` | 같은 파일 | `final class RepCancelledEvent extends RepCounterEvent { const RepCancelledEvent({required int startMs, required int cancelledMs}); }` (하강 시작 후 maxRepMs 초과. 이후 phase unknown, UP 재도달 전에는 반복 시작 안 함) | TASK-15, 49 |
| `RepCounter` | 같은 파일 | TASK-08 시그니처 그대로: `class RepCounter { RepCounter(RepThresholds thresholds); RepCounterEvent? update({required int timestampMs, required double angle, double? rawAngle}); int get count; int get partialCount; RepPhase get phase; void reset(); }` (사건을 돌려주는 프레임: 반복, 부분 반복, 빠른 반복이 끝난 프레임과 취소 프레임) | TASK-15 |

### 읽기만 하는 파일
- 없음

## 범위
- `RepThresholds.maxRepMs`, `TooFastRepEvent`, `RepCancelledEvent` 추가와 `RepCounter`의 빠른 반복, 취소 처리
- 기존 테스트 중 "최소 시간 미달이면 사건 없음"을 확인하던 두 곳(`푸쉬업 0.3초 안의 반복은 세지 않음`의 `expect(events, isEmpty)`, `스쿼트 0.7초 반복은 0, 1.0초 반복은 1`의 `expect(shortEvents, isEmpty)`)만 새 규칙(`TooFastRepEvent` 1개)으로 바꾼다. 이 두 테스트의 count, partialCount, phase 확인과 다른 테스트는 그대로 둔다
- 파일 푸터의 `[유지보수]` 중 이 Task로 해소되는 두 줄(빠른 반복 무피드백, 최대 시간 규칙 없음)은 QA가 정리한다(Impl은 푸터를 고치지 않음)

## 범위 밖 (건드리지 않음)
- 안내 문구, 음성, 화면 표시(TASK-18, 27, 29), 분석기 출력(TASK-15), 자세 게이트(TASK-49)
- `timestampMs` 역행, NaN 각도 검증(호출하는 TASK-15 몫)
- 판정 기준값(160, 145, 120, 600ms, 800ms) 변경

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 기본 maxRepMs | `forExercise(pushUp)`, `forExercise(squat)`, maxRepMs를 생략한 `RepThresholds(...)` | 셋 다 maxRepMs 10000 (기존 기본값 확인 테스트에 더해도 됨) |
| 푸쉬업 빠른 반복 (F-03, 기존 테스트 기대 수정) | 30fps로 [170, 140, 90, 140, 170] | 사건 1개 `TooFastRepEvent`(startMs 33, endMs 133, durationMs 100), count 0, partialCount 0, phase up |
| 스쿼트 0.7초 / 1.0초 (기존 테스트 기대 수정) | 기존 입력 그대로(stepMs 100) | 0.7초: `TooFastRepEvent`(startMs 100, endMs 800) 1개, count 0 / 1.0초: 기존 기대 그대로 `RepEvent` 1개 |
| 빠른 반복 뒤 정상 반복 | 푸쉬업 빠른 반복 1회 → 이어서 `repAngleSequence(reps: 1)` | 두 번째 사건 `RepEvent` repIndex 1, count 1, partialCount 0 |
| 최저점 3초 정지는 정상 (F-03) | stepMs 100: 170, 140(t=100), 120, 90을 t=3300까지 유지, 120, 140, 170(t=4000 근처) | `RepEvent` 1개, count 1, 그 전 프레임에서는 사건 없음 |
| 10초 초과 취소 (F-03) | stepMs 100: 170, 140(t=100), 90을 t=10100까지 → t=10200도 90 → 90 몇 프레임 → 140 → 170 → 정상 1회(1초) / 다른 카운터: 170, 140을 t=10200까지 유지(DOWN 미도달) | t=10100까지 사건 없음, t=10200에 `RepCancelledEvent`(startMs 100, cancelledMs 10200), phase unknown, 이후 90, 140 프레임은 사건 없음, 170에서 phase up, 다음 `RepEvent` repIndex 1, partialCount 0 / `RepCancelledEvent` 1개, partialCount 0 |
| 10초 경계 | stepMs 100: 170, 140(t=100), 90 유지, t=10100에 170 / 같은 입력에서 t=10200에 170 | `RepEvent`(durationMs 10000), count 1 / `RepCancelledEvent`(cancelledMs 10200), count 0, phase up(같은 프레임에 unknown 규칙 적용) |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/rep/rep_counter.dart`
- `app/test/pose/rep/rep_counter_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 위 "범위"에 적은 두 기대값 외의 기존 TASK-08 테스트가 그대로 통과
- [ ] 다른 기존 테스트(특히 `app/test/pose/judge/`의 TASK-09 테스트)가 깨지지 않음
- [ ] F-03 인수 조건 중 빠른 반복, 최저점 정지, 10초 취소 부분 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때(예: `RepEvent`를 switch로 다루는 기존 코드가 sealed 하위 타입 추가로 컴파일되지 않을 때)
- `RepPhase`에 값을 더하거나 `RepCounter` 시그니처를 바꿔야만 할 것 같을 때
- 기능 범위와 연결 범위만으로 판단할 수 없는 정보가 필요할 때 (Spec을 직접 열지 말고 무엇이 부족한지 보고)
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
