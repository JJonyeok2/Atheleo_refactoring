// [파일] 로컬 기록의 서버 동기화 상태 enum.
// [Spec] F-11, F-12 / [Task] TASK-31
// [의존] 없음 (환경 변수 사용 안 함)

/// 기록의 동기화 상태. 앱 로컬 전용이다.
enum SyncStatus {
  /// 아직 서버로 보내지 않음.
  pending('pending', '미동기화'),

  /// 서버에 백업됨.
  synced('synced', '동기화됨'),

  /// 전송에 실패함(재시도 대상).
  failed('failed', '실패'),

  /// 서버가 거절함.
  rejected('rejected', '거절');

  new(this.code, this.label);

  /// 저장에 쓰는 코드 값.
  final String code;

  /// 화면에 보이는 이름.
  final String label;

  /// 코드로 상태를 찾는다. 모르는 값이면 [ArgumentError].
  static SyncStatus fromCode(String code) {
    for (final status in values) {
      if (status.code == code) {
        return status;
      }
    }
    throw ArgumentError.value(code, 'code', '알 수 없는 동기화 상태');
  }
}

// [QA] 2026-11-13 PASS
// [보안] 해당 없음(입력은 로컬 DB 코드 값뿐).
// [유지보수] DB에 알 수 없는 코드가 있으면 fromCode가 ArgumentError를
//   던지므로 조회 쪽(TASK-32)에서 처리 방침을 정할 것.
