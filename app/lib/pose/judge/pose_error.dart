// [파일] 자세 오류 코드 enum(코드 문자열, 음성 문구, 짧은 이름).
// [Spec] F-04, 7장 자세 오류 코드 / [Task] TASK-09
// [의존] 없음 (환경 변수 사용 안 함)

/// 반복 1회에서 판정되는 자세 오류.
enum PoseErrorCode {
  /// 푸쉬업 깊이 부족.
  puShallow('PU_SHALLOW', '조금 더 내려가세요.', '깊이 부족'),

  /// 푸쉬업 허리 처짐.
  puHipSag('PU_HIP_SAG', '허리가 처졌어요. 몸을 일자로 유지하세요.', '허리 처짐'),

  /// 푸쉬업 엉덩이 들림.
  puHipPike('PU_HIP_PIKE', '엉덩이를 내리고 몸을 일자로 만드세요.', '엉덩이 들림'),

  /// 스쿼트 깊이 부족.
  sqShallow('SQ_SHALLOW', '더 깊이 앉으세요.', '깊이 부족'),

  /// 스쿼트 상체 숙임.
  sqTorsoLean('SQ_TORSO_LEAN', '가슴을 펴고 상체를 세우세요.', '상체 숙임'),

  /// 스쿼트 뒤꿈치 들림.
  sqHeelLift('SQ_HEEL_LIFT', '뒤꿈치를 바닥에 붙이세요.', '뒤꿈치 들림');

  new(this.code, this.voiceMessage, this.label);

  /// 저장, 전송에 쓰는 코드 문자열.
  final String code;

  /// 음성 안내 문구.
  final String voiceMessage;

  /// 화면에 보이는 짧은 이름.
  final String label;

  /// [code]에 맞는 오류를 돌려준다. 모르는 값이면 [ArgumentError].
  static PoseErrorCode fromCode(String code) {
    for (final error in values) {
      if (error.code == code) return error;
    }
    throw ArgumentError.value(code, 'code', '알 수 없는 자세 오류 코드');
  }
}

// [QA] 2026-11-13 FIX (이 파일은 수정 항목 없음, 판정은 TASK-09 전체 기준)
// [보안] 입력은 코드 문자열뿐, 모르는 값은 ArgumentError로 막는다.
// [유지보수] code 문자열은 저장, 전송 계약이므로 바꾸지 않는다. 문구 변경은 Spec 7장 기준.
