# QA-TASK-17

- 검토일: 2026-11-13
- 판정: PASS

## 검토 범위와 환경 메모
- TASK-16, TASK-22 Impl이 병렬 진행 중이라 전체 `flutter test`/`flutter analyze`는 돌리지 않고 TASK-17 파일 기준으로만 판단함.
  - `flutter test test/features/workout/domain/workout_summary_test.dart`: 11건 모두 통과
  - `flutter analyze lib/features/workout/domain/workout_summary.dart test/features/workout/domain/workout_summary_test.dart`: 문제 없음
  - `dart format`(대상 2개 파일): 변경 없음
- 오케스트레이터 지시에 있던 "JSON 왕복 테스트"는 Task에 JSON 계약이 없으므로 요구 사항이 아님(오케스트레이터 확인). 만들지 않은 것이 맞다.

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/features/workout/domain/workout_summary.dart` | 헤더 있음(Impl 작성, 규칙에 맞아 유지), 푸터에 QA 날짜/판정, 보안, 유지보수 메모 보강 | 주석 외 변경 없음 |
| `app/test/features/workout/domain/workout_summary_test.dart` | 달지 않음(테스트 파일) |  |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과(메모) | `buildSummary` | partialsPerSet 음수 미검사. 유일한 호출부 TASK-27이 TASK-16 카운터 값(0 이상)을 넘기므로 순수 도메인 함수로는 허용 범위. 길이 초과분 무시는 계약("짧으면 0")과 충돌 없음 |
| XSS 등 출력 처리 | 해당 없음 |  | UI, 문자열 출력 없음 |
| 인증 / 인가 | 해당 없음 |  |  |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 없음 |
| 새 의존성 | 통과 |  | `flutter/foundation.dart`(@immutable)만 사용, pubspec 변경 없음 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | `WorkoutSummary` | `sets.expand((s) => s.reps)`가 avgScore, topErrors에 두 번 나오지만 한 줄이라 허용 |
| 함수 길이 | 통과 |  | 가장 긴 `buildSummary` 약 30줄 |
| 이름 | 통과 |  | 계약 이름 그대로 |
| 죽은 코드 | 통과 |  | 없음 |
| 테스트가 인수 조건을 검증하는가 | 통과 | 테스트 파일 | Task의 Red 7건 모두 대응(총 횟수/평균 85, 세트 평균 88, 빈 세트 제외 [1, 2], 부분 반복 합계 3과 평균 무영향, topErrors 첫 항목 sqShallow 2, 반복 없음, 계획 값 15/45/intermediate). 추가로 중간 빈 세트 번호 유지 [1, 3], partialsPerSet 짧음, 동률 시 선언 순서, 세트 0개 검증 |

## Impl 판단 평가
| 판단 | 평가 |
|---|---|
| 반복 0개 + 부분 반복만 있는 세트 유지 | 맞음. Task 규칙은 "둘 다 0개일 때만 뺀다". 해당 세트 avgScore는 0이 되므로 TASK-30에서 표시 방식만 정하면 됨 |
| 세션 avgScore = 전체 반복 평균 | 맞음. Task 규칙 "모든 반복 점수 평균(반올림)" 그대로이며 세트 평균의 평균이 아님 |
| partialsPerSet 음수 미검사, 길이 초과 무시 | 허용. 푸터에 한계로 기록 |
| reps 리스트를 복사 없이 보관 | 허용(FIX 아님). 계약이 `const` 생성자라 생성자 안에서 `List.unmodifiable` 복사가 불가능. 실제 공급원인 TASK-16 `WorkoutSessionState.sets`가 이미 `List.unmodifiable` 스냅숏을 내보내고(진행 중 코드 확인), buildSummary가 만드는 바깥 `sets` 리스트는 외부로 새지 않음. 바깥에서 바뀔 수 있는 리스트를 넘기면 요약이 바뀐다는 점은 푸터에 명시. 원하면 buildSummary 안에서 `List.unmodifiable(sets[i])`로 감싸는 것은 계약을 바꾸지 않는 선택적 개선 |
| topErrors 동률 시 enum index 순서 | 맞음. Task 규칙 "같으면 PoseErrorCode 선언 순서" 그대로, 테스트로 확인 |
| 생성자 `const new(...)` 문법 | 프로젝트 전반에서 쓰는 Dart 3.13 문법으로 `const SetSummary(...)` 호출과 동일. 계약 위반 아님 |

## 소비 Task 계약 대조
| Task | 기대하는 것 | 결과 |
|---|---|---|
| TASK-18 | 이 파일을 쓰지 않음(WorkoutEvent만 사용) | 해당 없음 |
| TASK-27 | `buildSummary` 시그니처, sets와 partialsPerSet 전달 | 일치. TASK-16 계약상 partialsPerSet은 sets와 길이가 같아 경계 문제 없음 |
| TASK-30 | WorkoutSummary 4개 게터, SetSummary `reps`, `partialReps`, `doneReps`, `avgScore` | 일치 |
| TASK-32 | SetSummary/WorkoutSummary 생성자(DB에서 복원) | 일치. 모든 필드가 public 생성자 인자라 DB 값만으로 복원 가능 |
| TASK-38 | set_index, target_reps, done_reps, partial_reps, rest_sec 등을 만들 수 있는 필드 | 일치. 직렬화는 TASK-38 범위 |

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
