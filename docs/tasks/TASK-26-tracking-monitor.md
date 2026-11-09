# TASK-26: 추적 감시(사람 미검출, 저사양 전환 판단)

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 병렬 (그룹: G3)
- 실행 방식 근거: `app/lib/features/workout/domain/tracking_monitor.dart`만 새로 만드는 순수 로직, 공유 타입을 건드리지 않음
- Spec 출처: F-01 (4장 예외 흐름: 사람이 안 보일 때, 추론이 느릴 때)

## 왜 이렇게 나눴나
"언제 일시정지하고 언제 lite로 바꿀지" 판단만 시각 값으로 계산한다. 실제 일시정지, 음성, 모델 전환은 TASK-28이 이 신호를 받아 실행한다.

## 기능 범위 (Spec 발췌)
- 사람이 안 보일 때: 2초 이상 미검출 시 일시정지, 다시 잡히면 자동 재개
- 추론이 느릴 때(저사양): 10초 평균 10fps 미만이면 lite 모델로 전환
- 이 Task에서 정하는 규칙:
  - 미검출 시작 시각부터 2000ms 이상 지나면 `personLost` 1번. 이후 사람이 잡히면 `personReturned` 1번
  - fps = 최근 10초 창 안 결과 개수 / 10. 첫 결과부터 10초가 지난 뒤부터 판단
  - `switchToLite`는 한 번만 낸다(lite에서 full로 돌아가지 않음)

## 연결 범위

### 받아 쓰는 것
없음

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `TrackingSignal` | `app/lib/features/workout/domain/tracking_monitor.dart` | `enum TrackingSignal { personLost, personReturned, switchToLite }` | TASK-28 |
| `TrackingMonitor` | 같은 파일 | `class TrackingMonitor { TrackingMonitor({Duration lostAfter = const Duration(seconds: 2), Duration fpsWindow = const Duration(seconds: 10), double minFps = 10}); List<TrackingSignal> onResult({required int timestampMs, required bool hasPerson}); bool get isPersonLost; bool get switchedToLite; void reset(); }` | TASK-28 |

## 범위
- 위 클래스

## 범위 밖 (건드리지 않음)
- 감지기 호출, 음성, 화면

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 2초 미검출 | 0~1900ms 사람 없음 / 2000ms 사람 없음 | 1900ms까지 신호 없음, 2000ms에 `[personLost]` |
| 한 번만 | 이후 2500ms 사람 없음 | 빈 목록 |
| 다시 잡힘 | 3000ms 사람 있음 | `[personReturned]`, isPersonLost false |
| 짧은 끊김 무시 | 1초 없음 후 다시 있음 | 신호 없음 |
| 느린 추론 | 0~10초 동안 8fps 간격으로 결과 | 10초 이후 `[switchToLite]` 한 번 |
| 빠른 추론 | 0~10초 동안 25fps | 신호 없음 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/domain/tracking_monitor.dart`
- `app/test/features/workout/domain/tracking_monitor_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
