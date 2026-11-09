# TASK-28: 운동 중 예외 처리(사람 미검출, 저사양, 백그라운드, 추론 실패)

- 상태: 대기
- 선행 Task: TASK-26, TASK-27
- 실행 방식: 순차
- 실행 방식 근거: TASK-27과 같은 컨트롤러 파일을 고침
- Spec 출처: F-01, F-06 (4장 예외 흐름), 8장 모니터링

## 왜 이렇게 나눴나
정상 흐름(TASK-27)이 통과한 뒤 예외 흐름만 더해, 한 Task가 너무 커지지 않게 했다.

## 기능 범위 (Spec 발췌)
- 사람이 안 보일 때: 2초 이상 미검출 시 일시정지, "카메라 앞에 서 주세요" 음성 안내, 다시 잡히면 자동 재개
- 추론이 느릴 때(저사양): 10초 평균 10fps 미만이면 lite 모델로 전환
- 운동 중 앱이 백그라운드로 갈 때: 세션 일시정지, 복귀 시 "이어서 할까요?" 확인
- 추론 실패를 Sentry에 보고(여기서는 `ErrorReporter`로)
- 이 Task에서 정하는 규칙:
  - personLost → `session.pause`, notice '카메라 앞에 서 주세요', `VoiceCues.noPerson` 재생
  - personReturned → 사용자가 직접 일시정지한 상태가 아니면 `session.resume`, notice null
  - switchToLite → `detector.setModel(PoseModel.lite)`
  - 앱 `paused` 상태 → pause, 돌아오면(`resumed`) askResume true + `VoiceCues.askResume`. `confirmResume(true)`면 resume, false면 finish
  - 결과 스트림 오류 → `errorReporter.report(error, st, tag: 'inference_failed')`, 운동은 계속(구독 유지)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `TrackingMonitor`, `TrackingSignal` | `app/lib/features/workout/domain/tracking_monitor.dart` | `class TrackingMonitor { TrackingMonitor({Duration lostAfter = const Duration(seconds: 2), Duration fpsWindow = const Duration(seconds: 10), double minFps = 10}); List<TrackingSignal> onResult({required int timestampMs, required bool hasPerson}); bool get isPersonLost; bool get switchedToLite; void reset(); }`, `enum TrackingSignal { personLost, personReturned, switchToLite }` |
| `WorkoutController`, `WorkoutViewState` | `app/lib/features/workout/application/` | TASK-27 계약 그대로 |
| `VoiceCues` | `app/lib/features/workout/domain/voice_cues.dart` | `abstract final class VoiceCues { static const VoiceCue noPerson; static const VoiceCue askResume; }` |
| `PoseModel` | `app/lib/pose/detector/pose_detector.dart` | `enum PoseModel { full, lite }` |
| `ErrorReporter`, `errorReporterProvider` | `app/lib/core/monitoring/error_reporter.dart` | `abstract class ErrorReporter { Future<void> report(Object error, StackTrace? stackTrace, {String? tag, Map<String, Object?> context = const {}}); }` |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | TASK-19 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutController.confirmResume` | `app/lib/features/workout/application/workout_controller.dart` | `Future<void> confirmResume(bool resume)` | TASK-29 |
| `WorkoutController.onAppLifecycle` | 같은 파일 | `void onAppLifecycle(AppLifecycleState state)` (화면이 `AppLifecycleListener`로 호출) | TASK-29 |

## 범위
- 위 규칙을 컨트롤러에 추가

## 범위 밖 (건드리지 않음)
- 화면(TASK-29), 정상 흐름 동작 변경

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 2초 미검출 일시정지 | 사람 없는 결과를 2초간 emit | phase paused, notice '카메라 앞에 서 주세요', TTS 같은 문장 |
| 자동 재개 | 이어서 사람 있는 결과 | phase exercising, notice null |
| lite 전환 | 10초간 8fps로 결과 emit | FakePoseDetector.calls에 'setModel:lite' |
| 백그라운드 후 확인 | onAppLifecycle(paused) → (resumed) | phase paused, askResume true, TTS '이어서 할까요?' |
| 이어서 하기 거절 | confirmResume(false) | summary 설정(종료) |
| 추론 실패 보고 | FakePoseDetector.emitError | 가짜 ErrorReporter에 tag 'inference_failed' 1건, 이후 결과도 계속 처리 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/application/workout_controller.dart`
- `app/test/features/workout/application/workout_controller_exceptions_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트(TASK-27)가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- TASK-27 계약을 바꿔야 할 때

## 추가 발췌 (오케스트레이터가 보충)
