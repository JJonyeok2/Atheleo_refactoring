# QA-TASK-26

- 검토일: 2026-11-13
- 판정: PASS (재검토 후)

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/features/workout/domain/tracking_monitor.dart` | 헤더 있음(Impl 작성, 규칙 충족), 푸터 추가함 | ignore 주석 제거 필요(FIX 1) |
| `app/test/features/workout/domain/tracking_monitor_test.dart` | 해당 없음(테스트 파일) | 10건 통과, analyze 0건 재확인 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | - | 순수 로직. 입력은 프레임 시각과 bool뿐. 시각 역순 입력은 검사하지 않음(유지보수 메모) |
| XSS 등 출력 처리 | 해당 없음 | - | 화면 출력 없음 |
| 인증 / 인가 | 해당 없음 | - | - |
| 시크릿 하드코딩 | 통과 | - | 없음 |
| 로그의 민감 정보 | 통과 | - | 로그 없음 |
| 새 의존성 | 통과 | - | `dart:collection`만 사용 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | - | - |
| 함수 길이 | 통과 | - | 모든 함수 15줄 이하 |
| 이름 | 통과 | - | - |
| 죽은 코드 | 문제 | `tracking_monitor.dart:28-30` | 불필요한 `// ignore: prefer_initializing_formals`와 사실과 다른 설명 주석 |
| 테스트가 인수 조건을 검증하는가 | 통과 | 테스트 파일 | Task의 테스트 8항목 모두 대응. F-01 측정 초기화는 reset 유무 대조로 검증 |
| 내보내는 것 계약 | 통과 | `tracking_monitor.dart:8-65` | `TrackingSignal`, 생성자 인자 이름과 기본값, `onResult`, `isPersonLost`, `switchedToLite`, `reset` 모두 Task 그대로 |

## Impl 판단 지점 평가
1. fps 창 `(ts-10s, ts]`, 측정 시작에서 10초 뒤부터 판단: 적절. 정확히 10fps면 창 안에 100개가 들어가 `< 10`이 아니므로 경계도 맞음.
2. 사람 없는 결과도 fps에 셈: 적절. fps는 감지기 처리 속도이고, TASK-28은 phase와 관계없이 모든 결과를 `onResult`에 넣으므로 계약과도 맞음.
3. reset이 personLost를 풀되 personReturned를 내지 않음: 문제 없음. TASK-28에서 reset은 `resume()`(모든 재개 경로), 앱 `resumed`, `NextSetStarted`에서 불린다. 미검출로 멈춘 뒤 백그라운드 복귀 시에는 askResume → `confirmResume(true)` → `resume()`로 재개되므로 personReturned가 없어도 막히지 않음. 단 TASK-28은 "사람이 없어 멈춤" 플래그를 personReturned가 아니라 `resume()`에서 풀어야 한다(푸터에 메모).
4. reset이 switchedToLite 유지, 백그라운드 복귀 오전환: 측정 시작이 reset 뒤 첫 결과로 다시 잡히므로 멈춘 시간이 평균에 안 들어감(테스트 "멈췄다 돌아오면"에서 reset 없을 때 오전환, 있을 때 없음을 대조 확인). 남은 위험은 reset 직후 백그라운드 이전 프레임 결과가 늦게 도착해 측정 시작이 과거로 잡히는 경우뿐이며, 이는 호출부 사정이라 메모로 남김(FIX 아님).

## FIX 항목 (Impl로 회귀)
- [x] (재검토에서 해결 확인) `app/lib/features/workout/domain/tracking_monitor.dart:25-30` — 이 저장소 Dart(SDK ^3.13.7)는 private named parameter를 지원한다(`app/lib/core/tts/voice_guide.dart:31-32`에서 이미 사용, 별도 스크래치로 `this._minFps = 10` + 호출 `M(minFps: 5)` analyze 0건, 실행 확인). 생성자 인자를 `this._minFps = 10`으로 바꾸고 이니셜라이저의 `_minFps = minFps`, `// ignore: prefer_initializing_formals`, "이름 있는 인자는 private 필드로 바로 받을 수 없다" 주석을 지운다. 공개 인자 이름은 `minFps` 그대로라 계약은 바뀌지 않는다.

## PEER_REVIEW 사유
- 해당 없음

## 재검토 (FIX 1건 반영 후)
- 재검토일: 2026-11-13
- `tracking_monitor.dart:25-30`: 생성자 인자가 `this._minFps = 10`이고, 이니셜라이저의 `_minFps = minFps`, `ignore` 주석, 잘못된 설명 주석이 모두 사라짐(`ignore:` 0개).
- 계약: 바깥 인자 이름 `minFps`와 기본값 10 유지. 추가된 테스트 "minFps 이름 인자가 임계값으로 적용된다"(minFps: 5 / 9 대조)가 이를 검증함.
- 대상 2개 파일 `flutter analyze` 0건, `tracking_monitor_test.dart` 11건 전부 통과.
- 범위 밖 변경: `git status` 기준 이번 Task 코드 변경은 대상 2개 파일뿐. 그 밖의 갱신은 docs(STATE, TASK-28 문서, AGENT_LOG)이며 TASK-14 파일은 건드리지 않음.
- 판정: PASS. 자동 검증으로 넘긴다.
