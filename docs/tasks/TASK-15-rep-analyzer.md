# TASK-15: 프레임 분석기(각도 → 횟수 → 오류 → 점수)

- 상태: 대기
- 선행 Task: TASK-07, TASK-08, TASK-09, TASK-12
- 실행 방식: 순차
- 실행 방식 근거: 판정 조각들을 묶는 연결 지점, 세션과 화면이 기댐
- Spec 출처: F-02~F-05 (7장 횟수 판정 기준, 깊이 판정, 시간 기준, 9장 인수 조건), 8장 테스트 가능성

## 왜 이렇게 나눴나
프레임 하나를 넣으면 "반복 1회 결과" 또는 "부분 반복"이 나오는 파이프라인이다. 녹화(합성) 클립 전체를 넣어 F-03, F-04, F-05 인수 조건을 끝에서 끝까지 확인하는 자리이기도 하다. 측정 쪽 유지 규칙과 자세 게이트는 다음 Task(TASK-49)에서 같은 파일에 더한다.

## 기능 범위 (Spec 발췌)
- 기준 관절: 푸쉬업 팔꿈치, 스쿼트 무릎
- 상태 전이는 이동 평균 각도로 판정한다. 이동 평균 창은 시간 기준(최근 약 150ms, 최소 1프레임)
- 반복의 최저 각도(깊이 판정)는 원시 각도로 계산한다(최저점 주변 3프레임 중앙값, 계산은 RepCounter가 함)
- 프레임 타임스탬프는 판정 분석(이동 평균 창, 최소 1회 시간, duration_ms)에서만 쓴다. 분석기 밖으로 프레임 시각을 세션 시간으로 내보내지 않는다
- 처음 UP에 도달하기 전의 움직임은 세지 않는다. 다음 세트 시작과 일시정지 재개 때 분석기 상태를 초기화(reset)하고 이 규칙을 다시 적용한다. rep_index는 세트 안에서 1부터
- 이 Task에서 정하는 규칙:
  - 프레임마다 `selectSide`로 고른 쪽의 기준 관절 각도를 원시 각도로 쓴다. 고를 수 없는 프레임은 건너뛴다(이동 평균, RepCounter, 반복 구간 프레임 어디에도 넣지 않음)
  - 원시 각도를 `MovingAverage.add(raw, t)`에 넣은 값을 `angle`로, 원시 각도를 `rawAngle`로 `RepCounter.update`에 넘긴다
  - 반복이 끝나면(`RepEvent`) 그 반복 구간(startMs~endMs) 프레임으로 `judgeRep` 후 `scoreRep`
  - 부분 반복(`PartialRepEvent`)은 점수를 매기지 않고 그대로 알린다(오류 판정, 점수 계산 안 함)
  - `reset()`은 이동 평균, RepCounter, 보관 프레임을 모두 비운다
- 인수 조건:
  - F-03: 푸쉬업 10회 녹화 클립을 넣으면 정확히 10이 나온다. 130도까지만 내려갔다 올라온 동작은 세지 않고 부분 반복 사건이 1번 나온다. 155도까지만 흔들린 동작은 아무 사건도 나오지 않는다. 같은 클립을 15fps와 30fps로 넣어도 횟수가 같다. 재개 직후 처음 UP 전 움직임은 세지 않는다.
  - F-04: 허리를 처지게 한 푸쉬업 클립은 `PU_HIP_SAG`, 엉덩이를 든 클립은 `PU_HIP_PIKE`가 기록되고 서로 바뀌어 나오지 않는다. 최저 각도 105도 반복은 횟수로 세면서 `PU_SHALLOW`가 기록된다. 최저점이 1~2프레임만 짧게 88도를 찍는 85~95도 반복에서 min_angle은 최저점 주변 3프레임 원시 각도의 중앙값으로 기록되고, 이동 평균 때문에 실제보다 얕게 판정되지 않는다.
  - F-05: 오류 없는 반복은 100점, 깊이 부족 반복은 75점으로 기록된다.

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `PoseFrame` | `app/lib/pose/landmarks/pose_landmark.dart` | TASK-04 계약 그대로 |
| `selectSide`, `SideAngles` | `app/lib/pose/angle/joint_angle.dart` | `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})` (평균 visibility 높은 쪽, 같으면 left, 둘 다 기준 미만이면 null. 고른 쪽의 세 점 묶음(어깨-팔꿈치-손목, 골반-무릎-발목, 어깨-골반-무릎, 어깨-골반-발목) 중 하나라도 벡터 길이가 0이거나 좌표가 유한하지 않으면 그쪽은 쓸 수 없는 것으로 보고, 다른 쪽이 visibility 기준과 이 조건을 만족하면 다른 쪽을, 둘 다 안 되면 null), `class SideAngles { const SideAngles({required BodySide side, required double elbow, required double knee, required double hip, required double visibility}); }` |
| `MovingAverage` | `app/lib/pose/angle/moving_average.dart` | `class MovingAverage { MovingAverage({int windowMs = 150}); double add(double value, int timestampMs); void reset(); int get length; }` |
| `RepThresholds`, `RepCounter` | `app/lib/pose/rep/rep_counter.dart` | `class RepThresholds { const RepThresholds({required double upDeg, required double descendDeg, required double downDeg, required int minRepMs}); static RepThresholds forExercise(ExerciseType exercise); }`, `class RepCounter { RepCounter(RepThresholds thresholds); RepCounterEvent? update({required int timestampMs, required double angle, double? rawAngle}); int get count; int get partialCount; RepPhase get phase; void reset(); }` |
| `RepEvent`, `PartialRepEvent` | 같은 파일 | `final class RepEvent extends RepCounterEvent { const RepEvent({required int repIndex, required int startMs, required int bottomMs, required int endMs, required double minAngle}); int get durationMs; }`, `final class PartialRepEvent extends RepCounterEvent { const PartialRepEvent({required int startMs, required int endMs, required double minAngle}); }` (minAngle은 원시 각도 최저점 주변 3프레임 중앙값) |
| `PoseErrorCode`, `ErrorThresholds`, `judgeRep` | `app/lib/pose/judge/` | `List<PoseErrorCode> judgeRep({required ExerciseType exercise, required List<PoseFrame> repFrames, required RepEvent rep, ErrorThresholds thresholds = const ErrorThresholds()})` |
| `scoreRep` | `app/lib/pose/score/rep_score.dart` | `int scoreRep({required List<PoseErrorCode> errors, required int durationMs})` |
| `repAngleSequence`, `buildSyntheticClip`, `SyntheticPose`, `HipOffset` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만, `poseFor`는 `(int frameIndex, double angle)`) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `AnalyzerOutput` | `app/lib/pose/analyzer/rep_analyzer.dart` | `sealed class AnalyzerOutput` | TASK-27 |
| `RepResult` | 같은 파일 | `final class RepResult extends AnalyzerOutput { const RepResult({required int repIndex, required int score, required double minAngle, required int durationMs, required List<PoseErrorCode> errors}); }` (repIndex는 reset 이후 1부터) | TASK-16, 17, 18, 27 |
| `PartialRep` | 같은 파일 | `final class PartialRep extends AnalyzerOutput { const PartialRep({required double minAngle, required int endMs}); }` | TASK-27 |
| `RepAnalyzer` | 같은 파일 | `class RepAnalyzer { RepAnalyzer({required ExerciseType exercise, RepThresholds? repThresholds, ErrorThresholds errorThresholds = const ErrorThresholds(), int smoothingWindowMs = 150}); AnalyzerOutput? addFrame(PoseFrame frame); int get count; int get partialCount; double? get lastAngle; void reset(); }` (lastAngle은 마지막 이동 평균 각도) | TASK-49 (TASK-49가 생성자 인자와 `side`를 더해 최종 계약을 TASK-27에 넘김) |

## 범위
- 위 클래스. 반복 구간 프레임은 마지막 사건(반복 또는 부분 반복) 이후 프레임만 보관(메모리 누수 방지)

## 범위 밖 (건드리지 않음)
- 측정 쪽 유지 규칙(0.5초), 자세 게이트(TASK-49), 세트, 휴식(TASK-16), 판정 기준값 변경

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 푸쉬업 10회, 15fps와 30fps (F-03) | `buildSyntheticClip(pushUp, repAngleSequence(reps: 10), fps: 30)` / `repAngleSequence(reps: 10, framesPerRep: 15)`를 fps 15로 | 둘 다 RepResult 10개, PartialRep 0개, count 10 |
| 부분 반복과 흔들림 (F-03) | top 170, bottom 130 반복 1회 클립 / bottom 155 클립 | PartialRep 1개, RepResult 0개 / 출력 없음 |
| 처짐과 들림 구분 (F-04) | poseFor로 bodyLineDeg 140, hipOffset below / above를 준 푸쉬업 3회 클립 | 모든 RepResult.errors에 puHipSag만 / puHipPike만 |
| 105도 75점, 정상 100점 (F-04, F-05) | 푸쉬업 bottom 105, 1초 반복 / bottom 80, 1초 반복 | count 1, errors [puShallow], score 75 / score 100 |
| 짧은 최저점은 얕게 판정하지 않음 (F-04) | 팔꿈치 원시 각도가 ... 95, 92, 88, 88, 92, 95 ...인 1회(그 밖은 완만한 곡선) | RepResult.minAngle 88 ± 0.5, errors에 puShallow 없음 |
| 쓸 수 없는 프레임 건너뜀 | 10회 클립 중간 5프레임을 양쪽 visibility 0.1로, 다른 5프레임은 보이는 쪽 팔꿈치와 손목을 같은 좌표로(반대쪽은 가려짐) | 예외 없음, count 10, PartialRep 0개(0도가 이동 평균에 들어가지 않음) |
| reset 후 처음부터 (F-03) | 3회 넣고 reset → 팔꿈치 90에서 시작하는 동작 → 정상 1회 | reset 뒤 count 0, 90에서 시작한 동작은 출력 없음, 다음 RepResult.repIndex 1 |
| JSON 클립 왕복 | 10회 클립을 `encode` 후 `LandmarkClip.parse`해서 넣기 | count 10 |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/analyzer/rep_analyzer.dart`
- `app/test/pose/analyzer/rep_analyzer_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-03(게이트 제외), F-04, F-05(점수) 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 이동 평균 때문에 합성 클립의 최저 각도가 기준에 닿지 않아 테스트 클립 값을 바꿔야 할 때(클립 값 조정은 허용, 판정 기준값 변경은 보고)

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 이동 평균을 시간 기준(`smoothingWindowMs = 150`)으로, RepCounter에 원시 각도 전달, reset 규칙과 rep_index 1부터를 명시
- 측정 쪽 유지와 자세 게이트는 Task가 커져 TASK-49로 분리. 테스트: 15/30fps, 짧은 최저점, reset 추가, 기존 행 묶음
