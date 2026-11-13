# QA-TASK-10

- 검토일: 2026-11-13
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| app/lib/features/routine/domain/body_shape.dart | 헤더 있음(Impl), 푸터 추가함 | 8분류 code, label 계약과 일치 |
| app/lib/features/routine/domain/routine_plan.dart | 헤더 있음(Impl), 푸터 추가함 | RoutineLevel, RoutinePlan(==, hashCode) 계약과 일치 |
| app/lib/features/routine/domain/routine_table.dart | 헤더 있음(Impl), 푸터 추가함 | 표 값 RN 원본과 재대조 일치 |
| app/lib/features/routine/routine_providers.dart | 헤더 있음(Impl), 푸터 추가함 | provider 2개 계약과 일치 |
| app/test/features/routine/routine_table_test.dart | 테스트 파일이라 달지 않음 | 7건 통과 |

검증: `flutter test test/features/routine/` 7건 통과, `flutter analyze lib/features/routine test/features/routine` 0건(푸터 추가 후 재확인).

## 기존 RN 표 재대조 (`atheleo/app/utils/exerciseRoutines.js`)
| 단계 | 스쿼트(횟수/세트/휴식/최소) | 푸쉬업 | 체형 | 결과 |
|---|---|---|---|---|
| HIGH_MUSCLE → advanced | 20/3/30/70 | 15/3/30/70 | 역삼각형, 사각체형 | 일치 |
| MEDIUM → intermediate | 15/3/45/60 | 12/3/45/60 | 모래시계형, 체형 없음, 모르는 값 | 일치 |
| LOW_MUSCLE → beginner | 10/2/60/50 | 8/2/60/50 | 삼각형, 이상체형, 둥근체형, 튜브체형, 마름모형 | 일치 |

차이(의도된 것, 문제 아님): RN의 levelName '초보자'는 Task 계약대로 '초보'. RN의 feedback, description은 Task 범위 밖이라 옮기지 않음. RN은 체형 문자열을 trim했으나 Dart `fromCode`는 정확 일치만 받음(코드 값 기반이라 영향 작음, 푸터에 기록).

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | body_shape.dart `fromCode` | null, 모르는 값은 null로 떨어져 중급 루틴. 예외 없음 |
| XSS 등 출력 처리 | 해당 없음 |  | UI 출력 없음 |
| 인증 / 인가 | 해당 없음 |  |  |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 출력 없음. 체형은 메모리 상태로만 보관 |
| 새 의존성 | 통과 |  | 없음(flutter_riverpod 기존 의존성) |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 |  | 표는 한곳(`_table`)에만, 체형 코드는 `BodyShape.code`에만 정의 |
| 함수 길이 | 통과 |  | 모두 20줄 이하 |
| 이름 | 통과 |  | 계약 이름 그대로 |
| 죽은 코드 | 통과 | routine_plan.dart `minScore` | 미사용이지만 Task가 "값만 보관"을 명시. 죽은 코드 아님 |
| 테스트가 인수 조건을 검증하는가 | 통과 | routine_table_test.dart | Red 표 6건 + 나머지 표 값 1건. F-09 인수 조건(역삼각형 20회 3세트, 없음 15회 3세트)과 6칸 전부 검증. provider set 전후 15→20 검증 |

## Impl 판단 평가
- `routinePlanProvider`의 `ProviderFamily<RoutinePlan, ExerciseType>` 타입 명시: 정적 타입이 `Provider.family<...>` 추론 결과와 같아 계약 위반 아님. 다음 Task 사용법(`routinePlanProvider(exercise)`) 동일. 수용.
- `CurrentBodyShapeNotifier.set`의 `// ignore: use_setters_to_change_properties`: 계약이 `void set(BodyShape? shape)` 메서드를 요구하므로 setter로 바꿀 수 없음. 근거 있는 ignore, 수용.
- `BodyShape.code` 임시값(Q-01): Task 지시대로 enum 한곳에만 정의. 수용.
- `levelForBodyShape`의 switch에 default 없이 8개+null 전체 나열: 체형이 추가되면 컴파일러가 누락을 잡아 줌. 좋은 선택.
- `minScore` 미사용: Task 지시 그대로.
- 초기값 null이면 중급: Task 기능 범위("체형 정보 없으면 중급")와 일치. 실제 체형 반영은 TASK-43이 `set` 호출해야 함(푸터에 기록).

## 참고 (FIX 아님, 다음에 손볼 점)
- routine_table.dart `_table[level]![exercise]!`: switch와 달리 Map이라 `ExerciseType`에 운동이 추가돼도 컴파일 오류가 안 나고 실행 시 null 오류가 난다. 현재 운동 2개, 표 완비라 문제 없음. 운동 추가 시 switch 식으로 바꾸는 것을 고려(푸터에 기록).

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
