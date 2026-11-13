import 'package:atheleo/pose/angle/moving_average.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MovingAverage (시간 기준 창)', () {
    test('30fps 창: 5개가 평균된다', () {
      final avg = MovingAverage();
      final times = [0, 33, 67, 100, 133, 167];
      final results = <double>[];
      for (var i = 0; i < times.length; i++) {
        results.add(avg.add(i + 1.0, times[i]));
      }
      expect(results[4], 3);
      expect(results[5], 4);
      expect(avg.length, 5);
    });

    test('15fps 창: 3개가 평균된다', () {
      final avg = MovingAverage();
      final times = [0, 67, 133, 200];
      final values = [10.0, 20.0, 30.0, 40.0];
      late double last;
      for (var i = 0; i < times.length; i++) {
        last = avg.add(values[i], times[i]);
      }
      expect(last, 30);
      expect(avg.length, 3);
    });

    test('최소 1프레임은 항상 남는다', () {
      final avg = MovingAverage()..add(10, 0);
      expect(avg.add(50, 1000), 50);
      expect(avg.length, 1);
    });

    test('reset 후 처음부터 다시 쌓인다', () {
      final avg = MovingAverage()
        ..add(1, 0)
        ..add(2, 33)
        ..reset();
      expect(avg.length, 0);
      expect(avg.add(7, 0), 7);
      expect(avg.length, 1);
    });

    test('유한하지 않은 값은 버리고 현재 평균을 돌려준다', () {
      final avg = MovingAverage()..add(10, 0);
      expect(avg.add(double.nan, 33), 10);
      expect(avg.add(double.infinity, 66), 10);
      expect(avg.length, 1);
    });

    test('비어 있을 때 유한하지 않은 값이면 0', () {
      expect(MovingAverage().add(double.nan, 0), 0);
    });

    test('windowMs가 1 미만이면 ArgumentError', () {
      expect(() => MovingAverage(windowMs: 0), throwsArgumentError);
    });

    test('타임스탬프가 직전보다 작으면 ArgumentError', () {
      final avg = MovingAverage()..add(1, 100);
      expect(() => avg.add(2, 50), throwsArgumentError);
    });

    test('같은 타임스탬프는 허용된다', () {
      final avg = MovingAverage()..add(1, 100);
      expect(avg.add(3, 100), 2);
    });

    test('경계: 차이가 windowMs와 같으면 빠진다', () {
      final avg = MovingAverage()..add(10, 0);
      expect(avg.add(20, 150), 20);
      expect(avg.length, 1);
    });
  });
}
