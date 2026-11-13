// [파일] 반복 1회 점수 계산, 세트 평균, 점수 등급 변환(순수 함수).
// [Spec] F-05, F-07 점수 색상 기준 / [Task] TASK-12
// [의존] pose/judge/pose_error.dart (환경 변수 사용 안 함)

import 'package:atheleo/pose/judge/pose_error.dart';

/// 점수 등급. 색상 매핑은 화면(TASK-23)이 맡는다.
enum ScoreGrade {
  /// 85 이상.
  good,

  /// 60 이상 85 미만.
  fair,

  /// 60 미만.
  poor,
}

const int _maxScore = 100;
const int _tempoLimitMs = 3000;
const int _tempoPenalty = 5;

const Map<PoseErrorCode, int> _penalties = {
  PoseErrorCode.puShallow: 25,
  PoseErrorCode.sqShallow: 25,
  PoseErrorCode.puHipSag: 30,
  PoseErrorCode.puHipPike: 20,
  PoseErrorCode.sqTorsoLean: 20,
  PoseErrorCode.sqHeelLift: 15,
};

/// 완료된 반복 1회의 점수(0~100). 부분 반복은 이 함수로 오지 않는다.
int scoreRep({required List<PoseErrorCode> errors, required int durationMs}) {
  var score = _maxScore;
  for (final error in errors) {
    score -= _penalties[error]!;
  }
  if (durationMs > _tempoLimitMs) score -= _tempoPenalty;
  return score < 0 ? 0 : score;
}

/// 점수 평균(반올림 정수). 비어 있으면 0.
int averageScore(Iterable<int> scores) {
  if (scores.isEmpty) return 0;
  final sum = scores.fold<int>(0, (a, b) => a + b);
  return (sum / scores.length).round();
}

/// 85 이상 good, 60 이상 fair, 나머지 poor.
ScoreGrade gradeFor(int score) {
  if (score >= 85) return ScoreGrade.good;
  if (score >= 60) return ScoreGrade.fair;
  return ScoreGrade.poor;
}

// [QA] 2026-11-13 PASS
// [보안] 외부 입력 없음. 오류 목록과 시간(ms)만 받는 순수 함수, 로그와 시크릿 없음.
// [유지보수] _penalties가 Map이라 PoseErrorCode가 늘면 컴파일 오류 없이 `!`에서 실행 시
// 오류가 난다. 오류 코드를 추가할 때 switch 식으로 바꿀 것(routine_table과 같은 지적).
// 같은 코드가 여러 번 오면 그만큼 감점한다(Task 0점 하한 테스트 기준). judgeRep은 중복을 내지 않는다.
// averageScore는 Iterable을 여러 번 순회하므로 지연 Iterable을 넘기면 다시 계산된다.
