# QA-TASK-13

- 검토일: 2026-11-13
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/pose/body/body_check.dart` | 헤더 있음(Impl 작성, 형식 맞음), 푸터 `// [QA] 대기`를 QA 푸터로 교체 | 142줄, 공개 함수 4개 |
| `app/test/pose/body/body_check_test.dart` | 테스트 파일이라 달지 않음 | 228행 주석의 좌표, 각도 값이 실제 입력과 달라 주석만 고침(동작 변경 없음) |

- `flutter test test/pose/body/` 14건 통과, `flutter analyze` 대상 2개 0건, `dart format` 대상 2개 변경 없음.
- Impl이 `dart format test`로 바꿨던 TASK-01 테스트 2개는 되돌려져 `git status`에 나타나지 않음을 확인.

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | 14~17, 52, 79, 90, 126, 131, 139~142행 | NaN, Infinity, 몸통 길이 0, 벡터 길이 0이면 false 또는 후보 제외. 예외 없음(테스트 '노이즈 입력' 2건으로 확인). aspectRatio 0 이하는 막지 않음, joint_angle.dart와 같은 방침(파싱 쪽 책임) |
| XSS 등 출력 처리 | 해당 없음 |  | UI 출력 없음 |
| 인증 / 인가 | 해당 없음 |  | 순수 함수 |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 출력 없음 |
| 새 의존성 | 통과 |  | `dart:math`와 내부 모듈만 사용 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 |  | 좌우 점 꺼내기는 `_sideBody` 하나로 모음 |
| 함수 길이 | 통과 | `passesPostureGate` 101~136행 | 36줄, 50줄 미만 |
| 이름 | 통과 |  | `_usable`, `_primaryScore`, `_inUnitBox` 의미 분명 |
| 죽은 코드 | 통과 | 25행 | `_sideBody`의 무릎은 게이트에서 안 쓰지만 `isFullBodyVisible`에서 씀 |
| 테스트가 인수 조건을 검증하는가 | 통과 |  | Task의 Red 표 8행 모두 대응(측면 전신, 정면, 전신 아님, 주 인물/빈 목록, 푸쉬업 0/25/45/90, 스쿼트 15/30/45, 측정 쪽 지정, maxDeg 주입). 추가로 노이즈, 코 visibility, aspectRatio 테스트 |

## Impl 결정 평가
| 결정 | 평가 |
|---|---|
| 게이트 경계 `+1e-6` 허용오차 | 타당. 합성 프레임의 스쿼트 30도가 부동소수 오차로 30을 살짝 넘을 수 있어 "이하" 규칙을 지키려면 필요. 1e-6도는 판정에 실질 영향 없음 |
| side 지정 시에만 6점 평균 visibility 0.5 검사 | 일관적. `selectSide` 경로는 `selectSide` 자체가 같은 6점 평균(`SideAngles.visibility`) ≥ 0.5를 보장하므로 두 경로의 visibility 기준이 같음. 차이는 `selectSide`가 세 점 묶음 길이 0까지 거른다는 점뿐이고, 게이트가 쓰는 벡터는 `_usable`로 따로 검사하므로 지정 경로가 약간 더 관대한 정도. TASK-49(측정 쪽 고정)에 유리한 방향이라 문제 아님. 푸터에 기록 |
| `selectPrimaryPose` 비유한 점 무시, 후보 없으면 null | 타당. 계약(빈 목록이면 null)을 넓힌 것이고 TASK-25/27/45는 이미 null을 "사람 없음"으로 처리하므로 호환 |
| `isFrontFacing` 몸통 길이 0/비유한이면 false | 타당. 정면 안내를 잘못 띄우지 않는 쪽. visibility는 보지 않으므로 TASK-14가 `isFullBodyVisible`과 함께 써야 함(푸터에 기록) |
| 푸쉬업 게이트 벡터 길이 0이면 false | 타당. 0도로 통과시키지 않음 |
| `isFullBodyVisible`이 고른 쪽만 판정 | Task 기준 그대로(nose + `selectSide`로 고른 쪽) |

## 계약 대조 (내보내는 것)
| 이름 | Task 계약 | 구현 | 소비 Task 표기 |
|---|---|---|---|
| `isFullBodyVisible` | `bool (PoseFrame, {double minVisibility = 0.5})` | 일치 | TASK-14 일치 |
| `isFrontFacing` | `bool (PoseFrame, {double ratioThreshold = 0.35})` | 일치 | TASK-14 일치 |
| `selectPrimaryPose` | `PoseFrame? (List<PoseFrame>)`, 빈 목록 null | 일치 | TASK-25, 27, 45 일치 |
| `passesPostureGate` | `bool (PoseFrame, ExerciseType, {BodySide? side, double maxDeg = 30})` | 일치, Q-05 주석 있음(100행) | TASK-14, 49 일치 |

## aspectRatio 반영
- TASK-05 `angleDeg`는 각 벡터의 x 차이에 `aspectRatio`를 곱함. 이 파일도 정면 판정 어깨 너비, 몸통 x 성분, 푸쉬업/스쿼트 벡터의 x 차이에 `frame.aspectRatio`를 곱해 같은 방식. y는 그대로. 테스트 'aspectRatio를 x에 곱해 기울기를 잰다'로 확인(비율 1: 약 33.7도 false, 비율 3: 약 12.5도 true).

## QA가 직접 고친 것 (주석만)
- `app/test/pose/body/body_check_test.dart:228` — 주석이 실제 입력과 다른 좌표, 각도(22도/8도)를 적고 있어 실제 값(어깨 (0.2,0.4) → 발목 (0.8,0.8), 33.7도/12.5도)으로 고침.

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
