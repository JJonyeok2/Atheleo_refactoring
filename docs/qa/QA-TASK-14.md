# QA-TASK-14

- 검토일: 2026-11-13
- 판정: FIX

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/features/workout/domain/setup_guide_controller.dart` | 추가함(헤더 1~3행, 푸터 끝 7행) | Impl이 헤더를 달지 않아 새로 추가. 주석 외 변경 없음 |
| `app/test/features/workout/domain/setup_guide_controller_test.dart` | 테스트 파일이라 달지 않음 | 23건 |

- 주석 추가 후 `dart format` 대상 2개 변경 없음, `flutter analyze` 대상 2개 0건, `flutter test test/features/workout/domain/` 34건 통과.

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 문제 | `update` 137~148행 | 좌표 이상값(NaN, Infinity, 점 겹침, 낮은 visibility)은 body_check가 걸러 notFullBody(테스트 4건). 시각 역행은 다시 잼. 그러나 프레임 사이 간격을 보지 않아 안정 시간 판정이 실제 관측 없이 채워질 수 있음(아래 FIX 1). 생성자 `stableFor`, `countdownSec` 음수/0 검사 없음(비차단 권고) |
| XSS 등 출력 처리 | 해당 없음 |  | 문구는 상수, Flutter Text로 출력 예정 |
| 인증 / 인가 | 해당 없음 |  | 순수 상태 머신 |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 출력 없음 |
| 새 의존성 | 통과 |  | `flutter/foundation`(`@immutable`)과 내부 모듈만 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 |  | `selectSide`가 `isFullBodyVisible`, `passesPostureGate`, `_isInPosture`에서 각각 불리지만 같은 기본값이라 같은 쪽을 고름. 프레임당 비용 무시 가능 |
| 함수 길이 | 통과 |  | 가장 긴 `_blockingState` 22줄 |
| 이름 | 통과 |  | `_blockingState`, `_timedState`, `_readySinceMs` 의미 분명 |
| 죽은 코드 | 통과 |  | 없음 |
| 테스트가 인수 조건을 검증하는가 | 통과(간격 케이스 없음) |  | Red 표 8행 모두 대응. 추가로 160도 경계, 오른쪽 측면, 카운트다운 중 깨짐, 노이즈, 시각 역행, 주입 값, reset, 값 비교. 프레임 간격이 벌어지는 경우는 테스트 없음 |

## Impl 결정 평가
| 결정 | 평가 |
|---|---|
| (1) 첫 update 전, reset 후 state = noPerson | 타당. 프레임이 아직 없으니 "카메라 앞에 서 주세요"가 맞음. 단 TASK-51은 "status가 바뀔 때 말함"이므로 화면이 직전 status를 `controller.state`(noPerson)로 시작하면 첫 `update(null)`에서 말하지 않아 TASK-51 첫 테스트(speak 첫 항목 '카메라 앞에 서 주세요')가 깨짐. 화면은 "마지막으로 말한 status"를 null로 시작해야 함 — TASK-51 추가 발췌 권고 |
| (2) 판정 순서 noPerson→notFullBody→frontFacing→notInPosture | Task 표 순서 그대로. visibility 낮은 정면이 notFullBody가 먼저인 것도 QA-TASK-13 푸터 권고(isFrontFacing은 visibility를 안 봄)와 맞음 |
| (3) 프레임 간격 상한 없음 | 문제(FIX 1). holding 1000ms에서 카메라 정지나 백그라운드로 10초 비었다가 첫 프레임이 오면 경과 11000ms로 바로 ready. 사용자는 3, 2, 1 없이 '시작'만 듣고 운동 화면으로 넘어감. 1초 넘게 비면 카운트다운 숫자도 건너뜀. 촬영 가이드 화면에는 앱 lifecycle 처리가 없어(TASK-28은 운동 화면만) 컨트롤러가 막아야 함. "2초 이상 안정적으로 유지"는 그 사이 프레임으로 확인된 시간이어야 함 |
| (4) 시각 역행 시 그 시각부터 다시 잼 | 타당. 안전한 쪽(늦게 시작). 테스트 있음 |
| (5) 카운트다운 계산, 입력 검사 없음 | 계산 맞음(`remaining = countdownSec - (elapsed - stable) ~/ 1000`, 2000→3, 3000→2, 4000→1, 5000→ready). `countdownSec <= 0`이면 카운트다운 없이 ready, `stableFor` 음수면 holding 없이 countdown. 호출은 기본값뿐이라 비차단, `assert(countdownSec >= 0)`, `assert(!stableFor.isNegative)` 권고 |
| (6) 160도 상수, `passesPostureGate` 기본값 호출 | 타당. 160도는 Task 표 값. side를 넘기지 않아도 게이트 내부 `selectSide`가 같은 기본값으로 같은 쪽을 고름. 굳이 바꾸려면 `side: side.side`로 넘겨 한 번만 고르게 할 수 있음(선택) |

### 스쿼트 frontFacing과 notInPosture 문구가 같은 문제
- 둘 다 '옆으로 서 주세요'. 두 문구 모두 Task 기능 범위(Spec 발췌)에 적힌 그대로라 TASK-14 구현 결함은 아님.
- TASK-25(화면): status가 달라도 같은 글자가 보일 뿐, 화면 동작에 영향 없음.
- TASK-51(음성): frontFacing→notInPosture로 바뀌면 status 변화라 다시 말하려 하지만, `VoiceGuide.say`의 같은 문장 쿨다운 5초(voice_guide.dart 81~82행)에 걸려 버려짐. 결과적으로 반복 발화는 없음. 다만 측면으로 돌아선 사용자가 무릎/몸통 때문에 계속 notInPosture면 "옆으로 서 주세요"만 보고 듣게 되어 무엇을 고칠지 모름. 이건 Spec 문구 판단이라 오케스트레이터가 사용자에게 확인할 사항으로 남김(이 Task FIX 아님).
- 관련 위험(TASK-51 쪽): 같은 쿨다운 때문에 카운트다운이 깨졌다가 5초 안에 다시 시작되면 '3', '2', '1'이 묻힘. FIX 1을 넣으면 재시작이 더 잦아질 수 있으니 TASK-51에서 카운트다운 숫자와 '시작'의 쿨다운 처리를 정해야 함.

## 계약 대조 (내보내는 것)
| 이름 | Task 계약 | 구현 | 소비 Task 표기 |
|---|---|---|---|
| `SetupGuideStatus` | 7개 값, 순서 포함 | 일치 | TASK-51 일치 |
| `SetupGuideState` | `const ({required status, required message, int? countdown})`, `==` | 일치(`==`, `hashCode`, `toString`) | TASK-25, 51 일치 |
| `SetupGuideTexts`, `setupGuideTextsFor` | `({required distanceHint, required postureHint})`, Spec 문구 | 일치, 문구 글자 단위 일치 | TASK-25 일치 |
| `SetupGuideController` | `({required ExerciseType exercise, Duration stableFor = 2s, int countdownSec = 3})`, `update(PoseFrame?, int)`, `state`, `reset()` | 일치(private named parameter `this._exercise`, 호출 쪽 이름은 `exercise:`) | TASK-25 일치 |

## FIX 항목 (Impl로 회귀)

### Task 보충 권고 (오케스트레이터가 TASK-14 "추가 발췌"에 먼저 적을 것)
- 준비 조건 프레임 사이 간격이 500ms를 넘으면(직전 `update`의 시각과 비교, 상태 무관) 안정 시간을 그 프레임 시각부터 다시 잰다. holding, countdown 모두 같은 규칙이며 결과는 holding.
- 생성자에 선택 인자 `Duration maxFrameGap = const Duration(milliseconds: 500)` 추가. 기존 인자, 기본값, 시그니처는 그대로(TASK-25 호출 호환). 값 근거: 30fps 33ms, 저사양 lite 10fps 100ms에서 일시적 프레임 누락 몇 개는 허용하고, 카메라 정지/백그라운드(수 초)는 확실히 거름.
- 내보내는 것 표의 `SetupGuideController` 계약에 `Duration maxFrameGap = const Duration(milliseconds: 500)` 추가 표기.

### Impl 수정
- [ ] `app/lib/features/workout/domain/setup_guide_controller.dart:137~148` — `int? _lastUpdateMs` 필드를 두고 `update`마다 갱신(null 프레임 포함, ready 반환 전에는 갱신 불필요). 준비 조건 통과 시 `since == null || timestampMs < since || timestampMs - _lastUpdateMs > maxGapMs`면 `start = timestampMs`. `reset()`에서 `_lastUpdateMs = null`. 시각 역행 규칙은 유지.
- [ ] `app/test/features/workout/domain/setup_guide_controller_test.dart` — 테스트 추가: (a) 0~1000ms 30fps 후 11000ms 프레임 → holding, 이후 13000ms까지 30fps면 countdown 3 (b) countdown 중(3500ms) 다음 프레임이 4100ms(간격 600ms) → holding (c) 간격 정확히 500ms는 이어서 잼(경계) (d) `maxFrameGap` 주입.
- [ ] (비차단, 같이 처리 권장) 생성자에 `assert(countdownSec >= 0)`, `assert(!stableFor.isNegative)`.

## 다른 Task로 넘길 메모
- TASK-51 추가 발췌 권고: 화면의 "마지막으로 말한 status"는 null로 시작(컨트롤러 초기 state가 noPerson이라 그대로 비교하면 첫 안내가 빠짐). 카운트다운 숫자와 '시작'은 VoiceGuide 같은 문장 쿨다운(5초)에 걸릴 수 있으니 처리 방식을 정할 것.
- 사용자 확인 사항: 스쿼트 준비 자세 안내 '옆으로 서 주세요'가 정면 안내와 같아, 측면인데 몸통이 기울거나 무릎이 굽은 경우 무엇을 고칠지 알려 주지 못함(Spec 문구 문제).

## PEER_REVIEW 사유
- 해당 없음
