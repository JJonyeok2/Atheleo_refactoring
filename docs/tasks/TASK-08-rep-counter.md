# TASK-08: 횟수 상태 머신

- 상태: 대기
- 선행 Task: TASK-06, TASK-07
- 실행 방식: 순차
- 실행 방식 근거: 오류 판정, 점수, 세션 컨트롤러가 기대는 핵심 판정 로직
- Spec 출처: F-03 (3장, 7장 횟수 판정 기준, 9장 인수 조건)

## 왜 이렇게 나눴나
이미 부드럽게 만든 각도를 받아 UP/DOWN 상태만 판정하는 조각이다. 랜드마크나 오류는 모르고 "각도와 시각"만 받으므로 테스트가 단순하다.

## 기능 범위 (Spec 발췌)
| 운동 | 기준 관절 | UP | DOWN | 최소 1회 시간 |
|---|---|---|---|---|
| 푸쉬업 | 팔꿈치 | 160도 이상 | 100도 이하 | 0.6초 |
| 스쿼트 | 무릎 | 160도 이상 | 100도 이하 | 0.8초 |

- UP → DOWN → UP 순서가 완성될 때만 1회로 센다. 사이 구간(100~160)에서는 상태를 유지한다.
- 처음 UP에 도달하기 전에는 세지 않는다(시작 상태 unknown).
- 1회 시간(UP을 떠난 시각부터 다시 UP에 도달한 시각까지)이 최소 시간보다 짧으면 세지 않고 UP 상태로 돌아간다.
- 인수 조건(F-03): 푸쉬업 10회 녹화 클립을 넣으면 정확히 10이 나오고, 내려가다 멈추고 다시 올라온 동작은 세지 않는다.
- 주의: Spec 7장의 깊이 부족 오류(최저 각도 100도 초과)와 이 표의 DOWN(100도 이하)이 동시에 성립할 수 없다. INDEX.md "결정 필요 D-01" 참고. 이 Task는 임계값을 `RepThresholds`로 주입받게만 하고 표 값을 기본값으로 쓴다.

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `repAngleSequence` | `app/test/support/synthetic_clip.dart` | `List<double> repAngleSequence({required int reps, double top = 170, double bottom = 80, int framesPerRep = 30, int padFrames = 10})` (앞뒤 padFrames만큼 top 유지, 반복마다 top→bottom→top 코사인 곡선) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `RepThresholds` | `app/lib/pose/rep/rep_counter.dart` | `class RepThresholds { const RepThresholds({required double upDeg, required double downDeg, required int minRepMs}); static RepThresholds forExercise(ExerciseType exercise); }` | TASK-15 |
| `RepPhase` | 같은 파일 | `enum RepPhase { unknown, up, down }` | TASK-15 |
| `RepEvent` | 같은 파일 | `class RepEvent { const RepEvent({required int repIndex, required int startMs, required int bottomMs, required int endMs, required double minAngle}); int get durationMs; }` (repIndex 1부터, bottomMs는 최저 각도 시각) | TASK-09, 15 |
| `RepCounter` | 같은 파일 | `class RepCounter { RepCounter(RepThresholds thresholds); RepEvent? update({required int timestampMs, required double angle}); int get count; RepPhase get phase; void reset(); }` (1회가 완성된 프레임에서만 RepEvent 반환) | TASK-15 |

## 범위
- 위 상태 머신. 입력 각도는 이미 이동 평균된 값이라고 가정

## 범위 밖 (건드리지 않음)
- 이동 평균 적용, 랜드마크 처리(TASK-15), 오류 판정(TASK-09)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 푸쉬업 10회 (F-03) | `repAngleSequence(reps: 10)`을 30fps 시각과 함께 update | count 10, RepEvent 10개, repIndex 1~10 |
| 반쯤 내려갔다 올라옴 (F-03) | 170→120→170 시퀀스 | count 0 |
| 사이 구간 유지 | 170→90→130→90→170 | count 1 (130에서 UP으로 돌아가지 않음) |
| 너무 빠른 반복 | 푸쉬업 170→90→170을 0.3초 안에 | count 0, phase up |
| 스쿼트 최소 시간 | 스쿼트 0.7초 반복 / 1.0초 반복 | 0 / 1 |
| 시작 전 DOWN 무시 | 처음부터 90으로 시작 후 170 | count 0, phase up |
| RepEvent 값 | 1회 반복(최저 80) | minAngle 80 ± 0.5, startMs < bottomMs < endMs |

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
- D-01 결정에 따라 임계값 의미가 바뀌어야 할 때

## 추가 발췌 (오케스트레이터가 보충)
