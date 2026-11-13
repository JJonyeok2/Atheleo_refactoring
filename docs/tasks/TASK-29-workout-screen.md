# TASK-29: 운동 화면(표시)

- 상태: 대기
- 선행 Task: TASK-03, TASK-11, TASK-22, TASK-23, TASK-24, TASK-25, TASK-27, TASK-28
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정, 여러 위젯과 컨트롤러를 묶는 화면
- Spec 출처: F-01~F-08 (5장 운동 화면, 4장 정상 흐름 5번, 9장 인수 조건 F-01, F-05, F-06, F-07, F-08)

## 왜 이렇게 나눴나
이미 만든 위젯(미리보기, 스켈레톤, 점수 배지, 휴식 오버레이)과 컨트롤러를 화면 하나로 조립한다. 로직은 없고 상태를 그리기만 한다. 버튼, 뒤로 가기 확인 창, 이어서 하기 대화상자는 TASK-53에서 더한다.

## 기능 범위 (Spec 발췌)
- 운동 화면 `/workout/:type`: 카메라, 스켈레톤, 횟수, 세트, 점수, 오류 문구
- 미리보기는 실제 프레임 비율 유지, 전면 카메라 좌우 반전과 회전이 스켈레톤과 일치
- 반복 종료 시 점수 표시와 섬광 색상(점수 등급 색으로 화면 테두리가 0.4초 번쩍임)
- 휴식: 운동 화면 위 오버레이(카운트다운, 다음 세트 정보, 건너뛰기)
- 한국어 음성이 없는 기기에서는 이후 안내가 글자로 나온다
- 운동이 끝나면 결과 화면 `/workout/result`로 이동
- 인수 조건:
  - F-01: 전신이 보이게 서면 33개 점의 스켈레톤이 그려진다(화면에서는 `SkeletonOverlay`에 frame 전달 확인)
  - F-05: 화면 점수 색이 기준대로 바뀐다.
  - F-08: 10회를 채우면 세트가 2로 바뀌고 휴식 카운트다운이 나온다.
- 너무 빠른 반복(최소 1회 시간 미달)은 "조금 더 천천히"를 음성과 글자로 안내한다(글자는 컨트롤러가 `repHint`로 줌)
- 이 Task에서 정하는 표시: 횟수 `'$repsInSet / $targetReps'`, 세트 `'$currentSet / $totalSets 세트'`, 오류 문구 자리는 `repHint`가 있으면 repHint, 없으면 lastRep 첫 오류의 `voiceMessage`, 상단 안내 띠(notice가 있으면 notice, 없으면 `voiceCaptionProvider`의 마지막 값)
- 미리보기: `CameraPreviewView(camera: state.camera, overlay: SkeletonOverlay(frame: state.frame))`(비율 상자 안에 스켈레톤)
- 화면 생성 시 `start()`, `AppLifecycleListener`로 `onAppLifecycle` 호출

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `workoutControllerProvider`, `WorkoutController` | `app/lib/features/workout/application/workout_controller.dart` | `final workoutControllerProvider = NotifierProvider.autoDispose.family<WorkoutController, WorkoutViewState, ExerciseType>(WorkoutController.new);`, `Future<void> start(); void skipRest(); void onAppLifecycle(AppLifecycleState state)` |
| `WorkoutViewState` | `app/lib/features/workout/application/workout_view_state.dart` | `class WorkoutViewState { const WorkoutViewState({required WorkoutSessionState session, PoseCameraInfo? camera, PoseFrame? frame, RepResult? lastRep, String? notice, String? repHint, bool askResume = false, WorkoutSummary? summary}); WorkoutViewState copyWith(...); }` (repHint는 반복 단위 안내 글자, 지금은 빠른 반복의 '조금 더 천천히'만. copyWith에서 null로 지울 수 있어야 함) |
| `WorkoutPhase` | `app/lib/features/workout/domain/workout_session_controller.dart` | `enum WorkoutPhase { exercising, resting, paused, finished }` |
| `SkeletonOverlay` | `app/lib/features/workout/widgets/skeleton_overlay.dart` | `class SkeletonOverlay extends StatelessWidget { const SkeletonOverlay({super.key, required PoseFrame? frame, Color color = Colors.white}); }` |
| `ScoreBadge`, `scoreColor` | `app/lib/features/workout/widgets/score_badge.dart` | `class ScoreBadge extends StatelessWidget { const ScoreBadge({super.key, required int? score, double size = 64}); }`, `Color scoreColor(ScoreGrade grade)` |
| `RestOverlay` | `app/lib/features/workout/widgets/rest_overlay.dart` | `class RestOverlay extends StatelessWidget { const RestOverlay({super.key, required int remainingSec, required int nextSet, required int totalSets, required int targetReps, required VoidCallback onSkip}); }` |
| `CameraPreviewView` | `app/lib/features/workout/widgets/camera_preview_view.dart` | `class CameraPreviewView extends StatelessWidget { const CameraPreviewView({super.key, required PoseCameraInfo? camera, Widget? overlay}); }` (비율 유지, overlay는 같은 상자) |
| `voiceCaptionProvider` | `app/lib/core/tts/voice_guide.dart` | `final voiceCaptionProvider = StreamProvider<String>(...)` |
| `AppRoutes` | `app/lib/app/routes.dart` | `workout = '/workout/:type'`, `workoutResult = '/workout/result'` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutScreen` | `app/lib/features/workout/presentation/workout_screen.dart` | `class WorkoutScreen extends ConsumerStatefulWidget { const WorkoutScreen({super.key, required ExerciseType exercise}); }` | TASK-53, (라우터) |

## 범위
- 화면, 라우터 운동 경로 builder 교체
- 테스트는 `workoutControllerProvider`를 고정 상태를 내는 가짜 Notifier로 override

## 범위 밖 (건드리지 않음)
- 일시정지, 종료 버튼, 뒤로 가기 확인 창, 이어서 하기 대화상자(TASK-53), 컨트롤러 로직, 결과 화면(TASK-30)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 미리보기와 스켈레톤 (F-01, F-07) | state.camera(720 × 1280), state.frame 있음 | `CameraPreviewView.camera`가 같은 값, 그 overlay의 `SkeletonOverlay.frame`이 같은 객체 |
| 횟수와 세트 | repsInSet 3, targetReps 10, currentSet 1, totalSets 3 | '3 / 10', '1 / 3 세트' |
| 점수 색 (F-05) | lastRep score 75 | `ScoreBadge(score: 75)` 표시, 섬광 색이 fair 색 |
| 휴식 오버레이 (F-08) | phase resting, currentSet 2, restRemainingSec 30 | `RestOverlay` 표시, '30', '2 / 3 세트' |
| 오류 문구와 빠른 반복 글자 (F-03) | lastRep errors [puHipSag] / 같은 상태에 repHint '조금 더 천천히' | '허리가 처졌어요. 몸을 일자로 유지하세요.' / 그 자리에 '조금 더 천천히'(오류 문구는 보이지 않음) |
| 안내 띠 (F-06) | notice '카메라 앞에 서 주세요' / notice 없이 voiceCaptionProvider가 '3회' 발행 | 띠에 notice / 띠에 '3회' |
| 끝나면 결과로 | summary가 생김 | 경로 `/workout/result` |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/presentation/workout_screen.dart`
- `app/lib/app/router.dart`
- `app/test/features/workout/presentation/workout_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-05(색), F-08(화면) 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)

- (TASK-11 QA 반영) `VoiceGuide.captions`는 broadcast라 구독 전에 나간 unavailableNotice를 놓칠 수 있다. 화면이 열릴 때 `voiceAvailable == false`(init 완료 후)이면 글자 대체 안내를 직접 한 번 보여 준다. 운동 흐름(가이드→운동) 동안 한 번만 보이도록 한다.

## 2026-11-13 설계 검토 반영
- `CameraPreviewView(camera:)`에 스켈레톤을 overlay로 넣어 비율 일치, 글자 안내 띠(`voiceCaptionProvider`) 추가
- 이어서 하기 대화상자는 TASK-53으로 옮기고 버튼, 뒤로 가기 확인과 함께 분리. 선행 Task에 TASK-03, TASK-11 추가
- (재개 점검) 직접 받아 쓰는 TASK-27(`workoutControllerProvider`, `WorkoutViewState`)을 선행 Task에 명시

## 2026-11-13 TASK-08 QA 결정 반영
- `WorkoutViewState.repHint`(TASK-27) 표시: 오류 문구 자리에 repHint 우선. "오류 문구" 테스트 행을 넓힘(행 수 그대로)
- 한국어 음성이 없는 기기에서는 같은 문장이 안내 띠(captions)에도 나올 수 있다. 두 곳 표시는 허용(띠는 음성 대체, 오류 문구 자리는 반복 피드백)
