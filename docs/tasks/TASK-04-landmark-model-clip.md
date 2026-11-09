# TASK-04: 랜드마크 모델과 클립 JSON

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 순차
- 실행 방식 근거: 자세 판정 전체가 기대는 공유 타입
- Spec 출처: F-01(33개 랜드마크), 7장 LandmarkClip, 8장 테스트 가능성

## 왜 이렇게 나눴나
카메라 없이 판정 로직을 테스트하려면 "랜드마크 한 프레임"과 "녹화 클립 JSON"의 모양부터 정해야 한다. 이후 각도, 횟수, 오류, 개발자 메뉴가 모두 이 타입을 쓴다.

## 기능 범위 (Spec 발췌)
- MediaPipe Pose Landmarker로 33개 랜드마크와 3D 좌표(x, y, z, visibility) 추출
- LandmarkClip(로컬 전용): id(uuid), exercise(enum push_up, squat), label(string), fps(int), frames(33x(x,y,z,visibility) 배열). 서버로 보내지 않음
- 자세 판정 로직은 카메라 없이 녹화된 랜드마크 JSON으로 테스트할 수 있어야 한다.

## 연결 범위

### 받아 쓰는 것
없음 (`package:atheleo` 패키지만)

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }`, 필드 `final String code`('push_up', 'squat'), `final String label`('푸쉬업', '스쿼트'), `static ExerciseType fromCode(String code)`(모르는 값은 `ArgumentError`) | 거의 전체 |
| `PoseLandmark` | `app/lib/pose/landmarks/pose_landmark.dart` | `class PoseLandmark { const PoseLandmark({required double x, required double y, required double z, required double visibility}); }` (x, y는 0~1 정규화 이미지 좌표, y는 아래로 증가) | 거의 전체 |
| `PoseFrame` | 같은 파일 | `class PoseFrame { PoseFrame({required int timestampMs, required List<PoseLandmark> landmarks, double aspectRatio = 1.0}); PoseLandmark operator [](int index); }` (landmarks 길이가 33이 아니면 `ArgumentError`, aspectRatio는 이미지 너비/높이) | 거의 전체 |
| `BodySide` | 같은 파일 | `enum BodySide { left, right }` | TASK-05, 06 |
| `LandmarkIndex` | 같은 파일 | `abstract final class LandmarkIndex` 상수: nose 0, leftShoulder 11, rightShoulder 12, leftElbow 13, rightElbow 14, leftWrist 15, rightWrist 16, leftHip 23, rightHip 24, leftKnee 25, rightKnee 26, leftAnkle 27, rightAnkle 28, leftHeel 29, rightHeel 30, leftFootIndex 31, rightFootIndex 32, count 33 | TASK-05, 06, 09, 13, 22 |
| `LandmarkClip` | `app/lib/pose/landmarks/landmark_clip.dart` | `class LandmarkClip { const LandmarkClip({required String id, required ExerciseType exercise, required String label, required int fps, required List<PoseFrame> frames}); factory LandmarkClip.fromJson(Map<String, dynamic> json); Map<String, dynamic> toJson(); static LandmarkClip parse(String source); String encode(); }` (형식 오류는 `FormatException`) | TASK-06, 15, 45 |
| 클립 JSON 형식 | 같은 파일 | `{"id": str, "exercise": "push_up"\|"squat", "label": str, "fps": int, "aspect": double(생략 시 1.0), "frames": [{"t": int(ms), "lm": [[x, y, z, v] × 33]}]}` | TASK-45, 사용자 |

## 범위
- 위 타입과 JSON 직렬화/역직렬화
- 테스트 픽스처 `app/test/fixtures/clips/minimal_clip.json`(2프레임, 손으로 작성)
- `aspect`는 클립 최상위 값으로 저장하고, 읽을 때 각 `PoseFrame.aspectRatio`에 넣는다

## 범위 밖 (건드리지 않음)
- 각도 계산(TASK-05), 합성 클립 생성(TASK-06), 파일 저장(TASK-45)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 픽스처 읽기 | `LandmarkClip.parse(File('test/fixtures/clips/minimal_clip.json').readAsStringSync())` | frames 2개, 각 33개 점, exercise `pushUp` |
| 왕복 직렬화 | `parse(clip.encode())` | 원래 값과 id, label, fps, 첫 프레임 좌표가 같음 |
| 점 개수 오류 | lm 길이 32인 JSON | `FormatException` |
| 모르는 운동 | exercise `"lunge"` | `FormatException` |
| aspect 기본값 | aspect 없는 JSON | 모든 프레임 `aspectRatio == 1.0` |
| PoseFrame 검증 | landmarks 10개로 생성 | `ArgumentError` |
| ExerciseType 코드 | `ExerciseType.fromCode('squat')`, `pushUp.label` | `squat`, `'푸쉬업'` |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/landmarks/exercise_type.dart`
- `app/lib/pose/landmarks/pose_landmark.dart`
- `app/lib/pose/landmarks/landmark_clip.dart`
- `app/test/pose/landmarks/landmark_clip_test.dart`
- `app/test/fixtures/clips/minimal_clip.json`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 기능 범위와 연결 범위만으로 판단할 수 없는 정보가 필요할 때
- 새 외부 서비스나 새 환경 변수가 필요할 때

## 추가 발췌 (오케스트레이터가 보충)
