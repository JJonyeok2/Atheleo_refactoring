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
