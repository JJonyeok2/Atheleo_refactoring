# TASK-46: 개발자 메뉴 화면(디버그 빌드 전용)

- 상태: 대기
- 선행 Task: TASK-25, TASK-45
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정
- Spec 출처: F-14 (5장 `/dev`, 9장 인수 조건)

## 왜 이렇게 나눴나
기록, 내보내기 로직(TASK-45)을 화면에 붙인다. 릴리스 빌드에 메뉴가 없는 것은 라우터(TASK-03)가 이미 보장하므로 여기서는 홈 진입 버튼도 디버그에서만 보이게 한다.

## 기능 범위 (Spec 발췌)
- 개발자 메뉴 `/dev`(디버그 빌드만): 랜드마크 기록 시작/중지, 라벨, 내보내기, fps 표시
- 인수 조건(F-14): 디버그 빌드 개발자 메뉴에서 기록 후 내보내면 33개 랜드마크 시퀀스 JSON 파일이 생기고, 릴리스 빌드에는 메뉴가 없다.
- 이 Task에서 정하는 표시:
  - 운동 선택(푸쉬업, 스쿼트), 라벨 입력(기본 'normal'), 카메라 미리보기 + 스켈레톤
  - '기록 시작' / '기록 중지' 토글, 기록 중 프레임 수와 현재 fps
  - 중지하면 바로 내보내고 '저장됨: <파일 경로>' 표시
  - 카메라 권한이 없으면 촬영 가이드와 같은 안내 문구
  - 화면을 나가면 감지기 stop

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ClipRecorder` | `app/lib/features/dev/domain/clip_recorder.dart` | `class ClipRecorder { void start(); void addResult(PoseDetectionResult result); LandmarkClip stop({required ExerciseType exercise, required String label, required String id}); bool get isRecording; int get frameCount; double get currentFps; }` |
| `clipExporterProvider`, `ClipExporter` | `app/lib/features/dev/data/clip_exporter.dart` | `Future<File> export(LandmarkClip clip);` |
| `poseDetectorProvider`, `PoseDetector` | `app/lib/pose/detector/pose_detector.dart` | TASK-19 계약 그대로 |
| `cameraPermissionProvider`, `CameraPreviewView` | `app/lib/core/permission/camera_permission.dart`, `app/lib/features/workout/widgets/camera_preview_view.dart` | `abstract class CameraPermission { Future<bool> ensureGranted(); Future<void> openSettings(); }`, `class CameraPreviewView extends StatelessWidget { const CameraPreviewView({super.key, required int? textureId, Widget? overlay}); }` |
| `SkeletonOverlay` | `app/lib/features/workout/widgets/skeleton_overlay.dart` | `class SkeletonOverlay extends StatelessWidget { const SkeletonOverlay({super.key, required PoseFrame? frame, Color color = Colors.white}); }` |
| `buildRouter` | `app/lib/app/router.dart` | enableDevMenu가 false면 `/dev` 경로 자체를 등록하지 않음 |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | 테스트에서만 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `DevMenuScreen` | `app/lib/features/dev/presentation/dev_menu_screen.dart` | `class DevMenuScreen extends ConsumerStatefulWidget { const DevMenuScreen({super.key}); }` | (라우터) |

## 범위
- 화면, 라우터 dev 경로 builder 교체

## 범위 밖 (건드리지 않음)
- 홈의 진입 버튼(TASK-47)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 기록 후 파일 생성 (F-14) | 권한 허용, '기록 시작', 가짜 결과 30개 emit, '기록 중지'(가짜 exporter가 임시 파일 기록) | '저장됨:' 문구, 가짜 exporter가 받은 클립 frames 30, 각 33개 점 |
| 기록 중 표시 | 기록 중 결과 10개 | '10 프레임' 표시 |
| 라벨 반영 | 라벨 'hip_sag' 입력 후 기록 | 클립 label 'hip_sag' |
| 릴리스에는 메뉴 없음 (F-14) | `buildRouter(enableDevMenu: false)`에서 `/dev` | '페이지를 찾을 수 없어요' |
| 나가면 정지 | dispose | calls에 'stop' |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/dev/presentation/dev_menu_screen.dart`
- `app/lib/app/router.dart`
- `app/test/features/dev/dev_menu_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-14 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
