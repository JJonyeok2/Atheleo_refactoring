# TASK-14: 촬영 가이드 상태 머신(운동별 준비 조건과 문구)

- 상태: 대기
- 선행 Task: TASK-13
- 실행 방식: 순차
- 실행 방식 근거: 화면(TASK-25)과 음성(TASK-51)이 기대는 상태 설계 판단이 필요함
- Spec 출처: F-07, F-06 (4장 정상 흐름 2~3번, 7장 자세 게이트, 9장 인수 조건 F-07)

## 왜 이렇게 나눴나
"운동별 준비 조건 2초 안정 후 3초 카운트다운"을 타임스탬프만으로 움직이는 순수 상태 머신으로 만든다. 화면 Task는 이 상태를 그리고 말하기만 한다.

## 기능 범위 (Spec 발췌)
- 촬영 가이드 화면: 운동별 안내 문구, 거리 안내, 전신이 보이는 실루엣 표시
  - 푸쉬업: "휴대폰을 옆에 세우고 측면에서 약 2m 이상 떨어져 주세요. 전신이 화면에 들어와야 해요." 준비 자세 안내 "엎드려 팔을 편 자세를 잡아 주세요"
  - 스쿼트: "휴대폰을 옆에 세우고 측면에서 약 2m 떨어져 주세요. 전신이 화면에 들어와야 해요." 준비 자세 안내 "옆으로 서 주세요"
- 운동별 준비 조건(자세 게이트 포함)이 2초 이상 안정적으로 유지되면 3·2·1 카운트다운과 "시작" 안내 후 운동 화면으로 넘어간다.
- 자세 게이트: 푸쉬업 몸통이 수평에서 30도 이내, 스쿼트 몸통이 수직에서 30도 이내(촬영 가이드 준비 조건)
- 정면 판단 시 "옆으로 서 주세요" 안내
- 인수 조건(F-07, 이 Task 부분): 스쿼트는 몸통이 수직에서 30도 이내일 때 준비 조건을 통과한다. 정면으로 서면 "옆으로 서 주세요"가 표시되고, 운동별 준비 조건을 2초 유지하면 카운트다운이 시작된다.
- 이 Task에서 정하는 상태와 문구:

| 상태 | 조건(위에서부터 먼저 걸리는 것) | 문구 |
|---|---|---|
| noPerson | 프레임 없음 | 카메라 앞에 서 주세요 |
| notFullBody | 전신 인식 실패 | 운동별 거리 안내(`distanceHint`) |
| frontFacing | 정면 판정 | 옆으로 서 주세요 |
| notInPosture | 자세 게이트 실패, 또는 기준 관절(푸쉬업 팔꿈치, 스쿼트 무릎)이 160도 미만 | 운동별 준비 자세 안내(`postureHint`) |
| holding | 준비 조건 통과, 2초 미만 | 그대로 유지하세요 |
| countdown | 2초 유지 후 3초 동안 | 3, 2, 1 (countdown 값, message도 '3', '2', '1') |
| ready | 카운트다운 끝 | 시작 |

- holding이나 countdown 중 조건이 깨지면 해당 상태로 돌아가고 시간은 처음부터 다시 잰다. ready가 되면 더 바뀌지 않는다.
- 기준 관절 각도는 `selectSide`로 고른 쪽 값을 쓴다(준비 자세가 "팔을 편 / 선" 자세인지 확인).

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `isFullBodyVisible`, `isFrontFacing`, `passesPostureGate` | `app/lib/pose/body/body_check.dart` | `bool isFullBodyVisible(PoseFrame frame, {double minVisibility = 0.5})`, `bool isFrontFacing(PoseFrame frame, {double ratioThreshold = 0.35})`, `bool passesPostureGate(PoseFrame frame, ExerciseType exercise, {BodySide? side, double maxDeg = 30})` |
| `selectSide` | `app/lib/pose/angle/joint_angle.dart` | `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})` (`SideAngles.elbow`, `SideAngles.knee`) |
| `SyntheticPose`, `buildSyntheticFrame` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SetupGuideStatus` | `app/lib/features/workout/domain/setup_guide_controller.dart` | `enum SetupGuideStatus { noPerson, notFullBody, frontFacing, notInPosture, holding, countdown, ready }` | TASK-25, 51 |
| `SetupGuideState` | 같은 파일 | `class SetupGuideState { const SetupGuideState({required SetupGuideStatus status, required String message, int? countdown}); }` (`==` 구현) | TASK-25, 51 |
| `SetupGuideTexts`, `setupGuideTextsFor` | 같은 파일 | `class SetupGuideTexts { const SetupGuideTexts({required String distanceHint, required String postureHint}); }`, `SetupGuideTexts setupGuideTextsFor(ExerciseType exercise)` (위 Spec 문구 그대로) | TASK-25 |
| `SetupGuideController` | 같은 파일 | `class SetupGuideController { SetupGuideController({required ExerciseType exercise, Duration stableFor = const Duration(seconds: 2), int countdownSec = 3}); SetupGuideState update(PoseFrame? frame, int timestampMs); SetupGuideState get state; void reset(); }` | TASK-25 |

## 범위
- 위 상태 머신과 문구

## 범위 밖 (건드리지 않음)
- 음성(TASK-51), 화면, 카메라(TASK-25)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 운동별 문구 (F-07) | `setupGuideTextsFor(pushUp)`, `setupGuideTextsFor(squat)` / 발목이 화면 밖인 프레임 | 위 Spec 문구 그대로 / notFullBody, message가 그 운동의 distanceHint |
| 정면 안내 (F-07) | 정면 프레임(shoulderWidthRatio 0.7) | status frontFacing, message '옆으로 서 주세요' |
| 서 있는 푸쉬업 (F-07) | pushUp 컨트롤러에 bodyTiltDeg 90 프레임 | notInPosture, '엎드려 팔을 편 자세를 잡아 주세요' |
| 스쿼트 게이트 (F-07) | squat 컨트롤러에 torsoLeanDeg 45 / 20 프레임 | notInPosture '옆으로 서 주세요' / holding |
| 준비 조건 2초 후 카운트다운 (F-07) | pushUp 기본 프레임(엎드림, 팔꿈치 170)을 0~2000ms 30fps로 | 1999ms까지 holding, 2000ms 이후 countdown, countdown 3 |
| 카운트다운 진행 | 이어서 3초 더 | countdown 3→2→1(message '3'→'2'→'1'), 5000ms 이후 ready, message '시작' |
| 중간에 깨짐 | holding 1500ms 시점에 정면 프레임, 다시 측면 | frontFacing을 거쳐 다시 2초를 새로 잼 |
| 사람 없음과 ready 유지 | `update(null, t)` / ready 후 null 프레임 | noPerson, '카메라 앞에 서 주세요' / ready 그대로 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/domain/setup_guide_controller.dart`
- `app/test/features/workout/domain/setup_guide_controller_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-07 인수 조건(로직 부분) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 운동별 컨트롤러(`exercise` 필수), 상태 `notInPosture` 추가, 운동별 거리 안내와 준비 자세 문구(`setupGuideTextsFor`), ready 문구 '시작', countdown message '3', '2', '1'
- 자세 게이트와 기준 관절 160도 이상을 준비 조건에 포함. 테스트 8행으로 재구성
