# TASK-43: 프로필 저장소와 상태(체형 → 루틴 반영)

- 상태: 대기
- 선행 Task: TASK-10, TASK-35
- 실행 방식: 순차
- 실행 방식 근거: 인증 상태와 루틴 공유 상태를 잇는 작업
- Spec 출처: F-13, F-09 (4장 정상 흐름 계정 3번, 6장, 7장 Profile, 9장 인수 조건 F-13)

## 왜 이렇게 나눴나
프로필 조회, 수정과 "현재 체형"을 루틴 provider에 넘기는 연결을 한곳에 둔다. 화면은 TASK-44.

## 기능 범위 (Spec 발췌)
| 메서드 | 경로 | 요청 | 응답 | 에러 |
|---|---|---|---|---|
| GET | `/api/users/me/` | (인증) | user, profile | 401 |
| PATCH | `/api/users/me/` | nickname, height_cm, weight_kg, body_shape | user, profile | 400, 401 |

- Profile: height_cm(float), weight_kg(float), body_shape(8분류 중 하나 또는 null)
- 프로필 화면에서 신체 정보와 체형 수정 → 루틴 목표값에 반영
- 인수 조건(F-13): 프로필에서 체형을 바꾸고 저장하면 다음 운동의 목표 횟수가 바뀐다.
- 이 Task에서 정하는 규칙(Q-01 확정 전 가정):
  - 응답 `{"user": {"id", "email", "nickname"}, "profile": {"height_cm": num|null, "weight_kg": num|null, "body_shape": str|null}}`
  - PATCH 본문은 바뀐 필드만이 아니라 4개 모두 보냄
  - 로그인되면 프로필을 불러와 `currentBodyShapeProvider.set(...)`, 로그아웃되면 `set(null)`
  - 저장 성공 시 즉시 `currentBodyShapeProvider.set(새 체형)`

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `apiClientProvider`, `ApiErrorKind`, `classifyError` | `app/lib/core/network/api_client.dart` | `final apiClientProvider = Provider<Dio>(...)`, `enum ApiErrorKind { network, server, badRequest, unauthorized, forbidden, notFound, conflict, tooManyRequests, clientError, unknown }`, `ApiErrorKind classifyError(Object error)` |
| `authControllerProvider`, `AuthStatus`, `AuthUser` | `app/lib/features/auth/` | `enum AuthStatus { unknown, signedOut, signedIn }`, `class AuthUser { const AuthUser({required int id, required String email, required String nickname}); factory AuthUser.fromJson(Map<String, dynamic> json); }` |
| `BodyShape` | `app/lib/features/routine/domain/body_shape.dart` | `enum BodyShape {...}`, `final String code`, `final String label`, `static BodyShape? fromCode(String? code)` |
| `currentBodyShapeProvider`, `routinePlanProvider` | `app/lib/features/routine/routine_providers.dart` | `NotifierProvider<CurrentBodyShapeNotifier, BodyShape?>`(`void set(BodyShape? shape)`), `Provider.family<RoutinePlan, ExerciseType>` |
| `FakeHttpAdapter`, `InMemoryTokenStorage` | `app/test/support/` | 테스트에서만 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `UserProfile` | `app/lib/features/profile/data/profile_repository.dart` | `class UserProfile { const UserProfile({required AuthUser user, double? heightCm, double? weightKg, BodyShape? bodyShape}); UserProfile copyWith({String? nickname, double? heightCm, double? weightKg, BodyShape? bodyShape, bool clearBodyShape = false}); }` | TASK-44 |
| `ProfileRepository` | 같은 파일 | `abstract class ProfileRepository { Future<UserProfile> fetch(); Future<UserProfile> update(UserProfile profile); }`, `final profileRepositoryProvider = Provider<ProfileRepository>(...)` | TASK-44 |
| `ProfileException` | 같은 파일 | `class ProfileException implements Exception { const ProfileException(this.kind, [this.message]); final ApiErrorKind kind; final String? message; }` | TASK-44 |
| `ProfileController` | `app/lib/features/profile/application/profile_controller.dart` | `class ProfileController extends AsyncNotifier<UserProfile?> { Future<void> save(UserProfile profile); }` (signedOut이면 null) | TASK-44 |
| `profileControllerProvider` | 같은 파일 | `final profileControllerProvider = AsyncNotifierProvider<ProfileController, UserProfile?>(ProfileController.new);` | TASK-44 |

## 범위
- 위 저장소, 컨트롤러, 체형 동기화

## 범위 밖 (건드리지 않음)
- 화면(TASK-44), 루틴 표(TASK-10)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 불러오기 | 가짜 서버 me 200(body_shape 'hourglass') | UserProfile.bodyShape hourglass, currentBodyShape hourglass |
| 체형 변경이 목표에 반영 (F-13) | save(bodyShape: invertedTriangle), PATCH 200 | `routinePlanProvider(squat).targetReps` 15 → 20 |
| PATCH 본문 | save 호출 | 본문에 nickname, height_cm, weight_kg, body_shape 4개 |
| 체형 비우기 | save(clearBodyShape) | body_shape null 전송, 목표 15회 |
| 로그아웃 | signedOut으로 바뀜 | 상태 null, currentBodyShape null |
| 400 | PATCH 400 `{"nickname": ["너무 길어요"]}` | `ProfileException(badRequest, '너무 길어요')`, 체형 변하지 않음 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/profile/data/profile_repository.dart`
- `app/lib/features/profile/application/profile_controller.dart`
- `app/test/features/profile/profile_controller_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-13 인수 조건(로직) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 서버 응답 형식이 확정되어(Q-01) 위 가정과 다를 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 내보내기 표에 `profileControllerProvider`를 따로 적음, `ApiErrorKind` 값 목록을 TASK-34 최신 계약으로 맞춤. 동작과 테스트는 그대로
