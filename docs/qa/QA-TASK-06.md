# QA-TASK-06

- 검토일: 2026-11-13
- 판정: FIX

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/test/support/synthetic_clip.dart` | 해당 없음(테스트 지원 파일) | `docs/conventions/file-header-footer.md`는 테스트 파일을 제외한다. `app/test/` 아래 테스트 전용 코드이므로 제외로 처리(QA-TASK-05와 같은 기준). Impl이 단 헤더(1~4줄)는 내용이 맞아 그대로 두고, 푸터는 달지 않음 |
| `app/test/support/synthetic_clip_test.dart` | 해당 없음(테스트 파일) | |

확인 실행: `flutter test test/support/` 9건 통과, `flutter analyze` 0건. 수치 역검증은 임시 테스트 파일로 돌린 뒤 삭제함(저장소에 남은 파일 없음).

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | `synthetic_clip.dart` 전체 | 테스트 전용 유틸이라 범위 밖 각도(예: elbowDeg 200 → 160으로 접힘)를 막지 않지만 앱 코드에서 쓰지 않으므로 위험 없음 |
| XSS 등 출력 처리 | 통과 | - | 출력 UI 없음 |
| 인증 / 인가 | 해당 없음 | - | |
| 시크릿 하드코딩 | 통과 | - | 없음 |
| 로그의 민감 정보 | 통과 | - | 로그 출력 없음 |
| 새 의존성 | 통과 | - | `dart:math`와 기존 `app/lib` 타입만 사용 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 경미 | `synthetic_clip.dart:142` | 머리 길이 `0.3`이 `_seg`와 같은 값을 따로 적음. `_seg`를 쓰거나 이름 있는 상수로 |
| 함수 길이 | 문제 | `synthetic_clip.dart:97-158`(62줄), `:164-217`(54줄) | 50줄 기준 초과. 푸쉬업/스쿼트 분기를 `_pushUpSkeleton`/`_squatSkeleton`으로, 정규화(배치) 부분을 별도 함수로 나누면 아래 FIX와 함께 정리됨 |
| 이름 | 경미 | `synthetic_clip.dart:145, 149-151` | `0`은 `LandmarkIndex.nose`가 있음. 17, 19, 21(새끼, 검지, 엄지)은 상수가 없으니 주석으로 이름을 밝힐 것 |
| 죽은 코드 | 경미 | `synthetic_clip.dart:204` | `final leftIsVisible = visibleIsLeft;` 같은 값을 다시 담는 별칭. 바로 위 변수를 쓰면 됨 |
| 테스트가 인수 조건을 검증하는가 | 부분 | `synthetic_clip_test.dart:101-113` | Task 표의 8개 행은 모두 검증됨. 다만 뒤꿈치 상승을 한 프레임 안의 (발끝 y − 뒤꿈치 y)로만 봐서, 기능 범위의 "시작 자세 대비" 정의를 검증하지 못함(아래 FIX 1) |

### 계약 대조 ("내보내는 것")
| 이름 | 결과 |
|---|---|
| `SyntheticPose` | 생성자 인자, 기본값, 의미 모두 계약과 같음 (`const new` 문법은 저장소 공통 스타일) |
| `HipOffset` | 같음. `bodyTiltDeg < 90`인 모든 값에서 below는 골반 y가 어깨-발목 선보다 큼(차이 = 오프셋 / cos(tilt) > 0으로 확인) |
| `buildSyntheticFrame` | 시그니처, visibility 0.95 / hiddenVisibility, aspectRatio 1.0, 반대쪽 x 이동, 기본 자세 0~1 안 모두 맞음. 단 프레임 간 좌표계가 고정되지 않음(FIX 1) |
| `repAngleSequence` | 같음. 길이 2×pad + reps×framesPerRep, framesPerRep 짝수면 반복마다 bottom 정확히 1번 |
| `buildSyntheticClip` | 같음. `poseFor(frameIndex, angle)`, timestamp `i * 1000 ~/ fps` |

### 소비 Task별 자세 재현 (TASK-05 `angleDeg`, `selectSide`로 역검증)
| 소비 Task | 필요한 자세 | 결과 |
|---|---|---|
| 13, 14, 49 푸쉬업 게이트 | bodyTiltDeg 0/25/29/30/31/40/45/89/90 | 모두 오차 0.001도 이내. 균일 축척(x, y 같은 k) + 평행 이동만 하므로 aspectRatio 1.0에서 각도 보존. 30도 경계 양쪽 재현 가능 |
| 13, 14, 49 스쿼트 게이트 | torsoLeanDeg 15/20/30/40/45 | 45 ± 1 검증됨, 같은 구조라 다른 값도 정확 |
| 09, 15 처짐/들림 | bodyLineDeg 140 + below/above | 140.000, 방향 맞음(tilt 0~89 전 구간) |
| 09 뒤꿈치 들림 | 시작 프레임 대비 상승 / 정강이 | 실패. FIX 1 참고 |
| 13, 14, 25 정면 흉내 | shoulderWidthRatio 0.7 | 스쿼트, 푸쉬업 모두 0.700 |
| 49 측정 쪽 유지 | 프레임별 visibleSide 교체 | 통과 |
| F-02 | top 170 → elbow ≥ 160, 오른쪽 보임 클립 | 통과 |

## FIX 항목 (Impl로 회귀)
- [ ] `app/test/support/synthetic_clip.dart:173-196` — **프레임마다 다른 축척/이동으로 0~1에 맞추고 있어 프레임 사이 좌표가 이어지지 않음.** 각 프레임의 경계 상자로 `k`, `dx`, `dy`를 새로 구하므로 자세가 바뀌면 발목, 뒤꿈치 위치와 정강이 길이가 화면에서 움직인다. 실측(시작 = squat kneeDeg 170, heelLiftRatio 0):
  - kneeDeg 80, heelLiftRatio 0 → 시작 대비 뒤꿈치 상승 0.051, 정강이 길이 1.36배
  - kneeDeg 80, heelLiftRatio 0.05 → 0.119 (TASK-09 기준 0.1을 넘어 "미포함" 테스트가 깨짐)
  - kneeDeg 80, torsoLeanDeg 60, heelLiftRatio 0 → 0.685 (TASK-09 "최저점 torsoLeanDeg 60 → `[sqTorsoLean]`만" 테스트에 `sqHeelLift`가 섞임)
  
  기능 범위의 정의가 "랜드마크 29, 30이 **시작 자세 대비** 위로 이동한 거리 / 정강이 길이"이고, TASK-09가 이를 "repFrames 첫 프레임 대비 y 감소량 / 시작 프레임 정강이 길이"로 받아 쓰므로 생성기 쪽 결함이다. 고칠 방향: 운동별로 **고정된 축척과 고정 기준점**(스쿼트는 발목, 푸쉬업은 발목 또는 손목 등)을 쓰고 프레임별 경계 상자 정규화를 없앤다. 축척은 계약에 나오는 값 범위(kneeDeg 60~180, torsoLeanDeg 0~60, heelLiftRatio 0~0.3, bodyTiltDeg 0~90, bodyLineDeg 120~180, shoulderWidthRatio 0~0.8 정도)에서 0~1을 벗어나지 않게 정한다. 각도는 균일 축척이므로 그대로 유지된다.
- [ ] `app/test/support/synthetic_clip_test.dart:101-113` — 위 수정을 지키는 테스트 추가: (1) squat kneeDeg 170 프레임 대비 kneeDeg 80 / torsoLeanDeg 60 프레임(heelLiftRatio 0)의 뒤꿈치 y 차이 / 시작 정강이 ≈ 0 ± 0.02, (2) kneeDeg 80 + heelLiftRatio 0.2 → 시작 대비 0.2 ± 0.02, 0.05 → 0.05 ± 0.02, (3) 위 값 범위 끝 조합에서 모든 점 0~1 안.
- [ ] `app/test/support/synthetic_clip.dart:97-158, 164-217` — 위 수정과 함께 50줄 넘는 두 함수를 나누고, 유지보수 표의 경미 항목(`0` → `LandmarkIndex.nose`, 17/19/21 주석, 204줄 별칭, 머리 길이 상수)을 정리.

## Impl 판단 3가지와 지적 평가
1. **무릎 위치**: 푸쉬업은 무릎을 골반-발목 중점에 둬 kneeDeg를 반영하지 않고(항상 180), 스쿼트는 정강이를 수직으로 고정. 계약과 소비 Task 테스트(무릎 굽힘 푸쉬업 없음)에 비춰 타당. 단 "kneeDeg는 스쿼트에서만, bodyLineDeg/hipOffset/bodyTiltDeg는 푸쉬업에서만, torsoLeanDeg/heelLiftRatio는 스쿼트에서만 반영"이 Task 계약 표에는 없으므로 Task 보충 권고(아래).
2. **0~1 안으로 축소**: 한 프레임 안의 각도 보존은 정확(균일 축척). 그러나 프레임마다 축척이 달라 시작 자세 대비 측정이 깨짐 → FIX 1.
3. **반대쪽 점 이동**: 계약 문구("보이는 쪽 점을 x로 shoulderWidthRatio × 몸통 길이만큼 옮긴 위치") 그대로이고, 정면 흉내 0.7이 푸쉬업/스쿼트 모두 정확. 타당.
4. **"bodyTiltDeg 90에서 HipOffset 방향 모호"**: 맞는 지적이나 생성기 결함은 아님. tilt < 90이면 below는 항상 y가 큰 쪽이고(차이 = 오프셋/cos tilt), 90에서는 어깨-발목 선이 수직이라 "선 아래"라는 정의 자체가 없다. 현재 tilt 90을 쓰는 TASK-14, 49는 bodyLineDeg 180(오프셋 0)이라 영향 없음. 판정 쪽 계약 문제이므로 Task 보충으로 분리.

## Task 보충 권고 (FIX 아님, 오케스트레이터/task-agent 몫)
- **TASK-06 계약 표**: 각 자세 값이 어느 운동에서만 반영되는지 명시. "프레임 간 같은 운동이면 축척과 기준점이 고정됨(시작 자세 대비 측정 가능)"을 `buildSyntheticFrame` 계약에 추가.
- **TASK-09, 15**: `hipOffset`은 `bodyTiltDeg < 90`에서만 의미가 있다고 명시(테스트는 tilt 0 사용 권장). 처짐/들림 판정을 "골반 x에서의 선 y 보간"으로 하면 선이 수직일 때 0으로 나누게 되므로, 어깨→발목 벡터와 어깨→골반 벡터의 외적 부호(바닥 쪽 법선 기준)로 판정하도록 권고.
- **참고(현재 소비 Task 영향 없음)**: 푸쉬업에서 손목이 바닥에 고정되지 않고(top→bottom에 손목 y 0.635 → 0.544), visibleSide를 바꿔도 몸이 향하는 방향은 그대로다. 손목 위치나 진행 방향을 쓰는 Task가 생기면 생성기 계약 보충 필요.

## PEER_REVIEW 사유
- 해당 없음
