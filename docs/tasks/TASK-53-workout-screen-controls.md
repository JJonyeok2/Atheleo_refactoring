# TASK-53: 운동 화면 조작(일시정지, 종료, 뒤로 가기 확인, 이어서 하기)

- 상태: 대기
- 선행 Task: TASK-29
- 실행 방식: 순차
- 실행 방식 근거: TASK-29와 같은 화면 파일을 고침
- Spec 출처: F-08 (4장 예외 흐름 백그라운드, 뒤로 가기, 5장 운동 화면, 9장 인수 조건 F-08)

## 왜 이렇게 나눴나
표시(TASK-29)와 사용자 조작을 나눠 화면 Task 하나의 테스트가 8건을 넘지 않게 했다. 조작은 모두 컨트롤러 메서드 호출로 끝난다.

## 기능 범위 (Spec 발췌)
- 운동 화면: 일시정지/종료, 뒤로 가기 종료 확인 창
- 운동 화면에서 Android 뒤로 가기: 종료 확인 창 표시. "종료"를 누르면 그때까지의 기록으로 결과 화면, "취소"를 누르면 그대로 계속
- 운동 중 앱이 백그라운드로 갈 때: 세션 일시정지, 복귀 시 "이어서 할까요?" 확인
- 인수 조건(F-08): 운동 화면에서 뒤로 가기를 누르면 종료 확인 창이 나오고, "취소"는 계속, "종료"는 그때까지의 기록으로 결과 화면을 보여 준다.
- 이 Task에서 정하는 표시와 동작:
  - 버튼 '일시정지'(phase exercising, resting) → `pause()`, phase paused면 버튼이 '재개' → `resume()`
  - 버튼 '종료' → `finish()`(확인 창 없이)
  - `PopScope(canPop: false)`로 뒤로 가기를 막고 확인 창: 제목 '운동을 끝낼까요?', 내용 '지금까지의 기록으로 결과를 보여 드려요.', 버튼 '취소', '종료'. '종료'면 `finish()`. 결과 화면 이동은 TASK-29의 summary 감지가 함
  - askResume true면 대화상자 '이어서 할까요?' / '이어서 하기', '그만하기' → `confirmResume(true / false)`

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `WorkoutScreen` | `app/lib/features/workout/presentation/workout_screen.dart` | `class WorkoutScreen extends ConsumerStatefulWidget { const WorkoutScreen({super.key, required ExerciseType exercise}); }` (TASK-29 구현, summary가 생기면 `/workout/result`로 이동) |
| `WorkoutController` | `app/lib/features/workout/application/workout_controller.dart` | `void pause(); void resume(); Future<void> finish(); Future<void> confirmResume(bool resume);` |
| `WorkoutViewState`, `WorkoutPhase` | `app/lib/features/workout/application/workout_view_state.dart`, `.../domain/workout_session_controller.dart` | `bool askResume`, `WorkoutSessionState session`(phase), `enum WorkoutPhase { exercising, resting, paused, finished }` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| (화면 동작) | `workout_screen.dart` | 위 동작. 공개 시그니처는 TASK-29 그대로 | (라우터) |

## 범위
- 버튼, `PopScope` 확인 창, 이어서 하기 대화상자
- 테스트는 호출을 기록하는 가짜 Notifier로 override

## 범위 밖 (건드리지 않음)
- 컨트롤러 로직(TASK-27, 28, 52), 표시 요소(TASK-29)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 일시정지와 재개 | exercising에서 '일시정지' 탭 / paused 상태에서 '재개' 탭 | pause 1회 / resume 1회 |
| 종료 버튼 | '종료' 탭 | finish 1회 |
| 뒤로 가기 취소 (F-08) | 시스템 뒤로 가기 → '취소' | 확인 창이 닫히고 finish 0회, 경로 `/workout/<type>` 그대로 |
| 뒤로 가기 종료 (F-08) | 시스템 뒤로 가기 → '종료'(가짜가 finish에서 summary 설정) | finish 1회, 경로 `/workout/result` |
| 이어서 하기 | askResume true → '그만하기' 탭 / '이어서 하기' 탭 | confirmResume(false) / confirmResume(true) |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/presentation/workout_screen.dart`
- `app/test/features/workout/presentation/workout_screen_controls_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] TASK-29 테스트가 깨지지 않음
- [ ] F-08 뒤로 가기 인수 조건 충족
- [ ] TASK-29의 공개 시그니처가 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
