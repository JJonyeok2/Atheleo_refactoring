# TASK-27: 운동 진행 컨트롤러(감지 → 판정 → 세트 → 음성)

- 상태: 대기
- 선행 Task: TASK-11, TASK-13, TASK-15, TASK-16, TASK-17, TASK-18, TASK-19
- 실행 방식: 순차
- 실행 방식 근거: 여러 조각을 잇는 상태 관리, 운동 화면과 저장 흐름이 기댐
- Spec 출처: F-01~F-08 (4장 정상 흐름 3~7번, 9장 인수 조건 F-08)

## 왜 이렇게 나눴나
감지기 스트림을 받아 분석기, 세션 컨트롤러, 음성으로 흘려보내는 Riverpod 컨트롤러다. 예외 상황(사람 미검출, 저사양, 백그라운드)은 TASK-28에서 같은 파일에 더한다.

## 기능 범위 (Spec 발췌)
- 반복할 때마다 횟수 음성 안내, 반복 종료 시 점수 표시
- 자세 오류가 감지되면 해당 교정 문장 음성 안내
- 목표 횟수 달성 → "세트 완료, N초 쉬세요" → 휴식 카운트다운 → "다음 세트를 시작하세요"
- 마지막 세트 종료 또는 사용자가 종료 → 결과 화면(총 횟수, 평균 점수, 자주 나온 오류)
- 인수 조건(F-08): 목표 10회 루틴에서 10회를 채우면 세트가 2로 바뀌고 휴식 카운트다운이 나오며, 끝나면 다음 세트 음성이 나온다.
- 이 Task에서 정하는 규칙:
  - `start()`: 루틴 계획 읽기 → `detector.start()` → 결과 구독, 1초 `Timer.periodic`으로 `session.tick`
  - 결과마다 `selectPrimaryPose` → 있으면 `analyzer.addFrame` → `RepResult`면 `session.onRep`, `PartialRep`이면 `session.onPartialRep`
  - 모든 `WorkoutEvent`는 `cuesForEvent` 문구를 `voiceGuide.say`로 보냄
  - `WorkoutFinished`가 나오면 감지기 stop, 타이머 취소, `buildSummary`(sets와 partialsPerSet 전달)로 요약을 만들어 `lastWorkoutSummaryProvider`에 넣고 state.summary 설정
  - clientId는 `uuid` v4

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `PoseDetector`, `poseDetectorProvider`, `PoseDetectionResult` | `app/lib/pose/detector/pose_detector.dart` | `abstract class PoseDetector { Stream<PoseDetectionResult> get results; Future<int> start({PoseModel model = PoseModel.full}); Future<void> stop(); Future<void> setModel(PoseModel model); }`, `class PoseDetectionResult { const PoseDetectionResult({required int timestampMs, required List<PoseFrame> poses, required int inferenceMs}); }` |
| `selectPrimaryPose` | `app/lib/pose/body/body_check.dart` | `PoseFrame? selectPrimaryPose(List<PoseFrame> poses)` |
| `RepAnalyzer`, `AnalyzerOutput`, `RepResult`, `PartialRep` | `app/lib/pose/analyzer/rep_analyzer.dart` | `class RepAnalyzer { RepAnalyzer({required ExerciseType exercise, RepThresholds? repThresholds, ErrorThresholds errorThresholds = const ErrorThresholds(), int smoothingWindow = 5}); AnalyzerOutput? addFrame(PoseFrame frame); int get count; int get partialCount; double? get lastAngle; void reset(); }`, `sealed class AnalyzerOutput`, `final class PartialRep extends AnalyzerOutput { const PartialRep({required double minAngle, required int endMs}); }` |
| `WorkoutSessionController` 외 | `app/lib/features/workout/domain/workout_session_controller.dart` | `class WorkoutSessionController { WorkoutSessionController(RoutinePlan plan); WorkoutSessionState get state; List<WorkoutEvent> onRep(RepResult rep, int nowMs); List<WorkoutEvent> onPartialRep(int nowMs); List<WorkoutEvent> tick(int nowMs); List<WorkoutEvent> skipRest(int nowMs); void pause(int nowMs); void resume(int nowMs); List<WorkoutEvent> finish(int nowMs); }`, `WorkoutSessionState`, `WorkoutPhase`, `WorkoutEvent` 계열(TASK-16 계약 그대로) |
| `routinePlanProvider` | `app/lib/features/routine/routine_providers.dart` | `final routinePlanProvider = Provider.family<RoutinePlan, ExerciseType>(...)` |
| `buildSummary`, `WorkoutSummary` | `app/lib/features/workout/domain/workout_summary.dart` | `WorkoutSummary buildSummary({required String clientId, required RoutinePlan plan, required DateTime startedAt, required DateTime endedAt, required List<List<RepResult>> sets, List<int> partialsPerSet = const []})` (sets[0]이 1세트, partialsPerSet이 짧으면 나머지는 0) |
| `cuesForEvent`, `VoiceCue` | `app/lib/features/workout/domain/voice_cues.dart` | `List<VoiceCue> cuesForEvent(WorkoutEvent event)`, `class VoiceCue { const VoiceCue(this.text, {this.priority = VoicePriority.normal}); final String text; final VoicePriority priority; }` |
| `VoiceGuide`, `voiceGuideProvider` | `app/lib/core/tts/voice_guide.dart` | `Future<bool> say(String text, {VoicePriority priority = VoicePriority.normal}); Future<void> stopAll();` |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | TASK-19 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `clockProvider` | `app/lib/core/clock.dart` | `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);` | TASK-45, 47 |
| `WorkoutViewState` | `app/lib/features/workout/application/workout_view_state.dart` | `class WorkoutViewState { const WorkoutViewState({required WorkoutSessionState session, int? textureId, PoseFrame? frame, RepResult? lastRep, String? notice, bool askResume = false, WorkoutSummary? summary}); WorkoutViewState copyWith(...); }` | TASK-28, 29 |
| `WorkoutController` | `app/lib/features/workout/application/workout_controller.dart` | `class WorkoutController extends AutoDisposeFamilyNotifier<WorkoutViewState, ExerciseType> { Future<void> start(); void skipRest(); void pause(); void resume(); Future<void> finish(); }` | TASK-28, 29, 37 |
| `workoutControllerProvider` | 같은 파일 | `final workoutControllerProvider = NotifierProvider.autoDispose.family<WorkoutController, WorkoutViewState, ExerciseType>(WorkoutController.new);` | TASK-29, 37 |
| `activeWorkoutProvider` | 같은 파일 | `final activeWorkoutProvider = NotifierProvider<ActiveWorkoutNotifier, ExerciseType?>(ActiveWorkoutNotifier.new);` (start에서 설정, 종료 시 null) | TASK-37 |
| `lastWorkoutSummaryProvider` | 같은 파일 | `final lastWorkoutSummaryProvider = NotifierProvider<LastWorkoutSummaryNotifier, WorkoutSummary?>(LastWorkoutSummaryNotifier.new);` (`void set(WorkoutSummary? summary)`) | TASK-30, 40 |

## 범위
- 위 provider와 컨트롤러. 테스트는 `fake_async`, `FakePoseDetector`, 가짜 `TtsEngine`, 고정 clock, 낮은 목표값 계획(override)으로 작성

## 범위 밖 (건드리지 않음)
- 사람 미검출, lite 전환, 백그라운드, 추론 실패 보고(TASK-28), 화면(TASK-29)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 시작 | start() | 감지기 'start:full', textureId 설정, activeWorkout = 해당 운동 |
| 반복 반영 | 1회 반복 합성 프레임 emit | session.repsInSet 1, lastRep 설정, TTS '1회' |
| 부분 반복 반영 (F-03) | 130도까지만 내려간 합성 프레임 emit | repsInSet 0, partialsPerSet[0] 1, TTS '더 내려가세요' |
| 10회 후 휴식과 다음 세트 (F-08) | 목표 10회 계획 override, 10회 프레임 emit, fake_async로 restSec 경과 | currentSet 2, phase resting → TTS '세트 완료, 30초 쉬세요' → 경과 후 '다음 세트를 시작하세요' |
| 사용자 종료 | finish() | 감지기 stop, summary 설정, lastWorkoutSummaryProvider 값 존재, activeWorkout null |
| 휴식 건너뛰기 | resting 중 skipRest() | phase exercising |
| 사람 없는 결과 | poses 빈 결과 emit | 예외 없음, 횟수 변화 없음 |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/clock.dart`
- `app/lib/features/workout/application/workout_view_state.dart`
- `app/lib/features/workout/application/workout_controller.dart`
- `app/test/features/workout/application/workout_controller_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-08 인수 조건 충족(음성 포함)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
