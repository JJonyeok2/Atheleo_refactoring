# TASK-11: 음성 안내 서비스(TTS 래퍼, 쿨다운, 겹침 방지)

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 병렬 (그룹: G2)
- 실행 방식 근거: `app/lib/core/tts/`만 새로 만들고 TASK-09, TASK-10과 파일, 타입이 겹치지 않음
- Spec 출처: F-06 (3장, 4장 정상 흐름 5번, 8장 성능, 9장 인수 조건)

## 왜 이렇게 나눴나
TTS 엔진을 인터페이스로 감싸 가짜 구현으로 테스트한다. "무슨 문장을 말할지"는 TASK-18이 정하고, 이 Task는 "언제 말하고 언제 버릴지"만 책임진다.

## 기능 범위 (Spec 발췌)
- 요구사항: 한국어 TTS, 같은 문장 반복 방지 쿨다운, 겹침 방지
- 정상 흐름: 자세 오류가 감지되면 해당 교정 문장 음성 안내(같은 문장은 5초 안에 다시 말하지 않음)
- 성능: 음성 안내 지연은 판정 시점부터 0.5초 이내
- 인수 조건(F-06): 같은 오류가 연속으로 나와도 5초 안에 같은 문장을 다시 말하지 않고, 안내가 겹쳐 재생되지 않는다.
- 이 Task에서 정하는 규칙:
  - 같은 문장을 마지막으로 말한 시각부터 5초 안이면 버린다(false 반환)
  - 말하는 중에 새 문장이 오면 대기 칸 1개에 넣는다. 대기 칸에 이미 있으면 새 것으로 바꾸되, high가 들어 있으면 normal로는 바꾸지 않는다
  - 현재 문장이 끝나면 대기 칸 문장을 바로 말한다
  - `stopAll()`은 재생 중지와 대기 칸 비우기

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| 의존성 | `app/pubspec.yaml` | flutter_tts, flutter_riverpod(^2.6.1) 이미 추가됨 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `TtsEngine` | `app/lib/core/tts/tts_engine.dart` | `abstract class TtsEngine { Future<void> speak(String text); Future<void> stop(); }` (speak는 말하기가 끝나면 완료되는 Future) | TASK-27 |
| `FlutterTtsEngine` | 같은 파일 | `class FlutterTtsEngine implements TtsEngine` (언어 `ko-KR`, `awaitSpeakCompletion(true)`) | (provider 내부) |
| `VoicePriority` | `app/lib/core/tts/voice_guide.dart` | `enum VoicePriority { normal, high }` | TASK-18 |
| `VoiceGuide` | 같은 파일 | `class VoiceGuide { VoiceGuide({required TtsEngine engine, Duration cooldown = const Duration(seconds: 5), DateTime Function()? clock}); Future<bool> say(String text, {VoicePriority priority = VoicePriority.normal}); Future<void> stopAll(); bool get isSpeaking; }` (say는 재생 또는 대기 칸에 들어가면 true, 쿨다운으로 버리면 false) | TASK-27, 28 |
| `voiceGuideProvider` | 같은 파일 | `final voiceGuideProvider = Provider<VoiceGuide>(...)` (FlutterTtsEngine 사용, dispose 시 stopAll) | TASK-27 |

## 범위
- 위 클래스. 테스트는 `Completer`로 끝 시점을 조절하는 가짜 `TtsEngine`과 주입한 `clock`으로 작성

## 범위 밖 (건드리지 않음)
- 문장 내용 정하기(TASK-18), 화면 연결(TASK-27, 29)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 같은 문장 5초 안 반복 안 함 (F-06) | 't=0' say('더 깊이 앉으세요.'), 끝난 뒤 't=3s' 같은 문장 | 두 번째 false, 엔진 speak 1회 |
| 5초 지나면 다시 말함 | 't=0', 't=5.1s' 같은 문장 | 엔진 speak 2회 |
| 겹침 없음 (F-06) | 첫 문장 재생 중(Completer 미완료)에 다른 문장 say | 그 시점 엔진 speak 1회, 첫 문장 끝난 뒤 2회 |
| 대기 칸은 최신 1개 | 재생 중 'A', 'B' 차례로 say | 첫 문장 뒤 'B'만 재생 |
| high는 normal로 안 바뀜 | 재생 중 high 'H', normal 'N' | 'H'만 재생 |
| stopAll | 재생 중 대기 칸이 찬 상태에서 stopAll | 엔진 stop 호출, 대기 문장 재생 안 됨 |

## 바뀔 것으로 예상되는 파일
- `app/lib/core/tts/tts_engine.dart`
- `app/lib/core/tts/voice_guide.dart`
- `app/test/core/tts/voice_guide_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-06 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- flutter_tts가 완료 시점을 알려 주지 않아 겹침 방지를 보장할 수 없을 때

## 추가 발췌 (오케스트레이터가 보충)
