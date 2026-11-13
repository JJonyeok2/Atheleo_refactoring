import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/score/rep_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoreRep', () {
    test('오류 없음 (F-05)', () {
      expect(scoreRep(errors: [], durationMs: 1500), 100);
    });
    test('깊이 부족 (F-05)', () {
      expect(scoreRep(errors: [PoseErrorCode.sqShallow], durationMs: 1500), 75);
    });
    test('여러 오류 합산', () {
      expect(
        scoreRep(
          errors: [PoseErrorCode.puShallow, PoseErrorCode.puHipSag],
          durationMs: 1500,
        ),
        45,
      );
      expect(scoreRep(errors: [PoseErrorCode.puHipPike], durationMs: 1500), 80);
    });
    test('템포 저하', () {
      expect(scoreRep(errors: [], durationMs: 3001), 95);
      expect(scoreRep(errors: [], durationMs: 3000), 100);
    });
    test('스쿼트 감점', () {
      expect(
        scoreRep(
          errors: [
            PoseErrorCode.sqShallow,
            PoseErrorCode.sqTorsoLean,
            PoseErrorCode.sqHeelLift,
          ],
          durationMs: 4000,
        ),
        35,
      );
    });
    test('0점 하한', () {
      expect(
        scoreRep(
          errors: List.filled(5, PoseErrorCode.puHipSag),
          durationMs: 1500,
        ),
        0,
      );
    });
  });

  test('등급 경계 (F-05, F-07)', () {
    expect(gradeFor(85), ScoreGrade.good);
    expect(gradeFor(84), ScoreGrade.fair);
    expect(gradeFor(60), ScoreGrade.fair);
    expect(gradeFor(59), ScoreGrade.poor);
  });

  test('평균', () {
    expect(averageScore([100, 75, 80]), 85);
    expect(averageScore([]), 0);
  });
}
