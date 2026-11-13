// [파일] 운동 기록을 로컬 DB에 소유자별로 저장하고 읽는 저장소.
// [Spec] F-11, F-12 / [Task] TASK-32
// [의존] AppDatabase, SyncStatus, WorkoutSummary, RepResult (환경 변수 사용 안 함)

import 'package:atheleo/core/storage/app_database.dart';
import 'package:atheleo/features/history/domain/sync_status.dart';
import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/features/workout/domain/workout_summary.dart';
import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 기록 목록의 한 줄.
@immutable
class SessionListItem {
  /// 목록 항목을 만든다.
  const new({
    required this.clientId,
    required this.exercise,
    required this.startedAt,
    required this.totalReps,
    required this.avgScore,
    required this.syncStatus,
  });

  /// 세션 uuid.
  final String clientId;

  /// 운동 종류.
  final ExerciseType exercise;

  /// 시작 시각.
  final DateTime startedAt;

  /// 총 반복 수.
  final int totalReps;

  /// 평균 점수.
  final int avgScore;

  /// 동기화 상태.
  final SyncStatus syncStatus;
}

/// 운동 기록 로컬 저장소. userId가 null이면 guest 기록을 뜻한다.
class WorkoutLocalRepository {
  /// DB를 받아 저장소를 만든다.
  new(this._db);

  final AppDatabase _db;

  /// 요약을 한 트랜잭션으로 저장한다. 같은 clientId가 있으면 아무것도 하지 않는다.
  ///
  /// 값이 범위 밖이면 [ArgumentError]를 던지고 아무것도 저장하지 않는다.
  Future<void> saveSummary(
    WorkoutSummary summary, {
    required int? userId,
  }) async {
    _validate(summary);
    await _db.transaction(() async {
      final exists = await (_db.select(
        _db.workoutSessions,
      )..where((t) => t.clientId.equals(summary.clientId))).getSingleOrNull();
      if (exists != null) return;

      final sessionId = await _db
          .into(_db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              clientId: summary.clientId,
              userId: Value(userId),
              exercise: summary.exercise.code,
              startedAt: summary.startedAt,
              endedAt: summary.endedAt,
              routineLevel: summary.level.code,
              totalReps: summary.totalReps,
              avgScore: summary.avgScore,
            ),
          );
      for (final set in summary.sets) {
        final setId = await _db
            .into(_db.workoutSets)
            .insert(
              WorkoutSetsCompanion.insert(
                sessionId: sessionId,
                setIndex: set.setIndex,
                targetReps: set.targetReps,
                doneReps: set.doneReps,
                partialReps: Value(set.partialReps),
                restSec: set.restSec,
              ),
            );
        for (final rep in set.reps) {
          await _db
              .into(_db.repRecords)
              .insert(
                RepRecordsCompanion.insert(
                  setId: setId,
                  repIndex: rep.repIndex,
                  score: rep.score,
                  minAngle: rep.minAngle,
                  durationMs: rep.durationMs,
                  errors: rep.errors.map((e) => e.code).join(','),
                ),
              );
        }
      }
    });
  }

  /// 소유자의 세션 목록을 startedAt 최신순으로 내보낸다. [from, to) 범위.
  Stream<List<SessionListItem>> watchSessions({
    required int? userId,
    DateTime? from,
    DateTime? to,
  }) {
    final query = _db.select(_db.workoutSessions)
      ..where((t) {
        var cond = _ownedBy(t, userId);
        if (from != null) {
          cond = cond & t.startedAt.isBiggerOrEqualValue(from);
        }
        if (to != null) {
          cond = cond & t.startedAt.isSmallerThanValue(to);
        }
        return cond;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          SessionListItem(
            clientId: row.clientId,
            exercise: ExerciseType.fromCode(row.exercise),
            startedAt: row.startedAt,
            totalReps: row.totalReps,
            avgScore: row.avgScore,
            syncStatus: _statusOf(row.syncStatus),
          ),
      ],
    );
  }

  /// 소유자의 세션 상세를 복원한다. 없거나 소유자가 다르면 null.
  Future<WorkoutSummary?> findSummary(
    String clientId, {
    required int? userId,
  }) async {
    final row =
        await (_db.select(_db.workoutSessions)
              ..where((t) => t.clientId.equals(clientId) & _ownedBy(t, userId)))
            .getSingleOrNull();
    return row == null ? null : await _load(row);
  }

  /// 세션의 동기화 상태. 없으면 null.
  Future<SyncStatus?> statusOf(String clientId) => watchStatus(clientId).first;

  /// 세션의 동기화 상태 변화를 내보낸다. 없으면 null.
  Stream<SyncStatus?> watchStatus(String clientId) {
    final query = _db.selectOnly(_db.workoutSessions)
      ..addColumns([_db.workoutSessions.syncStatus])
      ..where(_db.workoutSessions.clientId.equals(clientId));
    return query.watch().map((rows) {
      if (rows.isEmpty) return null;
      return _statusOf(rows.first.read(_db.workoutSessions.syncStatus)!);
    });
  }

  /// 해당 사용자 소유이고 pending인 요약(guest는 동기화하지 않으므로 제외).
  Future<List<WorkoutSummary>> pendingSummaries({required int userId}) async {
    final rows =
        await (_db.select(_db.workoutSessions)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.syncStatus.equals(SyncStatus.pending.code),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
            .get();
    return [for (final row in rows) await _load(row)];
  }

  /// 서버에 백업됨으로 표시한다. 없는 clientId면 아무것도 하지 않는다.
  Future<void> markSynced(String clientId) async {
    await (_db.update(
      _db.workoutSessions,
    )..where((t) => t.clientId.equals(clientId))).write(
      WorkoutSessionsCompanion(
        syncStatus: Value(SyncStatus.synced.code),
        lastError: const Value(null),
      ),
    );
  }

  /// 서버가 거절함으로 표시한다. [reason]에는 토큰, 개인정보를 넣지 않는다.
  Future<void> markRejected(String clientId, String reason) async {
    await (_db.update(
      _db.workoutSessions,
    )..where((t) => t.clientId.equals(clientId))).write(
      WorkoutSessionsCompanion(
        syncStatus: Value(SyncStatus.rejected.code),
        lastError: Value(reason),
      ),
    );
  }

  Expression<bool> _ownedBy(WorkoutSessions t, int? userId) =>
      userId == null ? t.userId.isNull() : t.userId.equals(userId);

  /// 모르는 코드는 예외 대신 failed로 취급한다.
  SyncStatus _statusOf(String code) {
    for (final status in SyncStatus.values) {
      if (status.code == code) return status;
    }
    return SyncStatus.failed;
  }

  void _validate(WorkoutSummary summary) {
    for (final set in summary.sets) {
      if (set.setIndex < 1) {
        throw ArgumentError.value(set.setIndex, 'setIndex', '1 이상이어야 함');
      }
      if (set.partialReps < 0) {
        throw ArgumentError.value(set.partialReps, 'partialReps', '0 이상이어야 함');
      }
      for (final rep in set.reps) {
        if (rep.repIndex < 1) {
          throw ArgumentError.value(rep.repIndex, 'repIndex', '1 이상이어야 함');
        }
        if (rep.score < 0 || rep.score > 100) {
          throw ArgumentError.value(rep.score, 'score', '0~100이어야 함');
        }
      }
    }
  }

  Future<WorkoutSummary> _load(WorkoutSession row) async {
    final setRows =
        await (_db.select(_db.workoutSets)
              ..where((t) => t.sessionId.equals(row.id))
              ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
            .get();
    final sets = <SetSummary>[];
    for (final setRow in setRows) {
      final repRows =
          await (_db.select(_db.repRecords)
                ..where((t) => t.setId.equals(setRow.id))
                ..orderBy([(t) => OrderingTerm.asc(t.repIndex)]))
              .get();
      sets.add(
        SetSummary(
          setIndex: setRow.setIndex,
          targetReps: setRow.targetReps,
          restSec: setRow.restSec,
          partialReps: setRow.partialReps,
          reps: [
            for (final rep in repRows)
              RepResult(
                repIndex: rep.repIndex,
                score: rep.score,
                minAngle: rep.minAngle,
                durationMs: rep.durationMs,
                errors: [
                  for (final code in rep.errors.split(','))
                    if (code.isNotEmpty) PoseErrorCode.fromCode(code),
                ],
              ),
          ],
        ),
      );
    }
    return WorkoutSummary(
      clientId: row.clientId,
      exercise: ExerciseType.fromCode(row.exercise),
      level: RoutineLevel.values.firstWhere((l) => l.code == row.routineLevel),
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      sets: sets,
    );
  }
}

/// 앱 전체에서 쓰는 운동 기록 저장소.
final workoutLocalRepositoryProvider = Provider<WorkoutLocalRepository>(
  (ref) => WorkoutLocalRepository(ref.watch(appDatabaseProvider)),
);

// [QA] 2026-11-13 PASS
// [보안] 목록, 상세, 대기 목록은 소유자(userId, null은 guest)로 거른다.
//   statusOf, watchStatus, markSynced, markRejected는 계약상 clientId만 받아
//   소유자를 보지 않으므로 호출 쪽이 자기 소유 clientId만 넘겨야 한다.
//   같은 clientId 재저장은 소유자와 상관없이 무시(uuid 전제). lastError에
//   토큰, 개인정보 금지.
// [유지보수] 모르는 syncStatus만 failed로 흡수하고, 모르는 exercise,
//   routineLevel, 오류 코드는 예외라 한 행이 목록, 대기 목록 전체를 깬다.
//   목록 갱신은 drift API 쓰기로만 전파되므로 customStatement로 쓰면
//   updates를 지정해야 한다. saveSummary가 50줄을 조금 넘어 세트 저장
//   분리 후보.
