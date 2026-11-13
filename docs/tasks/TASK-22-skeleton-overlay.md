# TASK-22: 스켈레톤 오버레이 위젯

- 상태: 대기
- 선행 Task: TASK-04
- 실행 방식: 병렬 (그룹: G4)
- 실행 방식 근거: `app/lib/features/workout/widgets/skeleton_overlay.dart`만 새로 만듦. TASK-16, 17과 파일이 겹치지 않음
- Spec 출처: F-01, F-07 (9장 인수 조건 F-01)

## 왜 이렇게 나눴나
랜드마크를 화면 좌표로 바꾸는 계산(순수 함수)과 그리기(CustomPainter)를 함께 두되, 테스트는 계산 함수로 한다.

## 기능 범위 (Spec 발췌)
- 스켈레톤 오버레이
- 미리보기는 실제 프레임 비율 유지, 전면 카메라 좌우 반전과 회전이 스켈레톤과 일치
- 인수 조건(F-01): 운동 화면에서 전신이 보이게 서면, 1초 안에 33개 점의 스켈레톤이 몸에 맞게 그려진다.
- 인수 조건(F-07, 이 Task 부분): 전면 카메라에서 오른팔을 들면 화면과 스켈레톤이 같은 쪽 팔을 같은 위치에 그린다.
- 이 Task에서 정하는 것:
  - 점 위치 = (x × 너비, y × 높이). 좌표는 Kotlin이 이미 회전, 전면 좌우 반전까지 적용해 미리보기와 같은 방향으로 온다. 여기서 다시 뒤집거나 돌리지 않는다
  - 부모 크기는 미리보기와 같은 비율 상자라고 가정한다(`CameraPreviewView`의 overlay 자리, TASK-25). 이 위젯은 비율을 맞추지 않는다
  - visibility 0.5 미만인 점과, 그 점이 끝에 있는 선은 그리지 않는다
  - 선 목록은 MediaPipe 공식 POSE_CONNECTIONS(35개)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `PoseFrame`, `PoseLandmark`, `LandmarkIndex` | `app/lib/pose/landmarks/pose_landmark.dart` | TASK-04 계약 그대로 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `kPoseConnections` | `app/lib/features/workout/widgets/skeleton_overlay.dart` | `const List<(int, int)> kPoseConnections` | (내부) |
| `projectLandmarks` | 같은 파일 | `List<Offset?> projectLandmarks(PoseFrame frame, Size size, {double minVisibility = 0.5})` (길이 33, 안 보이는 점은 null) | (내부) |
| `SkeletonOverlay` | 같은 파일 | `class SkeletonOverlay extends StatelessWidget { const SkeletonOverlay({super.key, required PoseFrame? frame, Color color = Colors.white}); }` (frame이 null이면 아무것도 안 그림, 부모 크기를 꽉 채움) | TASK-29, 46 |

## 범위
- 위 함수와 위젯

## 범위 밖 (건드리지 않음)
- 카메라 미리보기, 점수 색(TASK-23)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 33개 점 투영 (F-01) | 모든 점 visibility 0.9, Size(400, 800) | 길이 33, null 없음, 점 (0.5, 0.25) → Offset(200, 200) |
| 안 보이는 점 제외 | 왼쪽 손목 visibility 0.1 | 인덱스 15가 null |
| 반전하지 않음 (F-07) | 오른쪽 손목(16) x 0.2, Size(400, 800) | Offset.dx 80(1 − x로 뒤집지 않음) |
| 연결선 개수 | `kPoseConnections.length` | 35 |
| 위젯 렌더 | `SkeletonOverlay(frame: ...)`을 pumpWidget | `CustomPaint` 하나, 예외 없음 |
| null 프레임 | `SkeletonOverlay(frame: null)` | 예외 없음 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/widgets/skeleton_overlay.dart`
- `app/test/features/workout/widgets/skeleton_overlay_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 회전, 전면 반전은 Kotlin 책임이고 이 위젯은 뒤집지 않음, 부모가 미리보기 비율 상자임을 명시. "반전하지 않음" 테스트 추가. 계약은 그대로
