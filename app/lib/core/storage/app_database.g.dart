// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WorkoutSessionsTable extends WorkoutSessions
    with TableInfo<$WorkoutSessionsTable, WorkoutSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exerciseMeta = const VerificationMeta(
    'exercise',
  );
  @override
  late final GeneratedColumn<String> exercise = GeneratedColumn<String>(
    'exercise',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineLevelMeta = const VerificationMeta(
    'routineLevel',
  );
  @override
  late final GeneratedColumn<String> routineLevel = GeneratedColumn<String>(
    'routine_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalRepsMeta = const VerificationMeta(
    'totalReps',
  );
  @override
  late final GeneratedColumn<int> totalReps = GeneratedColumn<int>(
    'total_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgScoreMeta = const VerificationMeta(
    'avgScore',
  );
  @override
  late final GeneratedColumn<int> avgScore = GeneratedColumn<int>(
    'avg_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncAttemptsMeta = const VerificationMeta(
    'syncAttempts',
  );
  @override
  late final GeneratedColumn<int> syncAttempts = GeneratedColumn<int>(
    'sync_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    userId,
    exercise,
    startedAt,
    endedAt,
    routineLevel,
    totalReps,
    avgScore,
    syncStatus,
    syncAttempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('exercise')) {
      context.handle(
        _exerciseMeta,
        exercise.isAcceptableOrUnknown(data['exercise']!, _exerciseMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('routine_level')) {
      context.handle(
        _routineLevelMeta,
        routineLevel.isAcceptableOrUnknown(
          data['routine_level']!,
          _routineLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_routineLevelMeta);
    }
    if (data.containsKey('total_reps')) {
      context.handle(
        _totalRepsMeta,
        totalReps.isAcceptableOrUnknown(data['total_reps']!, _totalRepsMeta),
      );
    } else if (isInserting) {
      context.missing(_totalRepsMeta);
    }
    if (data.containsKey('avg_score')) {
      context.handle(
        _avgScoreMeta,
        avgScore.isAcceptableOrUnknown(data['avg_score']!, _avgScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_avgScoreMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_attempts')) {
      context.handle(
        _syncAttemptsMeta,
        syncAttempts.isAcceptableOrUnknown(
          data['sync_attempts']!,
          _syncAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      ),
      exercise: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      routineLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_level'],
      )!,
      totalReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_reps'],
      )!,
      avgScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_score'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $WorkoutSessionsTable createAlias(String alias) {
    return $WorkoutSessionsTable(attachedDatabase, alias);
  }
}

class WorkoutSession extends DataClass implements Insertable<WorkoutSession> {
  /// 로컬 기본 키.
  final int id;

  /// 서버와 맞추는 유일한 uuid.
  final String clientId;

  /// 소유자 사용자 id. null이면 guest.
  final int? userId;

  /// 운동 종류 코드(push_up, squat).
  final String exercise;

  /// 시작 시각.
  final DateTime startedAt;

  /// 종료 시각.
  final DateTime endedAt;

  /// 루틴 단계 코드.
  final String routineLevel;

  /// 총 반복 수.
  final int totalReps;

  /// 평균 점수.
  final int avgScore;

  /// 동기화 상태 코드(pending, synced, failed, rejected). 로컬 전용.
  final String syncStatus;

  /// 동기화 시도 횟수. 로컬 전용.
  final int syncAttempts;

  /// 마지막 동기화 실패 사유.
  final String? lastError;
  const WorkoutSession({
    required this.id,
    required this.clientId,
    this.userId,
    required this.exercise,
    required this.startedAt,
    required this.endedAt,
    required this.routineLevel,
    required this.totalReps,
    required this.avgScore,
    required this.syncStatus,
    required this.syncAttempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_id'] = Variable<String>(clientId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    map['exercise'] = Variable<String>(exercise);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['routine_level'] = Variable<String>(routineLevel);
    map['total_reps'] = Variable<int>(totalReps);
    map['avg_score'] = Variable<int>(avgScore);
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_attempts'] = Variable<int>(syncAttempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  WorkoutSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsCompanion(
      id: Value(id),
      clientId: Value(clientId),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      exercise: Value(exercise),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      routineLevel: Value(routineLevel),
      totalReps: Value(totalReps),
      avgScore: Value(avgScore),
      syncStatus: Value(syncStatus),
      syncAttempts: Value(syncAttempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory WorkoutSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSession(
      id: serializer.fromJson<int>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      userId: serializer.fromJson<int?>(json['userId']),
      exercise: serializer.fromJson<String>(json['exercise']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      routineLevel: serializer.fromJson<String>(json['routineLevel']),
      totalReps: serializer.fromJson<int>(json['totalReps']),
      avgScore: serializer.fromJson<int>(json['avgScore']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncAttempts: serializer.fromJson<int>(json['syncAttempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientId': serializer.toJson<String>(clientId),
      'userId': serializer.toJson<int?>(userId),
      'exercise': serializer.toJson<String>(exercise),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'routineLevel': serializer.toJson<String>(routineLevel),
      'totalReps': serializer.toJson<int>(totalReps),
      'avgScore': serializer.toJson<int>(avgScore),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncAttempts': serializer.toJson<int>(syncAttempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  WorkoutSession copyWith({
    int? id,
    String? clientId,
    Value<int?> userId = const Value.absent(),
    String? exercise,
    DateTime? startedAt,
    DateTime? endedAt,
    String? routineLevel,
    int? totalReps,
    int? avgScore,
    String? syncStatus,
    int? syncAttempts,
    Value<String?> lastError = const Value.absent(),
  }) => WorkoutSession(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    userId: userId.present ? userId.value : this.userId,
    exercise: exercise ?? this.exercise,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    routineLevel: routineLevel ?? this.routineLevel,
    totalReps: totalReps ?? this.totalReps,
    avgScore: avgScore ?? this.avgScore,
    syncStatus: syncStatus ?? this.syncStatus,
    syncAttempts: syncAttempts ?? this.syncAttempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  WorkoutSession copyWithCompanion(WorkoutSessionsCompanion data) {
    return WorkoutSession(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      userId: data.userId.present ? data.userId.value : this.userId,
      exercise: data.exercise.present ? data.exercise.value : this.exercise,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      routineLevel: data.routineLevel.present
          ? data.routineLevel.value
          : this.routineLevel,
      totalReps: data.totalReps.present ? data.totalReps.value : this.totalReps,
      avgScore: data.avgScore.present ? data.avgScore.value : this.avgScore,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncAttempts: data.syncAttempts.present
          ? data.syncAttempts.value
          : this.syncAttempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSession(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('userId: $userId, ')
          ..write('exercise: $exercise, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('routineLevel: $routineLevel, ')
          ..write('totalReps: $totalReps, ')
          ..write('avgScore: $avgScore, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientId,
    userId,
    exercise,
    startedAt,
    endedAt,
    routineLevel,
    totalReps,
    avgScore,
    syncStatus,
    syncAttempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSession &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.userId == this.userId &&
          other.exercise == this.exercise &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.routineLevel == this.routineLevel &&
          other.totalReps == this.totalReps &&
          other.avgScore == this.avgScore &&
          other.syncStatus == this.syncStatus &&
          other.syncAttempts == this.syncAttempts &&
          other.lastError == this.lastError);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSession> {
  final Value<int> id;
  final Value<String> clientId;
  final Value<int?> userId;
  final Value<String> exercise;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<String> routineLevel;
  final Value<int> totalReps;
  final Value<int> avgScore;
  final Value<String> syncStatus;
  final Value<int> syncAttempts;
  final Value<String?> lastError;
  const WorkoutSessionsCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.userId = const Value.absent(),
    this.exercise = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.routineLevel = const Value.absent(),
    this.totalReps = const Value.absent(),
    this.avgScore = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String clientId,
    this.userId = const Value.absent(),
    required String exercise,
    required DateTime startedAt,
    required DateTime endedAt,
    required String routineLevel,
    required int totalReps,
    required int avgScore,
    this.syncStatus = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : clientId = Value(clientId),
       exercise = Value(exercise),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       routineLevel = Value(routineLevel),
       totalReps = Value(totalReps),
       avgScore = Value(avgScore);
  static Insertable<WorkoutSession> custom({
    Expression<int>? id,
    Expression<String>? clientId,
    Expression<int>? userId,
    Expression<String>? exercise,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? routineLevel,
    Expression<int>? totalReps,
    Expression<int>? avgScore,
    Expression<String>? syncStatus,
    Expression<int>? syncAttempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (userId != null) 'user_id': userId,
      if (exercise != null) 'exercise': exercise,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (routineLevel != null) 'routine_level': routineLevel,
      if (totalReps != null) 'total_reps': totalReps,
      if (avgScore != null) 'avg_score': avgScore,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncAttempts != null) 'sync_attempts': syncAttempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  WorkoutSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientId,
    Value<int?>? userId,
    Value<String>? exercise,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<String>? routineLevel,
    Value<int>? totalReps,
    Value<int>? avgScore,
    Value<String>? syncStatus,
    Value<int>? syncAttempts,
    Value<String?>? lastError,
  }) {
    return WorkoutSessionsCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      exercise: exercise ?? this.exercise,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      routineLevel: routineLevel ?? this.routineLevel,
      totalReps: totalReps ?? this.totalReps,
      avgScore: avgScore ?? this.avgScore,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (exercise.present) {
      map['exercise'] = Variable<String>(exercise.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (routineLevel.present) {
      map['routine_level'] = Variable<String>(routineLevel.value);
    }
    if (totalReps.present) {
      map['total_reps'] = Variable<int>(totalReps.value);
    }
    if (avgScore.present) {
      map['avg_score'] = Variable<int>(avgScore.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncAttempts.present) {
      map['sync_attempts'] = Variable<int>(syncAttempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('userId: $userId, ')
          ..write('exercise: $exercise, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('routineLevel: $routineLevel, ')
          ..write('totalReps: $totalReps, ')
          ..write('avgScore: $avgScore, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTable extends WorkoutSets
    with TableInfo<$WorkoutSetsTable, WorkoutSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _setIndexMeta = const VerificationMeta(
    'setIndex',
  );
  @override
  late final GeneratedColumn<int> setIndex = GeneratedColumn<int>(
    'set_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetRepsMeta = const VerificationMeta(
    'targetReps',
  );
  @override
  late final GeneratedColumn<int> targetReps = GeneratedColumn<int>(
    'target_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneRepsMeta = const VerificationMeta(
    'doneReps',
  );
  @override
  late final GeneratedColumn<int> doneReps = GeneratedColumn<int>(
    'done_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partialRepsMeta = const VerificationMeta(
    'partialReps',
  );
  @override
  late final GeneratedColumn<int> partialReps = GeneratedColumn<int>(
    'partial_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _restSecMeta = const VerificationMeta(
    'restSec',
  );
  @override
  late final GeneratedColumn<int> restSec = GeneratedColumn<int>(
    'rest_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    setIndex,
    targetReps,
    doneReps,
    partialReps,
    restSec,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('set_index')) {
      context.handle(
        _setIndexMeta,
        setIndex.isAcceptableOrUnknown(data['set_index']!, _setIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_setIndexMeta);
    }
    if (data.containsKey('target_reps')) {
      context.handle(
        _targetRepsMeta,
        targetReps.isAcceptableOrUnknown(data['target_reps']!, _targetRepsMeta),
      );
    } else if (isInserting) {
      context.missing(_targetRepsMeta);
    }
    if (data.containsKey('done_reps')) {
      context.handle(
        _doneRepsMeta,
        doneReps.isAcceptableOrUnknown(data['done_reps']!, _doneRepsMeta),
      );
    } else if (isInserting) {
      context.missing(_doneRepsMeta);
    }
    if (data.containsKey('partial_reps')) {
      context.handle(
        _partialRepsMeta,
        partialReps.isAcceptableOrUnknown(
          data['partial_reps']!,
          _partialRepsMeta,
        ),
      );
    }
    if (data.containsKey('rest_sec')) {
      context.handle(
        _restSecMeta,
        restSec.isAcceptableOrUnknown(data['rest_sec']!, _restSecMeta),
      );
    } else if (isInserting) {
      context.missing(_restSecMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      setIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_index'],
      )!,
      targetReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_reps'],
      )!,
      doneReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_reps'],
      )!,
      partialReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}partial_reps'],
      )!,
      restSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_sec'],
      )!,
    );
  }

  @override
  $WorkoutSetsTable createAlias(String alias) {
    return $WorkoutSetsTable(attachedDatabase, alias);
  }
}

class WorkoutSet extends DataClass implements Insertable<WorkoutSet> {
  /// 로컬 기본 키.
  final int id;

  /// 소속 세션.
  final int sessionId;

  /// 세션 안 순번(1부터).
  final int setIndex;

  /// 목표 반복 수.
  final int targetReps;

  /// 완료한 반복 수.
  final int doneReps;

  /// 부분 반복 수(0 이상).
  final int partialReps;

  /// 휴식 시간(초).
  final int restSec;
  const WorkoutSet({
    required this.id,
    required this.sessionId,
    required this.setIndex,
    required this.targetReps,
    required this.doneReps,
    required this.partialReps,
    required this.restSec,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['set_index'] = Variable<int>(setIndex);
    map['target_reps'] = Variable<int>(targetReps);
    map['done_reps'] = Variable<int>(doneReps);
    map['partial_reps'] = Variable<int>(partialReps);
    map['rest_sec'] = Variable<int>(restSec);
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      setIndex: Value(setIndex),
      targetReps: Value(targetReps),
      doneReps: Value(doneReps),
      partialReps: Value(partialReps),
      restSec: Value(restSec),
    );
  }

  factory WorkoutSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSet(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      setIndex: serializer.fromJson<int>(json['setIndex']),
      targetReps: serializer.fromJson<int>(json['targetReps']),
      doneReps: serializer.fromJson<int>(json['doneReps']),
      partialReps: serializer.fromJson<int>(json['partialReps']),
      restSec: serializer.fromJson<int>(json['restSec']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'setIndex': serializer.toJson<int>(setIndex),
      'targetReps': serializer.toJson<int>(targetReps),
      'doneReps': serializer.toJson<int>(doneReps),
      'partialReps': serializer.toJson<int>(partialReps),
      'restSec': serializer.toJson<int>(restSec),
    };
  }

  WorkoutSet copyWith({
    int? id,
    int? sessionId,
    int? setIndex,
    int? targetReps,
    int? doneReps,
    int? partialReps,
    int? restSec,
  }) => WorkoutSet(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    setIndex: setIndex ?? this.setIndex,
    targetReps: targetReps ?? this.targetReps,
    doneReps: doneReps ?? this.doneReps,
    partialReps: partialReps ?? this.partialReps,
    restSec: restSec ?? this.restSec,
  );
  WorkoutSet copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSet(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      setIndex: data.setIndex.present ? data.setIndex.value : this.setIndex,
      targetReps: data.targetReps.present
          ? data.targetReps.value
          : this.targetReps,
      doneReps: data.doneReps.present ? data.doneReps.value : this.doneReps,
      partialReps: data.partialReps.present
          ? data.partialReps.value
          : this.partialReps,
      restSec: data.restSec.present ? data.restSec.value : this.restSec,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSet(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('setIndex: $setIndex, ')
          ..write('targetReps: $targetReps, ')
          ..write('doneReps: $doneReps, ')
          ..write('partialReps: $partialReps, ')
          ..write('restSec: $restSec')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    setIndex,
    targetReps,
    doneReps,
    partialReps,
    restSec,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.setIndex == this.setIndex &&
          other.targetReps == this.targetReps &&
          other.doneReps == this.doneReps &&
          other.partialReps == this.partialReps &&
          other.restSec == this.restSec);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> setIndex;
  final Value<int> targetReps;
  final Value<int> doneReps;
  final Value<int> partialReps;
  final Value<int> restSec;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.setIndex = const Value.absent(),
    this.targetReps = const Value.absent(),
    this.doneReps = const Value.absent(),
    this.partialReps = const Value.absent(),
    this.restSec = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int setIndex,
    required int targetReps,
    required int doneReps,
    this.partialReps = const Value.absent(),
    required int restSec,
  }) : sessionId = Value(sessionId),
       setIndex = Value(setIndex),
       targetReps = Value(targetReps),
       doneReps = Value(doneReps),
       restSec = Value(restSec);
  static Insertable<WorkoutSet> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? setIndex,
    Expression<int>? targetReps,
    Expression<int>? doneReps,
    Expression<int>? partialReps,
    Expression<int>? restSec,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (setIndex != null) 'set_index': setIndex,
      if (targetReps != null) 'target_reps': targetReps,
      if (doneReps != null) 'done_reps': doneReps,
      if (partialReps != null) 'partial_reps': partialReps,
      if (restSec != null) 'rest_sec': restSec,
    });
  }

  WorkoutSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? setIndex,
    Value<int>? targetReps,
    Value<int>? doneReps,
    Value<int>? partialReps,
    Value<int>? restSec,
  }) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      setIndex: setIndex ?? this.setIndex,
      targetReps: targetReps ?? this.targetReps,
      doneReps: doneReps ?? this.doneReps,
      partialReps: partialReps ?? this.partialReps,
      restSec: restSec ?? this.restSec,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (setIndex.present) {
      map['set_index'] = Variable<int>(setIndex.value);
    }
    if (targetReps.present) {
      map['target_reps'] = Variable<int>(targetReps.value);
    }
    if (doneReps.present) {
      map['done_reps'] = Variable<int>(doneReps.value);
    }
    if (partialReps.present) {
      map['partial_reps'] = Variable<int>(partialReps.value);
    }
    if (restSec.present) {
      map['rest_sec'] = Variable<int>(restSec.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('setIndex: $setIndex, ')
          ..write('targetReps: $targetReps, ')
          ..write('doneReps: $doneReps, ')
          ..write('partialReps: $partialReps, ')
          ..write('restSec: $restSec')
          ..write(')'))
        .toString();
  }
}

class $RepRecordsTable extends RepRecords
    with TableInfo<$RepRecordsTable, RepRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _repIndexMeta = const VerificationMeta(
    'repIndex',
  );
  @override
  late final GeneratedColumn<int> repIndex = GeneratedColumn<int>(
    'rep_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minAngleMeta = const VerificationMeta(
    'minAngle',
  );
  @override
  late final GeneratedColumn<double> minAngle = GeneratedColumn<double>(
    'min_angle',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorsMeta = const VerificationMeta('errors');
  @override
  late final GeneratedColumn<String> errors = GeneratedColumn<String>(
    'errors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    repIndex,
    score,
    minAngle,
    durationMs,
    errors,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rep_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('rep_index')) {
      context.handle(
        _repIndexMeta,
        repIndex.isAcceptableOrUnknown(data['rep_index']!, _repIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_repIndexMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('min_angle')) {
      context.handle(
        _minAngleMeta,
        minAngle.isAcceptableOrUnknown(data['min_angle']!, _minAngleMeta),
      );
    } else if (isInserting) {
      context.missing(_minAngleMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('errors')) {
      context.handle(
        _errorsMeta,
        errors.isAcceptableOrUnknown(data['errors']!, _errorsMeta),
      );
    } else if (isInserting) {
      context.missing(_errorsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      repIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rep_index'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      minAngle: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_angle'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      errors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}errors'],
      )!,
    );
  }

  @override
  $RepRecordsTable createAlias(String alias) {
    return $RepRecordsTable(attachedDatabase, alias);
  }
}

class RepRecord extends DataClass implements Insertable<RepRecord> {
  /// 로컬 기본 키.
  final int id;

  /// 소속 세트.
  final int setId;

  /// 세트 안 순번(1부터).
  final int repIndex;

  /// 점수(0~100).
  final int score;

  /// 최소 관절 각도.
  final double minAngle;

  /// 반복에 걸린 시간(ms).
  final int durationMs;

  /// 오류 코드를 쉼표로 이은 문자열(없으면 빈 문자열).
  final String errors;
  const RepRecord({
    required this.id,
    required this.setId,
    required this.repIndex,
    required this.score,
    required this.minAngle,
    required this.durationMs,
    required this.errors,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['set_id'] = Variable<int>(setId);
    map['rep_index'] = Variable<int>(repIndex);
    map['score'] = Variable<int>(score);
    map['min_angle'] = Variable<double>(minAngle);
    map['duration_ms'] = Variable<int>(durationMs);
    map['errors'] = Variable<String>(errors);
    return map;
  }

  RepRecordsCompanion toCompanion(bool nullToAbsent) {
    return RepRecordsCompanion(
      id: Value(id),
      setId: Value(setId),
      repIndex: Value(repIndex),
      score: Value(score),
      minAngle: Value(minAngle),
      durationMs: Value(durationMs),
      errors: Value(errors),
    );
  }

  factory RepRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepRecord(
      id: serializer.fromJson<int>(json['id']),
      setId: serializer.fromJson<int>(json['setId']),
      repIndex: serializer.fromJson<int>(json['repIndex']),
      score: serializer.fromJson<int>(json['score']),
      minAngle: serializer.fromJson<double>(json['minAngle']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      errors: serializer.fromJson<String>(json['errors']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'setId': serializer.toJson<int>(setId),
      'repIndex': serializer.toJson<int>(repIndex),
      'score': serializer.toJson<int>(score),
      'minAngle': serializer.toJson<double>(minAngle),
      'durationMs': serializer.toJson<int>(durationMs),
      'errors': serializer.toJson<String>(errors),
    };
  }

  RepRecord copyWith({
    int? id,
    int? setId,
    int? repIndex,
    int? score,
    double? minAngle,
    int? durationMs,
    String? errors,
  }) => RepRecord(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    repIndex: repIndex ?? this.repIndex,
    score: score ?? this.score,
    minAngle: minAngle ?? this.minAngle,
    durationMs: durationMs ?? this.durationMs,
    errors: errors ?? this.errors,
  );
  RepRecord copyWithCompanion(RepRecordsCompanion data) {
    return RepRecord(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      repIndex: data.repIndex.present ? data.repIndex.value : this.repIndex,
      score: data.score.present ? data.score.value : this.score,
      minAngle: data.minAngle.present ? data.minAngle.value : this.minAngle,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      errors: data.errors.present ? data.errors.value : this.errors,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepRecord(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('repIndex: $repIndex, ')
          ..write('score: $score, ')
          ..write('minAngle: $minAngle, ')
          ..write('durationMs: $durationMs, ')
          ..write('errors: $errors')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, setId, repIndex, score, minAngle, durationMs, errors);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepRecord &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.repIndex == this.repIndex &&
          other.score == this.score &&
          other.minAngle == this.minAngle &&
          other.durationMs == this.durationMs &&
          other.errors == this.errors);
}

class RepRecordsCompanion extends UpdateCompanion<RepRecord> {
  final Value<int> id;
  final Value<int> setId;
  final Value<int> repIndex;
  final Value<int> score;
  final Value<double> minAngle;
  final Value<int> durationMs;
  final Value<String> errors;
  const RepRecordsCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.repIndex = const Value.absent(),
    this.score = const Value.absent(),
    this.minAngle = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.errors = const Value.absent(),
  });
  RepRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int setId,
    required int repIndex,
    required int score,
    required double minAngle,
    required int durationMs,
    required String errors,
  }) : setId = Value(setId),
       repIndex = Value(repIndex),
       score = Value(score),
       minAngle = Value(minAngle),
       durationMs = Value(durationMs),
       errors = Value(errors);
  static Insertable<RepRecord> custom({
    Expression<int>? id,
    Expression<int>? setId,
    Expression<int>? repIndex,
    Expression<int>? score,
    Expression<double>? minAngle,
    Expression<int>? durationMs,
    Expression<String>? errors,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (repIndex != null) 'rep_index': repIndex,
      if (score != null) 'score': score,
      if (minAngle != null) 'min_angle': minAngle,
      if (durationMs != null) 'duration_ms': durationMs,
      if (errors != null) 'errors': errors,
    });
  }

  RepRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? setId,
    Value<int>? repIndex,
    Value<int>? score,
    Value<double>? minAngle,
    Value<int>? durationMs,
    Value<String>? errors,
  }) {
    return RepRecordsCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      repIndex: repIndex ?? this.repIndex,
      score: score ?? this.score,
      minAngle: minAngle ?? this.minAngle,
      durationMs: durationMs ?? this.durationMs,
      errors: errors ?? this.errors,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (repIndex.present) {
      map['rep_index'] = Variable<int>(repIndex.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (minAngle.present) {
      map['min_angle'] = Variable<double>(minAngle.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (errors.present) {
      map['errors'] = Variable<String>(errors.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepRecordsCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('repIndex: $repIndex, ')
          ..write('score: $score, ')
          ..write('minAngle: $minAngle, ')
          ..write('durationMs: $durationMs, ')
          ..write('errors: $errors')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WorkoutSessionsTable workoutSessions = $WorkoutSessionsTable(
    this,
  );
  late final $WorkoutSetsTable workoutSets = $WorkoutSetsTable(this);
  late final $RepRecordsTable repRecords = $RepRecordsTable(this);
  late final Index workoutSessionsUserId = Index(
    'workout_sessions_user_id',
    'CREATE INDEX workout_sessions_user_id ON workout_sessions (user_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    workoutSessions,
    workoutSets,
    repRecords,
    workoutSessionsUserId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rep_records', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$WorkoutSessionsTableCreateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<int> id,
      required String clientId,
      Value<int?> userId,
      required String exercise,
      required DateTime startedAt,
      required DateTime endedAt,
      required String routineLevel,
      required int totalReps,
      required int avgScore,
      Value<String> syncStatus,
      Value<int> syncAttempts,
      Value<String?> lastError,
    });
typedef $$WorkoutSessionsTableUpdateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<int> id,
      Value<String> clientId,
      Value<int?> userId,
      Value<String> exercise,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<String> routineLevel,
      Value<int> totalReps,
      Value<int> avgScore,
      Value<String> syncStatus,
      Value<int> syncAttempts,
      Value<String?> lastError,
    });

final class $$WorkoutSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkoutSessionsTable, WorkoutSession> {
  $$WorkoutSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$WorkoutSetsTable, List<WorkoutSet>>
  _workoutSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSets,
    aliasName: 'workout_sessions__id__workout_sets__session_id',
  );

  $$WorkoutSetsTableProcessedTableManager get workoutSetsRefs {
    final manager = $$WorkoutSetsTableTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exercise => $composableBuilder(
    column: $table.exercise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineLevel => $composableBuilder(
    column: $table.routineLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalReps => $composableBuilder(
    column: $table.totalReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgScore => $composableBuilder(
    column: $table.avgScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncAttempts => $composableBuilder(
    column: $table.syncAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutSetsRefs(
    Expression<bool> Function($$WorkoutSetsTableFilterComposer f) f,
  ) {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exercise => $composableBuilder(
    column: $table.exercise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineLevel => $composableBuilder(
    column: $table.routineLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalReps => $composableBuilder(
    column: $table.totalReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgScore => $composableBuilder(
    column: $table.avgScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncAttempts => $composableBuilder(
    column: $table.syncAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get exercise =>
      $composableBuilder(column: $table.exercise, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get routineLevel => $composableBuilder(
    column: $table.routineLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalReps =>
      $composableBuilder(column: $table.totalReps, builder: (column) => column);

  GeneratedColumn<int> get avgScore =>
      $composableBuilder(column: $table.avgScore, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncAttempts => $composableBuilder(
    column: $table.syncAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  Expression<T> workoutSetsRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSessionsTable,
          WorkoutSession,
          $$WorkoutSessionsTableFilterComposer,
          $$WorkoutSessionsTableOrderingComposer,
          $$WorkoutSessionsTableAnnotationComposer,
          $$WorkoutSessionsTableCreateCompanionBuilder,
          $$WorkoutSessionsTableUpdateCompanionBuilder,
          (WorkoutSession, $$WorkoutSessionsTableReferences),
          WorkoutSession,
          PrefetchHooks Function({bool workoutSetsRefs})
        > {
  $$WorkoutSessionsTableTableManager(
    _$AppDatabase db,
    $WorkoutSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<String> exercise = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<String> routineLevel = const Value.absent(),
                Value<int> totalReps = const Value.absent(),
                Value<int> avgScore = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> syncAttempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => WorkoutSessionsCompanion(
                id: id,
                clientId: clientId,
                userId: userId,
                exercise: exercise,
                startedAt: startedAt,
                endedAt: endedAt,
                routineLevel: routineLevel,
                totalReps: totalReps,
                avgScore: avgScore,
                syncStatus: syncStatus,
                syncAttempts: syncAttempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientId,
                Value<int?> userId = const Value.absent(),
                required String exercise,
                required DateTime startedAt,
                required DateTime endedAt,
                required String routineLevel,
                required int totalReps,
                required int avgScore,
                Value<String> syncStatus = const Value.absent(),
                Value<int> syncAttempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => WorkoutSessionsCompanion.insert(
                id: id,
                clientId: clientId,
                userId: userId,
                exercise: exercise,
                startedAt: startedAt,
                endedAt: endedAt,
                routineLevel: routineLevel,
                totalReps: totalReps,
                avgScore: avgScore,
                syncStatus: syncStatus,
                syncAttempts: syncAttempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSessionsTable, WorkoutSession>(table),
                  $$WorkoutSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workoutSetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (workoutSetsRefs) db.workoutSets],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutSetsRefs)
                    await $_getPrefetchedDataByColumns<
                      WorkoutSession,
                      $WorkoutSessionsTable,
                      WorkoutSet,
                      $WorkoutSetsTable
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutSessionsTableReferences
                          ._workoutSetsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkoutSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).workoutSetsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'session_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSessionsTable,
      WorkoutSession,
      $$WorkoutSessionsTableFilterComposer,
      $$WorkoutSessionsTableOrderingComposer,
      $$WorkoutSessionsTableAnnotationComposer,
      $$WorkoutSessionsTableCreateCompanionBuilder,
      $$WorkoutSessionsTableUpdateCompanionBuilder,
      (WorkoutSession, $$WorkoutSessionsTableReferences),
      WorkoutSession,
      PrefetchHooks Function({bool workoutSetsRefs})
    >;
typedef $$WorkoutSetsTableCreateCompanionBuilder =
    WorkoutSetsCompanion Function({
      Value<int> id,
      required int sessionId,
      required int setIndex,
      required int targetReps,
      required int doneReps,
      Value<int> partialReps,
      required int restSec,
    });
typedef $$WorkoutSetsTableUpdateCompanionBuilder =
    WorkoutSetsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> setIndex,
      Value<int> targetReps,
      Value<int> doneReps,
      Value<int> partialReps,
      Value<int> restSec,
    });

final class $$WorkoutSetsTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutSetsTable, WorkoutSet> {
  $$WorkoutSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkoutSessionsTable _sessionIdTable(_$AppDatabase db) => db
      .workoutSessions
      .createAlias('workout_sets__session_id__workout_sessions__id');

  $$WorkoutSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$WorkoutSessionsTableTableManager(
      $_db,
      $_db.workoutSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RepRecordsTable, List<RepRecord>>
  _repRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.repRecords,
    aliasName: 'workout_sets__id__rep_records__set_id',
  );

  $$RepRecordsTableProcessedTableManager get repRecordsRefs {
    final manager = $$RepRecordsTableTableManager(
      $_db,
      $_db.repRecords,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_repRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutSetsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneReps => $composableBuilder(
    column: $table.doneReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partialReps => $composableBuilder(
    column: $table.partialReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSec => $composableBuilder(
    column: $table.restSec,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutSessionsTableFilterComposer get sessionId {
    final $$WorkoutSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> repRecordsRefs(
    Expression<bool> Function($$RepRecordsTableFilterComposer f) f,
  ) {
    final $$RepRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repRecords,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepRecordsTableFilterComposer(
            $db: $db,
            $table: $db.repRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneReps => $composableBuilder(
    column: $table.doneReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partialReps => $composableBuilder(
    column: $table.partialReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSec => $composableBuilder(
    column: $table.restSec,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutSessionsTableOrderingComposer get sessionId {
    final $$WorkoutSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get setIndex =>
      $composableBuilder(column: $table.setIndex, builder: (column) => column);

  GeneratedColumn<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get doneReps =>
      $composableBuilder(column: $table.doneReps, builder: (column) => column);

  GeneratedColumn<int> get partialReps => $composableBuilder(
    column: $table.partialReps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restSec =>
      $composableBuilder(column: $table.restSec, builder: (column) => column);

  $$WorkoutSessionsTableAnnotationComposer get sessionId {
    final $$WorkoutSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> repRecordsRefs<T extends Object>(
    Expression<T> Function($$RepRecordsTableAnnotationComposer a) f,
  ) {
    final $$RepRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repRecords,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.repRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSetsTable,
          WorkoutSet,
          $$WorkoutSetsTableFilterComposer,
          $$WorkoutSetsTableOrderingComposer,
          $$WorkoutSetsTableAnnotationComposer,
          $$WorkoutSetsTableCreateCompanionBuilder,
          $$WorkoutSetsTableUpdateCompanionBuilder,
          (WorkoutSet, $$WorkoutSetsTableReferences),
          WorkoutSet,
          PrefetchHooks Function({bool sessionId, bool repRecordsRefs})
        > {
  $$WorkoutSetsTableTableManager(_$AppDatabase db, $WorkoutSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> setIndex = const Value.absent(),
                Value<int> targetReps = const Value.absent(),
                Value<int> doneReps = const Value.absent(),
                Value<int> partialReps = const Value.absent(),
                Value<int> restSec = const Value.absent(),
              }) => WorkoutSetsCompanion(
                id: id,
                sessionId: sessionId,
                setIndex: setIndex,
                targetReps: targetReps,
                doneReps: doneReps,
                partialReps: partialReps,
                restSec: restSec,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int setIndex,
                required int targetReps,
                required int doneReps,
                Value<int> partialReps = const Value.absent(),
                required int restSec,
              }) => WorkoutSetsCompanion.insert(
                id: id,
                sessionId: sessionId,
                setIndex: setIndex,
                targetReps: targetReps,
                doneReps: doneReps,
                partialReps: partialReps,
                restSec: restSec,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSetsTable, WorkoutSet>(table),
                  $$WorkoutSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, repRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (repRecordsRefs) db.repRecords],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$WorkoutSetsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$WorkoutSetsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (repRecordsRefs)
                    await $_getPrefetchedDataByColumns<
                      WorkoutSet,
                      $WorkoutSetsTable,
                      RepRecord,
                      $RepRecordsTable
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutSetsTableReferences
                          ._repRecordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkoutSetsTableReferences(
                            db,
                            table,
                            p0,
                          ).repRecordsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'set_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSetsTable,
      WorkoutSet,
      $$WorkoutSetsTableFilterComposer,
      $$WorkoutSetsTableOrderingComposer,
      $$WorkoutSetsTableAnnotationComposer,
      $$WorkoutSetsTableCreateCompanionBuilder,
      $$WorkoutSetsTableUpdateCompanionBuilder,
      (WorkoutSet, $$WorkoutSetsTableReferences),
      WorkoutSet,
      PrefetchHooks Function({bool sessionId, bool repRecordsRefs})
    >;
typedef $$RepRecordsTableCreateCompanionBuilder = RepRecordsCompanion Function({
  Value<int> id,
  required int setId,
  required int repIndex,
  required int score,
  required double minAngle,
  required int durationMs,
  required String errors,
});
typedef $$RepRecordsTableUpdateCompanionBuilder = RepRecordsCompanion Function({
  Value<int> id,
  Value<int> setId,
  Value<int> repIndex,
  Value<int> score,
  Value<double> minAngle,
  Value<int> durationMs,
  Value<String> errors,
});

final class $$RepRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $RepRecordsTable, RepRecord> {
  $$RepRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkoutSetsTable _setIdTable(_$AppDatabase db) =>
      db.workoutSets.createAlias('rep_records__set_id__workout_sets__id');

  $$WorkoutSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$WorkoutSetsTableTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RepRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RepRecordsTable> {
  $$RepRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repIndex => $composableBuilder(
    column: $table.repIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minAngle => $composableBuilder(
    column: $table.minAngle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errors => $composableBuilder(
    column: $table.errors,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutSetsTableFilterComposer get setId {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RepRecordsTable> {
  $$RepRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repIndex => $composableBuilder(
    column: $table.repIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minAngle => $composableBuilder(
    column: $table.minAngle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errors => $composableBuilder(
    column: $table.errors,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutSetsTableOrderingComposer get setId {
    final $$WorkoutSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableOrderingComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepRecordsTable> {
  $$RepRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get repIndex =>
      $composableBuilder(column: $table.repIndex, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<double> get minAngle =>
      $composableBuilder(column: $table.minAngle, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errors =>
      $composableBuilder(column: $table.errors, builder: (column) => column);

  $$WorkoutSetsTableAnnotationComposer get setId {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepRecordsTable,
          RepRecord,
          $$RepRecordsTableFilterComposer,
          $$RepRecordsTableOrderingComposer,
          $$RepRecordsTableAnnotationComposer,
          $$RepRecordsTableCreateCompanionBuilder,
          $$RepRecordsTableUpdateCompanionBuilder,
          (RepRecord, $$RepRecordsTableReferences),
          RepRecord,
          PrefetchHooks Function({bool setId})
        > {
  $$RepRecordsTableTableManager(_$AppDatabase db, $RepRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> setId = const Value.absent(),
                Value<int> repIndex = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<double> minAngle = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> errors = const Value.absent(),
              }) => RepRecordsCompanion(
                id: id,
                setId: setId,
                repIndex: repIndex,
                score: score,
                minAngle: minAngle,
                durationMs: durationMs,
                errors: errors,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int setId,
                required int repIndex,
                required int score,
                required double minAngle,
                required int durationMs,
                required String errors,
              }) => RepRecordsCompanion.insert(
                id: id,
                setId: setId,
                repIndex: repIndex,
                score: score,
                minAngle: minAngle,
                durationMs: durationMs,
                errors: errors,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RepRecordsTable, RepRecord>(table),
                  $$RepRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.setId,
                        referencedTable: $$RepRecordsTableReferences
                            ._setIdTable(db),
                        referencedColumn: $$RepRecordsTableReferences
                            ._setIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RepRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepRecordsTable,
      RepRecord,
      $$RepRecordsTableFilterComposer,
      $$RepRecordsTableOrderingComposer,
      $$RepRecordsTableAnnotationComposer,
      $$RepRecordsTableCreateCompanionBuilder,
      $$RepRecordsTableUpdateCompanionBuilder,
      (RepRecord, $$RepRecordsTableReferences),
      RepRecord,
      PrefetchHooks Function({bool setId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(_db, _db.workoutSessions);
  $$WorkoutSetsTableTableManager get workoutSets =>
      $$WorkoutSetsTableTableManager(_db, _db.workoutSets);
  $$RepRecordsTableTableManager get repRecords =>
      $$RepRecordsTableTableManager(_db, _db.repRecords);
}
