import 'package:atheleo/features/workout/domain/tracking_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// fromMs부터 toMs까지 fps 간격으로 결과를 넣고 나온 신호를 모은다.
List<(int, TrackingSignal)> _feed(
  TrackingMonitor monitor, {
  required int fromMs,
  required int toMs,
  required double fps,
  bool hasPerson = true,
}) {
  final signals = <(int, TrackingSignal)>[];
  final count = ((toMs - fromMs) / 1000 * fps).round();
  for (var i = 0; i <= count; i++) {
    final t = fromMs + (i * 1000 / fps).round();
    for (final s in monitor.onResult(timestampMs: t, hasPerson: hasPerson)) {
      signals.add((t, s));
    }
  }
  return signals;
}

void main() {
  group('사람 미검출', () {
    test('2초 미검출이면 2000ms에 personLost', () {
      final m = TrackingMonitor();
      for (var t = 0; t <= 1900; t += 100) {
        expect(m.onResult(timestampMs: t, hasPerson: false), isEmpty);
      }
      expect(m.isPersonLost, isFalse);
      expect(m.onResult(timestampMs: 2000, hasPerson: false), [
        TrackingSignal.personLost,
      ]);
      expect(m.isPersonLost, isTrue);
    });

    test('personLost는 한 번만 나온다', () {
      final m = TrackingMonitor()
        ..onResult(timestampMs: 0, hasPerson: false)
        ..onResult(timestampMs: 2000, hasPerson: false);
      expect(m.onResult(timestampMs: 2500, hasPerson: false), isEmpty);
    });

    test('다시 잡히면 personReturned 한 번', () {
      final m = TrackingMonitor()
        ..onResult(timestampMs: 0, hasPerson: false)
        ..onResult(timestampMs: 2000, hasPerson: false);
      expect(m.onResult(timestampMs: 3000, hasPerson: true), [
        TrackingSignal.personReturned,
      ]);
      expect(m.isPersonLost, isFalse);
      expect(m.onResult(timestampMs: 3100, hasPerson: true), isEmpty);
    });

    test('짧은 끊김은 무시한다', () {
      final m = TrackingMonitor()..onResult(timestampMs: 0, hasPerson: false);
      expect(m.onResult(timestampMs: 1000, hasPerson: false), isEmpty);
      expect(m.onResult(timestampMs: 1100, hasPerson: true), isEmpty);
      expect(m.isPersonLost, isFalse);
      // 끊김 시작 시각이 새로 잡힌다.
      expect(m.onResult(timestampMs: 1200, hasPerson: false), isEmpty);
      expect(m.onResult(timestampMs: 3100, hasPerson: false), isEmpty);
      expect(m.onResult(timestampMs: 3200, hasPerson: false), [
        TrackingSignal.personLost,
      ]);
    });
  });

  group('저사양 전환', () {
    test('minFps 이름 인자가 임계값으로 적용된다', () {
      final m = TrackingMonitor(minFps: 5);
      expect(_feed(m, fromMs: 0, toMs: 12000, fps: 8), isEmpty);
      final strict = TrackingMonitor(minFps: 9);
      final signals = _feed(strict, fromMs: 0, toMs: 12000, fps: 8);
      expect(signals.map((e) => e.$2), [TrackingSignal.switchToLite]);
    });

    test('8fps면 10초 이후 switchToLite 한 번', () {
      final m = TrackingMonitor();
      final signals = _feed(m, fromMs: 0, toMs: 12000, fps: 8);
      expect(signals.map((e) => e.$2), [TrackingSignal.switchToLite]);
      expect(signals.single.$1, greaterThanOrEqualTo(10000));
      expect(m.switchedToLite, isTrue);
    });

    test('10초가 지나기 전에는 판단하지 않는다', () {
      final m = TrackingMonitor();
      expect(_feed(m, fromMs: 0, toMs: 9800, fps: 8), isEmpty);
    });

    test('25fps면 신호가 없다', () {
      final m = TrackingMonitor();
      expect(_feed(m, fromMs: 0, toMs: 12000, fps: 25), isEmpty);
      expect(m.switchedToLite, isFalse);
    });

    test('멈췄다 돌아오면 reset으로 측정이 초기화된다 (F-01)', () {
      List<TrackingSignal> scenario({required bool withReset}) {
        final m = TrackingMonitor();
        final all = <TrackingSignal>[
          ..._feed(m, fromMs: 0, toMs: 5000, fps: 25).map((e) => e.$2),
        ];
        if (withReset) m.reset();
        all.addAll(
          _feed(m, fromMs: 35000, toMs: 46000, fps: 25).map((e) => e.$2),
        );
        return all;
      }

      expect(scenario(withReset: true), isEmpty);
      expect(scenario(withReset: false), [TrackingSignal.switchToLite]);
    });

    test('reset 뒤 미검출은 reset부터 다시 센다', () {
      final m = TrackingMonitor()..onResult(timestampMs: 0, hasPerson: false);
      expect(m.onResult(timestampMs: 1500, hasPerson: false), isEmpty);
      m.reset();
      expect(m.onResult(timestampMs: 1600, hasPerson: false), isEmpty);
      expect(m.onResult(timestampMs: 3000, hasPerson: false), isEmpty);
      expect(m.onResult(timestampMs: 3600, hasPerson: false), [
        TrackingSignal.personLost,
      ]);
    });

    test('lite로 바뀐 뒤 reset해도 lite 유지, 신호는 다시 없다', () {
      final m = TrackingMonitor();
      _feed(m, fromMs: 0, toMs: 12000, fps: 8);
      expect(m.switchedToLite, isTrue);
      m.reset();
      expect(_feed(m, fromMs: 20000, toMs: 32000, fps: 8), isEmpty);
      expect(m.switchedToLite, isTrue);
    });
  });
}
