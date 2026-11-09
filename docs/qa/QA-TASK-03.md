# QA-TASK-03

- 검토일: 2026-11-09
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| app/lib/app/routes.dart | 추가함 | 계약 상수 10개, 경로 함수 3개 일치 |
| app/lib/app/router.dart | 추가함 | buildRouter 시그니처, routerProvider, errorBuilder 문구 일치 |
| app/lib/app/app.dart | 추가함 | AtheleoApp extends ConsumerWidget, MaterialApp.router + routerProvider |
| app/lib/app/placeholder_screen.dart | 추가함 | `const PlaceholderScreen({required String title})` 일치 |
| app/lib/main.dart | 푸터 갱신 | 낡은 "TASK-03에서 교체" 문구 제거, bootstrap 순서와 re-export 이유 기록 |
| app/test/app/router_test.dart | 해당 없음(테스트) | 7건 |
| app/test/smoke_test.dart | 해당 없음(테스트) | bootstrap 2건 추가 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | routes.dart 경로 함수 | type, id를 인코딩 없이 이어 붙임. 현재 입력은 고정 운동 종류와 내부 id라 문제없음, 사용자 입력이 들어오면 인코딩 필요(푸터에 기록) |
| XSS 등 출력 처리 | 통과 | - | Text 위젯만 사용 |
| 인증 / 인가 | 통과(범위 밖) | router.dart | redirect, refreshListenable 주입 지점만 있음. 실제 가드는 TASK-37 |
| 개발자 메뉴 노출(F-14) | 통과 | router.dart:110 | `if (enableDevMenu)`로 릴리스에서 경로 자체 미등록, routerProvider는 kDebugMode 사용. 테스트로 확인 |
| 설정 검증 호출 | 통과 | main.dart:13, 25 | `main()`이 `bootstrap()`을 부르고, bootstrap이 `(env ?? AppEnv.fromEnvironment()).validate()`를 runApp 전에 호출. 잘못된 설정에서 StateError와 미실행을 테스트로 확인 |
| 시크릿 하드코딩 | 통과 | - | 없음 |
| 로그의 민감 정보 | 통과 | - | 로그 없음 |
| 새 의존성 | 통과 | - | 없음(go_router, flutter_riverpod는 TASK-01에서 추가됨) |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | router.dart | `_placeholder` 헬퍼로 경로 등록 중복 제거 |
| 함수 길이 | 통과 | - | 모두 30줄 이하 |
| 이름 | 통과 | - | - |
| 죽은 코드 | 통과 | - | 없음 |
| 라우트 순서 | 통과 | router.dart:107-109 | workoutResult가 workoutSetup, workout보다 먼저 등록, 테스트로 확인 |
| routerProvider dispose | 통과 | router.dart:123 | `ref.onDispose(router.dispose)` |
| 한국어 글꼴 | 통과 | app.dart | 플랫폼 기본 글꼴(안드로이드 Noto Sans CJK)로 충분. 별도 번들 불필요 |
| 테스트가 인수 조건을 검증하는가 | 통과 | router_test.dart, smoke_test.dart | Red 표 6건 + 없는 경로 + bootstrap 2건. flutter test 25건 통과, analyze 0건(QA 재실행) |

## 계약 밖 공개 이름 판단
| 이름 | 판단 | 근거 |
|---|---|---|
| `bootstrap` (main.dart) | 허용(내부 확장) | 추가 발췌가 요구한 "시작 함수 validate 호출 테스트"의 주입 지점. 다른 Task가 기대는 계약을 바꾸지 않음. TASK-48은 main.dart를 고치는 Task이므로 이 함수에 Sentry 초기화를 붙이면 됨 |
| `notFoundMessage` (router.dart) | 허용 | 계약 문구('페이지를 찾을 수 없어요')와 값이 같음. 추가 공개일 뿐 계약 변경 아님 |
| `buildAppTheme` (app.dart) | 허용 | 추가 공개일 뿐 AtheleoApp 계약 그대로 |

- `AtheleoApp`의 import 위치: docs/tasks를 grep한 결과 다음 Task(TASK-48)는 `app/lib/app/app.dart`를 위치로 적었고, `package:atheleo/main.dart`에서 AtheleoApp을 import한다고 가정한 Task는 없음. main.dart의 re-export는 TASK-01 smoke 테스트 호환용으로 충분하고, 없어도 다른 Task에 영향 없음.

## FIX 항목 (Impl로 회귀)
- 없음

## 참고 (다음 Task에 넘길 것)
- 없는 경로 화면에 홈으로 돌아가는 수단이 없음. TASK-25/46 등 화면 Task에서 필요하면 추가.
- TASK-48에서 Sentry `appRunner`를 붙일 때 validate가 runApp보다 먼저 실행되는 순서를 유지할 것.

## PEER_REVIEW 사유
- 해당 없음
