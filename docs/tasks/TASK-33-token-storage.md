# TASK-33: 토큰 암호화 저장소

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 순차
- 실행 방식 근거: 인증, 보안 기반 작업
- Spec 출처: F-10 (3장, 4장 정상 흐름 계정 1번, 8장 보안)

## 왜 이렇게 나눴나
토큰을 어디에 어떻게 저장하는지만 다룬다. 테스트용 메모리 구현을 함께 만들어 API, 인증 Task가 실제 저장소 없이 테스트하게 한다.

## 기능 범위 (Spec 발췌)
- JWT(access, refresh)
- 토큰은 암호화 저장소(flutter_secure_storage)에만 저장한다.
- 이 Task에서 정하는 것: 키 `auth.access`, `auth.refresh`, Android 옵션 `encryptedSharedPreferences: true`. 둘 중 하나라도 없으면 read는 null

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| 의존성 | `app/pubspec.yaml` | flutter_secure_storage 이미 추가됨 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `AuthTokens` | `app/lib/core/storage/token_storage.dart` | `class AuthTokens { const AuthTokens({required String access, required String refresh}); final String access; final String refresh; }` | TASK-34, 35 |
| `TokenStorage` | 같은 파일 | `abstract class TokenStorage { Future<AuthTokens?> read(); Future<void> write(AuthTokens tokens); Future<void> clear(); }` | TASK-34, 35 |
| `SecureTokenStorage` | 같은 파일 | `class SecureTokenStorage implements TokenStorage { SecureTokenStorage([FlutterSecureStorage? storage]); }` | (provider 내부) |
| `tokenStorageProvider` | 같은 파일 | `final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());` | TASK-34, 35 |
| `InMemoryTokenStorage` | `app/test/support/in_memory_token_storage.dart` | `class InMemoryTokenStorage implements TokenStorage { InMemoryTokenStorage([AuthTokens? initial]); AuthTokens? get current; }` | TASK-34, 35, 37 |

## 범위
- 위 클래스

## 범위 밖 (건드리지 않음)
- 토큰 사용(TASK-34, 35)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 쓰고 읽기 (F-10) | `FlutterSecureStorage.setMockInitialValues({})` 후 write → 새 인스턴스로 read | 같은 access, refresh (앱 재시작 흉내) |
| 비었을 때 | 아무것도 없음 | null |
| 한쪽만 있음 | `auth.access`만 있음 | null |
| clear | write 후 clear → read | null |
| 메모리 구현 | `InMemoryTokenStorage(tokens)` read | 같은 값 |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/storage/token_storage.dart`
- `app/test/support/in_memory_token_storage.dart`
- `app/test/core/storage/token_storage_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] 토큰을 로그, 예외 메시지에 남기지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
