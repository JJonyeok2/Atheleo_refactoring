# TASK-51: 촬영 가이드 음성 안내와 글자 안내 띠

- 상태: 대기
- 선행 Task: TASK-11, TASK-14, TASK-25
- 실행 방식: 순차
- 실행 방식 근거: TASK-25와 같은 화면 파일을 고침
- Spec 출처: F-06 (3장, 4장 정상 흐름 2~3번, 예외 흐름 한국어 TTS 없음, 8장 접근성, 9장 인수 조건 F-06)

## 왜 이렇게 나눴나
촬영 가이드 화면(TASK-25)이 통과한 뒤 음성만 더한다. 화면 Task가 테스트 8건을 넘지 않게 나눴다. 문구는 TASK-14 상태 문구를 그대로 말한다.

## 기능 범위 (Spec 발췌)
- 촬영 가이드: 상태가 바뀔 때(전신이 안 보임, 자세 잡기, 유지) 음성으로도 안내한다.
- 준비 조건이 2초 이상 유지되면 3·2·1 음성 카운트다운과 "시작" 안내 후 운동 화면으로 넘어간다.
- 모든 핵심 피드백(촬영 가이드 상태, 카운트다운)은 음성으로도 제공한다. 한국어 음성이 없으면 글자로 대신하고 한 번 알린다.
- 인수 조건(F-06): 촬영 가이드에서 전신이 안 보임, 자세 잡기, 유지 상태로 바뀔 때마다 해당 음성이 나오고, "3, 2, 1, 시작"이 들린다. 한국어 음성이 없는 기기에서는 "음성 안내를 쓸 수 없어 글자로 안내합니다"가 한 번만 보이고 이후 안내는 글자로 나온다.
- 이 Task에서 정하는 규칙:
  - `SetupGuideState.status`가 바뀔 때 `state.message`를 `voiceGuide.say(message, priority: high)`로 말한다. 같은 status가 이어지면 말하지 않는다
  - countdown 상태에서는 countdown 값이 바뀔 때마다 '3', '2', '1'을 말하고, ready가 되면 '시작'을 말한 뒤 화면을 넘긴다(말이 끝나기를 기다리지 않음)
  - 화면 위쪽에 글자 안내 띠: `voiceCaptionProvider`의 마지막 값을 보여 준다(글자 모드일 때만 값이 옴)
  - 화면을 나갈 때 `stopAll`은 부르지 않는다('시작'이 운동 화면에서 끝까지 들리게)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `SetupGuideScreen` | `app/lib/features/workout/presentation/setup_guide_screen.dart` | `class SetupGuideScreen extends ConsumerStatefulWidget { const SetupGuideScreen({super.key, required ExerciseType exercise}); }` (TASK-25 구현) |
| `SetupGuideState`, `SetupGuideStatus` | `app/lib/features/workout/domain/setup_guide_controller.dart` | `enum SetupGuideStatus { noPerson, notFullBody, frontFacing, notInPosture, holding, countdown, ready }`, `class SetupGuideState { const SetupGuideState({required SetupGuideStatus status, required String message, int? countdown}); }` (countdown message '3', '2', '1', ready message '시작') |
| `VoiceGuide`, `voiceGuideProvider`, `voiceCaptionProvider`, `VoicePriority` | `app/lib/core/tts/voice_guide.dart` | `Future<bool> say(String text, {VoicePriority priority = VoicePriority.normal})`, `static const String unavailableNotice`, `final voiceCaptionProvider = StreamProvider<String>(...)` |
| `TtsEngine` | `app/lib/core/tts/tts_engine.dart` | `abstract class TtsEngine { Future<bool> isKoreanAvailable(); Future<void> speak(String text); Future<void> stop(); }` (테스트에서 가짜 구현으로 VoiceGuide override) |
| `FakePoseDetector`, `buildSyntheticFrame`, `SyntheticPose` | `app/test/support/` | TASK-06, 19 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| (화면 동작) | `setup_guide_screen.dart` | 위 규칙. 공개 시그니처는 TASK-25 그대로 | (라우터) |

## 범위
- 화면에 음성 호출과 글자 안내 띠 추가

## 범위 밖 (건드리지 않음)
- 상태 문구(TASK-14), 쿨다운과 글자 모드 판단(TASK-11), 운동 중 음성(TASK-27)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 상태가 바뀔 때만 말함 (F-06) | 사람 없음 → 발목이 화면 밖 → 측면 전신 프레임을 각각 여러 번 emit | 가짜 엔진 speak 순서 ['카메라 앞에 서 주세요', 거리 안내, '그대로 유지하세요'], 같은 문장 반복 없음 |
| 3, 2, 1, 시작 (F-06) | 준비 조건 프레임을 5초 넘게 emit | speak에 '3', '2', '1', '시작'이 이 순서로, 그 뒤 경로 `/workout/<type>` |
| 글자 안내 (F-06) | 가짜 엔진 isKoreanAvailable false, 상태 두 번 바뀜 | 띠에 '이 기기에서는 음성 안내를 쓸 수 없어 글자로 안내합니다'가 먼저 보이고 이후 상태 문구, speak 0회, 안내 문구는 한 번만 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/presentation/setup_guide_screen.dart`
- `app/test/features/workout/presentation/setup_guide_voice_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] TASK-25 테스트가 깨지지 않음
- [ ] F-06 촬영 가이드 부분 인수 조건 충족
- [ ] TASK-25의 공개 시그니처가 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 연결 범위의 계약과 실제 코드가 다를 때

## 추가 발췌 (오케스트레이터가 보충)
