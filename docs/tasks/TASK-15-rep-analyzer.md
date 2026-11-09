# TASK-15: 프레임 분석기(각도 → 횟수 → 오류 → 점수)

- 상태: 대기
- 선행 Task: TASK-07, TASK-08, TASK-09, TASK-12
- 실행 방식: 순차
- 실행 방식 근거: 판정 조각들을 묶는 연결 지점, 세션과 화면이 기댐
- Spec 출처: F-02~F-05 (7장, 9장 인수 조건), 8장 테스트 가능성

## 왜 이렇게 나눴나
프레임 하나를 넣으면 "반복 1회 결과"가 나오는 파이프라인이다. 녹화(합성) 클립 전체를 넣어 F-03, F-04, F-05 인수 조건을 끝에서 끝까지 확인하는 자리이기도 하다.

## 기능 범위 (Spec 발췌)
- 각도는 최근 5프레임 이동 평균으로 계산한다. 기준 관절: 푸쉬업 팔꿈치, 스쿼트 무릎
- 신뢰도 높은 쪽(좌/우) 자동 선택. 고를 수 없는 프레임은 건너뛴다(이동 평균에도 넣지 않음)
- 반복이 끝나면(RepEvent) 그 반복 구간(startMs~endMs) 프레임으로 오류 판정 후 점수 계산
- 인수 조건:
  - F-03: 푸쉬업 10회 녹화 클립을 넣으면 정확히 10이 나오고, 내려가다 멈추고 다시 올라온 동작은 세지 않는다.
  - F-04: 허리를 처지게 한 푸쉬업 클립을 넣으면 해당 반복에 `PU_HIP_SAG`가 기록된다.
  - F-05: 오류 없는 반복은 100점, 깊이 부족 반복은 75점으로 기록된다.
- 주의(INDEX D-01): 기본 기준에서는 최저 각도가 100 초과면 횟수가 세지지 않아 깊이 부족 반복이 생기지 않는다. 깊이 부족 75점 테스트는 `repThresholds`에 downDeg 120을 주입해 확인한다.

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `PoseFrame` | `app/lib/pose/landmarks/pose_landmark.dart` | TASK-04 계약 그대로 |
| `selectSide`, `SideAngles` | `app/lib/pose/angle/joint_angle.dart` | `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})`, `class SideAngles { const SideAngles({required BodySide side, required double elbow, required double knee, required double hip, required double visibility}); }` |
| `MovingAverage` | `app/lib/pose/angle/moving_average.dart` | `class MovingAverage { MovingAverage({int window = 5}); double add(double value); void reset(); bool get isFull; }` |
| `RepThresholds`, `RepCounter`, `RepEvent` | `app/lib/pose/rep/rep_counter.dart` | `class RepThresholds { const RepThresholds({required double upDeg, required double downDeg, required int minRepMs}); static RepThresholds forExercise(ExerciseType exercise); }`, `class RepCounter { RepCounter(RepThresholds thresholds); RepEvent? update({required int timestampMs, required double angle}); int get count; RepPhase get phase; void reset(); }`, `class RepEvent { const RepEvent({required int repIndex, required int startMs, required int bottomMs, required int endMs, required double minAngle}); int get durationMs; }` |
| `PoseErrorCode`, `ErrorThresholds`, `judgeRep` | `app/lib/pose/judge/` | `List<PoseErrorCode> judgeRep({required ExerciseType exercise, required List<PoseFrame> repFrames, required RepEvent rep, ErrorThresholds thresholds = const ErrorThresholds()})` |
| `scoreRep` | `app/lib/pose/score/rep_score.dart` | `int scoreRep({required List<PoseErrorCode> errors, required int durationMs})` |
| `repAngleSequence`, `buildSyntheticClip` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `RepResult` | `app/lib/pose/analyzer/rep_analyzer.dart` | `class RepResult { const RepResult({required int repIndex, required int score, required double minAngle, required int durationMs, required List<PoseErrorCode> errors}); }` | TASK-16, 17, 18, 26 |
| `RepAnalyzer` | 같은 파일 | `class RepAnalyzer { RepAnalyzer({required ExerciseType exercise, RepThresholds? repThresholds, ErrorThresholds errorThresholds = const ErrorThresholds(), int smoothingWindow = 5}); RepResult? addFrame(PoseFrame frame); int get count; double? get lastAngle; void reset(); }` | TASK-17, 26 |

## 범위
- 위 클래스. 반복 구간 프레임은 마지막 반복 종료 이후 프레임만 보관(메모리 누수 방지)

## 범위 밖 (건드리지 않음)
- 세트, 휴식(TASK-16), 판정 기준값 변경

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 푸쉬업 10회 클립 (F-03) | `buildSyntheticClip(pushUp, repAngleSequence(reps: 10))` 전체 addFrame | RepResult 10개, count 10 |
| 반쯤 내려갔다 올라옴 (F-03) | top 170, bottom 120 반복 3회 클립 | count 0 |
| 허리 처짐 클립 (F-04) | poseFor로 bodyLineDeg 140을 준 푸쉬업 3회 클립 | 모든 RepResult.errors에 puHipSag |
| 오류 없는 반복 100점 (F-05) | 정상 푸쉬업 1회 클립(1초) | score 100 |
| 깊이 부족 75점 (F-05) | 스쿼트 bottom 110, `repThresholds: RepThresholds(upDeg: 160, downDeg: 120, minRepMs: 800)` | errors [sqShallow], score 75 |
| 가려진 프레임 건너뜀 | 중간 5프레임 양쪽 visibility 0.1 | 예외 없이 count 유지, 결과 수 같음 |
| JSON 클립 왕복 | 위 10회 클립을 `encode` 후 `LandmarkClip.parse`해서 넣기 | count 10 |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/analyzer/rep_analyzer.dart`
- `app/test/pose/analyzer/rep_analyzer_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-03, F-04, F-05(점수) 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 이동 평균 때문에 합성 클립의 최저 각도가 기준을 넘지 못해 테스트 클립 값을 바꿔야 할 때(값 조정은 허용, 기준값 변경은 보고)

## 추가 발췌 (오케스트레이터가 보충)
