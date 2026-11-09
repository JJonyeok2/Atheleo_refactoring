# TASK-29: 운동 화면

- 상태: 대기
- 선행 Task: TASK-22, TASK-23, TASK-24, TASK-25, TASK-28
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정, 여러 위젯과 컨트롤러를 묶는 화면
- Spec 출처: F-01~F-08 (5장 운동 화면, 4장 정상 흐름 4번, 9장 인수 조건 F-01, F-05, F-08)

## 왜 이렇게 나눴나
이미 만든 위젯(스켈레톤, 점수 배지, 휴식 오버레이, 미리보기)과 컨트롤러를 화면 하나로 조립한다. 로직은 없고 상태를 그리기만 한다.

## 기능 범위 (Spec 발췌)
- 운동 화면 `/workout/:type`: 카메라, 스켈레톤, 횟수, 세트, 점수, 오류 문구, 일시정지/종료
- 반복 종료 시 점수 표시와 섬광 색상(점수 등급 색으로 화면 테두리가 0.4초 번쩍임)
- 휴식: 운동 화면 위 오버레이(카운트다운, 다음 세트 정보, 건너뛰기)
- 운동이 끝나면 결과 화면 `/workout/result`로 이동
- 인수 조건:
  - F-01: 전신이 보이게 서면 33개 점의 스켈레톤이 그려진다(화면에서는 `SkeletonOverlay`에 frame 전달 확인)
  - F-05: 화면 점수 색이 기준대로 바뀐다.
  - F-08: 10회를 채우면 세트가 2로 바뀌고 휴식 카운트다운이 나온다.
- 이 Task에서 정하는 표시: 횟수 `'$repsInSet / $targetReps'`, 세트 `'$currentSet / $totalSets 세트'`, 오류 문구는 lastRep 첫 오류의 `voiceMessage`, 상단 notice 띠, 이어서 하기 대화상자('이어서 할까요?' / '이어서 하기', '그만하기')

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `workoutControllerProvider`, `WorkoutController` | `app/lib/features/workout/application/workout_controller.dart` | `final workoutControllerProvider = NotifierProvider.autoDispose.family<WorkoutController, WorkoutViewState, ExerciseType>(WorkoutController.new);`, `Future<void> start(); void skipRest(); void pause(); void resume(); Future<void> finish(); Future<void> confirmResume(bool resume); void onAppLifecycle(AppLifecycleState state)` |
| `WorkoutViewState` | `app/lib/features/workout/application/workout_view_state.dart` | `class WorkoutViewState { const WorkoutViewState({required WorkoutSessionState session, int? textureId, PoseFrame? frame, RepResult? lastRep, String? notice, bool askResume = false, WorkoutSummary? summary}); }` |
| `WorkoutPhase` | `app/lib/features/workout/domain/workout_session_controller.dart` | `enum WorkoutPhase { exercising, resting, paused, finished }` |
| `SkeletonOverlay` | `app/lib/features/workout/widgets/skeleton_overlay.dart` | `class SkeletonOverlay extends StatelessWidget { const SkeletonOverlay({super.key, required PoseFrame? frame, Color color = Colors.white}); }` |
| `ScoreBadge`, `scoreColor` | `app/lib/features/workout/widgets/score_badge.dart` | `class ScoreBadge extends StatelessWidget { const ScoreBadge({super.key, required int? score, double size = 64}); }`, `Color scoreColor(ScoreGrade grade)` |
| `RestOverlay` | `app/lib/features/workout/widgets/rest_overlay.dart` | `class RestOverlay extends StatelessWidget { const RestOverlay({super.key, required int remainingSec, required int nextSet, required int totalSets, required int targetReps, required VoidCallback onSkip}); }` |
| `CameraPreviewView` | `app/lib/features/workout/widgets/camera_preview_view.dart` | `class CameraPreviewView extends StatelessWidget { const CameraPreviewView({super.key, required int? textureId, Widget? overlay}); }` |
| `AppRoutes` | `app/lib/app/routes.dart` | `workout = '/workout/:type'`, `workoutResult = '/workout/result'` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `WorkoutScreen` | `app/lib/features/workout/presentation/workout_screen.dart` | `class WorkoutScreen extends ConsumerStatefulWidget { const WorkoutScreen({super.key, required ExerciseType exercise}); }` | (라우터) |

## 범위
- 화면, 라우터 운동 경로 builder 교체
- 테스트는 `workoutControllerProvider`를 고정 상태를 내는 가짜 Notifier로 override

## 범위 밖 (건드리지 않음)
- 컨트롤러 로직, 결과 화면(TASK-30)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 스켈레톤 전달 (F-01) | state.frame 있음 | `SkeletonOverlay`의 frame이 같은 객체 |
| 횟수와 세트 | repsInSet 3, targetReps 10, currentSet 1, totalSets 3 | '3 / 10', '1 / 3 세트' |
| 점수 색 (F-05) | lastRep score 75 | `ScoreBadge(score: 75)` 표시, 섬광 색이 fair 색 |
| 휴식 오버레이 (F-08) | phase resting, currentSet 2, restRemainingSec 30 | `RestOverlay` 표시, '30', '1 / 3 세트'가 아닌 '2 / 3 세트' |
| 오류 문구 | lastRep errors [puHipSag] | '허리가 처졌어요. 몸을 일자로 유지하세요.' |
| 이어서 하기 | askResume true → '그만하기' 탭 | 가짜 컨트롤러 confirmResume(false) 호출 |
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
