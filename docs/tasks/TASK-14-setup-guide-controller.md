# TASK-14: 촬영 가이드 상태 머신

- 상태: 대기
- 선행 Task: TASK-13
- 실행 방식: 순차
- 실행 방식 근거: 화면(TASK-25)이 기대는 상태 설계 판단이 필요함
- Spec 출처: F-07 (4장 정상 흐름 2~3번, 9장 인수 조건)

## 왜 이렇게 나눴나
"2초 안정 후 3초 카운트다운"을 타임스탬프만으로 움직이는 순수 상태 머신으로 만든다. 화면 Task는 이 상태를 그리기만 한다.

## 기능 범위 (Spec 발췌)
- 촬영 가이드 화면: "휴대폰을 옆에 세우고 측면으로 서 주세요", 전신이 보이는 실루엣 표시
- 전신이 2초 이상 안정적으로 잡히면 3초 카운트다운 후 시작
- 정면 판단 시 "옆으로 서 주세요" 안내
- 인수 조건(F-07): 촬영 가이드에서 정면으로 서면 "옆으로 서 주세요"가 표시되고, 측면으로 2초 서면 카운트다운이 시작된다.
- 이 Task에서 정하는 상태와 문구:

| 상태 | 조건 | 문구 |
|---|---|---|
| noPerson | 프레임 없음 | 카메라 앞에 서 주세요 |
| notFullBody | 전신 인식 실패 | 휴대폰을 옆에 세우고 측면으로 서 주세요 |
| frontFacing | 정면 판정 | 옆으로 서 주세요 |
| holding | 측면 전신, 2초 미만 | 그대로 유지하세요 |
| countdown | 2초 유지 후 3초 동안 | 3, 2, 1 (countdown 값) |
| ready | 카운트다운 끝 | 시작합니다 |

- holding이나 countdown 중 조건이 깨지면 해당 상태로 돌아가고 시간은 처음부터 다시 잰다. ready가 되면 더 바뀌지 않는다.

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `isFullBodyVisible` | `app/lib/pose/body/body_check.dart` | `bool isFullBodyVisible(PoseFrame frame, {double minVisibility = 0.5})` |
| `isFrontFacing` | 같은 파일 | `bool isFrontFacing(PoseFrame frame, {double ratioThreshold = 0.35})` |
| `SyntheticPose`, `buildSyntheticFrame` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SetupGuideStatus` | `app/lib/features/workout/domain/setup_guide_controller.dart` | `enum SetupGuideStatus { noPerson, notFullBody, frontFacing, holding, countdown, ready }` | TASK-25 |
| `SetupGuideState` | 같은 파일 | `class SetupGuideState { const SetupGuideState({required SetupGuideStatus status, required String message, int? countdown}); }` | TASK-25 |
| `SetupGuideController` | 같은 파일 | `class SetupGuideController { SetupGuideController({Duration stableFor = const Duration(seconds: 2), int countdownSec = 3}); SetupGuideState update(PoseFrame? frame, int timestampMs); SetupGuideState get state; void reset(); }` | TASK-25 |

## 범위
- 위 상태 머신

## 범위 밖 (건드리지 않음)
- 음성, 화면, 카메라(TASK-25)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 정면 안내 (F-07) | 정면 프레임(shoulderWidthRatio 0.7) | status frontFacing, message '옆으로 서 주세요' |
| 측면 2초 후 카운트다운 (F-07) | 측면 전신 프레임을 0~2000ms 30fps로 | 1999ms까지 holding, 2000ms 이후 countdown, countdown 3 |
| 카운트다운 진행 | 이어서 3초 더 | countdown 3→2→1, 5000ms 이후 ready |
| 중간에 깨짐 | holding 1500ms 시점에 정면 프레임, 다시 측면 | frontFacing을 거쳐 다시 2초를 새로 잼 |
| 사람 없음 | `update(null, t)` | noPerson, '카메라 앞에 서 주세요' |
| ready 유지 | ready 후 null 프레임 | ready 그대로 |

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
