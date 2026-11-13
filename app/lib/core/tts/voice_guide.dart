// [파일] 음성 안내 서비스(VoiceGuide): 같은 문장 쿨다운, 겹침 방지
//   (대기 칸 1개), 한국어 음성이 없으면 글자 안내(captions)로 대체.
//   voiceGuideProvider, voiceCaptionProvider 제공.
// [Spec] F-06 음성 안내 / [Task] TASK-11
// [의존] tts_engine.dart, flutter_riverpod (환경 변수 사용 안 함)

import 'dart:async';

import 'package:atheleo/core/tts/tts_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 안내 우선순위. high는 대기 칸에서 normal에 밀리지 않는다.
enum VoicePriority {
  /// 일반 안내.
  normal,

  /// 먼저 말해야 하는 안내.
  high,
}

class _Pending {
  const new(this.text, this.priority);
  final String text;
  final VoicePriority priority;
}

/// 음성 안내: 쿨다운, 겹침 방지, 한국어 음성이 없으면 글자 안내로 대체.
class VoiceGuide {
  /// [clock]은 테스트용 시계.
  new({
    required this._engine,
    this._cooldown = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// 글자 모드 전환 시 한 번 알리는 문구.
  static const String unavailableNotice =
      '이 기기에서는 음성 안내를 쓸 수 없어 글자로 안내합니다';

  final TtsEngine _engine;
  final Duration _cooldown;
  final DateTime Function() _clock;
  final StreamController<String> _captions =
      StreamController<String>.broadcast();
  final Map<String, DateTime> _lastSaid = {};

  Future<void>? _initFuture;
  bool? _voiceAvailable;
  bool _speaking = false;
  bool _disposed = false;
  _Pending? _pending;

  /// 지금 말하는 중인지.
  bool get isSpeaking => _speaking;
  /// 한국어 음성 사용 가능 여부. init 전에는 null.
  bool? get voiceAvailable => _voiceAvailable;
  /// 글자 안내 스트림(글자 모드에서만 값이 나온다).
  Stream<String> get captions => _captions.stream;

  /// 엔진의 한국어 지원 여부를 한 번 확인한다.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    var available = false;
    try {
      available = await _engine.isKoreanAvailable();
    } on Object {
      available = false;
    }
    _voiceAvailable = available;
    if (!available && !_disposed) _captions.add(unavailableNotice);
  }

  /// 재생, 대기, 글자 안내 중 하나로 처리되면 true, 버리면 false.
  Future<bool> say(String text,
      {VoicePriority priority = VoicePriority.normal}) async {
    if (_disposed) return false;
    await init();
    if (_disposed) return false;
    final now = _clock();
    final last = _lastSaid[text];
    if (last != null && now.difference(last) < _cooldown) return false;

    if (_voiceAvailable != true) {
      _lastSaid[text] = now;
      _captions.add(text);
      return true;
    }

    if (_speaking) {
      final p = _pending;
      if (p != null &&
          p.priority == VoicePriority.high &&
          priority == VoicePriority.normal) {
        return false;
      }
      _lastSaid[text] = now;
      _pending = _Pending(text, priority);
      return true;
    }

    _lastSaid[text] = now;
    _speaking = true;
    unawaited(_playLoop(text));
    return true;
  }

  Future<void> _playLoop(String first) async {
    String? next = first;
    while (next != null) {
      try {
        await _engine.speak(next);
      } on Object {
        // 엔진 오류는 다음 문장 재생을 막지 않는다.
      }
      next = _pending?.text;
      _pending = null;
    }
    _speaking = false;
  }

  /// 재생을 멈추고 대기 칸을 비운다.
  Future<void> stopAll() async {
    _pending = null;
    try {
      await _engine.stop();
    } on Object {
      // 멈추기 실패는 무시한다.
    }
  }

  /// 정리한다.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stopAll());
    unawaited(_captions.close());
  }
}

/// 음성 안내 provider.
final voiceGuideProvider = Provider<VoiceGuide>((ref) {
  final guide = VoiceGuide(engine: FlutterTtsEngine());
  unawaited(guide.init());
  ref.onDispose(guide.dispose);
  return guide;
});

/// 글자 안내 스트림 provider.
final voiceCaptionProvider = StreamProvider<String>(
    (ref) => ref.watch(voiceGuideProvider).captions);

// [QA] 2026-11-13 PASS (재검토)
// [보안] 외부 입력 없음. 엔진 예외는 삼키고 로그를 남기지 않는다.
// [유지보수] 쿨다운은 "받아들인 시각" 기준이라 대기 칸에서 밀려
//   재생되지 않은 문장도 5초 쿨다운에 걸린다(Task 추가 발췌에 명시).
//   captions는 broadcast라 init 시점의 unavailableNotice를 늦게 구독한
//   쪽은 받지 못한다. 소비 쪽(TASK-29, 51)이 voiceAvailable == false로
//   직접 안내한다.
//   dispose()는 공개 계약(Task 추가 발췌). dispose 뒤 say는 false를
//   돌려주고 아무것도 하지 않는다. init 대기 중, speak 진행 중 dispose도
//   _disposed 재확인과 대기 칸 비우기로 닫힌 스트림에 쓰지 않는다.
//   stopAll의 engine.stop 예외는 잡아서 무시한다.
// [FIX 반영] 린트 6건(new, private named parameter), dispose 뒤 say false,
//   stop 예외 무시 반영.
