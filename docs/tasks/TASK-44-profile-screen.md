# TASK-44: 프로필 화면

- 상태: 대기
- 선행 Task: TASK-36, TASK-37, TASK-43
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정
- Spec 출처: F-13 (5장 `/profile`, 4장 예외 흐름 입력 비었을 때, 9장 인수 조건)

## 왜 이렇게 나눴나
프로필 컨트롤러(TASK-43)를 입력 폼으로 보여 준다.

## 기능 범위 (Spec 발췌)
- 프로필 `/profile`: 신체 정보(닉네임, 키, 몸무게), 체형, 로그아웃
- 입력이 비었을 때: 필드별 오류 문구 표시, 요청 보내지 않음
- 인수 조건(F-13): 프로필에서 체형을 바꾸고 저장하면 다음 운동의 목표 횟수가 바뀐다.
- 이 Task에서 정하는 검증과 표시:
  - 닉네임은 `validateNickname` 재사용
  - 키 100~250, 몸무게 20~300 숫자(빈칸 허용, 범위 밖이면 '100~250 사이로 입력해 주세요' / '20~300 사이로 입력해 주세요')
  - 체형은 드롭다운: '선택 안 함' + 8개 `BodyShape.label`
  - 체형 아래 안내: `'현재 루틴: ${level.label} · 스쿼트 ${targetReps}회 ${sets}세트'` (routinePlanProvider 값)
  - 저장 성공 '저장되었어요' 스낵바, 실패는 서버 문구 또는 '네트워크 연결을 확인해 주세요'
  - '로그아웃' 버튼 → `logout()` 후 `/`

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `profileControllerProvider`, `UserProfile`, `ProfileException` | `app/lib/features/profile/` | `class ProfileController extends AsyncNotifier<UserProfile?> { Future<void> save(UserProfile profile); }`, `UserProfile copyWith({String? nickname, double? heightCm, double? weightKg, BodyShape? bodyShape, bool clearBodyShape = false})` |
| `validateNickname` | `app/lib/features/auth/domain/auth_validators.dart` | `String? validateNickname(String? v)` |
| `authControllerProvider` | `app/lib/features/auth/application/auth_controller.dart` | `Future<void> logout();` |
| `BodyShape`, `routinePlanProvider`, `RoutineLevel` | `app/lib/features/routine/` | TASK-10 계약 그대로 |
| `AppRoutes` | `app/lib/app/routes.dart` | `profile = '/profile'`, `home = '/'` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `ProfileScreen` | `app/lib/features/profile/presentation/profile_screen.dart` | `class ProfileScreen extends ConsumerStatefulWidget { const ProfileScreen({super.key}); }` | (라우터) |

## 범위
- 화면, 라우터 profile 경로 builder 교체

## 범위 밖 (건드리지 않음)
- 체형 분석(F-15, 2차)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 불러온 값 표시 | 컨트롤러 override(닉네임 '종혁', 체형 hourglass) | 필드에 값, 드롭다운 '모래시계형' |
| 체형 변경 후 목표 변화 (F-13) | 드롭다운 '역삼각형' 선택 → 저장(가짜 컨트롤러가 currentBodyShape set) | 안내 문구 '스쿼트 20회 3세트' |
| 빈 닉네임 | 닉네임 지우고 저장 | '닉네임을 입력해 주세요', save 호출 0회 |
| 키 범위 | 키 '90' | '100~250 사이로 입력해 주세요' |
| 저장 실패 | save가 ProfileException(network) | '네트워크 연결을 확인해 주세요' |
| 로그아웃 | 버튼 탭 | logout 1회, 경로 `/` |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/profile/presentation/profile_screen.dart`
- `app/lib/app/router.dart`
- `app/test/features/profile/profile_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-13 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
