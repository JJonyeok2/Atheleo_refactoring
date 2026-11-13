# TASK-47: 홈 화면

- 상태: 대기
- 선행 Task: TASK-03, TASK-10, TASK-27, TASK-32, TASK-35, TASK-46
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정, 여러 상태를 묶음
- Spec 출처: F-09, F-12 (4장 정상 흐름 운동 1번, 5장 홈 `/`)

## 왜 이렇게 나눴나
모든 화면의 출발점이다. 다른 화면이 다 생긴 뒤에 이동 버튼만 연결하면 되므로 뒤쪽에 둔다.

## 기능 범위 (Spec 발췌)
- 홈 `/`: 운동 선택 카드, 오늘 기록 요약(로컬 DB), 로그인 상태
- 앱 실행 → 홈에서 운동 종류(푸쉬업, 스쿼트) 선택 → 촬영 가이드
- 체형 정보 없으면 중급 루틴
- 조회(홈 요약 포함)는 현재 사용자 id 소유 기록만 대상으로 한다. 비로그인이면 guest 기록만
- 이 Task에서 정하는 표시:
  - 운동 카드 2개: 이름, `'${targetReps}회 × ${sets}세트 · 휴식 ${restSec}초'`(routinePlanProvider), 탭 → `workoutSetupPath(code)`
  - 오늘 기록 요약: 오늘(현지 자정~다음 자정, `clockProvider` 기준) `watchSessions(userId: currentUserId, from, to)`의 세션 수와 총 횟수. 없으면 '오늘은 아직 운동 기록이 없어요'
  - 로그인 상태: signedIn이면 닉네임과 '기록', '프로필' 버튼, signedOut이면 '로그인' 버튼
  - 디버그 빌드(`kDebugMode`)에서만 '개발자 메뉴' 버튼

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `routinePlanProvider`, `RoutinePlan` | `app/lib/features/routine/` | `final routinePlanProvider = Provider.family<RoutinePlan, ExerciseType>(...)` |
| `workoutLocalRepositoryProvider` | `app/lib/features/history/data/workout_local_repository.dart` | `Stream<List<SessionListItem>> watchSessions({required int? userId, DateTime? from, DateTime? to});` |
| `authControllerProvider`, `AuthState`, `currentUserIdProvider` | `app/lib/features/auth/application/auth_controller.dart` | `class AuthState { const AuthState({required AuthStatus status, int? userId, AuthUser? user}); }`, `final currentUserIdProvider = Provider<int?>(...)` (비로그인 null = guest) |
| `clockProvider` | `app/lib/core/clock.dart` | `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);` |
| `AppRoutes` | `app/lib/app/routes.dart` | `static String workoutSetupPath(String type)`, `history`, `profile`, `login`, `dev` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `HomeScreen` | `app/lib/features/home/presentation/home_screen.dart` | `class HomeScreen extends ConsumerWidget { const HomeScreen({super.key, bool showDevMenu = kDebugMode}); }` | (라우터) |

## 범위
- 화면, 라우터 home 경로 builder 교체

## 범위 밖 (건드리지 않음)
- 각 화면 내용

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 체형 없으면 중급 (F-09) | 체형 null | 스쿼트 카드 '15회 × 3세트 · 휴식 45초' |
| 역삼각형이면 고강도 (F-09) | currentBodyShape invertedTriangle | 스쿼트 카드 '20회 × 3세트 · 휴식 30초' |
| 운동 선택 | 푸쉬업 카드 탭 | 경로 `/workout/push_up/setup` |
| 오늘 요약 | currentUserId 7, 7의 오늘 2건(10회, 12회), 7의 어제 1건, 8의 오늘 1건 | '2회 운동 · 22회' 형식(다른 계정 제외) |
| 로그인 상태 | signedOut / signedIn('종혁') | '로그인' 버튼 / '종혁' 표시 |
| 개발자 메뉴 버튼 | showDevMenu false | 버튼 없음 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/home/presentation/home_screen.dart`
- `app/lib/app/router.dart`
- `app/test/features/home/home_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-09 인수 조건(화면) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 오늘 요약을 현재 사용자(비로그인은 guest) 기록으로 한정, `watchSessions(userId:)` 계약 반영
- 선행 Task에 TASK-03(AppRoutes), TASK-27(clockProvider) 추가
