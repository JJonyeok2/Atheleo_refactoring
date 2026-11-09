# QA-TASK-02

- 검토일: 2026-11-09
- 판정: FIX (1차) → PASS (재검토, 아래 참조)
- 대상 커밋: ba99677
- 재실행: `flutter test` 12건 통과, `flutter analyze` 0건 (헤더/푸터 추가 후 다시 실행)

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| app/lib/app/env.dart | 추가함 | FIX 1건 |
| app/lib/core/monitoring/error_reporter.dart | 추가함 | 계약 일치 |
| app/.env.example | 해당 없음(설정 파일) | 키 2개, 값 비움. Git 추적됨 |
| app/test/app/env_test.dart | 해당 없음(테스트) | |
| app/test/core/monitoring/error_reporter_test.dart | 해당 없음(테스트) | |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 문제 | env.dart `fromEnvironment` | 빈 `API_BASE_URL`이 기본값을 덮어씀(FIX 1). 릴리스 http 거부는 정상 동작: `http://a.com` + isRelease true면 `StateError`(테스트로 확인). 대소문자 구분(`HTTPS://` 거부)은 안전한 쪽으로 실패하므로 허용 |
| XSS 등 출력 처리 | 해당 없음 | | |
| 인증 / 인가 | 해당 없음 | | |
| 시크릿 하드코딩 | 통과 | | 코드에는 에뮬레이터용 기본 주소 `http://10.0.2.2:8000`만 있음. DSN 기본값은 빈 문자열 |
| `.env` 제외 | 통과 | .gitignore 1~3행 | `git check-ignore -v`: `.env`, `app/.env`는 1행 `.env`, `app/.env.local`은 2행 `.env.*`로 무시됨. `app/.env.example`은 `!.env.example`로 추적됨. 추적 중인 env 파일은 `app/.env.example` 하나 |
| 로그의 민감 정보 | 통과(조건부) | error_reporter.dart | 지금은 Noop이라 아무것도 보내지 않음. 개인 식별 정보를 보내지 않는다는 규칙은 문서 주석에만 있음. 실제로 막는 필터는 TASK-48에서 강제해야 함 |
| 새 의존성 | 통과 | | 추가 없음(flutter_riverpod는 기존 의존성) |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | | |
| 함수 길이 | 통과 | | |
| 이름 | 통과 | | |
| 죽은 코드 | 통과 | | |
| 테스트가 인수 조건을 검증하는가 | 부분 | env_test.dart | Task의 Red 테스트 5개는 모두 있음. 빈 값 처리 테스트가 없어 FIX 1의 결함을 잡지 못함 |
| 내보내는 것 계약 | 통과 | | `AppEnv`(생성자, `fromEnvironment`, `validate`), `appEnvProvider`, `ErrorReporter.report` 시그니처, `NoopErrorReporter`, `errorReporterProvider`(기본 Noop), `.env.example` 키가 Task에 적힌 그대로 |

### Impl이 짚은 (2) 확인 결과: 실제로 그렇다
- Dart의 `String.fromEnvironment(name, defaultValue: d)`는 키가 **정의되지 않았을 때만** `d`를 돌려준다. 빈 값으로 정의되면 빈 문자열을 돌려준다.
  - 재현: `dart run -DAPI_BASE_URL= m.dart` 결과 `[] has=true`, define 없이 실행하면 `[http://10.0.2.2:8000] has=false`.
- `flutter run --dart-define-from-file=.env`의 .env 파서(`flutter_tools` `flutter_command.dart` `_parseProperty`, `DotEnvRegex.keyValue`)는 `API_BASE_URL=` 줄을 `"API_BASE_URL": ""`로 넘긴다. 빈 키를 빼지 않는다.
- 그래서 사용자가 `.env.example`을 그대로 `.env`로 복사해 디버그 실행하면 `apiBaseUrl`이 `''`가 되고, `validate()`도 디버그에서는 통과하므로 첫 API 호출에서야 알 수 없는 오류가 난다. 릴리스에서는 `validate()`가 `StateError`를 던져 안전하게 막힌다.
- `.env.example` 실행 방법과 기본값은 둘 다 이 Task의 계약이므로, 둘이 맞물리지 않는 것은 이 Task 안에서 고칠 문제다. 고칠 파일 `env.dart`도 범위 안이고 공개 시그니처는 바뀌지 않는다.

## FIX 항목 (Impl로 회귀)
- [ ] app/lib/app/env.dart:17-25 (`fromEnvironment`, 헤더 추가 후 기준) — `API_BASE_URL`이 빈 문자열(공백만 있는 경우 포함)이면 기본값 `http://10.0.2.2:8000`을 쓰도록 바꾼다. 예: 빈 값 판정과 대체를 `@visibleForTesting static String resolveApiBaseUrl(String raw)` 같은 순수 함수로 빼고 `fromEnvironment`가 그걸 쓴다. `AppEnv` 생성자, `fromEnvironment`, `validate`의 시그니처는 바꾸지 않는다.
- [ ] app/test/app/env_test.dart — Red부터: `resolveApiBaseUrl('')`와 `resolveApiBaseUrl('  ')`가 기본값을 주고, `resolveApiBaseUrl('https://a.com')`은 그대로 주는 테스트를 추가한다.
- (참고, 수정 안 해도 됨) 고친 뒤 env.dart 푸터의 `[유지보수]` 줄은 QA가 다시 볼 때 갱신한다.

## PEER_REVIEW 사유
- 없음

## 재검토 (2026-11-09, 커밋 f19c242)
- 범위: app/lib/app/env.dart, app/test/app/env_test.dart
- 반영 확인
  - `@visibleForTesting static String resolveApiBaseUrl(String raw)` 추가: trim 후 비면 `_defaultApiBaseUrl`로 대체. `fromEnvironment`가 이 함수를 거친다.
  - 기본 주소는 비공개 상수 `_defaultApiBaseUrl` 하나로 모음(중복 없음).
  - 공개 계약 유지: 생성자, `fromEnvironment`, `validate`, `appEnvProvider` 시그니처 변화 없음.
  - 테스트 4건 추가(빈 문자열, 공백뿐, 정상 주소, 앞뒤 공백 trim). Impl 보고 기준 Red 4건 실패 확인.
- 보안 영향: 릴리스에서 `API_BASE_URL`을 비우면 `http://10.0.2.2:8000`이 되고 `validate()`가 `StateError`로 거부한다. 우회 경로 없음. 단 `validate()` 호출은 TASK-03 몫이므로 거기서 빠지지 않게 확인할 것.
- 재실행: `flutter test` 16건 통과, `flutter analyze` 0건.
- 헤더/푸터: env.dart 푸터 판정을 PASS로 바꾸고 `[유지보수]` 줄을 갱신함.

## 최종 판정: PASS
