# TASK-18: 운동 이벤트별 음성 문구

- 상태: 대기
- 선행 Task: TASK-11, TASK-16
- 실행 방식: 병렬 (그룹: G5)
- 실행 방식 근거: `app/lib/features/workout/domain/voice_cues.dart`만 새로 만드는 순수 매핑. TASK-23, 24와 파일이 겹치지 않음
- Spec 출처: F-06, F-08 (4장 정상 흐름 4~6번, 예외 흐름 사람 안 보임), 8장 접근성

## 왜 이렇게 나눴나
"어떤 이벤트에 무슨 말을 할지"를 순수 함수로 떼어 문구를 한곳에서 관리한다. 실제 재생과 쿨다운은 `VoiceGuide`(TASK-11)가 맡는다.

## 기능 범위 (Spec 발췌)
- 반복할 때마다 횟수 음성 안내
- 자세 오류가 감지되면 해당 교정 문장 음성 안내
- 목표 횟수 달성 → "세트 완료, N초 쉬세요" → 휴식 카운트다운 → "다음 세트를 시작하세요"
- 부분 반복(덜 내려가고 올라옴): "더 내려가세요" 음성
- 사람이 안 보일 때: "카메라 앞에 서 주세요" 음성 안내
- 모든 핵심 피드백(횟수, 오류, 세트, 휴식)은 음성으로도 제공한다.
- 이 Task에서 정하는 문구와 우선순위:

| 이벤트 | 문구 | 우선순위 |
|---|---|---|
| `RepCounted` | `'${repsInSet}회'` | normal |
| `RepCounted`에 오류가 있을 때 | 위 문구 다음에 첫 번째 오류의 `voiceMessage` | high |
| `SetCompleted` | `'세트 완료, ${restSec}초 쉬세요'` | high |
| `NextSetStarted` | `'다음 세트를 시작하세요'` | high |
| `PartialRepNoticed` | `'더 내려가세요'` | normal |
| `WorkoutFinished` | `'운동을 마쳤어요. 수고하셨어요.'` | high |
| 사람 안 보임 | `'카메라 앞에 서 주세요'` | high |
| 이어서 하기 확인 | `'이어서 할까요?'` | high |

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `VoicePriority` | `app/lib/core/tts/voice_guide.dart` | `enum VoicePriority { normal, high }` |
| `WorkoutEvent` 계열 | `app/lib/features/workout/domain/workout_session_controller.dart` | `sealed class WorkoutEvent`, `final class RepCounted extends WorkoutEvent { const RepCounted(this.rep, this.repsInSet); final RepResult rep; final int repsInSet; }`, `final class SetCompleted extends WorkoutEvent { const SetCompleted(this.setIndex, this.restSec); final int setIndex; final int restSec; }`, `final class NextSetStarted extends WorkoutEvent { const NextSetStarted(this.setIndex); final int setIndex; }`, `final class WorkoutFinished extends WorkoutEvent { const WorkoutFinished(); }`, `final class PartialRepNoticed extends WorkoutEvent { const PartialRepNoticed(this.partialsInSet); final int partialsInSet; }` |
| `RepResult`, `PoseErrorCode` | `app/lib/pose/analyzer/rep_analyzer.dart`, `app/lib/pose/judge/pose_error.dart` | `RepResult.errors`는 `List<PoseErrorCode>`, `PoseErrorCode.voiceMessage`는 `String` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `VoiceCue` | `app/lib/features/workout/domain/voice_cues.dart` | `class VoiceCue { const VoiceCue(this.text, {this.priority = VoicePriority.normal}); final String text; final VoicePriority priority; }` (`==` 구현) | TASK-27, 28 |
| `cuesForEvent` | 같은 파일 | `List<VoiceCue> cuesForEvent(WorkoutEvent event)` | TASK-27 |
| `VoiceCues` | 같은 파일 | `abstract final class VoiceCues { static const VoiceCue noPerson; static const VoiceCue askResume; }` | TASK-28 |

## 범위
- 위 매핑

## 범위 밖 (건드리지 않음)
- 실제 재생(TASK-27), 촬영 가이드 문구(TASK-14)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 횟수 안내 | `RepCounted(오류 없는 rep, 3)` | `[VoiceCue('3회')]` |
| 오류 교정 안내 (F-06) | `RepCounted(errors [sqShallow], 4)` | `[VoiceCue('4회'), VoiceCue('더 깊이 앉으세요.', priority: high)]` |
| 세트 완료 (F-08) | `SetCompleted(1, 30)` | `[VoiceCue('세트 완료, 30초 쉬세요', priority: high)]` |
| 다음 세트 (F-08) | `NextSetStarted(2)` | `[VoiceCue('다음 세트를 시작하세요', priority: high)]` |
| 운동 종료 | `WorkoutFinished()` | 문구 1개, high |
| 부분 반복 (F-03) | `PartialRepNoticed(1)` | `[VoiceCue('더 내려가세요')]` |
| 사람 안 보임 상수 | `VoiceCues.noPerson.text` | '카메라 앞에 서 주세요' |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/domain/voice_cues.dart`
- `app/test/features/workout/domain/voice_cues_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
