# TASK-08: 횟수 상태 머신(부분 반복 감지 포함)

- 상태: 대기
- 선행 Task: TASK-06, TASK-07
- 실행 방식: 순차
- 실행 방식 근거: 오류 판정, 점수, 세션 컨트롤러가 기대는 핵심 판정 로직
- Spec 출처: F-03 (3장, 7장 횟수 판정 기준, 9장 인수 조건)

## 왜 이렇게 나눴나
이미 부드럽게 만든 각도를 받아 상태만 판정하는 조각이다. "반복을 시도했는가"(횟수, 부분 반복)만 다루고, "충분히 깊었는가"(깊이 부족)는 오류 판정(TASK-09)이 `minAngle`로 따로 본다.

## 기능 범위 (Spec 발췌)
| 운동 | 기준 관절 | UP | 하강 시작 | DOWN(횟수 인정) | 최소 1회 시간 |
|---|---|---|---|---|---|
| 푸쉬업 | 팔꿈치 | 160도 이상 | 145도 미만 | 120도 이하 | 0.6초 |
| 스쿼트 | 무릎 | 160도 이상 | 145도 미만 | 120도 이하 | 0.8초 |

| 구간 | 기준 | 횟수 | 결과 |
|---|---|---|---|
| 부분 반복 | 145도 미만으로 내려갔다가 120도 이하에 닿지 못하고 다시 160도 이상 | 세지 않음 | `PARTIAL` 사건 |
| 반복 | DOWN(120도 이하) 도달 후 다시 160도 이상 | 셈 | `RepEvent` |

- UP → DOWN → UP 순서가 완성될 때만 1회로 센다. DOWN에 닿은 뒤 120~160도 사이에서는 상태를 유지한다.
- 145도 아래로 내려가지 않은 흔들림(예: 155도)은 아무 사건도 만들지 않는다.
- 처음 UP에 도달하기 전의 움직임은 세지 않는다(시작 상태 unknown).
- 이 Task에서 정하는 규칙:
  - 1회 시간 = 하강 시작(145 미만이 된 시각)부터 다시 160 이상이 된 시각까지. 최소 시간보다 짧은 반복은 세지 않고 사건도 내지 않으며 UP으로 돌아간다
  - 최소 시간 규칙은 반복에만 적용. 부분 반복은 시간과 관계없이 사건을 낸다
- 인수 조건(F-03): 푸쉬업 10회 녹화 클립을 넣으면 정확히 10이 나온다. 130도까지만 내려갔다 올라온 동작은 세지 않고 부분 반복 사건이 1번 나온다. 155도까지만 흔들린 동작은 아무 사건도 나오지 않는다.

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `repAngleSequence` | `app/test/support/synthetic_clip.dart` | `List<double> repAngleSequence({required int reps, double top = 170, double bottom = 80, int framesPerRep = 30, int padFrames = 10})` (앞뒤 padFrames만큼 top 유지, 반복마다 top→bottom→top 코사인 곡선) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `RepThresholds` | `app/lib/pose/rep/rep_counter.dart` | `class RepThresholds { const RepThresholds({required double upDeg, required double descendDeg, required double downDeg, required int minRepMs}); static RepThresholds forExercise(ExerciseType exercise); }` (기본 160, 145, 120, 푸쉬업 600ms, 스쿼트 800ms) | TASK-15 |
| `RepPhase` | 같은 파일 | `enum RepPhase { unknown, up, descending, down }` (descending = 145 미만, 아직 120 이하에 닿지 않음) | TASK-15 |
| `RepCounterEvent` | 같은 파일 | `sealed class RepCounterEvent` | TASK-15 |
| `RepEvent` | 같은 파일 | `final class RepEvent extends RepCounterEvent { const RepEvent({required int repIndex, required int startMs, required int bottomMs, required int endMs, required double minAngle}); int get durationMs; }` (repIndex 1부터, bottomMs는 최저 각도 시각) | TASK-09, 15 |
| `PartialRepEvent` | 같은 파일 | `final class PartialRepEvent extends RepCounterEvent { const PartialRepEvent({required int startMs, required int endMs, required double minAngle}); }` | TASK-15 |
| `RepCounter` | 같은 파일 | `class RepCounter { RepCounter(RepThresholds thresholds); RepCounterEvent? update({required int timestampMs, required double angle}); int get count; int get partialCount; RepPhase get phase; void reset(); }` (반복이나 부분 반복이 끝난 프레임에서만 사건 반환) | TASK-15 |

## 범위
- 위 상태 머신. 입력 각도는 이미 이동 평균된 값이라고 가정

## 범위 밖 (건드리지 않음)
- 이동 평균 적용, 랜드마크 처리(TASK-15), 깊이 부족 등 오류 판정(TASK-09)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 푸쉬업 10회 (F-03) | `repAngleSequence(reps: 10)`을 30fps 시각과 함께 update | count 10, RepEvent 10개, repIndex 1~10, PartialRepEvent 0개 |
| 130도 부분 반복 (F-03) | 170→130→170 | count 0, PartialRepEvent 1개(minAngle 130 ± 0.5), partialCount 1 |
| 155도 흔들림 (F-03) | 170→155→170 | 사건 없음, phase up |
| 얕아도 120 이하면 셈 | 170→105→170 (1초) | RepEvent 1개, minAngle 105 ± 0.5 |
| DOWN 뒤 사이 구간 유지 | 170→110→140→110→170 | count 1 (140에서 UP으로 돌아가지 않음) |
| 너무 빠른 반복 | 푸쉬업 170→90→170을 0.3초 안에 | 사건 없음, phase up |
| 시작 전 움직임 무시 | 처음부터 90, 이어서 170 | 사건 없음, phase up |
| 스쿼트 최소 시간 | 스쿼트 0.7초 반복 / 1.0초 반복 | 0 / 1 |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/rep/rep_counter.dart`
- `app/test/pose/rep/rep_counter_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-03 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 기능 범위와 연결 범위만으로 판단할 수 없는 정보가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)
