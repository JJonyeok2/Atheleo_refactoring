# TASK-25: 촬영 가이드 화면(카메라 권한, 미리보기 비율 포함)

- 상태: 대기
- 선행 Task: TASK-03, TASK-06, TASK-13, TASK-14, TASK-19, TASK-21
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정, 권한 처리
- Spec 출처: F-01, F-07 (4장 정상 흐름 2~3번, 예외 흐름 카메라 권한 거부, 5장 `/workout/:type/setup`, 9장 인수 조건 F-01, F-07)

## 왜 이렇게 나눴나
촬영 가이드 상태 머신(TASK-14)을 실제 화면, 카메라, 권한과 붙인다. 운동 화면과 분리해 F-07 인수 조건을 위젯 테스트로 확인한다. 음성 안내는 TASK-51에서 같은 화면에 더한다.

## 기능 범위 (Spec 발췌)
- 카메라 권한 확인 → 촬영 가이드 화면(운동별 안내 문구, 거리 안내, 전신이 보이는 실루엣 표시)
  - 푸쉬업: "휴대폰을 옆에 세우고 측면에서 약 2m 이상 떨어져 주세요. 전신이 화면에 들어와야 해요." 준비 자세 안내 "엎드려 팔을 편 자세를 잡아 주세요"
  - 스쿼트: "휴대폰을 옆에 세우고 측면에서 약 2m 떨어져 주세요. 전신이 화면에 들어와야 해요." 준비 자세 안내 "똑바로 서서 무릎을 펴 주세요"
- 운동별 준비 조건이 2초 이상 안정적으로 유지되면 3·2·1 카운트다운 후 운동 화면으로 넘어간다. 이때 카메라와 감지 세션은 끊기지 않는다.
- 미리보기는 실제 프레임 비율 유지(늘어나거나 찌그러지지 않음)
- 카메라 권한 거부: 권한이 필요한 이유와 설정 열기 버튼 표시, 운동 시작 불가
- 여러 사람이 잡히면 가장 크게 중앙에 잡힌 1명만 사용
- 인수 조건:
  - F-07: 푸쉬업 촬영 가이드에는 "측면에서 약 2m 이상, 전신이 화면에 들어와야 해요"와 "엎드려 팔을 편 자세를 잡아 주세요"가, 스쿼트 촬영 가이드에는 "측면에서 약 2m 떨어져 주세요. 전신이 화면에 들어와야 해요"와 "옆으로 서 주세요"가 보인다. 정면으로 서면 "옆으로 서 주세요"가 표시되고, 운동별 준비 조건을 2초 유지하면 카운트다운이 시작된다. 미리보기는 늘어나거나 찌그러지지 않는다.
  - F-01: 촬영 가이드에서 운동 화면으로 넘어갈 때 미리보기가 검게 끊기지 않고 카메라가 다시 열리지 않는다.
- 이 Task에서 정하는 것:
  - 화면에 항상 `distanceHint`, `postureHint` 두 줄을 보이고, 그 아래 현재 상태 `message`(카운트다운이면 큰 숫자)
  - 권한 거부 문구: '자세를 분석하려면 카메라가 필요해요. 영상은 저장하거나 전송하지 않아요.' + 버튼 '설정 열기'
  - ready가 되면 감지기를 멈추지 않은 채 `context.go(AppRoutes.workoutPath(type))`
  - 운동 화면으로 넘기지 않고 화면을 나갈 때(뒤로 가기 등)만 `detector.stop()`
  - 미리보기: `AspectRatio(camera.aspectRatio)`를 가운데 두고 남는 곳은 검은 여백. overlay는 같은 비율 상자 안에 겹침
  - `:type`이 `push_up`, `squat`이 아니면 '페이지를 찾을 수 없어요'

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `AppRoutes` | `app/lib/app/routes.dart` | `workoutSetup = '/workout/:type/setup'`, `static String workoutPath(String type)` |
| `buildRouter` | `app/lib/app/router.dart` | `GoRouter buildRouter({required bool enableDevMenu, Listenable? refreshListenable, GoRouterRedirect? redirect})` (errorBuilder가 '페이지를 찾을 수 없어요') |
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `static ExerciseType fromCode(String code)`(모르는 값은 `ArgumentError`) |
| `SetupGuideController`, `SetupGuideState`, `SetupGuideStatus`, `setupGuideTextsFor` | `app/lib/features/workout/domain/setup_guide_controller.dart` | `class SetupGuideController { SetupGuideController({required ExerciseType exercise, Duration stableFor = const Duration(seconds: 2), int countdownSec = 3}); SetupGuideState update(PoseFrame? frame, int timestampMs); SetupGuideState get state; void reset(); }`, `class SetupGuideState { const SetupGuideState({required SetupGuideStatus status, required String message, int? countdown}); }`, `SetupGuideTexts setupGuideTextsFor(ExerciseType exercise)` (`distanceHint`, `postureHint`) |
| `selectPrimaryPose` | `app/lib/pose/body/body_check.dart` | `PoseFrame? selectPrimaryPose(List<PoseFrame> poses)` (빈 목록이면 null) |
| `PoseDetector`, `PoseCameraInfo`, `PoseDetectionResult`, `poseDetectorProvider` | `app/lib/pose/detector/pose_detector.dart` | `abstract class PoseDetector { Stream<PoseDetectionResult> get results; Future<PoseCameraInfo> start({PoseModel model = PoseModel.full}); Future<void> stop(); Future<void> setModel(PoseModel model); bool get isRunning; }`, `class PoseCameraInfo { const PoseCameraInfo({required int textureId, required int width, required int height}); double get aspectRatio; }` |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | `class FakePoseDetector implements PoseDetector { FakePoseDetector({PoseCameraInfo camera = const PoseCameraInfo(textureId: 1, width: 720, height: 1280)}); void emit(PoseDetectionResult result); void emitError(Object error); List<String> get calls; PoseModel? get currentModel; }` |
| `buildSyntheticFrame`, `SyntheticPose` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `CameraPermission` | `app/lib/core/permission/camera_permission.dart` | `abstract class CameraPermission { Future<bool> ensureGranted(); Future<void> openSettings(); }` | TASK-46 |
| `cameraPermissionProvider` | 같은 파일 | `final cameraPermissionProvider = Provider<CameraPermission>(...)` (permission_handler 구현) | TASK-46 |
| `CameraPreviewView` | `app/lib/features/workout/widgets/camera_preview_view.dart` | `class CameraPreviewView extends StatelessWidget { const CameraPreviewView({super.key, required PoseCameraInfo? camera, Widget? overlay}); }` (camera null이면 검은 화면. 아니면 `AspectRatio(camera.aspectRatio)` 상자에 `Texture(textureId)`와 overlay를 겹치고 가운데 정렬, 늘리지 않음. 회전, 반전하지 않음) | TASK-29, 46 |
| `SetupGuideScreen` | `app/lib/features/workout/presentation/setup_guide_screen.dart` | `class SetupGuideScreen extends ConsumerStatefulWidget { const SetupGuideScreen({super.key, required ExerciseType exercise}); }` | TASK-51, (라우터) |

## 범위
- 위 화면, 권한 래퍼, 미리보기 위젯, 라우터의 setup 경로 builder 교체
- 실루엣은 간단한 사람 모양 외곽선(CustomPaint 또는 아이콘)

## 범위 밖 (건드리지 않음)
- 음성 안내와 글자 안내 띠(TASK-51), 운동 화면(TASK-29), 화면 꺼짐 방지(Kotlin, TASK-20)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 운동별 문구 (F-07) | 가짜 권한 허용, `/workout/push_up/setup` / `/workout/squat/setup` | 푸쉬업 거리 안내와 '엎드려 팔을 편 자세를 잡아 주세요' / 스쿼트 거리 안내와 '옆으로 서 주세요' |
| 정면이면 안내 (F-07) | FakePoseDetector로 정면 프레임(shoulderWidthRatio 0.7) emit | '옆으로 서 주세요' 상태 문구 |
| 준비 조건 2초 후 카운트다운 (F-07) | 스쿼트 측면 프레임을 t 0~2100ms 동안 emit | '3' 카운트다운 표시 |
| 운동 화면으로 넘어갈 때 카메라 유지 (F-01) | 이어서 3초 더 emit | 현재 경로 `/workout/squat`, FakePoseDetector.calls에 'stop' 없음 |
| 뒤로 나가면 정지 | 카운트다운 전에 뒤로 가기(화면 dispose) | calls에 'stop' |
| 권한 거부 | 가짜 권한 false → '설정 열기' 탭 | 이유 문구와 버튼, 감지기 start 호출 없음, `openSettings` 1회 |
| 잘못된 type | `/workout/lunge/setup` | '페이지를 찾을 수 없어요' |
| 미리보기 비율 (F-07) | camera 720 × 1280을 400 × 900 화면에 | `AspectRatio.aspectRatio` 0.5625, Texture 크기 400 × 711(± 1), overlay가 같은 크기 |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/permission/camera_permission.dart`
- `app/lib/features/workout/widgets/camera_preview_view.dart`
- `app/lib/features/workout/presentation/setup_guide_screen.dart`
- `app/lib/app/router.dart`
- `app/test/features/workout/presentation/setup_guide_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-07(문구, 카운트다운, 비율), F-01(카메라 유지, 위젯 수준) 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 운동별 문구, `PoseCameraInfo` 기반 비율 유지 미리보기(`CameraPreviewView(camera:)`), 운동 화면으로 넘어갈 때 stop 안 함
- 음성은 TASK-51로 분리. 선행 Task에 TASK-03(AppRoutes, buildRouter), TASK-06 추가, `cameraPermissionProvider`를 내보내기 표에 따로 적음

- (2026-11-13 사용자 결정) 스쿼트 준비 자세 안내(notInPosture)는 '똑바로 서서 무릎을 펴 주세요'. 정면 안내(frontFacing)는 '옆으로 서 주세요' 그대로.
