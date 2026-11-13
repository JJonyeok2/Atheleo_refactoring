// [파일] TTS 엔진 추상화(TtsEngine)와 flutter_tts 기반 구현
//   (FlutterTtsEngine, ko-KR, 말하기 완료까지 대기).
// [Spec] F-06 음성 안내 / [Task] TASK-11
// [의존] flutter_tts (환경 변수 사용 안 함)

import 'package:flutter_tts/flutter_tts.dart';

/// TTS 엔진 추상화. 테스트에서는 가짜 구현을 쓴다.
abstract class TtsEngine {
  /// 기기에 한국어 음성이 있는지.
  Future<bool> isKoreanAvailable();

  /// 말하기가 끝나면 완료되는 Future.
  Future<void> speak(String text);

  /// 재생 중인 음성을 멈춘다.
  Future<void> stop();
}

/// flutter_tts 기반 구현(ko-KR).
class FlutterTtsEngine implements TtsEngine {
  /// [tts]를 주지 않으면 기본 FlutterTts를 쓴다.
  new({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  static const String _language = 'ko-KR';
  final FlutterTts _tts;
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(_language);
  }

  @override
  Future<bool> isKoreanAvailable() async {
    final result = await _tts.isLanguageAvailable(_language);
    return result == true || result == 1;
  }

  @override
  Future<void> speak(String text) async {
    await _configure();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

// [QA] 2026-11-13 PASS (재검토, 린트 0건)
// [보안] 외부 입력 없음. 안내 문장은 앱 내부 상수에서만 온다.
// [유지보수] Android isLanguageAvailable은 bool(>= LANG_AVAILABLE)을 돌려준다.
//   `== 1`은 다른 플랫폼 대비용. 언어 설정(_configure)은 첫 speak 때 하므로
//   첫 안내만 지연이 조금 늘 수 있다.
