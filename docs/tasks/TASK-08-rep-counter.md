# TASK-08: 횟수 상태 머신(부분 반복 감지, 원시 각도 최저점)

- 상태: 대기
- 선행 Task: TASK-06, TASK-07
- 실행 방식: 순차
- 실행 방식 근거: 오류 판정, 점수, 세션 컨트롤러가 기대는 핵심 판정 로직
- Spec 출처: F-03, F-04 (3장, 7장 횟수 판정 기준, 깊이 판정, 9장 인수 조건)

## 왜 이렇게 나눴나
이미 부드럽게 만든 각도로 상태만 판정하고, 깊이(최저 각도)는 함께 받은 원시 각도로 기록하는 조각이다. "반복을 시도했는가"(횟수, 부분 반복)만 다루고, "충분히 깊었는가"(깊이 부족)는 오류 판정(TASK-09)이 `minAngle`로 따로 본다.

## 기능 범위 (Spec 발췌)
| 운동 | 기준 관절 | UP | 하강 시작 | DOWN(횟수 인정) | 최소 1회 시간 |
|---|---|---|---|---|---|
| 푸쉬업 | 팔꿈치 | 160도 이상 | 145도 미만 | 120도 이하 | 0.6초 |
| 스쿼트 | 무릎 | 160도 이상 | 145도 미만 | 120도 이하 | 0.8초 |

| 구간 | 기준 | 횟수 | 결과 |
|---|---|---|---|
| 부분 반복 | 145도 미만으로 내려갔다가 120도 이하에 닿지 못하고 다시 160도 이상 | 세지 않음 | `PARTIAL` 사건 |
| 반복 | DOWN(120도 이하) 도달 후 다시 160도 이상 | 셈 | `RepEvent` |

- 상태 전이(UP, 하강, DOWN)는 이동 평균 각도로 판정한다.
- 반복의 최저 각도(RepRecord.min_angle, 깊이 판정)는 이동 평균이 아니라 원시 각도로 계산한다. 원시 각도가 가장 낮은 프레임과 그 앞뒤 프레임, 모두 3프레임의 중앙값을 최저 각도로 쓴다(튀는 값 1개 제거).
- UP → DOWN → UP 순서가 완성될 때만 1회로 센다. DOWN에 닿은 뒤 120~160도 사이에서는 상태를 유지한다.
- 145도 아래로 내려가지 않은 흔들림(예: 155도)은 아무 사건도 만들지 않는다.
- 처음 UP에 도달하기 전의 움직임은 세지 않는다(시작 상태 unknown). 다음 세트 시작과 일시정지 재개 때 분석기 상태를 초기화하고 이 규칙을 다시 적용한다(reset).
- 이 Task에서 정하는 규칙:
  - 1회 시간 = 하강 시작(145 미만이 된 시각)부터 다시 160 이상이 된 시각까지. 최소 시간보다 짧은 반복은 세지 않고 사건도 내지 않으며 UP으로 돌아간다
  - 최소 시간 규칙은 반복에만 적용. 부분 반복은 시간과 관계없이 사건을 낸다
  - 최저 각도는 하강 시작부터 끝 프레임까지의 원시 각도로 구한다. 최저 프레임이 구간 맨 앞이나 맨 뒤면 구간 안의 연속 3프레임(최저 프레임 포함)으로, 구간이 3프레임보다 짧으면 있는 프레임의 중앙값(2개면 평균)으로 한다. `bottomMs`는 원시 각도가 가장 낮은 프레임의 시각
  - `rawAngle`을 주지 않으면 `angle`을 원시 각도로 쓴다
  - reset은 count, partialCount, 상태(unknown)를 모두 처음으로 돌린다. 그 뒤 첫 반복의 repIndex는 1
- 인수 조건:
  - F-03: 푸쉬업 10회 녹화 클립을 넣으면 정확히 10이 나온다. 130도까지만 내려갔다 올라온 동작은 세지 않고 부분 반복 사건이 1번 나온다. 155도까지만 흔들린 동작은 아무 사건도 나오지 않는다.
  - F-04(이 Task 부분): 최저점이 1~2프레임만 짧게 88도를 찍는 반복에서 min_angle은 최저점 주변 3프레임 원시 각도의 중앙값으로 기록된다.

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
| `RepPhase` | 같은 파일 | `enum RepPhase { unknown, up, descending, down }` (descending = 145 미만, 아직 120 이하에 닿지 않음) | TASK-15, 49 |
| `RepCounterEvent` | 같은 파일 | `sealed class RepCounterEvent` | TASK-15 |
| `RepEvent` | 같은 파일 | `final class RepEvent extends RepCounterEvent { const RepEvent({required int repIndex, required int startMs, required int bottomMs, required int endMs, required double minAngle}); int get durationMs; }` (repIndex는 reset 이후 1부터, bottomMs는 원시 각도 최저 프레임 시각, minAngle은 원시 각도 최저점 주변 3프레임 중앙값) | TASK-09, 15 |
| `PartialRepEvent` | 같은 파일 | `final class PartialRepEvent extends RepCounterEvent { const PartialRepEvent({required int startMs, required int endMs, required double minAngle}); }` (minAngle은 RepEvent와 같은 방식) | TASK-15 |
| `RepCounter` | 같은 파일 | `class RepCounter { RepCounter(RepThresholds thresholds); RepCounterEvent? update({required int timestampMs, required double angle, double? rawAngle}); int get count; int get partialCount; RepPhase get phase; void reset(); }` (angle은 이동 평균 각도로 상태 전이에 씀, rawAngle은 최저 각도 계산에 씀. 반복이나 부분 반복이 끝난 프레임에서만 사건 반환) | TASK-15 |

## 범위
- 위 상태 머신. 입력 angle은 이미 이동 평균된 값이라고 가정

## 범위 밖 (건드리지 않음)
- 이동 평균 적용, 랜드마크 처리, 자세 게이트(TASK-15, 49), 깊이 부족 등 오류 판정(TASK-09)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 푸쉬업 10회 (F-03) | `repAngleSequence(reps: 10)`을 30fps 시각과 함께 update | count 10, RepEvent 10개, repIndex 1~10, PartialRepEvent 0개 |
| 130도 부분 반복 (F-03) | 170→130→170 | count 0, PartialRepEvent 1개(minAngle 130 ± 0.5), partialCount 1 |
| 155도 흔들림 (F-03) | 170→155→170 | 사건 없음, phase up |
| 얕아도 120 이하면 셈 | 170→105→170 (1초, rawAngle 생략) | RepEvent 1개, minAngle 105 ± 0.5 |
| DOWN 뒤 사이 구간 유지 | 170→110→140→110→170 | count 1 (140에서 UP으로 돌아가지 않음) |
| 최소 시간 | 푸쉬업 170→90→170을 0.3초 안에 / 스쿼트 0.7초 반복, 1.0초 반복 | 사건 없음, phase up / 0, 1 |
| 원시 최저 각도 3프레임 중앙값 (F-04) | angle은 완만한 곡선(최저 100), rawAngle 최저 부근 ... 95, 92, 88, 88, 92, 95 ... / 다른 반복은 ... 92, 92, 70, 92, 92 ... | minAngle 88 ± 0.01, bottomMs = 첫 88 프레임 시각 / minAngle 92 ± 0.01(튀는 값 70 제거) |
| 시작 전 움직임 무시와 reset | 처음부터 90, 이어서 170 / 3회 센 뒤 reset, 이어서 90에서 시작하는 1회와 정상 1회 | 사건 없음, phase up / reset 직후 count 0, phase unknown, 90에서 시작한 동작은 세지 않고 다음 반복 repIndex 1 |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/rep/rep_counter.dart`
- `app/test/pose/rep/rep_counter_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-03 인수 조건과 F-04 최저 각도 부분 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 기능 범위와 연결 범위만으로 판단할 수 없는 정보가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- `update`에 `rawAngle` 추가. `RepEvent.minAngle`, `PartialRepEvent.minAngle`, `bottomMs`를 원시 각도 최저점 주변 3프레임 중앙값으로 정의
- reset 뒤 repIndex가 1부터 다시 시작함을 계약과 테스트에 명시
- 테스트: 최소 시간 두 행 합침, 3프레임 중앙값, reset 행 추가
