import 'package:atheleo/core/tts/voice_guide.dart';
import 'package:atheleo/features/workout/domain/voice_cues.dart';
import 'package:atheleo/features/workout/domain/workout_session_controller.dart';
import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:flutter_test/flutter_test.dart';

RepResult _rep(List<PoseErrorCode> errors) => RepResult(
  repIndex: 1,
  score: 80,
  minAngle: 90,
  durationMs: 2000,
  errors: errors,
);

void main() {
  group('cuesForEvent', () {
    test('횟수 안내', () {
      expect(cuesForEvent(RepCounted(_rep(const []), 3)), const [
        VoiceCue('3회'),
      ]);
    });

    test('오류 교정 안내 (F-06)', () {
      expect(
        cuesForEvent(RepCounted(_rep(const [PoseErrorCode.sqShallow]), 4)),
        const [
          VoiceCue('4회'),
          VoiceCue('더 깊이 앉으세요.', priority: VoicePriority.high),
        ],
      );
    });

    test('오류가 여러 개여도 첫 번째 오류만 말한다', () {
      final cues = cuesForEvent(
        RepCounted(
          _rep(const [PoseErrorCode.sqShallow, PoseErrorCode.puHipSag]),
          2,
        ),
      );
      expect(cues, hasLength(2));
      expect(cues.last.text, PoseErrorCode.sqShallow.voiceMessage);
    });

    test('세트 완료 (F-08)', () {
      expect(cuesForEvent(const SetCompleted(1, 30)), const [
        VoiceCue('세트 완료, 30초 쉬세요', priority: VoicePriority.high),
      ]);
    });

    test('휴식 종료 3초 전 (F-06)', () {
      expect(cuesForEvent(const RestEndingSoon(3)), const [
        VoiceCue('3초 뒤 다음 세트를 시작해요', priority: VoicePriority.high),
      ]);
    });

    test('다음 세트 (F-08)', () {
      expect(cuesForEvent(const NextSetStarted(2)), const [
        VoiceCue('다음 세트를 시작하세요', priority: VoicePriority.high),
      ]);
    });

    test('운동 종료', () {
      final cues = cuesForEvent(const WorkoutFinished());
      expect(cues, hasLength(1));
      expect(cues.single.priority, VoicePriority.high);
    });

    test('마지막 세트: RepCounted 다음 WorkoutFinished에 쉬세요 문구 없음', () {
      final all = [
        ...cuesForEvent(RepCounted(_rep(const []), 10)),
        ...cuesForEvent(const WorkoutFinished()),
      ];
      expect(all.where((c) => c.text.contains('쉬세요')), isEmpty);
    });

    test('부분 반복 (F-03)', () {
      expect(cuesForEvent(const PartialRepNoticed(1)), const [
        VoiceCue('더 내려가세요'),
      ]);
    });

    test('같은 이벤트를 반복해도 같은 문장(쿨다운은 VoiceGuide 몫)', () {
      expect(
        cuesForEvent(const PartialRepNoticed(1)),
        cuesForEvent(const PartialRepNoticed(2)),
      );
    });
  });

  group('VoiceCue', () {
    test('값 비교와 기본 우선순위', () {
      expect(const VoiceCue('a'), const VoiceCue('a'));
      expect(const VoiceCue('a').hashCode, const VoiceCue('a').hashCode);
      expect(const VoiceCue('a').priority, VoicePriority.normal);
      expect(
        const VoiceCue('a'),
        isNot(const VoiceCue('a', priority: VoicePriority.high)),
      );
      expect(const VoiceCue('a'), isNot(const VoiceCue('b')));
    });
  });

  group('VoiceCues', () {
    test('고정 문구 상수 (F-03, F-06)', () {
      expect(VoiceCues.noPerson.text, '카메라 앞에 서 주세요');
      expect(VoiceCues.noPerson.priority, VoicePriority.high);
      expect(VoiceCues.slowDown, const VoiceCue('조금 더 천천히'));
      expect(VoiceCues.slowDown.priority, VoicePriority.normal);
      expect(
        VoiceCues.askResume,
        const VoiceCue('이어서 할까요?', priority: VoicePriority.high),
      );
    });
  });
}
