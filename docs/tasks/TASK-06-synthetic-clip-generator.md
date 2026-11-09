# TASK-06: 테스트용 합성 클립 생성기

- 상태: 대기
- 선행 Task: TASK-05
- 실행 방식: 병렬 (그룹: G1)
- 실행 방식 근거: `app/test/support/`만 만들고 공유 타입을 건드리지 않음. TASK-07과 파일이 겹치지 않음
- Spec 출처: 8장 테스트 가능성, F-02 인수 조건(클립 단위)

## 왜 이렇게 나눴나
실제 녹화 클립이 아직 없다(Spec Q-05). 각도 값만 주면 33개 랜드마크를 만들어 주는 유틸을 먼저 두면, 횟수, 오류, 점수 Task가 "녹화 클립을 넣으면" 형태의 인수 조건을 카메라 없이 테스트할 수 있다.

## 기능 범위 (Spec 발췌)
- 자세 판정 로직(F-02~F-05, F-08)은 카메라 없이 녹화된 랜드마크 JSON으로 테스트할 수 있어야 한다.
- 인수 조건(F-02): 녹화 클립에서 팔을 편 프레임을 넣으면 팔꿈치 각도가 160도 이상으로 계산되고, 반대쪽이 가려진 클립에서도 보이는 쪽 각도가 선택된다.
- 생성기가 표현해야 하는 자세 값(오류 판정 Task에서 씀):
  - 푸쉬업 몸통 일직선 각도(어깨-골반-발목), 160도 미만이면 허리 처짐
  - 스쿼트 상체 기울기(어깨-골반 선과 수직선 사이 각도)
  - 스쿼트 무릎 전진 비율(발끝보다 앞으로 나간 거리 / 정강이 길이)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }`, 필드 `final String code`('push_up', 'squat'), `final String label`('푸쉬업', '스쿼트'), `static ExerciseType fromCode(String code)`(모르는 값은 `ArgumentError`) |
| `PoseFrame`, `PoseLandmark`, `BodySide`, `LandmarkIndex` | `app/lib/pose/landmarks/pose_landmark.dart` | TASK-04 계약 그대로 |
| `LandmarkClip` | `app/lib/pose/landmarks/landmark_clip.dart` | `class LandmarkClip { const LandmarkClip({required String id, required ExerciseType exercise, required String label, required int fps, required List<PoseFrame> frames}); ... }` |
| `angleDeg`, `anglesForSide`, `selectSide` | `app/lib/pose/angle/joint_angle.dart` | `double angleDeg(PoseLandmark a, PoseLandmark vertex, PoseLandmark c, {double aspectRatio = 1.0})`, `SideAngles anglesForSide(PoseFrame frame, BodySide side)`, `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})` (검증용) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `SyntheticPose` | `app/test/support/synthetic_clip.dart` | `class SyntheticPose { const SyntheticPose({required ExerciseType exercise, double elbowDeg = 170, double kneeDeg = 170, double bodyLineDeg = 180, double torsoLeanDeg = 15, double kneeForwardRatio = 0, double shoulderWidthRatio = 0.05, BodySide visibleSide = BodySide.left, double hiddenVisibility = 0.1}); }` (shoulderWidthRatio = 좌우 어깨 x 거리 / 몸통 길이. 측면은 0.05, 정면 흉내는 0.6 이상) | TASK-09, 13, 14 |
| `buildSyntheticFrame` | 같은 파일 | `PoseFrame buildSyntheticFrame(SyntheticPose pose, {int timestampMs = 0})` (보이는 쪽 visibility 0.95, 반대쪽은 hiddenVisibility, aspectRatio 1.0, 측면 자세. 반대쪽 점은 보이는 쪽 점을 x로 shoulderWidthRatio × 몸통 길이만큼 옮긴 위치) | TASK-09, 13, 14 |
| `repAngleSequence` | 같은 파일 | `List<double> repAngleSequence({required int reps, double top = 170, double bottom = 80, int framesPerRep = 30, int padFrames = 10})` (앞뒤 padFrames만큼 top 유지, 반복마다 top→bottom→top 코사인 곡선) | TASK-08, 15 |
| `buildSyntheticClip` | 같은 파일 | `LandmarkClip buildSyntheticClip({required ExerciseType exercise, required List<double> primaryAngles, int fps = 30, String label = 'synthetic', SyntheticPose Function(double angle)? poseFor})` (primaryAngles는 푸쉬업이면 팔꿈치, 스쿼트면 무릎. poseFor가 없으면 기본 SyntheticPose에 그 각도만 넣음. timestamp는 `i * 1000 ~/ fps`) | TASK-15, 17 |

## 범위
- 위 유틸 구현(측면 자세의 2D 골격을 각도로부터 순방향으로 배치, z는 0)
- 생성한 클립이 `LandmarkClip.encode()`로 JSON 저장 가능해야 함(나중에 실제 클립과 같은 형식)

## 범위 밖 (건드리지 않음)
- `app/lib/` 아래 모든 파일
- 실제 녹화 클립 픽스처(F-14 이후 사용자가 추가)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 팔꿈치 각도 재현 | `SyntheticPose(exercise: pushUp, elbowDeg: 90)` → `selectSide` | elbow 90 ± 1 |
| 무릎 각도 재현 | squat, kneeDeg 75 | knee 75 ± 1 |
| 팔을 편 클립 (F-02) | 푸쉬업 클립 첫 프레임(top 170) | `selectSide(...)!.elbow >= 160` |
| 반대쪽 가려진 클립 (F-02) | visibleSide right, hiddenVisibility 0.05 | 모든 프레임에서 `selectSide(...)!.side == BodySide.right` |
| 몸통 일직선 재현 | pushUp, bodyLineDeg 140 | 어깨-골반-발목 각도 140 ± 1 (`angleDeg` 직접 계산) |
| 정면 흉내 | shoulderWidthRatio 0.7 | 좌우 어깨 x 거리 / (어깨-골반 거리) 0.7 ± 0.02 |
| 반복 시퀀스 길이 | `repAngleSequence(reps: 10, framesPerRep: 30, padFrames: 10)` | 길이 320, 최솟값 80 ± 0.5가 10번 나타남 |
| JSON 왕복 | `LandmarkClip.parse(clip.encode())` | 프레임 수와 첫 점 좌표가 같음 |

## 바뀔 것으로 예상되는 파일
- `app/test/support/synthetic_clip.dart`
- `app/test/support/synthetic_clip_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-02 인수 조건을 클립 단위로 확인
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때(특히 `anglesForSide` 계약 변경이 필요할 때)
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
