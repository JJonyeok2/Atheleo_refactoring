# TASK-09: 자세 오류 판정

- 상태: 대기
- 선행 Task: TASK-08
- 실행 방식: 병렬 (그룹: G2)
- 실행 방식 근거: `app/lib/pose/judge/`만 새로 만들고 TASK-10(루틴), TASK-11(TTS)과 파일, 타입이 겹치지 않음
- Spec 출처: F-04 (3장, 7장 자세 오류 코드, 9장 인수 조건)

## 왜 이렇게 나눴나
반복 1회가 끝났을 때 그 반복의 프레임만 보고 오류 코드를 고르는 순수 함수다. 2차 범위의 학습 모델(F-16)이 나중에 이 함수 자리를 대체할 수 있게 입력과 출력을 좁게 둔다. 부분 반복은 여기로 오지 않는다(점수 없음).

## 기능 범위 (Spec 발췌)
| 운동 | 코드 | 판정 기준(초기값) | 음성 문구 | 짧은 이름 |
|---|---|---|---|---|
| 푸쉬업 | `PU_SHALLOW` | 횟수로 인정된 반복의 최저 팔꿈치 각도(원시 각도 기준) 90도 초과 | 조금 더 내려가세요. | 깊이 부족 |
| 푸쉬업 | `PU_HIP_SAG` | 골반이 어깨와 발목을 잇는 선보다 아래에 있고, 어깨, 골반, 발목 각도 160도 미만 | 허리가 처졌어요. 몸을 일자로 유지하세요. | 허리 처짐 |
| 푸쉬업 | `PU_HIP_PIKE` | 골반이 어깨와 발목을 잇는 선보다 위에 있고, 어깨, 골반, 발목 각도 160도 미만 | 엉덩이를 내리고 몸을 일자로 만드세요. | 엉덩이 들림 |
| 스쿼트 | `SQ_SHALLOW` | 횟수로 인정된 반복의 최저 무릎 각도(원시 각도 기준) 90도 초과 | 더 깊이 앉으세요. | 깊이 부족 |
| 스쿼트 | `SQ_TORSO_LEAN` | 최저점에서 상체(어깨와 골반을 잇는 선)와 수직선 각도 45도 초과(실기기 보정 대상, Q-05) | 가슴을 펴고 상체를 세우세요. | 상체 숙임 |
| 스쿼트 | `SQ_HEEL_LIFT` | 반복 중 발뒤꿈치(랜드마크 29, 30)가 시작 자세 대비 정강이 길이 10% 이상 위로 이동 | 뒤꿈치를 바닥에 붙이세요. | 뒤꿈치 들림 |

- 허리 처짐과 엉덩이 들림은 어깨와 발목을 잇는 선 기준 골반의 위아래(부호)로 나눈다. 둘은 한 반복에 함께 나오지 않는다.
- 이 Task에서 정하는 세부:
  - 좌우는 `selectSide`로 고른 쪽 점을 쓴다. 고를 수 없는 프레임은 건너뛴다
  - 처짐/들림: 반복 구간 프레임들의 어깨-골반-발목 각도 중앙값이 160 미만일 때, 같은 프레임들에서 골반이 선 아래(이미지 y가 큼)인 프레임이 더 많으면 `PU_HIP_SAG`, 위면 `PU_HIP_PIKE`
  - "최저점" = 타임스탬프가 `rep.bottomMs`에 가장 가까운 프레임
  - 상체 기울기 = 골반→어깨 벡터와 수직 위쪽 벡터 사이 각도(x에 aspectRatio 곱함)
  - "시작 자세" = `repFrames`의 첫 프레임. 뒤꿈치 상승 = 시작 대비 뒤꿈치 y 감소량의 최댓값 / 시작 프레임의 정강이(무릎-발목) 길이
  - 판정 기준값은 `ErrorThresholds`로 주입 가능하게 하고 표 값을 기본값으로 둔다(Q-05 실측 보정 대비)
  - 깊이 부족은 `rep.minAngle`만 본다. 이 값은 TASK-08이 원시 각도 최저점 주변 3프레임 중앙값으로 이미 계산해 준다(여기서 다시 계산하지 않음)
  - `ErrorThresholds.torsoLeanDeg` 기본값 45는 그대로 두고, 코드의 그 필드에 "실기기 보정 대상(Spec Q-05)" 주석을 단다
- 인수 조건(F-04): 허리를 처지게 한 푸쉬업 클립은 `PU_HIP_SAG`, 엉덩이를 든 클립은 `PU_HIP_PIKE`가 기록되고 서로 바뀌어 나오지 않는다. 최저 각도 105도 반복은 `PU_SHALLOW`가 기록된다(횟수 인정은 TASK-08, 끝에서 끝 확인은 TASK-15).

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }` |
| `PoseFrame`, `LandmarkIndex` | `app/lib/pose/landmarks/pose_landmark.dart` | TASK-04 계약 그대로 (leftHeel 29, rightHeel 30 포함) |
| `angleDeg`, `selectSide`, `SideAngles` | `app/lib/pose/angle/joint_angle.dart` | `double angleDeg(PoseLandmark a, PoseLandmark vertex, PoseLandmark c, {double aspectRatio = 1.0})`, `SideAngles? selectSide(PoseFrame frame, {double minVisibility = 0.5})` (평균 visibility 높은 쪽, 같으면 left, 둘 다 기준 미만이면 null. 고른 쪽의 세 점 묶음(어깨-팔꿈치-손목, 골반-무릎-발목, 어깨-골반-무릎, 어깨-골반-발목) 중 하나라도 벡터 길이가 0이거나 좌표가 유한하지 않으면 그쪽은 쓸 수 없는 것으로 보고, 다른 쪽이 visibility 기준과 이 조건을 만족하면 다른 쪽을, 둘 다 안 되면 null) |
| `RepEvent` | `app/lib/pose/rep/rep_counter.dart` | `final class RepEvent extends RepCounterEvent { const RepEvent({required int repIndex, required int startMs, required int bottomMs, required int endMs, required double minAngle}); int get durationMs; }` (repIndex는 reset 이후 1부터, bottomMs는 원시 각도 최저 프레임 시각, minAngle은 원시 각도 최저점 주변 3프레임 중앙값) |
| `SyntheticPose`, `HipOffset`, `buildSyntheticFrame` | `app/test/support/synthetic_clip.dart` | TASK-06 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `PoseErrorCode` | `app/lib/pose/judge/pose_error.dart` | `enum PoseErrorCode { puShallow, puHipSag, puHipPike, sqShallow, sqTorsoLean, sqHeelLift }`, 필드 `final String code`(위 표 코드), `final String voiceMessage`, `final String label`(짧은 이름), `static PoseErrorCode fromCode(String code)`(모르는 값은 `ArgumentError`) | TASK-12, 15, 17, 18, 29, 30, 32, 42 |
| `ErrorThresholds` | `app/lib/pose/judge/error_judge.dart` | `class ErrorThresholds { const ErrorThresholds({double depthDeg = 90, double bodyLineDeg = 160, double torsoLeanDeg = 45, double heelLiftRatio = 0.1}); }` | TASK-15 |
| `judgeRep` | 같은 파일 | `List<PoseErrorCode> judgeRep({required ExerciseType exercise, required List<PoseFrame> repFrames, required RepEvent rep, ErrorThresholds thresholds = const ErrorThresholds()})` (운동에 맞는 코드만, enum 선언 순서대로) | TASK-15 |

## 범위
- 위 enum과 판정 함수

## 범위 밖 (건드리지 않음)
- 점수 계산(TASK-12), 음성 재생(TASK-11, 18), 루틴 파일(TASK-10), 부분 반복 처리(TASK-08, 15)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 허리 처짐 (F-04) | bodyLineDeg 140, hipOffset below 푸쉬업 프레임들 + RepEvent(minAngle 80) | `[puHipSag]`, puHipPike 없음 |
| 엉덩이 들림 (F-04) | bodyLineDeg 140, hipOffset above | `[puHipPike]`, puHipSag 없음 |
| 푸쉬업 깊이 부족 (F-04) | 정상 몸통, rep.minAngle 105 | `[puShallow]` (90 이하면 없음) |
| 정상 푸쉬업 | bodyLineDeg 178, minAngle 85 | 빈 목록 |
| 스쿼트 상체 숙임 | 최저점 프레임 torsoLeanDeg 60, minAngle 80 | `[sqTorsoLean]` |
| 스쿼트 뒤꿈치 들림 | 중간 프레임 heelLiftRatio 0.2 / 0.05 | `sqHeelLift` 포함 / 미포함 |
| 운동별 코드 분리 | 스쿼트 프레임에 bodyLineDeg 140 | 푸쉬업 코드는 나오지 않음 |
| 코드 문자열 | `PoseErrorCode.fromCode('SQ_HEEL_LIFT')` | `sqHeelLift`, voiceMessage '뒤꿈치를 바닥에 붙이세요.' |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/judge/pose_error.dart`
- `app/lib/pose/judge/error_judge.dart`
- `app/test/pose/judge/error_judge_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-04 인수 조건 충족
- [ ] `torsoLeanDeg` 기본값에 보정 대상 주석이 있음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 합성 클립으로 판정 기준을 표현할 수 없을 때(TASK-06 계약 변경 필요)

## 추가 발췌 (오케스트레이터가 보충)

- (TASK-06 QA 권고) 골반 처짐/들림(PU_HIP_SAG, PU_HIP_PIKE) 방향은 어깨→발목 벡터와 어깨→골반 벡터의 외적 부호로 판정하되, 몸이 화면 왼쪽을 보든 오른쪽을 보든 같게 나오도록 어깨→발목 x 성분의 부호를 곱한다(합성 클립의 좌우 양쪽으로 테스트). "골반 x에서 선 y를 보간"하는 방식은 선이 수직일 때 0으로 나누므로 쓰지 않는다. 화면 아래쪽(y가 큰 쪽)이 처짐. 이 방향 판정은 몸이 수평에 가까운 푸쉬업 자세(자세 게이트 통과)에서만 의미가 있다.

- (QA-TASK-09 FIX 반영) "시작 자세"는 selectSide로 고를 수 있는 첫 프레임이다.
- (QA-TASK-09 FIX 반영) 뒤꿈치 상승: 시작 프레임 쪽을 반복 내내 고정하고, selectSide가 null이거나 고른 쪽이 시작 쪽과 다르거나 뒤꿈치 좌표가 유한하지 않거나 그 쪽 뒤꿈치(29 또는 30) visibility가 0.5 미만인 프레임은 건너뛴다. 한 프레임 튐을 막기 위해 상승량은 "최댓값"이 아니라 남은 프레임 상승량을 시간 순으로 3프레임 이동 중앙값으로 만든 뒤의 최댓값을 쓴다(남은 프레임이 3개 미만이면 그 중 최솟값). visibility 0.5는 실기기 보정 대상.
- (QA-TASK-09 FIX 반영) 스쿼트 상체 기울기: 고를 수 있는 프레임 중 bottomMs에 가장 가까운 프레임과 그 앞뒤 고를 수 있는 프레임(최대 3개)의 상체 기울기 중앙값을 쓴다. 동률이면 앞 프레임. 고를 수 있는 프레임이 없을 때만 0(오류 없음).
- (QA-TASK-09 FIX 반영) 처짐/들림 다수결이 동수면 그 오류는 내지 않는다.

## 2026-11-13 설계 검토 반영
- 깊이 판정이 원시 각도 기준(`rep.minAngle`, TASK-08에서 계산)임을 명시. `SQ_TORSO_LEAN` 45도는 값 유지, 보정 대상 주석을 완료 조건에 추가. 계약과 테스트는 그대로
