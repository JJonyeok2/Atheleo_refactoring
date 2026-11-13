// [파일] 체형 8분류 enum(코드 값, 화면 이름, 코드로 찾기).
// [Spec] F-09, 7장 Profile.body_shape / [Task] TASK-10
// [의존] 없음 (환경 변수 사용 안 함)

/// 체형 분류. 코드 문자열은 서버 확정 전 임시값(Q-01)이며 여기서만 정의한다.
enum BodyShape {
  /// 역삼각형.
  invertedTriangle('inverted_triangle', '역삼각형'),

  /// 사각체형.
  rectangle('rectangle', '사각체형'),

  /// 모래시계형.
  hourglass('hourglass', '모래시계형'),

  /// 삼각형.
  triangle('triangle', '삼각형'),

  /// 이상체형.
  ideal('ideal', '이상체형'),

  /// 둥근체형.
  round('round', '둥근체형'),

  /// 튜브체형.
  tube('tube', '튜브체형'),

  /// 마름모형.
  diamond('diamond', '마름모형');

  new(this.code, this.label);

  /// 저장, 전송에 쓰는 코드 값.
  final String code;

  /// 화면에 보이는 이름.
  final String label;

  /// [code]에 맞는 체형. null이나 모르는 값이면 null.
  static BodyShape? fromCode(String? code) {
    if (code == null) return null;
    for (final shape in values) {
      if (shape.code == code) return shape;
    }
    return null;
  }
}

// [QA] 2026-11-13 PASS
// [보안] 외부 입력은 fromCode에서 8개 코드와 정확히 일치할 때만 받아들이고 나머지는 null.
// [유지보수] code 값은 서버 확정 전 임시값(Q-01). 서버 확정 시 여기만 바꾼다.
//   기존 RN과 달리 앞뒤 공백은 trim하지 않는다.
