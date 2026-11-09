/// 앱의 모든 경로 문자열과 경로 파라미터를 채우는 함수.
abstract final class AppRoutes {
  /// 홈.
  static const home = '/';

  /// 로그인.
  static const login = '/login';

  /// 회원가입.
  static const signup = '/signup';

  /// 기록 목록.
  static const history = '/history';

  /// 기록 상세. `:id`는 기록 id.
  static const historyDetail = '/history/:id';

  /// 프로필.
  static const profile = '/profile';

  /// 개발자 메뉴(디버그 빌드만).
  static const dev = '/dev';

  /// 운동 결과. `workout`보다 먼저 등록해야 `result`가 type으로 잡히지 않는다.
  static const workoutResult = '/workout/result';

  /// 촬영 가이드. `:type`은 운동 종류.
  static const workoutSetup = '/workout/:type/setup';

  /// 운동. `:type`은 운동 종류.
  static const workout = '/workout/:type';

  /// [type] 운동의 촬영 가이드 주소.
  static String workoutSetupPath(String type) => '/workout/$type/setup';

  /// [type] 운동의 운동 화면 주소.
  static String workoutPath(String type) => '/workout/$type';

  /// [id] 기록의 상세 주소.
  static String historyDetailPath(String id) => '/history/$id';
}
