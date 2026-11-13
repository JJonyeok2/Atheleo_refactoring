// [파일] 로컬 기록 DB(drift) 테이블과 DB 클래스.
// [Spec] F-11, F-12 / [Task] TASK-31
// [의존] drift, drift_flutter, flutter_riverpod (환경 변수 사용 안 함)

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// 운동 세션. userId가 null이면 guest 기록이다.
@TableIndex(name: 'workout_sessions_user_id', columns: {#userId})
class WorkoutSessions extends Table {
  /// 로컬 기본 키.
  IntColumn get id => integer().autoIncrement()();

  /// 서버와 맞추는 유일한 uuid.
  TextColumn get clientId => text().unique()();

  /// 소유자 사용자 id. null이면 guest.
  IntColumn get userId => integer().nullable()();

  /// 운동 종류 코드(push_up, squat).
  TextColumn get exercise => text()();

  /// 시작 시각.
  DateTimeColumn get startedAt => dateTime()();

  /// 종료 시각.
  DateTimeColumn get endedAt => dateTime()();

  /// 루틴 단계 코드.
  TextColumn get routineLevel => text()();

  /// 총 반복 수.
  IntColumn get totalReps => integer()();

  /// 평균 점수.
  IntColumn get avgScore => integer()();

  /// 동기화 상태 코드(pending, synced, failed, rejected). 로컬 전용.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// 동기화 시도 횟수. 로컬 전용.
  IntColumn get syncAttempts => integer().withDefault(const Constant(0))();

  /// 마지막 동기화 실패 사유.
  TextColumn get lastError => text().nullable()();
}

/// 세션 안의 세트. 세션 삭제 시 함께 삭제된다.
class WorkoutSets extends Table {
  /// 로컬 기본 키.
  IntColumn get id => integer().autoIncrement()();

  /// 소속 세션.
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();

  /// 세션 안 순번(1부터).
  IntColumn get setIndex => integer()();

  /// 목표 반복 수.
  IntColumn get targetReps => integer()();

  /// 완료한 반복 수.
  IntColumn get doneReps => integer()();

  /// 부분 반복 수(0 이상).
  IntColumn get partialReps => integer().withDefault(const Constant(0))();

  /// 휴식 시간(초).
  IntColumn get restSec => integer()();
}

/// 세트 안의 반복 기록. 세트 삭제 시 함께 삭제된다.
class RepRecords extends Table {
  /// 로컬 기본 키.
  IntColumn get id => integer().autoIncrement()();

  /// 소속 세트.
  IntColumn get setId =>
      integer().references(WorkoutSets, #id, onDelete: KeyAction.cascade)();

  /// 세트 안 순번(1부터).
  IntColumn get repIndex => integer()();

  /// 점수(0~100).
  IntColumn get score => integer()();

  /// 최소 관절 각도.
  RealColumn get minAngle => real()();

  /// 반복에 걸린 시간(ms).
  IntColumn get durationMs => integer()();

  /// 오류 코드를 쉼표로 이은 문자열(없으면 빈 문자열).
  TextColumn get errors => text()();
}

/// 앱 로컬 DB.
@DriftDatabase(tables: [WorkoutSessions, WorkoutSets, RepRecords])
class AppDatabase extends _$AppDatabase {
  /// 주어진 실행기로 DB를 연다.
  new(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// 앱 전체에서 쓰는 DB. dispose 시 닫는다.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'atheleo'));
  ref.onDispose(db.close);
  return db;
});

// [QA] 2026-11-13 PASS
// [보안] 값 범위(점수 0~100, partialReps 0 이상 등)는 DB CHECK로
//   걸지 않음. 저장 경로(TASK-32)에서 검증할 것.
// [유지보수] 배포 후 스키마가 바뀌면 schemaVersion을 올리고
//   onUpgrade를 추가할 것. app_database.g.dart는 생성물로 커밋함.
