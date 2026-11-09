# TASK-05: 관절 각도 계산과 좌우 자동 선택

- 상태: 대기
- 선행 Task: TASK-04
- 실행 방식: 순차
- 실행 방식 근거: 횟수, 오류, 촬영 가이드가 모두 기대는 기반 로직
- Spec 출처: F-02 (3장, 9장 인수 조건)

## 왜 이렇게 나눴나
측면 촬영에서는 한쪽 팔다리가 가려진다. 각도 계산과 "보이는 쪽 고르기"를 하나의 순수 함수 묶음으로 만들어 이후 모든 판정이 같은 기준을 쓰게 한다.

## 기능 범위 (Spec 발췌)
- 요구사항: 랜드마크에서 팔꿈치, 무릎, 골반 각도 계산. 신뢰도 높은 쪽(좌/우) 자동 선택
- 인수 조건(F-02): 녹화 클립에서 팔을 편 프레임을 넣으면 팔꿈치 각도가 160도 이상으로 계산되고, 반대쪽이 가려진 클립에서도 보이는 쪽 각도가 선택된다.
- 각도 정의(이 Task에서 확정):
  - 팔꿈치 = 어깨-팔꿈치-손목, 무릎 = 골반-무릎-발목, 골반 = 어깨-골반-무릎
  - 2D(x, y)로 계산. 정규화 좌표의 가로세로 비율 왜곡을 막기 위해 x에 `aspectRatio`(이미지 너비/높이)를 곱한다
  - 한쪽 신뢰도 = 그쪽 어깨, 팔꿈치, 손목, 골반, 무릎, 발목 visibility 평균

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `PoseLandmark` | `app/lib/pose/landmarks/pose_landmark.dart` | `class PoseLandmark { const PoseLandmark({required double x, required double y, required double z, required double visibility}); }` (x, y는 0~1 정규화 이미지 좌표, y는 아래로 증가) |
| `PoseFrame` | 같은 파일 | `class PoseFrame { PoseFrame({required int timestampMs, required List<PoseLandmark> landmarks, double aspectRatio = 1.0}); PoseLandmark operator [](int index); }` (landmarks 길이가 33이 아니면 `ArgumentError`, aspectRatio는 이미지 너비/높이) |
| `BodySide` | 같은 파일 | `enum BodySide { left, right }` |
| `LandmarkIndex` | 같은 파일 | `abstract final class LandmarkIndex` 상수: nose 0, leftShoulder 11, rightShoulder 12, leftElbow 13, rightElbow 14, leftWrist 15, rightWrist 16, leftHip 23, rightHip 24, leftKnee 25, rightKnee 26, leftAnkle 27, rightAnkle 28, leftHeel 29, rightHeel 30, leftFootIndex 31, rightFootIndex 32, count 33 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `angleDeg` | `app/lib/pose/angle/joint_angle.dart` | `double angleDeg(PoseLandmark a, PoseLandmark vertex, PoseLandmark c, {double aspectRatio = 1.0})` (x에 aspectRatio를 곱한 2D 각도, 0~180, 길이 0이면 0) | TASK-06, 09, 13 |
| `SideAngles` | 같은 파일 | `class SideAngles { const SideAngles({required BodySide side, required double elbow, required double knee, required double hip, required double visibility}); }` (elbow=어깨-팔꿈치-손목, knee=골반-무릎-발목, hip=어깨-골반-무릎, visibility=그쪽 6개 점 평균) | TASK-06, 09, 13, 15 |
| (참고) | | 정면 판정, 상체 기울기처럼 이 3개 각도 밖의 기하는 각 사용 Task가 `angleDeg`로 직접 계산 | |
| `anglesForSide` | 같은 파일 | `SideAngles anglesForSide(PoseFrame frame, BodySide side)` | TASK-06 |
| `selectSide` | 같은 파일 | `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})` (평균 visibility 높은 쪽, 같으면 left, 둘 다 기준 미만이면 null) | TASK-09, 13, 15 |

## 범위
- 위 함수 구현. 테스트에서는 33개 점 목록을 만드는 작은 테스트 내부 헬퍼로 필요한 점만 배치한다

## 범위 밖 (건드리지 않음)
- 이동 평균(TASK-07), 몸통 일직선/상체 기울기 같은 오류용 각도(TASK-09)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 직각 | a(0,0), vertex(0,1), c(1,1) | 90 ± 0.01 |
| 일직선 | 세 점이 한 줄 | 180 ± 0.01 |
| 길이 0 | a와 vertex가 같은 점 | 0 |
| aspectRatio 반영 | 정규화 좌표 직각이 aspect 2.0에서 | 90이 아닌 값(왜곡 보정 확인) |
| 팔을 편 프레임 (F-02) | 왼팔 어깨-팔꿈치-손목 일직선, visibility 0.9 | `selectSide(...)!.elbow >= 160` |
| 가려진 쪽 무시 (F-02) | 왼쪽 visibility 0.1, 오른쪽 0.9 | `side == BodySide.right` |
| 둘 다 가려짐 | 양쪽 visibility 0.2 | null |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/angle/joint_angle.dart`
- `app/test/pose/angle/joint_angle_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-02 인수 조건 충족(클립 단위 확인은 TASK-06에서 한 번 더)
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때
- 기능 범위와 연결 범위만으로 판단할 수 없는 정보가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)
