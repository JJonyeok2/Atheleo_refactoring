# TASK-27: 운동 진행 컨트롤러(감지 → 판정 → 세트 → 음성)

- 상태: 대기
- 선행 Task: TASK-11, TASK-13, TASK-16, TASK-17, TASK-18, TASK-19, TASK-49
- 실행 방식: 순차
- 실행 방식 근거: 여러 조각을 잇는 상태 관리, 운동 화면과 저장 흐름이 기댐
- Spec 출처: F-01~F-08 (4장 정상 흐름 3~8번, 7장 시간 기준, 9장 인수 조건 F-01, F-06, F-08)

## 왜 이렇게 나눴나
감지기 스트림을 받아 분석기, 세션 컨트롤러, 음성으로 흘려보내는 Riverpod 컨트롤러다. 휴식, 일시정지 중 분석 중단과 분석기 초기화는 TASK-52, 예외 상황(사람 미검출, 저사양, 백그라운드)은 TASK-28에서 같은 파일에 더한다.

## 기능 범위 (Spec 발췌)
- 촬영 가이드에서 운동 화면으로 넘어갈 때 카메라와 감지 세션은 끊기지 않는다(감지기는 이미 실행 중이고 start는 같은 textureId를 돌려줌)
- 반복할 때마다 횟수 음성 안내, 반복 종료 시 점수 표시
- 자세 오류가 감지되면 해당 교정 문장 음성 안내
- 목표 횟수 달성 → "세트 완료, N초 쉬세요" → 휴식 카운트다운 → 휴식 종료 3초 전 음성 안내 → "다음 세트를 시작하세요"
- 마지막 세트 종료 또는 사용자가 종료 → 결과 화면(총 횟수, 평균 점수, 자주 나온 오류)
- 시간 기준: 세션 시간(세트, 휴식 카운트다운, 일시정지, 운동 시간, started_at, ended_at)은 앱 시계 하나로 잰다. 프레임 타임스탬프는 판정 분석에서만 쓴다.
- 인수 조건:
  - F-08: 목표 10회 루틴에서 10회를 채우면 세트가 2로 바뀌고 휴식 카운트다운이 나오며, 끝나면 다음 세트 음성이 나온다.
  - F-06: 휴식이 3초 남았을 때 안내 음성이 나온다.
- 이 Task에서 정하는 규칙:
  - `start()`: 루틴 계획 읽기 → `detector.start()`(반환 `PoseCameraInfo`를 state.camera에) → 결과 구독 → 1초 `Timer.periodic`으로 `session.tick(nowMs)`
  - `nowMs`와 `startedAt`, `endedAt`는 모두 `clockProvider`에서 얻는다. 프레임의 `timestampMs`는 `analyzer.addFrame`에만 들어간다
  - 결과마다 `selectPrimaryPose` → state.frame 갱신 → 있으면 `analyzer.addFrame` → `RepResult`면 `session.onRep(rep, nowMs)`, `PartialRep`이면 `session.onPartialRep(nowMs)`, `TooFastRep`이면 세션은 건드리지 않고 `voiceGuide.say(VoiceCues.slowDown.text, priority: VoiceCues.slowDown.priority)`와 state.repHint = `VoiceCues.slowDown.text`
  - 빠른 반복 안내: 최소 1회 시간보다 빠른 반복은 횟수와 부분 반복에 넣지 않고 "조금 더 천천히"를 음성과 글자로 안내한다. 같은 문장은 5초 안에 다시 말하지 않는다(`VoiceGuide` 쿨다운 그대로, 컨트롤러는 따로 막지 않음). 글자(repHint)는 다음 `RepResult` 또는 `PartialRep`이 나오면 null로 지운다
  - 모든 `WorkoutEvent`는 `cuesForEvent` 문구를 `voiceGuide.say`로 보냄
  - `WorkoutFinished`가 나오면 감지기 stop(화면 꺼짐 방지도 함께 풀림), 타이머 취소, `buildSummary`(sets와 partialsPerSet 전달)로 요약을 만들어 `lastWorkoutSummaryProvider`에 넣고 state.summary 설정
  - provider가 dispose될 때 아직 끝나지 않았으면 감지기 stop과 타이머 취소
  - clientId는 `uuid` v4

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `PoseDetector`, `poseDetectorProvider`, `PoseDetectionResult`, `PoseCameraInfo` | `app/lib/pose/detector/pose_detector.dart` | `abstract class PoseDetector { Stream<PoseDetectionResult> get results; Future<PoseCameraInfo> start({PoseModel model = PoseModel.full}); Future<void> stop(); Future<void> setModel(PoseModel model); bool get isRunning; }`, `class PoseDetectionResult { const PoseDetectionResult({required int timestampMs, required List<PoseFrame> poses, required int inferenceMs}); }`, `class PoseCameraInfo { const PoseCameraInfo({required int textureId, required int width, required int height}); double get aspectRatio; }` |
| `selectPrimaryPose` | `app/lib/pose/body/body_check.dart` | `PoseFrame? selectPrimaryPose(List<PoseFrame> poses)` |
| `RepAnalyzer`, `AnalyzerOutput`, `RepResult`, `PartialRep` | `app/lib/pose/analyzer/rep_analyzer.dart` | `class RepAnalyzer { RepAnalyzer({required ExerciseType exercise, RepThresholds? repThresholds, ErrorThresholds errorThresholds = const ErrorThresholds(), int smoothingWindowMs = 150, int sideSwitchAfterMs = 500, double gateMaxDeg = 30}); AnalyzerOutput? addFrame(PoseFrame frame); int get count; int get partialCount; double? get lastAngle; BodySide? get side; void reset(); }`, `sealed class AnalyzerOutput`, `final class PartialRep extends AnalyzerOutput { const PartialRep({required double minAngle, required int endMs}); }`, `final class TooFastRep extends AnalyzerOutput { const TooFastRep({required int durationMs, required int endMs}); }` (최소 1회 시간 미달 반복. 점수, 오류 없음, count, partialCount 미포함) |
| `WorkoutSessionController` 외 | `app/lib/features/workout/domain/workout_session_controller.dart` | `class WorkoutSessionController { WorkoutSessionController(RoutinePlan plan); WorkoutSessionState get state; List<WorkoutEvent> onRep(RepResult rep, int nowMs); List<WorkoutEvent> onPartialRep(int nowMs); List<WorkoutEvent> tick(int nowMs); List<WorkoutEvent> skipRest(int nowMs); void pause(int nowMs); void resume(int nowMs); List<WorkoutEvent> finish(int nowMs); }`, `WorkoutSessionState`, `WorkoutPhase`, `WorkoutEvent` 계열(`RestEndingSoon` 포함, TASK-16 계약 그대로) |
| `routinePlanProvider` | `app/lib/features/routine/routine_providers.dart` | `final routinePlanProvider = Provider.family<RoutinePlan, ExerciseType>(...)` |
| `buildSummary`, `WorkoutSummary` | `app/lib/features/workout/domain/workout_summary.dart` | `WorkoutSummary buildSummary({required String clientId, required RoutinePlan plan, required DateTime startedAt, required DateTime endedAt, required List<List<RepResult>> sets, List<int> partialsPerSet = const []})` |
| `cuesForEvent`, `VoiceCue`, `VoiceCues` | `app/lib/features/workout/domain/voice_cues.dart` | `List<VoiceCue> cuesForEvent(WorkoutEvent event)`, `class VoiceCue { const VoiceCue(this.text, {this.priority = VoicePriority.normal}); final String text; final VoicePriority priority; }`, `abstract final class VoiceCues { static const VoiceCue noPerson; static const VoiceCue askResume; static const VoiceCue slowDown; }` (slowDown은 `VoiceCue('조금 더 천천히')`, priority normal) |
| `VoiceGuide`, `voiceGuideProvider` | `app/lib/core/tts/voice_guide.dart` | `Future<bool> say(String text, {VoicePriority priority = VoicePriority.normal}); Future<void> stopAll();` |
| `FakePoseDetector`, `buildSyntheticClip`, `repAngleSequence` | `app/test/support/` | TASK-06, 19 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `clockProvider` | `app/lib/core/clock.dart` | `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);` (세션 시간의 유일한 출처) | TASK-28, 45, 47, 52 |
| `WorkoutViewState` | `app/lib/features/workout/application/workout_view_state.dart` | `class WorkoutViewState { const WorkoutViewState({required WorkoutSessionState session, PoseCameraInfo? camera, PoseFrame? frame, RepResult? lastRep, String? notice, String? repHint, bool askResume = false, WorkoutSummary? summary}); WorkoutViewState copyWith(...); }` (repHint는 반복 단위 안내 글자, 지금은 빠른 반복의 '조금 더 천천히'만. copyWith에서 null로 지울 수 있어야 함) | TASK-28, 29, 52, 53 |
| `WorkoutController` | `app/lib/features/workout/application/workout_controller.dart` | `class WorkoutController extends AutoDisposeFamilyNotifier<WorkoutViewState, ExerciseType> { Future<void> start(); void skipRest(); void pause(); void resume(); Future<void> finish(); }` | TASK-28, 29, 52, 53 |
| `workoutControllerProvider` | 같은 파일 | `final workoutControllerProvider = NotifierProvider.autoDispose.family<WorkoutController, WorkoutViewState, ExerciseType>(WorkoutController.new);` | TASK-29, 53 |
| `lastWorkoutSummaryProvider` | 같은 파일 | `final lastWorkoutSummaryProvider = NotifierProvider<LastWorkoutSummaryNotifier, WorkoutSummary?>(LastWorkoutSummaryNotifier.new);` (`void set(WorkoutSummary? summary)`) | TASK-30, 40 |

## 범위
- 위 provider와 컨트롤러. 테스트는 `fake_async`, `FakePoseDetector`, 가짜 `TtsEngine`, 조절 가능한 가짜 clock, 낮은 목표값 계획(override)으로 작성

## 범위 밖 (건드리지 않음)
- 휴식, 일시정지 중 프레임 미투입과 분석기 초기화(TASK-52), 사람 미검출, lite 전환, 백그라운드, 추론 실패 보고(TASK-28), 화면(TASK-29, 53)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 시작과 카메라 유지 (F-01) | 이미 start된 FakePoseDetector(camera textureId 5)로 start() | state.camera.textureId 5, calls에 'stop' 없음 |
| 반복 반영 | 1회 반복 합성 프레임 emit | session.repsInSet 1, lastRep 설정, TTS '1회' |
| 부분 반복 반영 (F-03) | 130도까지만 내려간 합성 프레임 emit | repsInSet 0, partialsPerSet[0] 1, TTS '더 내려가세요' |
| 빠른 반복 안내 (F-03, F-06) | 하강부터 복귀까지 0.6초 미만인 푸쉬업 반복 2번을 5초 안에 emit → 이어서 정상 1회 | 빠른 반복 뒤: repsInSet 0, partialsPerSet[0] 0, state.repHint '조금 더 천천히', TTS '조금 더 천천히' 1번(두 번째는 쿨다운으로 재생 안 됨) / 정상 1회 뒤: repsInSet 1, repHint null |
| 10회 후 휴식과 다음 세트 (F-08, F-06) | 목표 10회, restSec 30 계획 override, 10회 프레임 emit, fake_async와 가짜 clock을 30초 진행 | currentSet 2, phase resting → TTS '세트 완료, 30초 쉬세요' → 27초에 '3초 뒤 다음 세트를 시작해요' → 30초에 '다음 세트를 시작하세요' |
| 세션 시간은 앱 시계 | 프레임 t를 1,000,000,000부터 주고 clock은 10:00:00에서 시작, 30초 진행 후 finish() | restRemainingSec가 clock 기준으로 줄어듦, summary.startedAt 10:00:00, endedAt 10:00:30 |
| 사용자 종료 | finish() | 감지기 stop, summary 설정, lastWorkoutSummaryProvider 값 존재 |
| 휴식 건너뛰기 | resting 중 skipRest() | phase exercising |
| 사람 없는 결과 | poses 빈 결과 emit | 예외 없음, 횟수 변화 없음, state.frame null |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/clock.dart`
- `app/lib/features/workout/application/workout_view_state.dart`
- `app/lib/features/workout/application/workout_controller.dart`
- `app/test/features/workout/application/workout_controller_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-08 인수 조건 충족(음성 포함), F-06 휴식 종료 3초 전 음성
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- `WorkoutViewState.textureId` → `camera`(`PoseCameraInfo`), 세션 시간은 `clockProvider`만 사용, 휴식 종료 3초 전 음성, dispose 시 stop
- `activeWorkoutProvider` 삭제: 토큰 만료 시 운동 중 이동하지 않는 규칙(D3)으로 바뀌어 TASK-37이 경로로 판단함
- 선행 Task를 TASK-15에서 TASK-49(분석기 최종 계약)로 바꿈. 휴식, 일시정지 중 분석 중단은 TASK-52로 분리

## 2026-11-13 TASK-08 QA 결정 반영
- `TooFastRep`(TASK-15) 처리: 세션 미반영, `VoiceCues.slowDown` 음성, `WorkoutViewState.repHint` 글자. 다음 반복이나 부분 반복에서 repHint 지움
- `WorkoutViewState`에 `String? repHint` 추가(선택 인자라 TASK-28, 52, 53 쪽 생성 코드는 영향 없음). 받아 쓰는 표에 `VoiceCues` 추가
- 반복 취소(10초 초과)는 분석기가 출력하지 않으므로 이 Task에서 할 일 없음
- 테스트 1행 추가(빠른 반복 안내). 테스트 행 9개로 기준(8개)을 1개 넘지만, 같은 결과 분기 처리라 따로 떼지 않음
- (TASK-16 QA 반영, 오케스트레이터 결정) 세션 시간(onRep/tick/pause/resume에 넘기는 nowMs)은 단조 시계(Stopwatch 기반, 테스트에서 주입 가능한 `monotonicMsProvider` 등)에서 얻고, `clockProvider`(벽시계)는 startedAt/endedAt 기록에만 쓴다. 벽시계가 앞으로 튀어 휴식이 일찍 끝나는 일을 막기 위함이다. 세션 state는 이벤트 처리나 tick 직후에 읽는다.
- (TASK-18 QA 반영) VoiceGuide 대기 칸 규칙 때문에 앞 문장 재생 중 오류가 있는 반복이 오면 'N회'(normal)가 교정(high)에 밀려 빠질 수 있다. 빠른 반복 클립으로 횟수 안내가 연속으로 빠지지 않는지 테스트 1건을 두고, 결과를 보고에 적는다(사용자 최종 검증 확인 항목).
