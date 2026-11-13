# QA-TASK-09

- 검토일: 2026-11-13
- 판정: FIX

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/pose/judge/pose_error.dart` | 헤더는 Impl이 이미 작성(규칙 충족), 푸터 추가함 | 계약 일치 |
| `app/lib/pose/judge/error_judge.dart` | 헤더는 Impl이 이미 작성(규칙 충족), 푸터 추가함 | FIX 2건 |
| `app/test/pose/judge/error_judge_test.dart` | 테스트 파일이라 추가하지 않음 | 19건 통과 확인 |

검증 실행: `flutter test test/pose/judge/` 19건 통과, `flutter analyze lib/pose/judge test/pose/judge` 이슈 없음.
전체 `flutter analyze`의 info 6건은 병렬 작업 중인 TASK-11(`lib/core/tts`, `test/core/tts`) 파일에서 나온 것이다. TASK-09 판정은 TASK-09 파일 기준이며, 그 파일들은 건드리지 않았다.

## Impl 판단 평가
| 번호 | Impl 판단 | 평가 |
|---|---|---|
| 1 | 처짐/들림 방향 = 프레임별 외적 부호 × 어깨→발목 x 부호, 다수결, 동수면 null | 타당. 추가 발췌(외적 × x 부호, 보간 금지)와 일치. 좌우 반전 테스트도 있음. 동수 null은 Task에 없는 세부라 Task 보충 권고 |
| 2 | 각도 중앙값은 selectSide 가능한 프레임만, 없으면 오류 없음 | 타당. 중앙값이라 한 프레임 튐에 강함 |
| 2' | 스쿼트 상체 기울기: 최저점 프레임에서 side를 못 고르면 0 | **Task 위반.** "고를 수 없는 프레임은 건너뛴다"이므로 고를 수 있는 프레임 중 bottomMs에 가장 가까운 프레임을 써야 한다. 지금은 최저점 한 프레임이 끊기면 상체 숙임을 놓친다(검증함: 상체 60도 클립에서 최저점 프레임만 visibility 0으로 바꾸면 `sqTorsoLean` 미검출) |
| 3 | 뒤꿈치 좌우를 시작 프레임 쪽으로 고정 | 고정 자체는 타당(다른 쪽 뒤꿈치와 y를 비교하면 의미 없음). 그러나 루프가 selectSide 불가 프레임도 그대로 읽는 것이 문제(아래 FIX 1) |
| 4 | 뒤꿈치 = 시작 대비 y 감소 최댓값 / 시작 정강이 길이, `>=`; 깊이, 상체는 `>` | 경계 비교는 Task 표와 일치(아래 표). 시작 프레임을 "첫 프레임"이 아닌 "첫 선택 가능 프레임"으로 한 것은 건너뛰기 규칙과 맞아 수용, Task 문구 보충 권고 |
| 5 | 최저점 동률 시 먼저 나온 프레임 | 타당 (`<` 비교로 앞 프레임 유지) |

### 경계 비교 대조
| 코드 | Task 표 | 구현 | 결과 |
|---|---|---|---|
| PU_SHALLOW, SQ_SHALLOW | 90도 초과 | `rep.minAngle > depthDeg` | 일치 (90 없음, 90.1 있음 테스트) |
| PU_HIP_SAG / PIKE | 160도 미만 | 중앙값 `>= bodyLineDeg`이면 null | 일치 |
| SQ_TORSO_LEAN | 45도 초과 | `> torsoLeanDeg` | 일치 (경계 테스트 없음) |
| SQ_HEEL_LIFT | 10% 이상 | `>= heelLiftRatio` | 일치 (경계 테스트 없음. 합성 클립에서 정확히 0.1을 넣으면 부동소수 오차로 미검출됨, 실사용 영향은 작음) |

### 카메라 노이즈 점검 (임시 프로브 테스트로 실행 후 삭제)
| 상황 | 결과 | 분류 |
|---|---|---|
| 몸 랜드마크 전체가 visibility 0인 프레임 1개(좌표 0,0) | `sqHeelLift` 오탐 | Task 위반 → FIX 1 |
| 최저점 프레임만 선택 불가 | `sqTorsoLean` 놓침 | Task 위반 → FIX 2 |
| 몸통은 정상, 뒤꿈치만 visibility 0.1로 한 프레임 위로 튐 | `sqHeelLift` 오탐 | Task에 뒤꿈치 visibility 규칙이 없음 → Task 보충 권고 |
| 푸쉬업 한 프레임 튐 | 중앙값, 다수결이라 영향 없음 | 문제 없음 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | `pose_error.dart` `fromCode` | 모르는 코드는 ArgumentError. 프레임 입력의 노이즈 처리는 유지보수성 항목에서 다룸 |
| XSS 등 출력 처리 | 해당 없음 |  | UI 출력 없음 |
| 인증 / 인가 | 해당 없음 |  | 순수 함수 |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 출력 없음 |
| 새 의존성 | 통과 |  | `pubspec.yaml` 변경 없음, `dart:math`만 사용 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 |  | `_points`, `_median`으로 묶여 있음 |
| 함수 길이 | 통과 |  | 최장 `_bodyLineError` 약 28줄 |
| 이름 | 통과 |  | 의미가 분명함 |
| 죽은 코드 | 통과 |  | 없음 |
| 테스트가 인수 조건을 검증하는가 | 부분 통과 | `error_judge_test.dart` | F-04(처짐/들림 서로 안 바뀜, 좌우 반전, 105도 PU_SHALLOW)와 Task Red 표 8건 모두 있음. 다만 선택 불가 프레임이 섞인 경우(뒤꿈치, 최저점) 테스트가 없어 FIX 1, 2를 잡지 못함 |

## 계약 대조 ("내보내는 것")
| 이름 | 결과 | 설명 |
|---|---|---|
| `PoseErrorCode` | 일치 | 6개 값 순서, `code`/`voiceMessage`/`label`, `fromCode`(ArgumentError) 모두 표와 같음 |
| `ErrorThresholds` | 일치 | `const new({...})` 문법이지만 공개 API는 `const ErrorThresholds({double depthDeg = 90, double bodyLineDeg = 160, double torsoLeanDeg = 45, double heelLiftRatio = 0.1})`와 같음. `torsoLeanDeg` 보정 대상 주석 있음 |
| `judgeRep` | 일치 | 시그니처 동일, 운동별 코드만, enum 선언 순서 |

## FIX 항목 (Impl로 회귀)
- [ ] `app/lib/pose/judge/error_judge.dart:205-207` (`_heelLift` 두 번째 루프) — `selectSide(frame)`가 null이거나 고른 쪽이 시작 프레임 쪽과 다른 프레임, 뒤꿈치 y가 유한하지 않은 프레임은 건너뛴다. 지금은 모든 프레임의 뒤꿈치 y를 읽어서, 랜드마크가 끊긴 프레임 하나로 `sqHeelLift` 오탐이 난다.
- [ ] `app/lib/pose/judge/error_judge.dart:164-175` (`_torsoLean`) — 최저점 후보를 `selectSide`가 null이 아닌 프레임으로 한정하고, 그중 `bottomMs`에 가장 가까운 프레임을 쓴다(동률은 앞 프레임). 선택 가능한 프레임이 하나도 없을 때만 0.
- [ ] `app/test/pose/judge/error_judge_test.dart` — 위 두 경우를 Red로 먼저 추가: (a) 뒤꿈치 정상 클립에 전체 visibility 0 프레임 1개를 섞으면 `sqHeelLift` 없음 (b) 상체 60도 클립에서 최저점 프레임만 선택 불가면 인접 프레임으로 `sqTorsoLean` 검출.

## Task 보충 권고 (계약, 기준 쪽. Impl 회귀 대상 아님)
- 뒤꿈치 랜드마크(29, 30) 자체 visibility 기준이 Task에 없다. `selectSide`는 뒤꿈치를 보지 않으므로 뒤꿈치만 흔들리면 오탐한다. 뒤꿈치 visibility 하한(예: 0.5)과, "최댓값" 대신 연속 2프레임 이상 또는 3프레임 중앙값 같은 노이즈 완화 규칙을 Spec/Task에 정할 것(Q-05 실측 보정과 함께).
- `SQ_TORSO_LEAN`이 최저점 한 프레임만 본다. `minAngle`처럼 최저점 주변 3프레임 중앙값으로 할지 정할 것.
- "시작 자세 = 첫 프레임"을 "선택 가능한 첫 프레임"으로 문구 보충.
- 처짐/들림 다수결 동수일 때 오류 없음(null)으로 둔다는 규칙을 문구로 명시.

## PEER_REVIEW 사유
- 해당 없음 (판단 갈림 없음, 수정 범위 작음)
