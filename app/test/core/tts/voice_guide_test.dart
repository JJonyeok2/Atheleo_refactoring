import 'dart:async';

import 'package:atheleo/core/tts/tts_engine.dart';
import 'package:atheleo/core/tts/voice_guide.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEngine implements TtsEngine {
  new({this.korean = true});
  final bool korean;
  final List<String> spoken = [];
  final List<Completer<void>> completers = [];
  int stopCount = 0;
  bool stopThrows = false;
  bool autoComplete = false;

  @override
  Future<bool> isKoreanAvailable() async => korean;

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    if (autoComplete) return Future.value();
    final c = Completer<void>();
    completers.add(c);
    return c.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (stopThrows) throw StateError('stop 실패');
  }

  Future<void> finishCurrent() async {
    completers.last.complete();
    await pump();
  }
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  late DateTime now;
  late FakeEngine engine;
  late VoiceGuide guide;

  VoiceGuide make(FakeEngine e) {
    engine = e;
    return VoiceGuide(engine: e, clock: () => now);
  }

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    guide = make(FakeEngine());
  });

  test('같은 문장 5초 안 반복 안 함 (F-06)', () async {
    engine.autoComplete = true;
    await guide.init();
    expect(await guide.say('더 깊이 앉으세요.'), isTrue);
    await pump();
    now = now.add(const Duration(seconds: 3));
    expect(await guide.say('더 깊이 앉으세요.'), isFalse);
    expect(engine.spoken.length, 1);
  });

  test('5초 지나면 다시 말함', () async {
    engine.autoComplete = true;
    await guide.say('더 깊이 앉으세요.');
    await pump();
    now = now.add(const Duration(milliseconds: 5100));
    expect(await guide.say('더 깊이 앉으세요.'), isTrue);
    await pump();
    expect(engine.spoken.length, 2);
  });

  test('겹침 없음 (F-06)', () async {
    await guide.say('첫째');
    expect(guide.isSpeaking, isTrue);
    expect(await guide.say('둘째'), isTrue);
    await pump();
    expect(engine.spoken, ['첫째']);
    await engine.finishCurrent();
    expect(engine.spoken, ['첫째', '둘째']);
    await engine.finishCurrent();
    expect(guide.isSpeaking, isFalse);
  });

  test('대기 칸은 최신 1개', () async {
    await guide.say('X');
    await guide.say('A');
    await guide.say('B');
    await engine.finishCurrent();
    expect(engine.spoken, ['X', 'B']);
  });

  test('high는 normal로 안 바뀜', () async {
    await guide.say('X');
    await guide.say('H', priority: VoicePriority.high);
    await guide.say('N');
    await engine.finishCurrent();
    expect(engine.spoken, ['X', 'H']);
  });

  test('stopAll', () async {
    await guide.say('X');
    await guide.say('A');
    await guide.stopAll();
    expect(engine.stopCount, 1);
    await engine.finishCurrent();
    expect(engine.spoken, ['X']);
    expect(guide.isSpeaking, isFalse);
  });

  test('한국어 음성 없음 (F-06)', () async {
    guide = make(FakeEngine(korean: false));
    final captions = <String>[];
    guide.captions.listen(captions.add);
    expect(guide.voiceAvailable, isNull);
    expect(await guide.say('1회'), isTrue);
    expect(await guide.say('2회'), isTrue);
    await pump();
    expect(engine.spoken, isEmpty);
    expect(captions, [VoiceGuide.unavailableNotice, '1회', '2회']);
    expect(guide.voiceAvailable, isFalse);
  });

  test('안내는 한 번만 (F-06)', () async {
    guide = make(FakeEngine(korean: false));
    final captions = <String>[];
    guide.captions.listen(captions.add);
    await guide.init();
    await guide.init();
    await guide.say('가');
    now = now.add(const Duration(seconds: 3));
    expect(await guide.say('가'), isFalse);
    await guide.say('나');
    await pump();
    expect(captions.where((c) => c == VoiceGuide.unavailableNotice).length, 1);
    expect(captions, [VoiceGuide.unavailableNotice, '가', '나']);
  });

  test('음성 모드에서는 captions 비어 있음', () async {
    engine.autoComplete = true;
    final captions = <String>[];
    guide.captions.listen(captions.add);
    await guide.say('가');
    await pump();
    expect(captions, isEmpty);
    expect(guide.voiceAvailable, isTrue);
  });

  test('dispose 뒤 say는 false, 무동작', () async {
    engine.autoComplete = true;
    await guide.init();
    guide.dispose();
    await pump();
    expect(await guide.say('가'), isFalse);
    await pump();
    expect(engine.spoken, isEmpty);
  });

  test('글자 모드에서도 dispose 뒤 say는 false', () async {
    guide = make(FakeEngine(korean: false));
    await guide.init();
    guide.dispose();
    expect(await guide.say('가'), isFalse);
  });

  test('stopAll에서 engine.stop 예외가 나도 오류 없음', () async {
    engine.stopThrows = true;
    await guide.say('X');
    await guide.say('A');
    await guide.stopAll();
    expect(engine.stopCount, 1);
    await engine.finishCurrent();
    expect(engine.spoken, ['X']);
  });

  test('dispose 중 stop 예외도 미처리 오류가 없다', () async {
    engine.stopThrows = true;
    await guide.say('X');
    guide.dispose();
    await pump();
    expect(engine.stopCount, 1);
  });

  test('호출부 이름 engine:, cooldown:, clock: 유지', () async {
    final g = VoiceGuide(
      engine: FakeEngine()..autoComplete = true,
      cooldown: const Duration(seconds: 1),
      clock: () => now,
    );
    expect(await g.say('가'), isTrue);
    now = now.add(const Duration(milliseconds: 1100));
    expect(await g.say('가'), isTrue);
  });
}
