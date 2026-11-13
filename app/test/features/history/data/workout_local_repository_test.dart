import 'package:atheleo/core/storage/app_database.dart';
import 'package:atheleo/features/history/data/workout_local_repository.dart';
import 'package:atheleo/features/history/domain/sync_status.dart';
import 'package:atheleo/features/routine/domain/routine_plan.dart';
import 'package:atheleo/features/workout/domain/workout_summary.dart';
import 'package:atheleo/pose/analyzer/rep_analyzer.dart';
import 'package:atheleo/pose/judge/pose_error.dart';
import 'package:atheleo/pose/landmarks/exercise_type.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

RepResult _rep(int index, int score, [List<PoseErrorCode> errors = const []]) {
  return RepResult(
    repIndex: index,
    score: score,
    minAngle: 80.5,
    durationMs: 1200,
    errors: errors,
  );
}

WorkoutSummary _summary(
  String clientId, {
  DateTime? startedAt,
  List<SetSummary>? sets,
}) {
  final start = startedAt ?? DateTime.utc(2026, 11, 13, 10);
  return WorkoutSummary(
    clientId: clientId,
    exercise: ExerciseType.pushUp,
    level: RoutineLevel.beginner,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 5)),
    sets:
        sets ??
        [
          SetSummary(
            setIndex: 1,
            targetReps: 10,
            restSec: 60,
            reps: [
              _rep(1, 90),
              _rep(2, 70, [PoseErrorCode.values.first]),
            ],
          ),
          SetSummary(
            setIndex: 2,
            targetReps: 10,
            restSec: 60,
            partialReps: 2,
            reps: [_rep(1, 80, PoseErrorCode.values.take(2).toList())],
          ),
        ],
  );
}

void main() {
  late AppDatabase db;
  late WorkoutLocalRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutLocalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  test('저장 후 상세 복원', () async {
    final original = _summary('a');
    await repo.saveSummary(original, userId: 7);

    final found = await repo.findSummary('a', userId: 7);

    expect(found, isNotNull);
    expect(found!.clientId, 'a');
    expect(found.exercise, ExerciseType.pushUp);
    expect(found.level, RoutineLevel.beginner);
    expect(found.startedAt.isAtSameMomentAs(original.startedAt), isTrue);
    expect(found.sets.map((s) => s.setIndex), [1, 2]);
    expect(found.sets.map((s) => s.doneReps), [2, 1]);
    expect(found.sets.map((s) => s.partialReps), [0, 2]);
    expect(found.sets.map((s) => s.targetReps), [10, 10]);
    expect(found.sets.map((s) => s.restSec), [60, 60]);
    expect(found.sets[0].reps.map((r) => r.score), [90, 70]);
    expect(found.sets[0].reps.map((r) => r.repIndex), [1, 2]);
    expect(found.sets[0].reps[1].errors, [PoseErrorCode.values.first]);
    expect(found.sets[1].reps[0].errors, PoseErrorCode.values.take(2).toList());
    expect(found.sets[0].reps[0].errors, isEmpty);
    expect(found.sets[0].reps[0].minAngle, 80.5);
    expect(found.sets[0].reps[0].durationMs, 1200);
    expect(found.totalReps, original.totalReps);
    expect(found.avgScore, original.avgScore);
  });

  test('미동기화로 시작', () async {
    await repo.saveSummary(_summary('a'), userId: 7);

    final items = await repo.watchSessions(userId: 7).first;

    expect(items.single.syncStatus, SyncStatus.pending);
    expect(items.single.totalReps, 3);
    expect(items.single.avgScore, 80);
    expect(items.single.exercise, ExerciseType.pushUp);
    expect(await repo.statusOf('a'), SyncStatus.pending);
    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.syncAttempts, 0);
  });

  test('중복 저장 무시', () async {
    await repo.saveSummary(_summary('a'), userId: 7);
    await repo.saveSummary(_summary('a'), userId: 7);

    expect(await count('workout_sessions'), 1);
    expect(await count('workout_sets'), 2);
    expect(await count('rep_records'), 3);
  });

  test('같은 clientId를 다른 소유자로 저장해도 기존 기록을 바꾸지 않음', () async {
    await repo.saveSummary(_summary('a'), userId: 7);
    await repo.saveSummary(_summary('a'), userId: 8);

    expect(await repo.findSummary('a', userId: 8), isNull);
    expect(await repo.findSummary('a', userId: 7), isNotNull);
    expect(await count('workout_sessions'), 1);
  });

  test('상태 변경 반영', () async {
    await repo.saveSummary(_summary('a'), userId: 7);
    final listStream = repo.watchSessions(userId: 7);
    final statusStream = repo.watchStatus('a');

    final listFuture = expectLater(
      listStream.map((l) => l.single.syncStatus),
      emitsInOrder([
        SyncStatus.pending,
        SyncStatus.synced,
        SyncStatus.rejected,
      ]),
    );
    final statusFuture = expectLater(
      statusStream,
      emitsInOrder([
        SyncStatus.pending,
        SyncStatus.synced,
        SyncStatus.rejected,
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.markSynced('a');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.markRejected('a', '서버가 거절함');
    await listFuture;
    await statusFuture;

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.lastError, '서버가 거절함');
    expect(await repo.statusOf('a'), SyncStatus.rejected);
  });

  test('없는 clientId의 상태는 null', () async {
    expect(await repo.statusOf('none'), isNull);
    expect(await repo.watchStatus('none').first, isNull);
    await repo.markSynced('none');
    await repo.markRejected('none', 'x');
  });

  test('소유자 구분', () async {
    await repo.saveSummary(_summary('seven'), userId: 7);
    await repo.saveSummary(_summary('eight'), userId: 8);
    await repo.saveSummary(_summary('guest'), userId: null);

    final seven = await repo.watchSessions(userId: 7).first;
    final guest = await repo.watchSessions(userId: null).first;

    expect(seven.map((i) => i.clientId), ['seven']);
    expect(guest.map((i) => i.clientId), ['guest']);
    expect(await repo.findSummary('seven', userId: 8), isNull);
    expect(await repo.findSummary('seven', userId: null), isNull);
    expect(await repo.findSummary('guest', userId: 7), isNull);
    expect(await repo.findSummary('guest', userId: null), isNotNull);
  });

  test('대기 목록', () async {
    await repo.saveSummary(_summary('p1'), userId: 7);
    await repo.saveSummary(_summary('p2'), userId: 7);
    await repo.saveSummary(_summary('s1'), userId: 7);
    await repo.saveSummary(_summary('o1'), userId: 8);
    await repo.saveSummary(_summary('g1'), userId: null);
    await repo.markSynced('s1');

    final pending = await repo.pendingSummaries(userId: 7);

    expect(pending.map((s) => s.clientId).toSet(), {'p1', 'p2'});
    expect(pending.first.sets, hasLength(2));
  });

  test('날짜 범위와 정렬', () async {
    await repo.saveSummary(
      _summary('d1', startedAt: DateTime.utc(2026, 11, 1, 9)),
      userId: 7,
    );
    await repo.saveSummary(
      _summary('d2', startedAt: DateTime.utc(2026, 11, 2, 9)),
      userId: 7,
    );
    await repo.saveSummary(
      _summary('d3', startedAt: DateTime.utc(2026, 11, 3, 9)),
      userId: 7,
    );

    final all = await repo.watchSessions(userId: 7).first;
    final ranged = await repo
        .watchSessions(
          userId: 7,
          from: DateTime.utc(2026, 11, 2, 9),
          to: DateTime.utc(2026, 11, 3, 9),
        )
        .first;
    final fromOnly = await repo
        .watchSessions(userId: 7, from: DateTime.utc(2026, 11, 2, 9, 0, 1))
        .first;

    expect(all.map((i) => i.clientId), ['d3', 'd2', 'd1']);
    expect(ranged.map((i) => i.clientId), ['d2']);
    expect(fromOnly.map((i) => i.clientId), ['d3']);
  });

  group('값 검증', () {
    Future<void> expectRejected(WorkoutSummary summary) async {
      await expectLater(
        repo.saveSummary(summary, userId: 7),
        throwsArgumentError,
      );
      expect(await count('workout_sessions'), 0);
      expect(await count('workout_sets'), 0);
      expect(await count('rep_records'), 0);
    }

    SetSummary set({
      int setIndex = 1,
      int partialReps = 0,
      List<RepResult>? reps,
    }) => SetSummary(
      setIndex: setIndex,
      targetReps: 10,
      restSec: 60,
      partialReps: partialReps,
      reps: reps ?? [_rep(1, 50)],
    );

    test('점수 100 초과 거부', () async {
      await expectRejected(
        _summary(
          'a',
          sets: [
            set(reps: [_rep(1, 101)]),
          ],
        ),
      );
    });

    test('점수 음수 거부', () async {
      await expectRejected(
        _summary(
          'a',
          sets: [
            set(reps: [_rep(1, -1)]),
          ],
        ),
      );
    });

    test('partialReps 음수 거부', () async {
      await expectRejected(_summary('a', sets: [set(partialReps: -1)]));
    });

    test('setIndex 0 거부', () async {
      await expectRejected(_summary('a', sets: [set(setIndex: 0)]));
    });

    test('repIndex 0 거부', () async {
      await expectRejected(
        _summary(
          'a',
          sets: [
            set(reps: [_rep(0, 50)]),
          ],
        ),
      );
    });

    test('경계값 점수 0, 100은 저장', () async {
      await repo.saveSummary(
        _summary(
          'a',
          sets: [
            set(reps: [_rep(1, 0), _rep(2, 100)]),
          ],
        ),
        userId: 7,
      );
      expect(await count('rep_records'), 2);
    });
  });

  test('저장 중 실패하면 전부 롤백', () async {
    await db.customStatement(
      'CREATE TRIGGER fail_rep BEFORE INSERT ON rep_records '
      'WHEN NEW.score = 55 BEGIN SELECT RAISE(ABORT, "forced"); END',
    );
    final summary = _summary(
      'a',
      sets: [
        SetSummary(
          setIndex: 1,
          targetReps: 10,
          restSec: 60,
          reps: [_rep(1, 90), _rep(2, 55)],
        ),
      ],
    );

    await expectLater(repo.saveSummary(summary, userId: 7), throwsA(anything));

    expect(await count('workout_sessions'), 0);
    expect(await count('workout_sets'), 0);
    expect(await count('rep_records'), 0);
  });

  test('모르는 syncStatus 행은 failed로 취급하고 목록을 깨지 않음', () async {
    await repo.saveSummary(_summary('a'), userId: 7);
    await repo.saveSummary(
      _summary('b', startedAt: DateTime.utc(2026, 11, 14, 10)),
      userId: 7,
    );
    await (db.update(db.workoutSessions)..where((t) => t.clientId.equals('a')))
        .write(const WorkoutSessionsCompanion(syncStatus: Value('weird')));

    final items = await repo.watchSessions(userId: 7).first;

    expect(items.map((i) => i.clientId), ['b', 'a']);
    expect(items.last.syncStatus, SyncStatus.failed);
    expect(await repo.statusOf('a'), SyncStatus.failed);
    expect(await repo.watchStatus('a').first, SyncStatus.failed);
    expect(await repo.pendingSummaries(userId: 7).then((l) => l.length), 1);
  });
}
