# TASK-40: 결과 화면의 기록 저장과 로그인 안내

- 상태: 대기
- 선행 Task: TASK-27, TASK-30, TASK-31, TASK-32, TASK-35, TASK-36, TASK-39, TASK-55
- 실행 방식: 순차
- 실행 방식 근거: 인증, 저장, 동기화를 잇는 연결 지점
- Spec 출처: F-10, F-11 (4장 정상 흐름 운동 9번, 예외 흐름 네트워크, 토큰 만료, 5장 운동 결과, 9장 인수 조건 F-10, F-11)

## 왜 이렇게 나눴나
결과 화면(TASK-30)이 남겨 둔 저장 자리에 "소유자에 따른 저장과 안내"를 끼운다. 저장 로직은 작은 컨트롤러, 화면은 위젯 하나.

## 기능 범위 (Spec 발췌)
- 결과는 로그인 여부와 관계없이 로컬 DB에 저장한다. 로그인 상태면 그 사용자 소유로 저장하고 동기화 대상에 넣는다. 비로그인이면 소유자 없음(guest)으로 저장하고 "로그인하면 기록이 계정에 저장되고 백업됩니다" 안내 후 로그인 선택 가능
- 로그인하면 guest 기록을 그 계정 소유로 바꾸고 동기화 대상에 넣는다(귀속과 동기화는 TASK-55가 함)
- 네트워크가 끊겼을 때: 기록을 로컬에 저장하고 "나중에 자동으로 동기화됩니다" 표시
- 토큰 만료(운동 세션 중): 결과 화면에서 저장, 동기화할 때 "로그인이 필요합니다" 안내(needLogin 흐름)를 보여 주고, 기록은 로컬에 그대로 남는다.
- 인수 조건:
  - F-11: 비행기 모드에서 운동을 마치면 기록 목록에 "미동기화"로 보인다(저장 쪽). 비로그인으로 운동한 기록은 로그인 직후 그 계정 기록 목록에 보이고 동기화된다.
  - F-10: 운동 중 refresh까지 만료되면 결과 화면에서 "로그인이 필요합니다" 안내가 나온다.
- 이 Task에서 정하는 규칙:
  - 결과 화면이 열리면 한 번 `saveSummary(summary, userId: currentUserId)`(비로그인이면 null = guest). 같은 요약은 저장소가 중복을 무시
  - signedIn이면 저장 뒤 `syncPending()`
  - 표시는 `watchStatus(clientId)`와 인증 상태로 정한다:

| 조건 | 상태 | 문구 |
|---|---|---|
| 인증 signedOut(비로그인, 만료 모두) | needLogin | '로그인이 필요합니다' + '로그인하면 기록이 계정에 저장되고 백업됩니다' + '로그인' 버튼(`loginLocation(from: '/workout/result')`) |
| 저장 중 | saving | '저장 중이에요' |
| signedIn, pending | savedOffline | '나중에 자동으로 동기화됩니다' |
| signedIn, synced | synced | '저장되었어요' |
| signedIn, failed | failed | '동기화에 실패했어요. 기록 화면에서 다시 시도할 수 있어요' |
| signedIn, rejected | rejected | '서버가 이 기록을 받지 않았어요' |

  - 로그인하고 돌아오면 TASK-55가 guest를 귀속하고 동기화하며, 이 화면은 `watchStatus`로 바뀐 상태를 보여 준다

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `WorkoutResultScreen` | `app/lib/features/workout/presentation/workout_result_screen.dart` | `class WorkoutResultScreen extends ConsumerWidget { const WorkoutResultScreen({super.key, Widget? saveSlot}); }` |
| `lastWorkoutSummaryProvider` | `app/lib/features/workout/application/workout_controller.dart` | `NotifierProvider<LastWorkoutSummaryNotifier, WorkoutSummary?>` |
| `workoutLocalRepositoryProvider` | `app/lib/features/history/data/workout_local_repository.dart` | `Future<void> saveSummary(WorkoutSummary summary, {required int? userId}); Stream<SyncStatus?> watchStatus(String clientId);` |
| `SyncStatus` | `app/lib/features/history/domain/sync_status.dart` | `enum SyncStatus { pending, synced, failed, rejected }` |
| `syncServiceProvider` | `app/lib/features/history/application/sync_service.dart` | `Future<void> syncPending()` (생성 시 자동 동기화 구독 시작) |
| `authControllerProvider`, `AuthStatus`, `currentUserIdProvider` | `app/lib/features/auth/application/auth_controller.dart` | `enum AuthStatus { unknown, signedOut, signedIn }`, `final currentUserIdProvider = Provider<int?>(...)` |
| `AppRoutes.loginLocation` | `app/lib/app/routes.dart` | `static String loginLocation({String? from})` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `ResultSaveStatus` | `app/lib/features/workout/application/result_save_controller.dart` | `enum ResultSaveStatus { needLogin, saving, savedOffline, synced, failed, rejected }` | (내부) |
| `resultSaveControllerProvider` | 같은 파일 | `final resultSaveControllerProvider = NotifierProvider.autoDispose<ResultSaveController, ResultSaveStatus>(ResultSaveController.new);` | (내부) |
| `ResultSaveSection` | `app/lib/features/workout/widgets/result_save_section.dart` | `class ResultSaveSection extends ConsumerWidget { const ResultSaveSection({super.key}); }` | (라우터에서 saveSlot으로 전달) |

## 범위
- 컨트롤러, 위젯, 라우터 result 경로에서 `WorkoutResultScreen(saveSlot: const ResultSaveSection())`

## 범위 밖 (건드리지 않음)
- 결과 표시 내용(TASK-30), 동기화 규칙과 귀속(TASK-39, 55), 만료 시 화면 이동(TASK-37)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 비로그인은 guest로 저장 (F-11) | signedOut | saveSummary 1회(userId null), '로그인이 필요합니다', '로그인하면 기록이 계정에 저장되고 백업됩니다', '로그인' 버튼, syncPending 0회 |
| 로그인 버튼 | 탭 | 경로 `/login?from=%2Fworkout%2Fresult` |
| 오프라인 저장 (F-11) | signedIn(7), 동기화 후 상태 pending | saveSummary 1회(userId 7), '나중에 자동으로 동기화됩니다' |
| 온라인 저장 | 동기화 후 synced | '저장되었어요' |
| 로그인 후 귀속 반영 (F-11) | signedOut으로 저장 → signedIn(7)으로 바뀌고 watchStatus가 synced 발행 | saveSummary 1회뿐, '저장되었어요' |
| 운동 중 만료 뒤 결과 (F-10) | 결과 화면 진입 시 이미 signedOut(만료) | guest로 저장, '로그인이 필요합니다' |
| 실패와 거절 | 동기화 후 failed / rejected | 각 문구 |

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

## 2026-11-13 설계 검토 반영(D3, D4)
- 비로그인과 토큰 만료 모두 guest로 로컬 저장 후 needLogin 안내('로그인이 필요합니다' + 백업 안내). 로그인 뒤 귀속과 동기화는 TASK-55, 이 화면은 `watchStatus`로 반영
- `ResultSaveStatus.failed` 추가, 문구 정리. 선행 Task에 TASK-32, 35, 55 추가
- (재개 점검) 직접 받아 쓰는 TASK-27(`lastWorkoutSummaryProvider`), TASK-31(`SyncStatus`)을 선행 Task에 명시
