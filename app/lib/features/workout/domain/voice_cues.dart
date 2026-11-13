// [파일] 운동 이벤트별 음성 문구와 우선순위 매핑(순수 함수).
//        재생과 쿨다운은 VoiceGuide(TASK-11) 몫.
// [Spec] F-03, F-06, F-08 / [Task] TASK-18
// [의존] 없음 (환경 변수 사용 안 함)

import 'package:atheleo/core/tts/voice_guide.dart';
import 'package:atheleo/features/workout/domain/workout_session_controller.dart';
import 'package:flutter/foundation.dart';

/// 말할 문구 하나와 우선순위.
@immutable
class VoiceCue {
  /// 문구를 만든다.
  const new(this.text, {this.priority = VoicePriority.normal});

  /// 말할 문장.
  final String text;

  /// 우선순위.
  final VoicePriority priority;

  @override
  bool operator ==(Object other) =>
      other is VoiceCue && other.text == text && other.priority == priority;

  @override
  int get hashCode => Object.hash(text, priority);

  @override
  String toString() => 'VoiceCue($text, $priority)';
}

/// 이벤트에 맞는 음성 문구(순서대로 말한다). 재생과 쿨다운은 VoiceGuide 몫.
List<VoiceCue> cuesForEvent(WorkoutEvent event) {
  return switch (event) {
    RepCounted(:final rep, :final repsInSet) => [
      VoiceCue('$repsInSet회'),
      if (rep.errors.isNotEmpty)
        VoiceCue(rep.errors.first.voiceMessage, priority: VoicePriority.high),
    ],
    SetCompleted(:final restSec) => [
      VoiceCue('세트 완료, $restSec초 쉬세요', priority: VoicePriority.high),
    ],
    RestEndingSoon(:final remainingSec) => [
      VoiceCue('$remainingSec초 뒤 다음 세트를 시작해요', priority: VoicePriority.high),
    ],
    NextSetStarted() => const [
      VoiceCue('다음 세트를 시작하세요', priority: VoicePriority.high),
    ],
    PartialRepNoticed() => const [VoiceCue('더 내려가세요')],
    WorkoutFinished() => const [
      VoiceCue('운동을 마쳤어요. 수고하셨어요.', priority: VoicePriority.high),
    ],
  };
}

/// 이벤트가 아닌 고정 문구.
abstract final class VoiceCues {
  /// 사람이 안 보일 때.
  static const VoiceCue noPerson = VoiceCue(
    '카메라 앞에 서 주세요',
    priority: VoicePriority.high,
  );

  /// 이어서 하기 확인.
  static const VoiceCue askResume = VoiceCue(
    '이어서 할까요?',
    priority: VoicePriority.high,
  );

  /// 너무 빠른 반복(TASK-27이 TooFastRep을 받을 때 직접 사용).
  static const VoiceCue slowDown = VoiceCue('조금 더 천천히');
}

// [QA] 2026-11-13 PASS
// [보안] 외부 입력 없음. 고정 문자열과 정수 보간뿐이라 주입 경로 없음.
// [유지보수] RepCounted 뒤 교정(high)이 재생 중 대기 칸의 횟수(normal)를
//   밀어낼 수 있음(TASK-11 대기 칸 규칙). 같은 오류가 매 반복이면 교정은
//   5초 쿨다운으로 격회 재생됨. 체감은 TASK-27과 사용자 검증에서 확인.
