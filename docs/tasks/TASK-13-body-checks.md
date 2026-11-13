# TASK-13: 전신 인식, 정면 판정, 주 인물 선택, 자세 게이트

- 상태: 대기
- 선행 Task: TASK-05, TASK-06
- 실행 방식: 병렬 (그룹: G3)
- 실행 방식 근거: `app/lib/pose/body/`만 새로 만드는 순수 함수, TASK-12, 26과 파일이 겹치지 않음
- Spec 출처: F-07(촬영 가이드), F-03(자세 게이트), 4장 예외 흐름(여러 사람, 정면, 운동 자세가 아닐 때), 7장 자세 게이트

## 왜 이렇게 나눴나
촬영 가이드, 프레임 분석기, 운동 화면이 공통으로 쓰는 "이 프레임이 쓸 만한가" 판단을 순수 함수로 모은다. 자세 게이트도 촬영 가이드(TASK-14)와 분석기(TASK-49)가 함께 쓰므로 여기에 둔다.

## 기능 범위 (Spec 발췌)
- 촬영 가이드: 전신이 보이는 실루엣 표시, 전신이 잡히는지 판단
- 정면으로 섰을 때: 어깨 너비 대비 몸통 각도로 정면 판단 시 "옆으로 서 주세요" 안내
- 여러 사람이 잡힐 때: 화면 중앙에 가장 크게 잡힌 1명만 추적
- 자세 게이트(초기값, 보정 대상 Q-05):

| 운동 | 조건 |
|---|---|
| 푸쉬업 | 몸통(어깨-골반-발목을 잇는 선)이 수평에서 30도 이내 |
| 스쿼트 | 몸통(어깨와 골반을 잇는 선)이 수직에서 30도 이내 |

- 이 Task에서 정하는 기준:
  - 전신 인식: nose와, `selectSide`로 고른 쪽의 어깨, 골반, 무릎, 발목이 모두 visibility 0.5 이상이고 x, y가 0~1 안
  - 정면 판정: (좌우 어깨 x 거리 × aspectRatio) / (어깨 중점과 골반 중점 거리) 가 0.35 초과이면 정면. 0.35는 기본값(실측 보정 대상)
  - 주 인물: 점들의 경계 상자 면적 × (1 − 상자 중심과 화면 중심(0.5, 0.5) 거리) 가 가장 큰 사람
  - 게이트 측정 쪽: side를 주면 그쪽, 없으면 `selectSide`로 고른 쪽. 고를 수 없거나 그쪽 점의 visibility 평균이 0.5 미만이면 false
  - 푸쉬업 기울기 = 그쪽 어깨→발목 벡터(x × aspectRatio)와 수평선 사이 각도(0~90). 스쿼트 기울기 = 그쪽 골반→어깨 벡터(x × aspectRatio)와 수직 위쪽 사이 각도(0~180). 둘 다 maxDeg 이하이면 통과

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `PoseFrame`, `LandmarkIndex`, `BodySide` | `app/lib/pose/landmarks/pose_landmark.dart` | TASK-04 계약 그대로 |
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `angleDeg` | `app/lib/pose/angle/joint_angle.dart` | `double angleDeg(PoseLandmark a, PoseLandmark vertex, PoseLandmark c, {double aspectRatio = 1.0})` (x에 aspectRatio를 곱한 2D 각도, 0~180, 길이 0이면 0) |
| `selectSide`, `anglesForSide` | 같은 파일 | `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})` (평균 visibility 높은 쪽, 같으면 left, 둘 다 기준 미만이면 null. 고른 쪽의 세 점 묶음(어깨-팔꿈치-손목, 골반-무릎-발목, 어깨-골반-무릎, 어깨-골반-발목) 중 하나라도 벡터 길이가 0이거나 좌표가 유한하지 않으면 그쪽은 쓸 수 없는 것으로 보고, 다른 쪽이 visibility 기준과 이 조건을 만족하면 다른 쪽을, 둘 다 안 되면 null), `SideAngles anglesForSide(PoseFrame frame, BodySide side)` |
| `SyntheticPose`, `buildSyntheticFrame` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만, `shoulderWidthRatio`로 정면 흉내, `bodyTiltDeg`로 푸쉬업 기울기, `torsoLeanDeg`로 스쿼트 기울기) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `isFullBodyVisible` | `app/lib/pose/body/body_check.dart` | `bool isFullBodyVisible(PoseFrame frame, {double minVisibility = 0.5})` | TASK-14 |
| `isFrontFacing` | 같은 파일 | `bool isFrontFacing(PoseFrame frame, {double ratioThreshold = 0.35})` | TASK-14 |
| `selectPrimaryPose` | 같은 파일 | `PoseFrame? selectPrimaryPose(List<PoseFrame> poses)` (빈 목록이면 null) | TASK-25, 27, 45 |
| `passesPostureGate` | 같은 파일 | `bool passesPostureGate(PoseFrame frame, ExerciseType exercise, {BodySide? side, double maxDeg = 30})` (위 기울기 규칙) | TASK-14, 49 |

## 범위
- 위 함수

## 범위 밖 (건드리지 않음)
- 시간 흐름(2초 안정, 카운트다운)은 TASK-14, 게이트를 언제 적용할지는 TASK-14, 49

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 측면 전신 | 기본 SyntheticPose(squat), 기본 SyntheticPose(pushUp) 프레임 | 둘 다 isFullBodyVisible true, isFrontFacing false |
| 정면 판정 (F-07) | shoulderWidthRatio 0.7 | isFrontFacing true |
| 전신 아님 | 발목 y를 1.2로 바꾼 프레임 / 모든 visibility 0.2 | 둘 다 isFullBodyVisible false |
| 여러 사람 중 중앙 큰 사람 | 가장자리 큰 사람, 중앙 큰 사람, 중앙 작은 사람 / 빈 목록 | 중앙 큰 사람 / null |
| 푸쉬업 게이트 (F-03) | pushUp bodyTiltDeg 0 / 25 / 45 / 90 | true / true / false / false |
| 스쿼트 게이트 (F-07) | squat torsoLeanDeg 15 / 30 / 45 | true / true / false |
| 게이트 측정 쪽 지정 | 왼쪽만 보이는 pushUp 프레임에 side: right | false |
| 게이트 기준값 주입 | pushUp bodyTiltDeg 40, maxDeg 45 | true |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/body/body_check.dart`
- `app/test/pose/body/body_check_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] `maxDeg` 기본값 30에 "실기기 보정 대상(Spec Q-05)" 주석
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 합성 프레임으로 정면이나 기울기를 표현할 수 없을 때(TASK-06 계약 변경 필요)

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 운동별 자세 게이트 `passesPostureGate` 추가(푸쉬업 수평 30도, 스쿼트 수직 30도). 테스트: 기존 6건을 4행으로 묶고 게이트 4행 추가
