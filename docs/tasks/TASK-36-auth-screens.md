# TASK-36: 로그인, 회원가입 화면

- 상태: 대기
- 선행 Task: TASK-03, TASK-35
- 실행 방식: 순차
- 실행 방식 근거: 인증 화면, 라우터(공유 파일) 수정
- Spec 출처: F-10 (4장 정상 흐름 계정 1번, 예외 흐름 입력 비었을 때, 5장 `/login`, `/signup`)

## 왜 이렇게 나눴나
입력 검증과 화면을 만든다. 로그인 후 어디로 돌아갈지(`from` 쿼리)는 결과 화면과 인증 가드가 같이 쓰므로 여기서 정한다.

## 기능 범위 (Spec 발췌)
- 로그인 `/login`: 이메일, 비밀번호, 회원가입 이동
- 회원가입 `/signup`: 이메일, 비밀번호, 닉네임
- 입력이 비었을 때: 필드별 오류 문구 표시, 요청 보내지 않음
- 이 Task에서 정하는 검증과 문구:
  - 이메일: 비었으면 '이메일을 입력해 주세요', `@`와 `.`가 없으면 '이메일 형식이 아니에요'
  - 비밀번호: 비었으면 '비밀번호를 입력해 주세요', 회원가입은 8자 미만이면 '8자 이상 입력해 주세요'
  - 닉네임: 비었으면 '닉네임을 입력해 주세요', 20자 초과면 '20자 이하로 입력해 주세요'
  - `AuthException.invalidCredentials` → '이메일 또는 비밀번호가 맞지 않아요', `rejected` → 서버 문구, `network` → '네트워크 연결을 확인해 주세요'
  - 성공하면 `from` 쿼리 값(없으면 `/`)으로 `context.go`. `from`은 `/`로 시작하는 앱 내부 경로만 허용
  - 요청 중에는 버튼 비활성, 비밀번호는 가림

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `authControllerProvider`, `AuthController` | `app/lib/features/auth/application/auth_controller.dart` | `Future<void> login({required String email, required String password}); Future<void> signup({required String email, required String password, required String nickname});` (실패는 `AuthException` throw) |
| `AuthException`, `AuthErrorKind` | `app/lib/features/auth/data/auth_repository.dart` | `enum AuthErrorKind { invalidCredentials, rejected, network, unknown }`, `class AuthException implements Exception { const AuthException(this.kind, [this.message]); final AuthErrorKind kind; final String? message; }` |
| `AppRoutes` | `app/lib/app/routes.dart` | `login = '/login'`, `signup = '/signup'`, `home = '/'` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `validateEmail`, `validatePassword` | `app/lib/features/auth/domain/auth_validators.dart` | `String? validateEmail(String? v)`, `String? validatePassword(String? v, {bool forSignup = false})` (통과하면 null) | (내부) |
| `validateNickname` | 같은 파일 | `String? validateNickname(String? v)` (통과하면 null) | TASK-44 |
| `AppRoutes.loginLocation` | `app/lib/app/routes.dart`에 추가 | `static String loginLocation({String? from})` (`/login?from=<인코딩된 경로>`) | TASK-37, 40 |
| `LoginScreen`, `SignupScreen` | `app/lib/features/auth/presentation/` | `class LoginScreen extends ConsumerStatefulWidget { const LoginScreen({super.key, String? from}); }`, `class SignupScreen extends ConsumerStatefulWidget { const SignupScreen({super.key, String? from}); }` | (라우터) |

## 범위
- 검증 함수, 두 화면, 라우터 login/signup builder 교체, `AppRoutes.loginLocation` 추가

## 범위 밖 (건드리지 않음)
- 인증 가드, 만료 이동(TASK-37)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 빈 입력 | 아무것도 안 넣고 '로그인' 탭 | '이메일을 입력해 주세요', '비밀번호를 입력해 주세요', 가짜 컨트롤러 login 호출 0회 |
| 형식 오류 | 이메일 'abc' | '이메일 형식이 아니에요' |
| 로그인 성공 후 복귀 | `/login?from=/workout/result`에서 성공 | 경로 `/workout/result` |
| 외부 경로 차단 | `from=https://evil.com` | 성공 후 `/` |
| 비밀번호 틀림 | login이 invalidCredentials throw | '이메일 또는 비밀번호가 맞지 않아요' |
| 회원가입 검증 | 비밀번호 '1234' | '8자 이상 입력해 주세요', signup 호출 0회 |
| 중복 이메일 | signup이 `AuthException(rejected, '이미 가입된 이메일이에요.')` | 그 문구 표시 |
| 검증 함수 단위 | 닉네임 21자 | '20자 이하로 입력해 주세요' |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/auth/domain/auth_validators.dart`
- `app/lib/features/auth/presentation/login_screen.dart`
- `app/lib/features/auth/presentation/signup_screen.dart`
- `app/lib/app/routes.dart`, `app/lib/app/router.dart`
- `app/test/features/auth/auth_screens_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 서버 비밀번호 규칙이 확정되어(Q-01) 위 검증과 다를 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 내보내기 표 표기만 정리: `validateNickname`, `AppRoutes.loginLocation`을 이름 그대로 적음. 동작과 테스트는 그대로
