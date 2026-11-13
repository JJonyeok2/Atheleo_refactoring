# QA-TASK-33

- 검토일: 2026-11-13
- 판정: FIX

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/core/storage/token_storage.dart` | 추가함 | 계약(AuthTokens, TokenStorage, SecureTokenStorage, tokenStorageProvider) 일치 |
| `app/test/support/in_memory_token_storage.dart` | 추가함 | test/support는 소스로 취급. 빈 문자열 처리 불일치(FIX 1) |
| `app/test/core/storage/token_storage_test.dart` | 달지 않음(테스트 파일) | 14건 통과 확인 |

- 대상 3개 파일만 `dart format`(변경 0건), `dart analyze`(0건), `flutter test test/core/storage/token_storage_test.dart`(14건 통과).
- TASK-31 Impl이 병렬로 진행 중이라 전체 analyze/test는 돌리지 않았다. 판단은 이 Task 파일 기준이다.

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 암호화 저장(Android) | 통과 | token_storage.dart `SecureTokenStorage` | `~/.pub-cache/hosted/pub.dev/flutter_secure_storage-11.2.0/lib/options/android_options.dart` 50~76행 확인: 기본 `storageCipherAlgorithm = AES_GCM_NoPadding`, `keyCipherAlgorithm = RSA_ECB_OAEPwithSHA_256andMGF1Padding`. `FlutterSecureStorage` 기본 `aOptions = AndroidOptions.defaultOptions`. 기본 생성자 사용으로 암호화 저장이 맞다. |
| 복호화 실패 동작 | 통과(참고) | 같은 파일 | 기본 `resetOnError = true`라 네이티브(`FlutterSecureStorage.java` 1316행 부근)가 손상 데이터를 지운다. 결과적으로 로그아웃 상태가 되어 `_safeRead`의 null 정책과 같은 방향이다. |
| 입력 검증 | 통과 | `read`, `readUserId` | 빈 문자열 토큰 = 없음, 한쪽만 있으면 null. `readUserId`는 `int.tryParse`라 'abc', '1.5', ''는 null(계약 일치). 단 ' 7', '+7', '0x7', '-3'도 정수로 받는다. 쓰는 경로가 `writeUserId(int)`뿐이라 위험은 낮음, 권고 2. |
| XSS 등 출력 처리 | 해당 없음 | | |
| 인증 / 인가 | 해당 없음 | | 토큰 사용은 TASK-34, 35 |
| 시크릿 하드코딩 | 통과 | | 키 이름만 상수. 테스트의 'access-secret-1'은 가짜 값 |
| 로그의 민감 정보 | 통과 | | print/log/assert 없음. `AuthTokens.toString`은 `AuthTokens(***)`. 예외는 플러그인 예외를 그대로 전파하고 값을 덧붙이지 않는다. |
| 새 의존성 | 통과 | pubspec.yaml | flutter_secure_storage ^11.2.0은 선행 Task에서 이미 추가. 이번 Task에서 새 의존성 없음 |

### 요청받은 확인 항목
- 읽기 예외를 null로 삼키는 정책: TASK-35 `restore()` 규칙("토큰이나 사용자 id가 없으면 토큰을 지우고 signedOut")과 TASK-34 refresh 규칙("토큰 없음 → clear")에 맞는다. 다만 `restore()`가 이어서 `clear()`를 부르는데 `clear()`는 예외를 삼키지 않으므로, 저장소가 고장난 기기에서는 TASK-35가 clear 예외를 처리해야 한다(TASK-35 QA에서 확인할 것).
- 관측 수단: 지금은 `on Object { return null; }`로 완전히 숨긴다. 권고 1 참고.
- 저장 순서 원자성: `write`는 access → refresh 순서. refresh 쓰기 실패 시 새 access + 옛 refresh 쌍이 남고, 예외는 호출자로 전파된다. 다음 read는 짝이 안 맞는 쌍을 돌려준다. access 만료 후 refresh가 거절되면 TASK-34 규칙대로 clear → 로그아웃으로 수렴하므로 보안 문제는 아니고 UX 문제다. 순서를 바꿔도 같은 문제라 지금은 기록만 한다.
- clear 부분 실패: 첫 delete가 실패하면 뒤 두 키가 남고 예외 전파. access 삭제 후 refresh 삭제가 실패하면 read는 null(로그아웃)이지만 user_id가 남는다. TASK-35는 토큰이 없으면 signedOut이라 user_id 잔존으로 로그인 상태가 되지는 않는다. 권고 3.

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | | `_safeRead`로 읽기 공통화 |
| 함수 길이 | 통과 | | 모두 10줄 이하 |
| 이름 | 통과 | | |
| 죽은 코드 | 통과 | | |
| 테스트가 인수 조건을 검증하는가 | 통과(보완 권고) | token_storage_test.dart | Task의 Red 테스트 6종 모두 있음. 다만 "쓰기 예외 메시지에 토큰이 없다"는 가짜 저장소가 고정 문구 `StateError('storage failure')`를 던지므로 구현이 값을 덧붙이는지만 본다(의미는 있지만 약함). |
| 계약 일치(내보내는 것) | 통과 | | 시그니처 5개 모두 Task 표와 같다 |
| 메모리 구현 의미 일치 | 문제 | in_memory_token_storage.dart `read` | FIX 1 |

## FIX 항목 (Impl로 회귀)
- [ ] `app/test/support/in_memory_token_storage.dart:18` (`read`) — `_tokens`의 access나 refresh가 빈 문자열이면 null을 돌려주도록 해 `SecureTokenStorage.read`(빈 문자열 = 없음)와 의미를 맞춘다. `current` getter는 저장된 값 그대로 둬도 된다(검사용). 대응 테스트 1건 추가(`InMemoryTokenStorage(AuthTokens(access: '', refresh: 'r')).read()` → null). 이 구현은 TASK-34, 35, 37, 55 테스트가 실제 저장소 대신 쓰므로 의미가 다르면 실제 동작과 다른 테스트가 통과할 수 있다.

## 권고 (이번 FIX 범위 밖, 후속 Task에서 판단)
1. 관측 수단: `_safeRead`에서 삼킨 예외를 `ErrorReporter`(TASK-02, `app/lib/core/monitoring/error_reporter.dart`)로 보고할 것을 권한다. 단 `SecureTokenStorage` 생성자 계약이 `([FlutterSecureStorage? storage])`로 고정돼 있으므로 이번 Task에서 바꾸지 말고, Sentry 연결 Task(TASK-48)에서 선택 인자 추가로 다룬다. 보고 시 예외 타입과 키 이름(`auth.access` 등)만 보내고 값이나 메시지 본문은 보내지 않는다.
2. `readUserId`를 `RegExp(r'^\d+$')` 같은 엄격 검사로 좁히는 것을 고려(현재 ' 7', '+7', '0x7' 허용). 실해는 없음.
3. `clear`는 세 delete를 각각 시도한 뒤 마지막에 첫 예외를 다시 던지면 부분 실패 때 남는 키를 줄일 수 있다.
4. Android `allowBackup`이 매니페스트에 명시되지 않아 기본값(true)이다. 백업 복원 시 Keystore 키가 없어 복호화가 실패하고 resetOnError로 로그아웃된다. 보안상 문제는 아니지만 백업 정책은 플랫폼 설정 Task에서 정할 것.

## PEER_REVIEW 사유
- 해당 없음
