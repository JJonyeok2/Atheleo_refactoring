# QA-TASK-11

- 검토일: 2026-11-13
- 판정: PASS (최초 FIX, 재검토 후 PASS)

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| app/lib/core/tts/tts_engine.dart | 추가함 | analyze info 1건(생성자) |
| app/lib/core/tts/voice_guide.dart | 추가함 | analyze info 4건(생성자 2, initializing formal 2) |
| app/test/core/tts/voice_guide_test.dart | 테스트 파일이라 달지 않음 | analyze info 1건(생성자), 9건 통과 확인 |

`flutter analyze lib/core/tts test/core/tts`: 6 issues(info). 주석 추가 뒤에도 6건 그대로(주석으로 생긴 issue 없음). `flutter test test/core/tts`: 9건 통과.

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | voice_guide.dart say | 문장은 앱 내부 상수(TASK-18, 51)에서 옴. 외부 입력 없음 |
| XSS 등 출력 처리 | 해당 없음 |  | captions는 Flutter Text로 표시될 예정(HTML 아님) |
| 인증 / 인가 | 해당 없음 |  |  |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 출력 없음 |
| 새 의존성 | 통과 |  | flutter_tts, flutter_riverpod 기존 추가분만 사용 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | voice_guide.dart say | `_lastSaid[text] = now`가 세 분기에 반복되지만 분기별 의미가 달라 허용 |
| 함수 길이 | 통과 |  | 최장 say 약 30줄 |
| 이름 | 통과 |  |  |
| 죽은 코드 | 통과 |  |  |
| 린트(저장소 기준 0 issues) | 문제 | 아래 FIX | 6건 모두 `new(...)` 문법과 private named parameter(`this._engine`)로 named 이름을 유지한 채 해결됨을 scratch 복사본에서 확인(analyze 0건, 테스트 9건 통과) |
| 테스트가 인수 조건을 검증하는가 | 통과 | voice_guide_test.dart | Task 표 8건 + 음성 모드 captions 비어 있음 1건. 엔진 예외, init 전 동시 say 경로는 테스트 없음(권고) |
| 계약 대조 | 통과(경미 차이) |  | 시그니처 모두 일치. 차이: (1) 계약 밖 `dispose()` 추가 (2) say false가 쿨다운 외에 "대기 칸 high에 밀린 normal"에서도 나옴. 아래 Impl 판단 평가 참고 |

## Impl 판단 평가
| 항목 | 평가 |
|---|---|
| 쿨다운 기록 시점(받아들인 시각) | 수용. 겹침 시나리오에서 재생 시작 기준과 거의 같음. 단 대기 칸에서 다른 문장에 밀려 버려진 문장이나 stopAll로 비워진 문장도 5초 쿨다운에 걸려, say는 true였는데 실제로는 안 들리는 교정이 생길 수 있음. 규칙 문구("마지막으로 말한 시각")와 미세하게 다르므로 Task에 "받아들인 시각 기준"을 명시하도록 보충 권고 |
| say false 조건 | 쿨다운 + high 대기 중 normal. 후자도 "버림"이므로 false가 합리적. 계약 문구가 쿨다운만 적어 Task 계약에 "high에 밀린 normal도 false" 한 줄 보충 권고 |
| 글자 모드 쿨다운 | 규칙대로 적용, 테스트 있음. 통과 |
| captions broadcast로 init 시점 unavailableNotice 놓침 | 계약 쪽 문제. provider 생성 시 init이 돌고, voiceGuideProvider를 TASK-27이 먼저 읽고 TASK-29/51 글자 UI가 isKoreanAvailable 응답 뒤에 구독하면 안내를 못 받음(인수 조건 "한 번 보인다" 실패 가능). 이 Task의 FIX가 아니라 Task 보충 권고: 예) `String? get pendingNotice`/`bool get noticeShown` 같은 보관 값, 또는 captions가 늦은 구독자에게 마지막 알림을 한 번 재생. TASK-29, 51 착수 전 결정 필요 |
| 엔진 예외 처리 | isKoreanAvailable 예외 시 글자 모드로 안전하게 전환, 수용. speak 예외는 조용히 삼켜 계속 진행, 수용하되 기록이 없어 Sentry 단계에서 안 보임. 엔진이 계속 실패하면 음성도 글자도 안 나옴(메모). stop() 예외는 stopAll 밖으로 나가며 dispose에서 unawaited라 zone 미처리 오류가 될 수 있음(권고: stopAll에서 try/catch) |
| stopAll 뒤 isSpeaking | stopAll은 `_speaking`을 직접 내리지 않고 speak Future 완료에 맡김. flutter_tts 4.2.5 Android는 stop 시 대기 중인 speakResult를 success(0)으로 완료하므로 곧 false가 됨(플러그인 소스 확인). 수용 |
| Android isLanguageAvailable 반환값 | Android는 `>= LANG_AVAILABLE` Boolean 반환(LANG_MISSING_DATA는 false). 엔진 초기화 전 호출은 플러그인이 대기열에 넣음. `== true \|\| == 1` 처리 수용 |
| 계약에 없는 dispose() | provider의 "dispose 시 stopAll"을 이행하고 StreamController를 닫는 용도라 수용. 다만 공개 API가 늘었으므로 Task 계약 표에 추가 권고. dispose 뒤 say(글자 모드)는 닫힌 스트림 add로 StateError(메모) |

## FIX 항목 (Impl로 회귀)
- [ ] app/lib/core/tts/tts_engine.dart:23 — `FlutterTtsEngine({FlutterTts? tts})` → `new({FlutterTts? tts})`
- [ ] app/lib/core/tts/voice_guide.dart:22 — `const _Pending(this.text, this.priority);` → `const new(this.text, this.priority);`
- [ ] app/lib/core/tts/voice_guide.dart:30-37 — 생성자를 아래로 교체(named 이름 `engine`, `cooldown` 유지. private named parameter라 호출부 변경 없음)
  ```dart
  new({
    required this._engine,
    this._cooldown = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  ```
- [ ] app/test/core/tts/voice_guide_test.dart:8 — `FakeEngine({this.korean = true});` → `new({this.korean = true});`
- 확인: `flutter analyze lib/core/tts test/core/tts` 0 issues, `flutter test` 전체 통과
- (선택 권고, FIX 필수 아님) voice_guide.dart stopAll의 `_engine.stop()`을 try/catch로 감싸기

## Task 보충 권고 (오케스트레이터)
- TASK-11 계약에 `dispose()`, say false 조건(high에 밀린 normal), 쿨다운 기준 시각(받아들인 시각) 명시
- unavailableNotice 늦은 구독 문제: VoiceGuide에 알림 보관 값을 추가하거나 TASK-29/51이 `voiceAvailable == false`를 보고 안내를 직접 띄우도록 계약 결정

## PEER_REVIEW 사유
- 없음

## 재검토 (2026-11-13, FIX 재작업 후)

- 최종 판정: PASS

### 이전 FIX 해소
| 항목 | 결과 |
|---|---|
| tts_engine.dart 생성자 `new(...)` | 해소 |
| voice_guide.dart `_Pending` `const new` | 해소 |
| voice_guide.dart 생성자 private named parameter(`this._engine`, `this._cooldown`) | 해소. 호출부 `engine:`, `cooldown:`, `clock:` 유지(테스트로 확인) |
| voice_guide_test.dart FakeEngine 생성자 | 해소 |
| `flutter analyze lib/core/tts test/core/tts` | No issues found |
| `flutter test test/core/tts` / 전체 | 14건 / 135건 통과 |
| (권고) stopAll의 stop 예외 무시 | 반영, 테스트 2건(stopAll 직접, dispose 경유) |

### 추가 발췌(QA-TASK-11 반영 4줄) 대조
| 발췌 | 결과 |
|---|---|
| 쿨다운은 받아들인 시각 기준 | 일치 |
| say false: 쿨다운, high 대기 중 normal, dispose 이후 | 일치 |
| `dispose()` 공개, dispose 뒤 say 무동작 false, stop 예외 무시 | 일치, 두 번 dispose 안전 |
| 늦은 구독은 소비 쪽(TASK-29, 51)이 voiceAvailable로 처리 | 이 Task 범위 밖. `voiceAvailable` getter 제공 확인 |

### 경쟁 조건 검토
| 시나리오 | 결과 | 근거 |
|---|---|---|
| init 대기 중 dispose(글자 모드) | 안전 | `_doInit`이 `!_disposed`일 때만 알림 add, say가 init 뒤 `_disposed` 재확인 후 동기 구간에서 add. 닫힌 스트림 쓰기 없음 |
| init 대기 중 dispose(음성 모드) | 안전 | say false, speak 호출 0회 |
| speak 진행 중 dispose | 안전 | stopAll이 await 전에 `_pending`을 동기로 비움. speak 완료 뒤 루프 종료, `isSpeaking` false. 대기 문장 재생 안 됨 |
| dispose 두 번 | 안전 | `_disposed` 가드 |

위 세 시나리오는 QA가 임시 테스트(Completer로 init, speak 완료 시점 제어)로 실행해 통과를 확인했고, 임시 파일은 삭제함. 저장소 테스트에는 없으므로 회귀 방지용으로 추가하면 좋음(권고, 필수 아님).

### 메모
- stopAll(dispose 아님) 직후 들어온 say는 진행 중 speak가 끝난 뒤 재생된다. 의도된 동작(멈춘 뒤 새 안내)으로 수용.
- 헤더/푸터: 두 lib 파일 푸터를 재검토 결과로 갱신(계약 반영 문구). 테스트 파일은 기존대로 달지 않음.

### PEER_REVIEW 사유
- 없음
