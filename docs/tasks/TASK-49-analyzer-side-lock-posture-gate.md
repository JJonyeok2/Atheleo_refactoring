# TASK-49: 분석기 측정 쪽 유지 규칙과 자세 게이트

- 상태: 대기
- 선행 Task: TASK-06, TASK-08, TASK-13, TASK-15
- 실행 방식: 순차
- 실행 방식 근거: TASK-15와 같은 파일(`rep_analyzer.dart`)을 고치고, 운동 진행 컨트롤러(TASK-27)가 이 최종 계약에 기댐
- Spec 출처: F-02, F-03, F-07 (7장 측정 쪽 유지 규칙, 자세 게이트, 9장 인수 조건)

## 왜 이렇게 나눴나
2026-11-13 설계 검토로 분석기에 두 규칙이 생겼다. TASK-15에 함께 넣으면 테스트가 14건을 넘어 따로 뗐다. TASK-05의 `selectSide`는 프레임 하나만 보는 함수로 그대로 두고, "시간에 걸친 유지"는 분석기가 맡는다.

## 기능 범위 (Spec 발췌)
- 측정 쪽 유지 규칙:
  - 측정 쪽(좌/우)은 세트 시작 때 신뢰도가 높은 쪽으로 정한다.
  - 세트 중에는 선택된 쪽의 신뢰도가 기준 아래로 떨어진 상태가 0.5초 이상 이어질 때만 반대쪽으로 바꾼다. 짧게 흔들리는 것으로는 바꾸지 않는다.
- 자세 게이트(운동 자세가 아닌 상태에서 팔꿈치나 무릎을 굽혀 횟수가 올라가는 것을 막음):

| 운동 | 조건 | 적용 |
|---|---|---|
| 푸쉬업 | 몸통이 수평에서 30도 이내 | 운동 중 매 프레임. 벗어난 프레임은 상태 전이에 쓰지 않는다 |
| 스쿼트 | 몸통이 수직에서 30도 이내 | 세트의 처음 UP 인정 |

- 인수 조건:
  - F-02: 세트 중 선택된 쪽 신뢰도가 0.3초 떨어졌다 돌아오면 측정 쪽이 바뀌지 않고, 0.5초 이상 떨어져 있으면 반대쪽으로 바뀐다.
  - F-03: 몸통이 수평에서 30도 넘게 기운(서 있는) 상태에서 팔을 굽혔다 편 클립은 푸쉬업 횟수가 오르지 않는다.
  - F-07(분석기 부분): 스쿼트는 몸통이 수직에서 30도 이내일 때 세트의 처음 UP 인정을 통과한다.
- 이 Task에서 정하는 규칙:
  - "세트 시작" = 분석기 생성 직후 또는 `reset()` 직후. 그 뒤 처음으로 `selectSide`가 null이 아닌 프레임의 side로 측정 쪽을 정한다
  - 프레임마다 `anglesForSide(frame, 측정 쪽)`을 본다. 그쪽 visibility가 0.5 이상이고 기준 관절 각도가 0보다 크면(0은 측정 불가) 정상 프레임
  - 정상이 아니면 그 프레임은 건너뛰고(이동 평균, RepCounter, 보관 프레임에 넣지 않음) 떨어진 시각을 기록한다. 떨어진 상태가 `sideSwitchAfterMs`(500) 이상 이어진 프레임에서 `selectSide`가 반대쪽을 고르면 측정 쪽을 바꾸고 그 프레임부터 반대쪽 각도를 쓴다. 바꿀 때 RepCounter와 이동 평균은 초기화하지 않는다
  - 정상 프레임이 오면 떨어진 시각 기록을 지운다
  - 푸쉬업: `passesPostureGate(frame, pushUp, side: 측정 쪽, maxDeg: gateMaxDeg)`가 false인 프레임은 건너뛴다(측정 쪽 판단 다음, 이동 평균 전)
  - 스쿼트: RepCounter의 phase가 unknown인 동안에만 게이트를 적용해, 통과하지 못한 프레임은 건너뛴다. 처음 UP 이후에는 적용하지 않는다(깊이 앉을 때 상체가 숙여지므로)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `RepAnalyzer` 외 | `app/lib/pose/analyzer/rep_analyzer.dart` | TASK-15 계약: `class RepAnalyzer { RepAnalyzer({required ExerciseType exercise, RepThresholds? repThresholds, ErrorThresholds errorThresholds = const ErrorThresholds(), int smoothingWindowMs = 150}); AnalyzerOutput? addFrame(PoseFrame frame); int get count; int get partialCount; double? get lastAngle; void reset(); }` |
| `selectSide`, `anglesForSide`, `SideAngles` | `app/lib/pose/angle/joint_angle.dart` | `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})`, `SideAngles anglesForSide(PoseFrame frame, BodySide side)` (TASK-05 계약 그대로, 고치지 않음) |
| `passesPostureGate` | `app/lib/pose/body/body_check.dart` | `bool passesPostureGate(PoseFrame frame, ExerciseType exercise, {BodySide? side, double maxDeg = 30})` |
| `RepPhase` | `app/lib/pose/rep/rep_counter.dart` | `enum RepPhase { unknown, up, descending, down }` |
| `buildSyntheticClip`, `repAngleSequence`, `SyntheticPose` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만, `poseFor: (frameIndex, angle)`, `bodyTiltDeg`, `torsoLeanDeg`, `visibleSide`) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `RepAnalyzer` | `app/lib/pose/analyzer/rep_analyzer.dart` | `class RepAnalyzer { RepAnalyzer({required ExerciseType exercise, RepThresholds? repThresholds, ErrorThresholds errorThresholds = const ErrorThresholds(), int smoothingWindowMs = 150, int sideSwitchAfterMs = 500, double gateMaxDeg = 30}); AnalyzerOutput? addFrame(PoseFrame frame); int get count; int get partialCount; double? get lastAngle; BodySide? get side; void reset(); }` (side는 현재 측정 쪽, 세트 시작 전 null. reset은 측정 쪽도 지움) | TASK-27, 52 |
| `AnalyzerOutput`, `RepResult`, `PartialRep` | 같은 파일 | TASK-15 계약 그대로 | TASK-16, 17, 18, 27 |

## 범위
- 위 규칙을 `RepAnalyzer`에 추가

## 범위 밖 (건드리지 않음)
- `joint_angle.dart`(TASK-05 완료, `selectSide` 그대로), `body_check.dart`, 판정 기준값

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 0.3초 흔들림은 유지 (F-02) | 왼쪽이 보이는 푸쉬업 10회 클립, 앞 padFrames 구간에서 9프레임(0.3초)만 visibleSide right | 모든 프레임 뒤 side left, count 10 |
| 0.5초 이상이면 전환 (F-02) | 왼쪽으로 시작해 앞 padFrames 뒤부터 끝까지 visibleSide right | 떨어진 지 500ms가 된 프레임부터 side right, 이후 반복이 세어짐 |
| 세트 시작 때 다시 결정 (F-02) | 왼쪽 클립 몇 프레임 → reset → 오른쪽만 보이는 프레임 | reset 직후 side null, 그 뒤 side right |
| 서 있는 푸쉬업 (F-03) | poseFor로 bodyTiltDeg 90을 준 푸쉬업 10회 클립 | count 0, 출력 없음 |
| 엎드린 푸쉬업은 그대로 (F-03) | bodyTiltDeg 0 기본 10회 클립 | count 10 |
| 스쿼트 처음 UP 게이트 (F-07) | 처음부터 끝까지 torsoLeanDeg 45인 스쿼트 3회 / 처음 padFrames는 torsoLeanDeg 15, 반복 중 최저점에서 40인 스쿼트 3회 | count 0 / count 3 |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/analyzer/rep_analyzer.dart`
- `app/test/pose/analyzer/rep_analyzer_side_gate_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] TASK-15 테스트가 깨지지 않음
- [ ] F-02(유지 규칙), F-03(게이트) 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때(특히 `selectSide`를 바꿔야 할 것 같을 때)
- 측정 쪽을 바꿀 때 RepCounter를 초기화해야만 테스트가 통과할 때(규칙 변경이므로 보고)
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
