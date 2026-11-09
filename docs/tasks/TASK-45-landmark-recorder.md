# TASK-45: 랜드마크 클립 기록과 JSON 내보내기

- 상태: 대기
- 선행 Task: TASK-13, TASK-19, TASK-27
- 실행 방식: 병렬 (그룹: G6)
- 실행 방식 근거: `app/lib/features/dev/`만 새로 만들고 공유 파일을 건드리지 않음. TASK-38과 파일이 겹치지 않음
- Spec 출처: F-14 (3장, 7장 LandmarkClip, 8장 보안, 9장 인수 조건)

## 왜 이렇게 나눴나
기록과 파일 쓰기 로직을 화면과 분리한다. 여기서 만든 JSON이 나중에 판정 기준 보정(Q-05)과 테스트 픽스처로 쓰인다.

## 기능 범위 (Spec 발췌)
- 세션 랜드마크 시퀀스를 JSON으로 저장, 라벨 지정
- LandmarkClip(로컬 전용): id(uuid), exercise, label, fps, frames(33x(x,y,z,visibility))
- 랜드마크는 개발자 메뉴의 명시적 내보내기 외에는 기기 밖으로 보내지 않는다.
- 인수 조건(F-14): 기록 후 내보내면 33개 랜드마크 시퀀스 JSON 파일이 생긴다.
- 이 Task에서 정하는 규칙:
  - 기록 중 들어온 결과마다 `selectPrimaryPose`로 1명을 골라 프레임 추가(사람 없으면 건너뜀)
  - 프레임 timestamp는 기록 시작 시각을 0으로 다시 맞춤
  - fps = 반올림(프레임 수 / 기록 시간(초)), 기록 시간 0이면 0
  - 저장 위치: `getExternalStorageDirectory()`(앱 전용 외부 저장소, adb로 꺼낼 수 있음) 아래 `clips/`. 없으면 `getApplicationDocumentsDirectory()`
  - 파일 이름: `<exercise>_<label>_<yyyyMMdd_HHmmss>.json`, 라벨의 파일명에 못 쓰는 문자는 `_`로 바꿈
  - 프레임이 0개면 내보내지 않고 `StateError`

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `LandmarkClip`, `ExerciseType` | `app/lib/pose/landmarks/` | `class LandmarkClip { const LandmarkClip({required String id, required ExerciseType exercise, required String label, required int fps, required List<PoseFrame> frames}); ... String encode(); static LandmarkClip parse(String source); }` |
| `PoseDetector`, `PoseDetectionResult` | `app/lib/pose/detector/pose_detector.dart` | `abstract class PoseDetector { Stream<PoseDetectionResult> get results; ... }` |
| `selectPrimaryPose` | `app/lib/pose/body/body_check.dart` | `PoseFrame? selectPrimaryPose(List<PoseFrame> poses)` |
| `clockProvider` | `app/lib/core/clock.dart` | `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);` |
| `FakePoseDetector` | `app/test/support/fake_pose_detector.dart` | 테스트에서만 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `ClipRecorder` | `app/lib/features/dev/domain/clip_recorder.dart` | `class ClipRecorder { void start(); void addResult(PoseDetectionResult result); LandmarkClip stop({required ExerciseType exercise, required String label, required String id}); bool get isRecording; int get frameCount; double get currentFps; }` (currentFps는 최근 1초 결과 수) | TASK-46 |
| `ClipExporter` | `app/lib/features/dev/data/clip_exporter.dart` | `class ClipExporter { ClipExporter({Future<Directory> Function()? baseDir, DateTime Function()? clock}); Future<File> export(LandmarkClip clip); }` | TASK-46 |
| `clipExporterProvider` | 같은 파일 | `final clipExporterProvider = Provider<ClipExporter>(...)` | TASK-46 |

## 범위
- 위 클래스

## 범위 밖 (건드리지 않음)
- 화면, 라우터(TASK-46)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 33개 점 시퀀스 JSON (F-14) | 결과 30개 기록 → stop → export(임시 폴더) | 파일 존재, `LandmarkClip.parse` 결과 frames 30, 각 33개 점 |
| 라벨과 운동 | label 'hip sag/1', squat | 파일 이름 `squat_hip_sag_1_<시각>.json`, 본문 label 'hip sag/1' |
| 시각 0 기준 | 첫 결과 t 5000 | 첫 프레임 t 0 |
| 사람 없는 결과 건너뜀 | 30개 중 5개 poses 빈 목록 | frames 25 |
| fps 계산 | 2초 동안 60개 | fps 30 |
| 빈 기록 | 결과 없이 stop 후 export | `StateError` |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/dev/domain/clip_recorder.dart`
- `app/lib/features/dev/data/clip_exporter.dart`
- `app/test/features/dev/clip_recorder_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-14 인수 조건(파일 생성) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 파일을 기기 밖으로 보내는 기능(공유 시트 등)이 필요해 보일 때

## 추가 발췌 (오케스트레이터가 보충)

- (오케스트레이터 보충, QA-TASK-04) `LandmarkClip.encode()`는 좌표에 Infinity가 있으면 `JsonUnsupportedObjectError`를 던진다. 내보내기에서 이 예외를 잡아 사용자에게 "내보내기 실패" 안내를 하고 앱이 죽지 않게 하며, 이를 확인하는 테스트를 포함한다.
