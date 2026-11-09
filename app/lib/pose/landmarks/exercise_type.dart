// [파일] 운동 종류 enum(코드 값, 화면 이름, 코드로 찾기).
// [Spec] F-01, 7장 LandmarkClip / [Task] TASK-04
// [의존] 없음 (환경 변수 사용 안 함)

/// 앱이 판정하는 운동 종류.
enum ExerciseType {
  /// 푸쉬업.
  pushUp('push_up', '푸쉬업'),

  /// 스쿼트.
  squat('squat', '스쿼트');

  new(this.code, this.label);

  /// 저장, 전송에 쓰는 코드 값.
  final String code;

  /// 화면에 보이는 이름.
  final String label;

  /// [code]에 맞는 운동을 돌려준다. 모르는 값이면 [ArgumentError].
  static ExerciseType fromCode(String code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    throw ArgumentError.value(code, 'code', '알 수 없는 운동 코드');
  }
}

// [QA] 2026-11-09 PASS
// [보안] fromCode는 모르는 값에 ArgumentError. 외부 JSON 경로에서는
//   LandmarkClip이 먼저 검사해 FormatException으로 바꾼다.
// [유지보수] 운동을 추가해도 기존 code 값은 바꾸지 않는다(DB, 클립 JSON에
//   저장됨).
