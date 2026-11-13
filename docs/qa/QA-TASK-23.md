# QA-TASK-23

- 검토일: 2026-11-13
- 판정: PASS (재검토 후, 최초 판정은 FIX)

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/features/workout/widgets/score_badge.dart` | 헤더는 Impl이 단 것 유지, 푸터 `// [QA] 대기`를 FIX 판정으로 교체 | `dart format` 변경 없음 |
| `app/test/features/workout/widgets/score_badge_test.dart` | 규칙상 달지 않음 | 9건 통과 확인 |

검증 범위: 병렬로 TASK-18, TASK-24 Impl이 진행 중이라 전체 `flutter analyze`/`flutter test`는 돌리지 않았다. 대상 두 파일만 `flutter analyze`(이슈 0건)와 `flutter test test/features/workout/widgets/score_badge_test.dart`(9건 통과)로 확인했다. TASK-18, 24 파일은 건드리지 않았다.

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | score_badge.dart 생성자 | null 허용, 0~100 밖 값은 clamp |
| XSS 등 출력 처리 | 해당 없음 | | Flutter `Text` 렌더링, HTML 없음 |
| 인증 / 인가 | 해당 없음 | | 표시 전용 위젯 |
| 시크릿 하드코딩 | 통과 | | 없음 |
| 로그의 민감 정보 | 통과 | | 로그 없음 |
| 새 의존성 | 통과 | | 없음 (`rep_score.dart`, material만) |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | | 색 정의는 `scoreColor` 한 곳 |
| 함수 길이 | 통과 | `build` 약 30줄 | |
| 이름 | 통과 | | |
| 죽은 코드 | 통과 | | |
| 테스트가 인수 조건을 검증하는가 | 통과 | 테스트 파일 | Task의 Red 5건 + 경계값(0/60/84/85), clamp, null 라벨, size 검증. 글자색 검증은 없음 |
| 접근성(글자 대비) | 문제 | score_badge.dart:47 | 아래 FIX 참조 |

### 평가 항목별 판단
- **clamp 정책**: Task에 명시는 없지만 표시 전용 위젯에서 0~100으로 맞추는 것은 방어적으로 타당하다. 문서 주석과 테스트에 정책이 드러나 있다. 다만 상위 계산 버그를 가릴 수 있으므로 점수 생산 쪽(TASK-12)에서 범위가 보장된다는 전제를 유지할 것. 수용.
- **'점수 없음' 라벨**: Task는 null일 때 '-'와 회색만 정했다. 스크린리더에 '-'를 읽히는 것보다 낫고 '점수 N점' 형식과도 어긋나지 않는다. 수용.
- **글자 흰색, 크기 0.4배**: 기본 64 기준 25.6 bold로 WCAG "큰 글자"(약 18.66px bold 이상)에 해당해 3:1 기준 적용. 단, size 46 미만이면 큰 글자에서 벗어나 4.5:1 기준이 된다(TASK-42 목록 등 작게 쓸 때 주의).
- **대비비(WCAG, 흰 글자 기준)**: good `0xFF2E7D32` 5.13:1 통과, poor `0xFFC62828` 5.62:1 통과, fair `0xFFF9A825` **1.97:1 미달**(3:1도 못 넘음), 회색 `Colors.grey`(0xFF9E9E9E) **2.68:1 미달**. 검은 글자로 바꾸면 fair 10.66:1, 회색 7.84:1로 4.5:1까지 충족한다. 배경색은 Task가 정했으니 글자색으로 해결 가능하다. (참고로 good/poor에 검은 글자는 4.10, 3.74라 흰 글자를 유지해야 한다.)
- **생성자 인자 순서**: `{required int? score, super.key, this.size = 64}`. very_good_analysis의 `always_put_required_named_parameters_first` 때문이며 모두 named라 호출부에 영향 없음. `const new(...)` 문법은 저장소 전반 관례와 같다. 계약 위반 아님.
- **소비 Task 계약 대조**: TASK-29/30/42가 기대하는 `ScoreBadge(score:, size:)`(const 가능), `scoreColor(ScoreGrade)`, Semantics '점수 N점', TASK-30의 `scoreColor(gradeFor(score))` 모두 그대로다. 글자색 수정은 계약을 바꾸지 않는다.

## FIX 항목 (Impl로 회귀)
- [ ] `app/lib/features/workout/widgets/score_badge.dart:47` — 글자색을 `Colors.white` 고정에서 배경 밝기에 따라 고르도록 변경. 예: `ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black` (계산상 good/poor는 흰색, fair/회색은 검정이 나옴). 배경색과 공개 계약은 바꾸지 않는다.
- [ ] `app/test/features/workout/widgets/score_badge_test.dart` — 글자색 테스트 추가: 75점(fair)과 null은 어두운 글자, 100점과 59점은 흰 글자.

## PEER_REVIEW 사유
- 해당 없음

## 재검토 (FIX 반영 후, 2026-11-13)
- 글자색: `estimateBrightnessForColor(배경) == dark ? 흰 : 검정`. 배경색, 공개 계약(`ScoreBadge(score:, size:)`, `scoreColor`, Semantics)은 그대로.
- 4개 배경 대비비 재계산 (WCAG 상대 휘도):

| 배경 | 선택 글자 | 대비비 | 반대색 대비비 |
|---|---|---|---|
| good 0xFF2E7D32 | 흰 | 5.13 | 검정 4.10 |
| fair 0xFFF9A825 | 검정 | 10.66 | 흰 1.97 |
| poor 0xFFC62828 | 흰 | 5.62 | 검정 3.74 |
| grey 0xFF9E9E9E | 검정 | 7.84 | 흰 2.68 |

  QA 보고서 계산과 일치하고 네 경우 모두 4.5:1 이상. 단, 회색은 Flutter 임계값(0.15) 근처(0.1538)라 밝음으로 판정되며 여유가 작다. 회색 값이 바뀌면 이 테스트가 깨지므로 이대로 고정해 둔다.
- 테스트: 100점(good)·59점(poor) 흰색, 75점(fair)·null(회색) 검정으로 네 배경을 모두 고정. `flutter test` 10건 통과, 대상 두 파일 `flutter analyze` 0건.
- 범위 밖 변경: 저장소가 git 저장소가 아니라 `git status`는 불가. 이번 재검토에서 대상 두 파일과 QA 보고서, AGENT_LOG 외는 수정하지 않았다(TASK-24 파일 미접촉).
- 판정: PASS. 푸터 [QA] 갱신(아래 파일 푸터 참조).
