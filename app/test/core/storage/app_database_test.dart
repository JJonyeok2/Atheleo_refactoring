import 'package:atheleo/core/storage/app_database.dart';
import 'package:atheleo/features/history/domain/sync_status.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSessionsCompanion _session(String clientId, {int? userId}) {
  return WorkoutSessionsCompanion.insert(
    clientId: clientId,
    userId: Value(userId),
    exercise: 'push_up',
    startedAt: DateTime.utc(2026, 11, 13, 10),
    endedAt: DateTime.utc(2026, 11, 13, 10, 5),
    routineLevel: 'beginner',
    totalReps: 20,
    avgScore: 80,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schemaVersion은 1이다', () {
    expect(db.schemaVersion, 1);
  });

  test('세션, 세트, 반복 저장과 조회', () async {
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(_session('c-1', userId: 7));
    final set1 = await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            setIndex: 1,
            targetReps: 10,
            doneReps: 10,
            restSec: 30,
          ),
        );
    final set2 = await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            setIndex: 2,
            targetReps: 10,
            doneReps: 8,
            partialReps: const Value(2),
            restSec: 30,
          ),
        );
    for (final (setId, index, errors) in [
      (set1, 1, ''),
      (set1, 2, 'PU_SHALLOW,PU_HIP_SAG'),
      (set2, 1, 'PU_SHALLOW'),
    ]) {
      await db
          .into(db.repRecords)
          .insert(
            RepRecordsCompanion.insert(
              setId: setId,
              repIndex: index,
              score: 90,
              minAngle: 72.5,
              durationMs: 1500,
              errors: errors,
            ),
          );
    }

    final session = await db.select(db.workoutSessions).getSingle();
    expect(session.clientId, 'c-1');
    expect(session.userId, 7);
    expect(session.exercise, 'push_up');
    expect(session.routineLevel, 'beginner');
    expect(session.totalReps, 20);
    expect(session.avgScore, 80);
    expect(session.startedAt.toUtc(), DateTime.utc(2026, 11, 13, 10));
    expect(session.endedAt.toUtc(), DateTime.utc(2026, 11, 13, 10, 5));

    final sets = await (db.select(
      db.workoutSets,
    )..orderBy([(t) => OrderingTerm.asc(t.setIndex)])).get();
    expect(sets.map((s) => s.partialReps), [0, 2]);
    expect(sets.map((s) => s.doneReps), [10, 8]);
    expect(sets.every((s) => s.sessionId == sessionId), isTrue);

    final reps = await (db.select(
      db.repRecords,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(reps, hasLength(3));
    expect(reps[1].errors, 'PU_SHALLOW,PU_HIP_SAG');
    expect(reps[0].errors, '');
    expect(reps[0].minAngle, 72.5);
    expect(reps[2].setId, set2);
  });

  test('기본값은 pending, 0, null 소유자(guest), null lastError', () async {
    await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            clientId: 'c-1',
            exercise: 'squat',
            startedAt: DateTime.utc(2026),
            endedAt: DateTime.utc(2026),
            routineLevel: 'beginner',
            totalReps: 0,
            avgScore: 0,
          ),
        );
    final session = await db.select(db.workoutSessions).getSingle();
    expect(session.syncStatus, 'pending');
    expect(session.syncAttempts, 0);
    expect(session.userId, isNull);
    expect(session.lastError, isNull);
  });

  test('같은 clientId를 두 번 넣으면 예외', () async {
    await db.into(db.workoutSessions).insert(_session('dup'));
    expect(
      () => db.into(db.workoutSessions).insert(_session('dup')),
      throwsA(isA<Exception>()),
    );
  });

  test('세션 삭제 시 세트, 반복이 함께 삭제된다', () async {
    final sessionId = await db.into(db.workoutSessions).insert(_session('c'));
    final setId = await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            setIndex: 1,
            targetReps: 10,
            doneReps: 10,
            restSec: 30,
          ),
        );
    await db
        .into(db.repRecords)
        .insert(
          RepRecordsCompanion.insert(
            setId: setId,
            repIndex: 1,
            score: 90,
            minAngle: 70,
            durationMs: 1000,
            errors: '',
          ),
        );

    await db.delete(db.workoutSessions).go();

    expect(await db.select(db.workoutSets).get(), isEmpty);
    expect(await db.select(db.repRecords).get(), isEmpty);
  });

  test('존재하지 않는 세션을 가리키는 세트는 외래 키 위반', () async {
    expect(
      () => db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              sessionId: 999,
              setIndex: 1,
              targetReps: 10,
              doneReps: 10,
              restSec: 30,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('소유자별 조회: userId 7은 2건, null(guest)은 1건', () async {
    await db.into(db.workoutSessions).insert(_session('a', userId: 7));
    await db.into(db.workoutSessions).insert(_session('b', userId: 7));
    await db.into(db.workoutSessions).insert(_session('c', userId: 8));
    await db.into(db.workoutSessions).insert(_session('d'));

    final owned = await (db.select(
      db.workoutSessions,
    )..where((t) => t.userId.equals(7))).get();
    final guest = await (db.select(
      db.workoutSessions,
    )..where((t) => t.userId.isNull())).get();
    expect(owned, hasLength(2));
    expect(guest, hasLength(1));
  });

  test('userId 인덱스가 있다', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'workout_sessions'",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toList();
    expect(names.any((n) => n.contains('user_id')), isTrue);
  });

  test('SyncStatus 코드와 라벨', () {
    expect(SyncStatus.fromCode('failed').label, '실패');
    expect(SyncStatus.fromCode('rejected').label, '거절');
    expect(SyncStatus.fromCode('pending').label, '미동기화');
    expect(SyncStatus.fromCode('synced').label, '동기화됨');
    expect(SyncStatus.failed.code, 'failed');
    expect(() => SyncStatus.fromCode('x'), throwsArgumentError);
  });
}
