# TASK-09: 자세 오류 판정

- 상태: 대기
- 선행 Task: TASK-08
- 실행 방식: 병렬 (그룹: G2)
- 실행 방식 근거: `app/lib/pose/judge/`만 새로 만들고 TASK-10(루틴), TASK-11(TTS)과 파일, 타입이 겹치지 않음
- Spec 출처: F-04 (3장, 7장 자세 오류 코드, 9장 인수 조건)

## 왜 이렇게 나눴나
반복 1회가 끝났을 때 그 반복의 프레임만 보고 오류 코드를 고르는 순수 함수다. 2차 범위의 학습 모델(F-16)이 나중에 이 함수 자리를 대체할 수 있게 입력과 출력을 좁게 둔다.

## 기능 범위 (Spec 발췌)
| 운동 | 코드 | 판정 기준(초기값) | 음성 문구 | 짧은 이름 |
|---|---|---|---|---|
| 푸쉬업 | `PU_HIP_SAG` | 어깨, 골반, 발목이 이루는 각도 160도 미만 | 허리가 처졌어요. 몸을 일자로 유지하세요. | 허리 처짐 |
| 푸쉬업 | `PU_SHALLOW` | 반복 중 최저 팔꿈치 각도 100도 초과 | 조금 더 내려가세요. | 깊이 부족 |
| 스쿼트 | `SQ_SHALLOW` | 반복 중 최저 무릎 각도 100도 초과 | 더 깊이 앉으세요. | 깊이 부족 |
| 스쿼트 | `SQ_TORSO_LEAN` | 최저점에서 상체와 수직선 각도 45도 초과 | 가슴을 펴고 상체를 세우세요. | 상체 숙임 |
| 스쿼트 | `SQ_KNEE_FORWARD` | 최저점에서 무릎이 발끝보다 정강이 길이 30% 이상 앞 | 무릎이 너무 앞으로 나갔어요. | 무릎 전진 |

- 이 Task에서 정하는 세부:
  - 좌우는 `selectSide`로 고른 쪽 점을 쓴다. 고를 수 없는 프레임은 건너뛴다
  - `PU_HIP_SAG`: 반복 구간 프레임들의 어깨-골반-발목 각도 중앙값이 160 미만
  - "최저점" = 타임스탬프가 `rep.bottomMs`에 가장 가까운 프레임
  - 상체 기울기 = 골반→어깨 벡터와 수직 위쪽 벡터 사이 각도(x에 aspectRatio 곱함)
  - 무릎 전진: 진행 방향은 발목→발끝(foot index) x 부호. (무릎 x − 발끝 x)를 진행 방향으로 잰 값이 정강이(무릎-발목) 길이의 0.3 이상
  - 판정 기준값은 `ErrorThresholds`로 주입 가능하게 하고 표 값을 기본값으로 둔다(Q-05 실측 보정 대비)
- 인수 조건(F-04): 허리를 처지게 한 푸쉬업 클립을 넣으면 해당 반복에 `PU_HIP_SAG`가 기록된다.

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `PoseFrame`, `LandmarkIndex` | `app/lib/pose/landmarks/pose_landmark.dart` | TASK-04 계약 그대로 |
| `angleDeg`, `selectSide`, `SideAngles` | `app/lib/pose/angle/joint_angle.dart` | `double angleDeg(PoseLandmark a, PoseLandmark vertex, PoseLandmark c, {double aspectRatio = 1.0})`, `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})` |
| `RepEvent` | `app/lib/pose/rep/rep_counter.dart` | `class RepEvent { const RepEvent({required int repIndex, required int startMs, required int bottomMs, required int endMs, required double minAngle}); int get durationMs; }` (repIndex 1부터, bottomMs는 최저 각도 시각) |
| `SyntheticPose`, `buildSyntheticFrame` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `PoseErrorCode` | `app/lib/pose/judge/pose_error.dart` | `enum PoseErrorCode { puHipSag, puShallow, sqShallow, sqTorsoLean, sqKneeForward }`, 필드 `final String code`(위 표 코드), `final String voiceMessage`, `final String label`(짧은 이름), `static PoseErrorCode fromCode(String code)`(모르는 값은 `ArgumentError`) | TASK-12, 15, 17, 18, 29, 30, 32, 42 |
| `ErrorThresholds` | `app/lib/pose/judge/error_judge.dart` | `class ErrorThresholds { const ErrorThresholds({double hipSagDeg = 160, double shallowDeg = 100, double torsoLeanDeg = 45, double kneeForwardRatio = 0.3}); }` | TASK-15 |
| `judgeRep` | 같은 파일 | `List<PoseErrorCode> judgeRep({required ExerciseType exercise, required List<PoseFrame> repFrames, required RepEvent rep, ErrorThresholds thresholds = const ErrorThresholds()})` (운동에 맞는 코드만, 표 순서대로) | TASK-15 |

## 범위
- 위 enum과 판정 함수

## 범위 밖 (건드리지 않음)
- 점수 계산(TASK-12), 음성 재생(TASK-11, 18), 루틴 파일(TASK-10)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 허리 처짐 클립 (F-04) | bodyLineDeg 140인 푸쉬업 프레임들 + RepEvent | `[PoseErrorCode.puHipSag]` 포함 |
| 정상 푸쉬업 | bodyLineDeg 178, rep.minAngle 80 | 빈 목록 |
| 푸쉬업 깊이 부족 | rep.minAngle 115 | `puShallow` 포함 |
| 스쿼트 상체 숙임 | 최저점 프레임 torsoLeanDeg 60 | `sqTorsoLean` 포함 |
| 스쿼트 무릎 전진 | 최저점 프레임 kneeForwardRatio 0.5 | `sqKneeForward` 포함, 0.1이면 미포함 |
| 운동별 코드 분리 | 스쿼트 프레임에 푸쉬업 기준 위반 값 | 푸쉬업 코드는 나오지 않음 |
| 코드 문자열 | `PoseErrorCode.fromCode('SQ_SHALLOW')` | `sqShallow`, voiceMessage '더 깊이 앉으세요.' |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/judge/pose_error.dart`
- `app/lib/pose/judge/error_judge.dart`
- `app/test/pose/judge/error_judge_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-04 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 합성 클립으로 판정 기준을 표현할 수 없을 때(TASK-06 계약 변경 필요)

## 추가 발췌 (오케스트레이터가 보충)
