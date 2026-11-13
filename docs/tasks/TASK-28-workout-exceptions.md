# TASK-28: 운동 중 예외 처리(사람 미검출, 저사양, 백그라운드, 추론 실패)

- 상태: 대기
- 선행 Task: TASK-02, TASK-18, TASK-26, TASK-52
- 실행 방식: 순차
- 실행 방식 근거: TASK-27, 52와 같은 컨트롤러 파일을 고침
- Spec 출처: F-01, F-06, F-08 (4장 예외 흐름, 9장 인수 조건 F-01, F-08), 8장 모니터링

## 왜 이렇게 나눴나
정상 흐름(TASK-27)과 분석 중단 규칙(TASK-52)이 통과한 뒤 예외 흐름만 더해, 한 Task가 너무 커지지 않게 했다.

## 기능 범위 (Spec 발췌)
- 사람이 안 보일 때(운동 중): 2초 이상 미검출 시 일시정지, "카메라 앞에 서 주세요" 음성 안내, 다시 잡히면 자동 재개
- 사람이 안 보일 때(휴식 중): 일시정지하지 않고 휴식 타이머는 계속 간다.
- 추론이 느릴 때(저사양): 10초 평균 10fps 미만이면 lite 모델로 전환. 백그라운드 복귀와 일시정지 해제 직후에는 성능 측정을 초기화해 멈춰 있던 시간이 평균에 들어가지 않게 한다.
- 운동 중 앱이 백그라운드로 갈 때: 세션 일시정지, 복귀 시 "이어서 할까요?" 확인
- 추론 실패를 Sentry에 보고(여기서는 `ErrorReporter`로)
- 인수 조건:
  - F-01: 일시정지를 30초 한 뒤 재개하거나 백그라운드에서 복귀해도 lite 모델로 바뀌지 않는다(측정 초기화).
  - F-08: 휴식 중 화면에서 벗어나도 일시정지되지 않고 휴식 타이머가 계속 줄어든다.
- 이 Task에서 정하는 규칙:
  - 감지 결과는 phase와 관계없이 모두 `trackingMonitor.onResult`에 넣는다(멈춘 동안에도 사람이 돌아온 것을 알아야 하므로). `timestampMs`는 결과의 프레임 시각
  - personLost: phase가 exercising일 때만 `session.pause`, notice '카메라 앞에 서 주세요', `VoiceCues.noPerson` 재생. resting이면 무시
  - personReturned: 사람이 없어 멈춘 상태였고 사용자가 직접 일시정지하지 않았으면 `resume()`(TASK-52 경로, 분석기 초기화 포함), notice null
  - `NextSetStarted`가 나오면 `trackingMonitor.reset()`(휴식 중 사람이 없었으면 다음 세트에서 2초를 다시 잼)
  - `resume()`(모든 재개 경로)와 앱 `resumed` 복귀 때 `trackingMonitor.reset()`(성능 측정 초기화)
  - switchToLite → `detector.setModel(PoseModel.lite)`
  - 앱 `paused` 상태 → pause, 돌아오면(`resumed`) askResume true + `VoiceCues.askResume`. `confirmResume(true)`면 `resume()`, false면 finish
  - 결과 스트림 오류 → `errorReporter.report(error, st, tag: 'inference_failed')`, 운동은 계속(구독 유지)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `TrackingMonitor`, `TrackingSignal` | `app/lib/features/workout/domain/tracking_monitor.dart` | `class TrackingMonitor { TrackingMonitor({Duration lostAfter = const Duration(seconds: 2), Duration fpsWindow = const Duration(seconds: 10), double minFps = 10}); List<TrackingSignal> onResult({required int timestampMs, required bool hasPerson}); bool get isPersonLost; bool get switchedToLite; void reset(); }` (reset은 미검출과 fps 창 초기화, lite 유지), `enum TrackingSignal { personLost, personReturned, switchToLite }` |
| `WorkoutController`, `WorkoutViewState` | `app/lib/features/workout/application/` | TASK-27 계약 그대로, `void resume()`(TASK-52: 세션 재개 + 분석기 초기화), phase가 exercising일 때만 분석기 투입 |
| `WorkoutPhase`, `NextSetStarted` | `app/lib/features/workout/domain/workout_session_controller.dart` | `enum WorkoutPhase { exercising, resting, paused, finished }`, `final class NextSetStarted extends WorkoutEvent` |
| `VoiceCues` | `app/lib/features/workout/domain/voice_cues.dart` | `abstract final class VoiceCues { static const VoiceCue noPerson; static const VoiceCue askResume; }` |
| `PoseModel` | `app/lib/pose/detector/pose_detector.dart` | `enum PoseModel { full, lite }` |
| `ErrorReporter`, `errorReporterProvider` | `app/lib/core/monitoring/error_reporter.dart` | `abstract class ErrorReporter { Future<void> report(Object error, StackTrace? stackTrace, {String? tag, Map<String, Object?> context = const {}}); }`, `final errorReporterProvider = Provider<ErrorReporter>(...)` |
| `clockProvider` | `app/lib/core/clock.dart` | `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);` |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | TASK-19 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutController.confirmResume` | `app/lib/features/workout/application/workout_controller.dart` | `Future<void> confirmResume(bool resume)` | TASK-53 |
| `WorkoutController.onAppLifecycle` | 같은 파일 | `void onAppLifecycle(AppLifecycleState state)` (화면이 `AppLifecycleListener`로 호출) | TASK-29 |

## 범위
- 위 규칙을 컨트롤러에 추가

## 범위 밖 (건드리지 않음)
- 화면(TASK-29, 53), 정상 흐름과 분석 중단 규칙 변경(TASK-27, 52)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 미검출 일시정지와 자동 재개 | exercising 중 사람 없는 결과 2초 → 사람 있는 결과 | phase paused, notice와 TTS '카메라 앞에 서 주세요' → phase exercising, notice null, 재개 직후 처음 UP 전 동작은 세지 않음 |
| 휴식 중 미검출 무시 (F-08) | resting 중 사람 없는 결과 3초, clock 3초 진행 | phase resting, restRemainingSec 3 줄어듦, TTS '카메라 앞에 서 주세요' 없음 |
| 휴식 뒤 미검출 다시 잼 | 휴식 내내 사람 없음 → NextSetStarted → 사람 없음 2초 | 다음 세트에서 2초 뒤 phase paused |
| lite 전환 | 10초간 8fps로 결과 emit | FakePoseDetector.calls에 'setModel:lite' |
| 백그라운드 복귀 측정 초기화 (F-01) | 25fps 5초 → onAppLifecycle(paused) → 30초 결과 없음 → (resumed) → confirmResume(true) → 25fps 11초 | askResume true와 TTS '이어서 할까요?', 'setModel:lite' 없음 |
| 일시정지 해제 측정 초기화 (F-01) | 25fps 5초 → pause() → 30초 결과 없음 → resume() → 25fps 11초 | 'setModel:lite' 없음 |
| 이어서 하기 거절 | 복귀 후 confirmResume(false) | summary 설정(종료) |
| 추론 실패 보고 | FakePoseDetector.emitError | 가짜 ErrorReporter에 tag 'inference_failed' 1건, 이후 결과도 계속 처리 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/application/workout_controller.dart`
- `app/test/features/workout/application/workout_controller_exceptions_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트(TASK-27, 52)가 깨지지 않음
- [ ] F-01(측정 초기화), F-08(휴식 중 미검출) 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- TASK-27, 52 계약을 바꿔야 할 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 휴식 중 미검출 무시, 다음 세트에서 감시 reset, 재개와 백그라운드 복귀 때 성능 측정 초기화, 자동 재개는 TASK-52 `resume()` 경로
- 선행 Task에 TASK-02(ErrorReporter), TASK-18(VoiceCues), TASK-52 추가. `confirmResume` 사용 Task를 TASK-53으로
