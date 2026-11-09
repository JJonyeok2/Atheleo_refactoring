# TASK-40: 결과 화면의 기록 저장과 로그인 안내

- 상태: 대기
- 선행 Task: TASK-30, TASK-36, TASK-39
- 실행 방식: 순차
- 실행 방식 근거: 인증, 저장, 동기화를 잇는 연결 지점
- Spec 출처: F-10, F-11 (4장 정상 흐름 운동 8번, 예외 흐름 네트워크, 9장 인수 조건 F-11)

## 왜 이렇게 나눴나
결과 화면(TASK-30)이 남겨 둔 저장 자리에 "로그인 여부에 따른 저장"을 끼운다. 저장 로직은 작은 컨트롤러, 화면은 위젯 하나.

## 기능 범위 (Spec 발췌)
- 로그인 상태면 기록 저장, 아니면 "로그인하면 기록이 저장됩니다" 안내 후 로그인 선택 가능
- 네트워크가 끊겼을 때: 기록을 로컬에 저장하고 "나중에 자동으로 동기화됩니다" 표시
- 인수 조건(F-11): 비행기 모드에서 운동을 마치면 기록 목록에 "미동기화"로 보인다(저장 쪽).
- 이 Task에서 정하는 규칙:
  - 결과 화면이 열리고 signedIn이면 자동으로 `saveSummary` → `syncPending`
  - 저장 후 오프라인이면 '나중에 자동으로 동기화됩니다', 동기화되면 '저장되었어요', rejected면 '저장 실패'
  - signedOut이면 '로그인하면 기록이 저장됩니다' + '로그인' 버튼(`loginLocation(from: '/workout/result')`). 로그인하고 돌아오면 자동 저장
  - 같은 요약은 한 번만 저장(저장소가 clientId 중복을 무시)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `WorkoutResultScreen` | `app/lib/features/workout/presentation/workout_result_screen.dart` | `class WorkoutResultScreen extends ConsumerWidget { const WorkoutResultScreen({super.key, Widget? saveSlot}); }` |
| `lastWorkoutSummaryProvider` | `app/lib/features/workout/application/workout_controller.dart` | `NotifierProvider<LastWorkoutSummaryNotifier, WorkoutSummary?>` |
| `workoutLocalRepositoryProvider` | `app/lib/features/history/data/workout_local_repository.dart` | `Future<void> saveSummary(WorkoutSummary summary); Future<SyncStatus?> statusOf(String clientId);` |
| `syncServiceProvider`, `networkStatusProvider` | `app/lib/features/history/application/sync_service.dart`, `app/lib/core/network/network_status.dart` | `Future<void> syncPending()`, `Future<bool> isOnline()` |
| `authControllerProvider`, `AuthStatus` | `app/lib/features/auth/application/auth_controller.dart` | `enum AuthStatus { unknown, signedOut, signedIn }` |
| `AppRoutes.loginLocation` | `app/lib/app/routes.dart` | `static String loginLocation({String? from})` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `ResultSaveStatus` | `app/lib/features/workout/application/result_save_controller.dart` | `enum ResultSaveStatus { needLogin, saving, savedOffline, synced, rejected }` | (내부) |
| `resultSaveControllerProvider` | 같은 파일 | `final resultSaveControllerProvider = NotifierProvider.autoDispose<ResultSaveController, ResultSaveStatus>(ResultSaveController.new);` | (내부) |
| `ResultSaveSection` | `app/lib/features/workout/widgets/result_save_section.dart` | `class ResultSaveSection extends ConsumerWidget { const ResultSaveSection({super.key}); }` | (라우터에서 saveSlot으로 전달) |

## 범위
- 컨트롤러, 위젯, 라우터 result 경로에서 `WorkoutResultScreen(saveSlot: const ResultSaveSection())`

## 범위 밖 (건드리지 않음)
- 결과 표시 내용(TASK-30), 동기화 규칙(TASK-39)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 로그인 안 됨 | signedOut | '로그인하면 기록이 저장됩니다', '로그인' 버튼, 저장 0회 |
| 로그인 버튼 | 탭 | 경로 `/login?from=%2Fworkout%2Fresult` |
| 오프라인 저장 (F-11) | signedIn, 오프라인, 동기화 후 상태 pending | 저장 1회, '나중에 자동으로 동기화됩니다' |
| 온라인 저장 | 동기화 후 synced | '저장되었어요' |
| 로그인 후 자동 저장 | signedOut → signedIn으로 바뀜 | 저장 1회 |
| 저장 실패 | 동기화 후 rejected | '저장 실패' |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/application/result_save_controller.dart`
- `app/lib/features/workout/widgets/result_save_section.dart`
- `app/lib/app/router.dart`
- `app/test/features/workout/result_save_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
