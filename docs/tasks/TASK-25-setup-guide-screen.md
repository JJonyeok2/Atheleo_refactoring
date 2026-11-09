# TASK-25: 촬영 가이드 화면(카메라 권한 포함)

- 상태: 대기
- 선행 Task: TASK-14, TASK-19, TASK-21
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정, 권한 처리
- Spec 출처: F-01, F-07 (4장 정상 흐름 2~3번, 예외 흐름 카메라 권한 거부, 5장 `/workout/:type/setup`, 9장 인수 조건 F-07)

## 왜 이렇게 나눴나
촬영 가이드 상태 머신(TASK-14)을 실제 화면, 카메라, 권한과 붙인다. 운동 화면과 분리해 F-07 인수 조건을 위젯 테스트로 확인한다.

## 기능 범위 (Spec 발췌)
- 카메라 권한 확인 → 촬영 가이드 화면("휴대폰을 옆에 세우고 측면으로 서 주세요", 전신이 보이는 실루엣 표시)
- 전신이 2초 이상 안정적으로 잡히면 3초 카운트다운 후 시작
- 카메라 권한 거부: 권한이 필요한 이유와 설정 열기 버튼 표시, 운동 시작 불가
- 여러 사람이 잡히면 가장 크게 중앙에 잡힌 1명만 사용
- 인수 조건(F-07): 촬영 가이드에서 정면으로 서면 "옆으로 서 주세요"가 표시되고, 측면으로 2초 서면 카운트다운이 시작된다.
- 이 Task에서 정하는 것:
  - 권한 거부 문구: '자세를 분석하려면 카메라가 필요해요. 영상은 저장하거나 전송하지 않아요.' + 버튼 '설정 열기'
  - ready가 되면 `context.go(AppRoutes.workoutPath(type))`
  - 화면을 나갈 때 `detector.stop()`
  - `:type`이 `push_up`, `squat`이 아니면 '페이지를 찾을 수 없어요'

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `AppRoutes` | `app/lib/app/routes.dart` | `workoutSetup = '/workout/:type/setup'`, `static String workoutPath(String type)` |
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `static ExerciseType fromCode(String code)`(모르는 값은 `ArgumentError`) |
| `SetupGuideController`, `SetupGuideState`, `SetupGuideStatus` | `app/lib/features/workout/domain/setup_guide_controller.dart` | `class SetupGuideController { SetupGuideController({Duration stableFor = const Duration(seconds: 2), int countdownSec = 3}); SetupGuideState update(PoseFrame? frame, int timestampMs); SetupGuideState get state; void reset(); }`, `class SetupGuideState { const SetupGuideState({required SetupGuideStatus status, required String message, int? countdown}); }` |
| `selectPrimaryPose` | `app/lib/pose/body/body_check.dart` | `PoseFrame? selectPrimaryPose(List<PoseFrame> poses)` (빈 목록이면 null) |
| `PoseDetector`, `PoseDetectionResult`, `poseDetectorProvider` | `app/lib/pose/detector/pose_detector.dart` | `abstract class PoseDetector { Stream<PoseDetectionResult> get results; Future<int> start({PoseModel model = PoseModel.full}); Future<void> stop(); Future<void> setModel(PoseModel model); }` |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | `class FakePoseDetector implements PoseDetector { void emit(PoseDetectionResult result); void emitError(Object error); List<String> get calls; PoseModel? get currentModel; }` |
| `buildSyntheticFrame`, `SyntheticPose` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `CameraPermission` | `app/lib/core/permission/camera_permission.dart` | `abstract class CameraPermission { Future<bool> ensureGranted(); Future<void> openSettings(); }`, `final cameraPermissionProvider = Provider<CameraPermission>(...)` (permission_handler 구현) | TASK-28, 45 |
| `CameraPreviewView` | `app/lib/features/workout/widgets/camera_preview_view.dart` | `class CameraPreviewView extends StatelessWidget { const CameraPreviewView({super.key, required int? textureId, Widget? overlay}); }` (textureId null이면 검은 화면, 세로 비율 유지) | TASK-28, 45 |
| `SetupGuideScreen` | `app/lib/features/workout/presentation/setup_guide_screen.dart` | `class SetupGuideScreen extends ConsumerStatefulWidget { const SetupGuideScreen({super.key, required ExerciseType exercise}); }` | (라우터) |

## 범위
- 위 화면, 권한 래퍼, 미리보기 위젯, 라우터의 setup 경로 builder 교체
- 실루엣은 간단한 사람 모양 외곽선(CustomPaint 또는 아이콘)

## 범위 밖 (건드리지 않음)
- 운동 화면(TASK-28), 음성 안내(이 화면에서는 글자만)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 정면이면 안내 (F-07) | 가짜 권한 허용, FakePoseDetector로 정면 프레임(shoulderWidthRatio 0.7) emit | '옆으로 서 주세요' 표시 |
| 측면 2초 후 카운트다운 (F-07) | 측면 프레임을 t 0~2100ms 동안 emit | '3' 카운트다운 표시 |
| 카운트다운 끝나면 운동 화면 | 이어서 3초 더 emit | 현재 경로 `/workout/squat` |
| 권한 거부 | 가짜 권한 false | 이유 문구와 '설정 열기' 버튼, 감지기 start 호출 없음 |
| 설정 열기 | 버튼 탭 | `openSettings` 1회 |
| 잘못된 type | `/workout/lunge/setup` | '페이지를 찾을 수 없어요' |
| 나가면 정지 | 화면 dispose | FakePoseDetector.calls에 'stop' |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/permission/camera_permission.dart`
- `app/lib/features/workout/widgets/camera_preview_view.dart`
- `app/lib/features/workout/presentation/setup_guide_screen.dart`
- `app/lib/app/router.dart`
- `app/test/features/workout/presentation/setup_guide_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-07 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
