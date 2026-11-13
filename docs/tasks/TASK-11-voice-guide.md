# TASK-11: 음성 안내 서비스(TTS 래퍼, 쿨다운, 겹침 방지, 글자 안내 대체)

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 병렬 (그룹: G2)
- 실행 방식 근거: `app/lib/core/tts/`만 새로 만들고 TASK-09, TASK-10과 파일, 타입이 겹치지 않음
- Spec 출처: F-06 (3장, 4장 정상 흐름 6번, 예외 흐름 한국어 TTS 없음, 8장 성능, 접근성, 9장 인수 조건)

## 왜 이렇게 나눴나
TTS 엔진을 인터페이스로 감싸 가짜 구현으로 테스트한다. "무슨 문장을 말할지"는 TASK-18, 51이 정하고, 이 Task는 "언제 말하고 언제 버릴지", "음성을 못 쓰면 글자로 돌릴지"만 책임진다.

## 기능 범위 (Spec 발췌)
- 요구사항: 한국어 TTS, 같은 문장 반복 방지 쿨다운, 겹침 방지. 한국어 음성이 없는 기기에서는 글자 안내만 하고 그 사실을 한 번 알린다
- 정상 흐름: 자세 오류가 감지되면 해당 교정 문장 음성 안내(같은 문장은 5초 안에 다시 말하지 않음)
- 예외 흐름: 한국어 TTS 음성이 없는 기기: 음성 대신 글자 안내만 하고, "이 기기에서는 음성 안내를 쓸 수 없어 글자로 안내합니다"를 한 번 알린다.
- 성능: 음성 안내 지연은 판정 시점부터 0.5초 이내
- 인수 조건(F-06): 같은 오류가 연속으로 나와도 5초 안에 같은 문장을 다시 말하지 않고, 안내가 겹쳐 재생되지 않는다. 한국어 음성이 없는 기기에서는 "음성 안내를 쓸 수 없어 글자로 안내합니다"가 한 번만 보이고 이후 안내는 글자로 나온다.
- 이 Task에서 정하는 규칙:
  - 같은 문장을 마지막으로 말한 시각부터 5초 안이면 버린다(false 반환). 글자 모드에서도 같다
  - 말하는 중에 새 문장이 오면 대기 칸 1개에 넣는다. 대기 칸에 이미 있으면 새 것으로 바꾸되, high가 들어 있으면 normal로는 바꾸지 않는다
  - 현재 문장이 끝나면 대기 칸 문장을 바로 말한다
  - `stopAll()`은 재생 중지와 대기 칸 비우기
  - `init()`에서 엔진의 한국어 지원 여부를 한 번 확인한다. 지원하지 않으면 글자 모드: `say`는 엔진을 부르지 않고 문장을 `captions` 스트림으로 내보낸다. 글자 모드로 처음 정해질 때 `VoiceGuide.unavailableNotice`를 `captions`로 한 번만 내보낸다
  - `init()` 전에 `say`가 오면 먼저 `init()`을 마치고 처리한다
  - 음성 모드에서는 `captions`에 아무것도 내보내지 않는다

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| 의존성 | `app/pubspec.yaml` | flutter_tts, flutter_riverpod(^2.6.1) 이미 추가됨 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `TtsEngine` | `app/lib/core/tts/tts_engine.dart` | `abstract class TtsEngine { Future<bool> isKoreanAvailable(); Future<void> speak(String text); Future<void> stop(); }` (speak는 말하기가 끝나면 완료되는 Future) | TASK-27, 51 |
| `FlutterTtsEngine` | 같은 파일 | `class FlutterTtsEngine implements TtsEngine` (언어 `ko-KR`, `awaitSpeakCompletion(true)`, isKoreanAvailable은 `isLanguageAvailable('ko-KR')`) | (provider 내부) |
| `VoicePriority` | `app/lib/core/tts/voice_guide.dart` | `enum VoicePriority { normal, high }` | TASK-18 |
| `VoiceGuide` | 같은 파일 | `class VoiceGuide { VoiceGuide({required TtsEngine engine, Duration cooldown = const Duration(seconds: 5), DateTime Function()? clock}); static const String unavailableNotice = '이 기기에서는 음성 안내를 쓸 수 없어 글자로 안내합니다'; Future<void> init(); Future<bool> say(String text, {VoicePriority priority = VoicePriority.normal}); Future<void> stopAll(); bool get isSpeaking; bool? get voiceAvailable; Stream<String> get captions; }` (say는 재생, 대기 칸, 글자 안내 중 하나로 처리되면 true, 쿨다운으로 버리면 false. voiceAvailable은 init 전 null. captions는 broadcast) | TASK-27, 28, 51 |
| `voiceGuideProvider` | 같은 파일 | `final voiceGuideProvider = Provider<VoiceGuide>(...)` (FlutterTtsEngine 사용, 생성 시 init 시작, dispose 시 stopAll) | TASK-27, 51 |
| `voiceCaptionProvider` | 같은 파일 | `final voiceCaptionProvider = StreamProvider<String>((ref) => ref.watch(voiceGuideProvider).captions);` | TASK-29, 51 |

## 범위
- 위 클래스. 테스트는 `Completer`로 끝 시점을 조절하고 `isKoreanAvailable` 값을 정할 수 있는 가짜 `TtsEngine`과 주입한 `clock`으로 작성

## 범위 밖 (건드리지 않음)
- 문장 내용 정하기(TASK-18, 51), 화면에 글자 안내 띄우기(TASK-29, 51)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 같은 문장 5초 안 반복 안 함 (F-06) | 't=0' say('더 깊이 앉으세요.'), 끝난 뒤 't=3s' 같은 문장 | 두 번째 false, 엔진 speak 1회 |
| 5초 지나면 다시 말함 | 't=0', 't=5.1s' 같은 문장 | 엔진 speak 2회 |
| 겹침 없음 (F-06) | 첫 문장 재생 중(Completer 미완료)에 다른 문장 say | 그 시점 엔진 speak 1회, 첫 문장 끝난 뒤 2회 |
| 대기 칸은 최신 1개 | 재생 중 'A', 'B' 차례로 say | 첫 문장 뒤 'B'만 재생 |
| high는 normal로 안 바뀜 | 재생 중 high 'H', normal 'N' | 'H'만 재생 |
| stopAll | 재생 중 대기 칸이 찬 상태에서 stopAll | 엔진 stop 호출, 대기 문장 재생 안 됨 |
| 한국어 음성 없음 (F-06) | 가짜 엔진 isKoreanAvailable false, say('1회'), say('2회') | 엔진 speak 0회, captions 순서 [unavailableNotice, '1회', '2회'], voiceAvailable false |
| 안내는 한 번만 (F-06) | 글자 모드에서 init 두 번, say 여러 번 | captions에 unavailableNotice 1번만, 쿨다운도 그대로 적용(같은 문장 3초 뒤 false) |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/tts/tts_engine.dart`
- `app/lib/core/tts/voice_guide.dart`
- `app/test/core/tts/voice_guide_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-06 인수 조건(쿨다운, 겹침, 글자 대체 로직) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- flutter_tts가 완료 시점이나 언어 지원 여부를 알려 주지 않아 겹침 방지나 글자 대체를 보장할 수 없을 때

## 추가 발췌 (오케스트레이터가 보충)

- (QA-TASK-11 반영) 쿨다운은 say가 문장을 받아들인 시각 기준이다(대기 칸에서 밀리거나 stopAll로 비워진 문장도 쿨다운에 걸린다).
- (QA-TASK-11 반영) say가 false를 돌려주는 경우: 쿨다운 안, 대기 칸에 high가 있는데 normal이 들어옴, dispose 이후.
- (QA-TASK-11 반영) `void dispose()`를 공개 계약에 넣는다. dispose 뒤 say는 아무것도 하지 않고 false. stopAll 안의 engine.stop() 예외는 잡아서 무시한다.
- (QA-TASK-11 반영) 글자 안내 대체 알림은 captions 스트림만 믿지 않는다. 소비 쪽(TASK-29, 51)은 `voiceAvailable == false`이면 화면을 열 때 직접 "음성 안내를 쓸 수 없어 글자로 안내합니다"를 한 번 보여 준다.

## 2026-11-13 설계 검토 반영
- 한국어 TTS가 없을 때 글자 모드: `TtsEngine.isKoreanAvailable`, `VoiceGuide.init`, `voiceAvailable`, `captions`, `unavailableNotice`, `voiceCaptionProvider` 추가. 테스트 2건 추가
