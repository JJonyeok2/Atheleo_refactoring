# QA-TASK-16

- 검토일: 2026-11-13
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/features/workout/domain/workout_session_controller.dart` | 추가함 | dart format 변경 없음, analyze 0건 |
| `app/test/features/workout/domain/workout_session_controller_test.dart` | 해당 없음(테스트) | 29건 통과 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | `_clock`, `_remainingSec` | nowMs 역행은 직전 값으로 맞춤, 남은 초는 0~restSec로 제한. 휴식/일시정지/종료 중 반복 입력 무시 |
| XSS 등 출력 처리 | 해당 없음 | | UI, 문자열 출력 없음 |
| 인증 / 인가 | 해당 없음 | | 순수 도메인 로직 |
| 시크릿 하드코딩 | 통과 | | 없음 |
| 로그의 민감 정보 | 통과 | | 로그 없음 |
| 새 의존성 | 통과 | | `dart:math`, `flutter/foundation`만 사용 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | 이벤트 클래스 `==`/`hashCode` | 계약상 값 비교가 필요해 반복은 불가피. 허용 |
| 함수 길이 | 통과 | | 가장 긴 `_completeSet` 약 17줄 |
| 이름 | 통과 | | |
| 죽은 코드 | 참고 | `_remainingSec`의 `math.min(..., restSec)` | 단조 시계 보정 뒤에는 restSec를 넘을 수 없어 사실상 방어 코드. 해롭지 않아 유지 |
| 테스트가 인수 조건을 검증하는가 | 통과 | 테스트 전체 | Task 표 8행 모두 있음(F-08 10회 후 2세트/휴식/NextSetStarted, F-06 27초 RestEndingSoon(3) 한 번). 경계 테스트 추가(올림, 역행, 0초 휴식, 3초 이하 휴식, 불변 목록) |
| 내보내는 계약 | 통과 | | `WorkoutPhase`, `WorkoutSessionState`, 이벤트 6종, 컨트롤러 메서드 시그니처 모두 Task 표와 같음 |

## Impl이 정한 동작 평가 (소비 Task 대조)
1. 마지막 세트 완료 시 `[RepCounted, WorkoutFinished]`, SetCompleted 없음: 타당. Task 규칙 "마지막 세트 완료 시 휴식 없이 WorkoutFinished"와 같고, TASK-18의 SetCompleted 문구가 "N초 쉬세요"라 마지막 세트에 내면 틀린 안내가 됨. TASK-18은 '{N}회' 다음 '운동을 마쳤어요' 순으로 말하게 됨.
2. 휴식 0초면 같은 호출에서 `SetCompleted(n, 0)` + `NextSetStarted`: 루틴 표의 restSec 최소값이 30이라 실제 흐름에서는 나오지 않음. 방어 동작으로 타당. TASK-52의 analyzer.reset은 onRep 결과에서도 NextSetStarted를 보면 동작해야 함(아래 권고).
3. 휴식 중 finish면 빈 다음 세트를 빼고 currentSet 감소: 휴식 중 반복/부분 반복은 무시되므로 뺀 세트는 항상 비어 있음. TASK-17 "빈 세트 제외"와 결과가 같고, 마지막 세트만 빼므로 set_index 원래 번호 유지 규칙과도 충돌 없음. 중복이지만 state(화면의 '세트 n / N')가 종료 후 실제 마친 세트를 가리키므로 유지가 낫다.
4. 시각 역행을 직전 값으로 조용히 맞춤: TASK-27의 `clockProvider`가 `DateTime.now`(벽시계)라 NTP 보정, 사용자 시간 변경으로 역행이 실제로 생길 수 있음. 도메인에서 조용히 맞추는 것은 맞다(로그 수단 없음, 휴식이 늘지 않는 쪽이 안전). 반대로 앞으로 튀는 경우는 막을 수 없으므로 아래 권고 참고.
5. 일시정지: exercising/resting에서만 pause, paused에서만 resume, 일시정지 중 남은 초 고정, 일시정지 중 finish 허용, 두 번 pause와 쉬지 않는 resume 무시. Task 규칙과 일치. exercising에서 pause/resume해도 `_restEndMs`를 미는데, 다음 `_completeSet`에서 다시 계산되므로 영향 없음.
6. tick이 3초 이하 구간을 건너뛰면 RestEndingSoon 없이 NextSetStarted: 3초 구간은 1초 주기 tick(TASK-27)으로 정상 흐름에서 건너뛸 수 없음. 건너뛰는 경우는 앱 정지 등 비정상뿐이고, 그때 "3초 뒤" 안내 직후 "다음 세트"를 연달아 말하는 것이 더 나쁘므로 생략이 맞다. 인수 조건과 충돌하지 않음.
7. state getter 매번 복사: 최대 3세트 x 20회 = 60개 참조 복사라 30fps에서 읽어도 비용 무시 가능. 다만 TASK-27은 이벤트, tick 뒤에만 읽는 것을 권장.
8. `RepCounted.==`가 rep 동일 객체 기준: `RepResult`에 `==`가 없어 동일성 비교. 컨트롤러는 받은 객체를 그대로 넣으므로 문제 없음. TASK-18 테스트는 직접 만든 RepCounted를 입력으로만 쓰므로 영향 없음.

## Task 보충 권고 (계약 쪽, 이 Task FIX 아님)
- TASK-27: 세션 nowMs는 벽시계 대신 단조 시계(`Stopwatch` 경과 시간 등)를 쓰는 것을 검토. startedAt/endedAt만 `clockProvider` 사용. 지금 방식이면 시계가 앞으로 튈 때 휴식이 일찍 끝날 수 있음.
- TASK-52: "NextSetStarted가 나오면(tick, skipRest 모두) analyzer.reset()"에 onRep도 포함한다고 명시(휴식 0초 경로). 실제 루틴에서는 안 나오지만 계약상 가능.
- TASK-18: 마지막 세트에는 SetCompleted가 없고 RepCounted 다음 WorkoutFinished만 온다는 점을 기능 범위에 한 줄 추가.

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
