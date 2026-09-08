import 'dart:convert';

import 'recent_lift_record.dart';

enum LoadKind { manual, fixedKg, percentOfBaseline }

enum BaselineSource { userEntered, recordedWeight }

enum SetActualStatus { completed, skipped }

final class LoadPrescription {
  final LoadKind kind;
  final double? value;
  final MainLift? lift;
  const LoadPrescription.manual()
    : kind = LoadKind.manual,
      value = null,
      lift = null;
  LoadPrescription.fixedKg(double kilograms)
    : kind = LoadKind.fixedKg,
      value = kilograms,
      lift = null {
    _positive(kilograms);
  }
  LoadPrescription.percentOfBaseline(MainLift baselineLift, double percent)
    : kind = LoadKind.percentOfBaseline,
      value = percent,
      lift = baselineLift {
    _positive(percent);
  }
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'value': value,
    'lift': lift?.key,
  };
  factory LoadPrescription.fromJson(Map<String, dynamic> json) =>
      switch (json['kind']) {
        'manual' => const LoadPrescription.manual(),
        'fixedKg' => LoadPrescription.fixedKg(_number(json['value'])),
        'percentOfBaseline' => LoadPrescription.percentOfBaseline(
          _lift(json['lift']),
          _number(json['value']),
        ),
        _ => throw const FormatException('Unknown load prescription'),
      };
}

final class LiftBaseline {
  final MainLift lift;
  final double kilograms;
  final BaselineSource source;
  final DateTime? recordDate;
  LiftBaseline({
    required this.lift,
    required this.kilograms,
    required this.source,
    DateTime? recordDate,
  }) : recordDate = recordDate == null ? null : calendarDate(recordDate) {
    _positive(kilograms);
    _check(
      source != BaselineSource.recordedWeight || recordDate != null,
      'Recorded baseline needs a date',
    );
  }
  Map<String, Object?> toJson() => {
    'lift': lift.key,
    'kilograms': kilograms,
    'source': source.name,
    'recordDate': recordDate == null ? null : isoDate(recordDate!),
  };
  factory LiftBaseline.fromJson(Map<String, dynamic> j) => LiftBaseline(
    lift: _lift(j['lift']),
    kilograms: _number(j['kilograms']),
    source: BaselineSource.values.byName(j['source'] as String),
    recordDate: j['recordDate'] == null
        ? null
        : parseCalendarDate(j['recordDate'] as String),
  );
}

final class ProgramSet {
  final String id;
  final int repetitions;
  final double? rir;
  final LoadPrescription load;
  final bool isRequired;
  ProgramSet({
    required this.id,
    required this.repetitions,
    this.rir,
    required this.load,
    this.isRequired = true,
  }) {
    _id(id);
    _check(repetitions > 0, 'Repetitions must be positive');
    _rir(rir);
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'repetitions': repetitions,
    'rir': rir,
    'load': load.toJson(),
    'isRequired': isRequired,
  };
  factory ProgramSet.fromJson(Map<String, dynamic> j) => ProgramSet(
    id: j['id'] as String,
    repetitions: j['repetitions'] as int,
    rir: (j['rir'] as num?)?.toDouble(),
    load: LoadPrescription.fromJson(_map(j['load'])),
    isRequired: j['isRequired'] as bool,
  );
}

final class ProgramExercise {
  final String id, name;
  final MainLift? mainLift;
  final List<ProgramSet> sets;
  ProgramExercise({
    required this.id,
    required this.name,
    this.mainLift,
    required List<ProgramSet> sets,
  }) : sets = List.unmodifiable(sets) {
    _id(id);
    _id(name);
    _unique(sets.map((set) => set.id));
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'mainLift': mainLift?.key,
    'sets': sets.map((set) => set.toJson()).toList(),
  };
  factory ProgramExercise.fromJson(Map<String, dynamic> j) => ProgramExercise(
    id: j['id'] as String,
    name: j['name'] as String,
    mainLift: j['mainLift'] == null ? null : _lift(j['mainLift']),
    sets: (j['sets'] as List).map((v) => ProgramSet.fromJson(_map(v))).toList(),
  );
}

final class ProgramSession {
  final String id, title;
  final int week, dayOrder;
  final List<ProgramExercise> exercises;
  ProgramSession({
    required this.id,
    required this.week,
    required this.dayOrder,
    required this.title,
    required List<ProgramExercise> exercises,
  }) : exercises = List.unmodifiable(exercises) {
    _id(id);
    _id(title);
    _check(week > 0 && dayOrder > 0, 'Invalid week or session order');
    _unique(exercises.map((exercise) => exercise.id));
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'week': week,
    'dayOrder': dayOrder,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
  factory ProgramSession.fromJson(Map<String, dynamic> j) => ProgramSession(
    id: j['id'] as String,
    title: j['title'] as String,
    week: j['week'] as int,
    dayOrder: j['dayOrder'] as int,
    exercises: (j['exercises'] as List)
        .map((v) => ProgramExercise.fromJson(_map(v)))
        .toList(),
  );
}

/// 트레이너의 전체 프로그램 스냅샷. 각 주의 세션 수와 순서를 명시한다.
final class TrainingProgram {
  final String id, version, title, trainerName, description;
  final int weeks;
  final List<ProgramSession> sessions;
  TrainingProgram({
    required this.id,
    required this.version,
    required this.title,
    required this.trainerName,
    required this.description,
    required this.weeks,
    required List<ProgramSession> sessions,
  }) : sessions = List.unmodifiable(sessions) {
    for (final value in [id, version, title, trainerName]) {
      _id(value);
    }
    _check(weeks > 0, 'Weeks must be positive');
    _unique(sessions.map((s) => s.id));
    final count = sessions.where((s) => s.week == 1).length;
    _check(
      count > 0 && count <= 7 && sessions.length == weeks * count,
      'Invalid weekly session count',
    );
    for (var week = 1; week <= weeks; week++) {
      final orders = sessions
          .where((s) => s.week == week)
          .map((s) => s.dayOrder)
          .toSet();
      _check(
        orders.length == count &&
            List.generate(count, (i) => i + 1).every(orders.contains),
        'Each week needs contiguous session order',
      );
    }
  }
  int get sessionsPerWeek => sessions.length ~/ weeks;
  List<ProgramSession> get orderedSessions => List.of(sessions)
    ..sort(
      (a, b) => a.week == b.week
          ? a.dayOrder.compareTo(b.dayOrder)
          : a.week.compareTo(b.week),
    );
  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'title': title,
    'trainerName': trainerName,
    'description': description,
    'weeks': weeks,
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };
  factory TrainingProgram.fromJson(Map<String, dynamic> j) => TrainingProgram(
    id: j['id'] as String,
    version: j['version'] as String,
    title: j['title'] as String,
    trainerName: j['trainerName'] as String,
    description: j['description'] as String,
    weeks: j['weeks'] as int,
    sessions: (j['sessions'] as List)
        .map((v) => ProgramSession.fromJson(_map(v)))
        .toList(),
  );
}

final class PlannedSet {
  final String id;
  final ProgramSet template;
  final double? targetKg;
  const PlannedSet._(this.id, this.template, this.targetKg);
  int get repetitions => template.repetitions;
  double? get rir => template.rir;
  bool get isRequired => template.isRequired;
}

final class PlannedExercise {
  final String id, name;
  final List<PlannedSet> sets;
  PlannedExercise._(this.id, this.name, List<PlannedSet> sets)
    : sets = List.unmodifiable(sets);
}

final class PlannedSession {
  final String id, title;
  final int week, dayOrder;
  final DateTime date;
  final List<PlannedExercise> exercises;
  PlannedSession._(
    this.id,
    this.title,
    this.week,
    this.dayOrder,
    this.date,
    List<PlannedExercise> exercises,
  ) : exercises = List.unmodifiable(exercises);
}

/// 저장된 날짜·중량은 현재 시각이나 새 프로그램에서 다시 계산하지 않는다.
final class ActiveTrainingPlan {
  final String id;
  final TrainingProgram program;
  final DateTime startDate;
  final List<int> weekdays;
  final double incrementKg;
  final Map<MainLift, LiftBaseline> baselines;
  final Map<String, DateTime> sessionDates;
  final Map<String, double?> targetKgBySetId;
  ActiveTrainingPlan._({
    required this.id,
    required this.program,
    required DateTime startDate,
    required List<int> weekdays,
    required this.incrementKg,
    required Map<MainLift, LiftBaseline> baselines,
    required Map<String, DateTime> sessionDates,
    required Map<String, double?> targetKgBySetId,
  }) : startDate = calendarDate(startDate),
       weekdays = List.unmodifiable(weekdays),
       baselines = Map.unmodifiable(baselines),
       sessionDates = Map.unmodifiable(sessionDates),
       targetKgBySetId = Map.unmodifiable(targetKgBySetId) {
    _id(id);
    _positive(incrementKg);
    _weekdays(weekdays, program.sessionsPerWeek);
    _check(
      baselines.entries.every((e) => e.key == e.value.lift),
      'Baseline lift mismatch',
    );
    final expectedSessions = program.sessions
        .map((s) => _path([id, s.id]))
        .toSet();
    final expectedSets = _sets(program, id);
    _check(
      _sameKeys(sessionDates.keys, expectedSessions) &&
          _sameKeys(targetKgBySetId.keys, expectedSets.keys.toSet()),
      'Incomplete plan snapshot',
    );
    for (final entry in expectedSets.entries) {
      _check(
        (entry.value.load.kind == LoadKind.manual) ==
            (targetKgBySetId[entry.key] == null),
        'Snapshot target does not match authored load type',
      );
    }
    for (final weight in targetKgBySetId.values) {
      if (weight != null) _positive(weight);
    }
    DateTime? previous;
    for (final session in program.orderedSessions) {
      final date = sessionDates[_path([id, session.id])]!;
      _check(
        date == calendarDate(date) &&
            !date.isBefore(this.startDate) &&
            weekdays.contains(date.weekday),
        'Invalid planned date',
      );
      _check(
        previous == null || date.isAfter(previous),
        'Session dates must preserve order',
      );
      previous = date;
    }
  }
  List<PlannedSession> get sessions => List.unmodifiable(
    program.orderedSessions.map(
      (s) => PlannedSession._(
        _path([id, s.id]),
        s.title,
        s.week,
        s.dayOrder,
        sessionDates[_path([id, s.id])]!,
        s.exercises
            .map(
              (e) => PlannedExercise._(
                _path([id, s.id, e.id]),
                e.name,
                e.sets.map((set) {
                  final key = _path([id, s.id, e.id, set.id]);
                  return PlannedSet._(key, set, targetKgBySetId[key]);
                }).toList(),
              ),
            )
            .toList(),
      ),
    ),
  );

  /// 명시적 일정 편집만 허용한다. 오늘/과거 세션의 날짜는 보존한다.
  ActiveTrainingPlan rescheduleFuture(
    Map<String, DateTime> changes, {
    required DateTime asOf,
  }) {
    final dates = Map.of(sessionDates);
    for (final entry in changes.entries) {
      _check(dates.containsKey(entry.key), 'Unknown session');
      final next = calendarDate(entry.value);
      _check(
        dates[entry.key]!.isAfter(calendarDate(asOf)) &&
            next.isAfter(calendarDate(asOf)),
        'Only future sessions may move',
      );
      dates[entry.key] = next;
    }
    return ActiveTrainingPlan._(
      id: id,
      program: program,
      startDate: startDate,
      weekdays: weekdays,
      incrementKg: incrementKg,
      baselines: baselines,
      sessionDates: dates,
      targetKgBySetId: targetKgBySetId,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'program': program.toJson(),
    'startDate': isoDate(startDate),
    'weekdays': weekdays,
    'incrementKg': incrementKg,
    'baselines': baselines.values.map((b) => b.toJson()).toList(),
    'sessionDates': sessionDates.map(
      (key, value) => MapEntry(key, isoDate(value)),
    ),
    'targets': targetKgBySetId,
  };
  factory ActiveTrainingPlan.fromJson(Map<String, dynamic> j) {
    final baselineList = (j['baselines'] as List)
        .map((v) => LiftBaseline.fromJson(_map(v)))
        .toList();
    _check(
      baselineList.map((b) => b.lift).toSet().length == baselineList.length,
      'Duplicate baseline',
    );
    return ActiveTrainingPlan._(
      id: j['id'] as String,
      program: TrainingProgram.fromJson(_map(j['program'])),
      startDate: parseCalendarDate(j['startDate'] as String),
      weekdays: (j['weekdays'] as List).cast<int>(),
      incrementKg: _number(j['incrementKg']),
      baselines: {for (final b in baselineList) b.lift: b},
      sessionDates: _map(
        j['sessionDates'],
      ).map((key, value) => MapEntry(key, parseCalendarDate(value as String))),
      targetKgBySetId: _map(
        j['targets'],
      ).map((key, value) => MapEntry(key, (value as num?)?.toDouble())),
    );
  }
}

ActiveTrainingPlan createActivePlan({
  required String id,
  required TrainingProgram program,
  required DateTime startDate,
  required List<int> weekdays,
  required double incrementKg,
  Map<MainLift, LiftBaseline> baselines = const {},
}) {
  _positive(incrementKg);
  _weekdays(weekdays, program.sessionsPerWeek);
  final dates = <String, DateTime>{};
  var day = calendarDate(startDate);
  for (final session in program.orderedSessions) {
    while (!weekdays.contains(day.weekday)) {
      day = day.add(const Duration(days: 1));
    }
    dates[_path([id, session.id])] = day;
    day = day.add(const Duration(days: 1));
  }
  final targets = <String, double?>{};
  for (final entry in _sets(program, id).entries) {
    final load = entry.value.load;
    double? weight;
    if (load.kind == LoadKind.fixedKg) weight = load.value;
    if (load.kind == LoadKind.percentOfBaseline) {
      final baseline = baselines[load.lift];
      _check(baseline != null, 'Missing baseline for ${load.lift!.key}');
      _check(
        baseline!.recordDate == null ||
            !baseline.recordDate!.isAfter(calendarDate(startDate)),
        'Baseline record is in the future',
      );
      weight = baseline.kilograms * load.value! / 100;
    }
    if (weight != null) {
      _positive(weight);
      _positive(weight / incrementKg);
    }
    targets[entry.key] = weight == null
        ? null
        : (weight / incrementKg).round() * incrementKg;
  }
  return ActiveTrainingPlan._(
    id: id,
    program: program,
    startDate: startDate,
    weekdays: weekdays,
    incrementKg: incrementKg,
    baselines: baselines,
    sessionDates: dates,
    targetKgBySetId: targets,
  );
}

final class SetActual {
  final SetActualStatus status;
  final double? weight, rir;
  final WeightUnit? unit;
  final int? repetitions;
  final String note;
  SetActual.completed({
    required double this.weight,
    required WeightUnit this.unit,
    required int this.repetitions,
    this.rir,
    this.note = '',
  }) : status = SetActualStatus.completed {
    _check(
      weight!.isFinite && weight! >= 0,
      'Actual weight must be finite and nonnegative',
    );
    _check(repetitions! > 0, 'Actual repetitions must be positive');
    _rir(rir);
  }
  const SetActual.skipped({this.note = ''})
    : status = SetActualStatus.skipped,
      weight = null,
      unit = null,
      repetitions = null,
      rir = null;
  Map<String, Object?> toJson() => {
    'status': status.name,
    'weight': weight,
    'unit': unit?.key,
    'repetitions': repetitions,
    'rir': rir,
    'note': note,
  };
  factory SetActual.fromJson(Map<String, dynamic> j) => switch (j['status']) {
    'completed' => SetActual.completed(
      weight: _number(j['weight']),
      unit: WeightUnit.values.byName(j['unit'] as String),
      repetitions: j['repetitions'] as int,
      rir: (j['rir'] as num?)?.toDouble(),
      note: j['note'] as String,
    ),
    'skipped' => SetActual.skipped(note: j['note'] as String),
    _ => throw const FormatException('Unknown set status'),
  };
}

/// 원본 계획을 바꾸지 않는 사용자 승인 중량 조정 이력.
final class TargetLoadAdjustment {
  final String id, planId, exerciseKey, exerciseName, policyId;
  final DateTime appliedOn;
  final DateTime? undoneOn;
  final List<String> evidenceSessionIds;
  final List<double> evidenceRirGaps;
  final Map<String, String> evidenceRecords;
  final Map<String, double> beforeKg, afterKg;
  TargetLoadAdjustment({
    required this.id,
    required this.planId,
    required this.exerciseKey,
    required this.exerciseName,
    required this.policyId,
    required DateTime appliedOn,
    DateTime? undoneOn,
    required List<String> evidenceSessionIds,
    required List<double> evidenceRirGaps,
    required Map<String, String> evidenceRecords,
    required Map<String, double> beforeKg,
    required Map<String, double> afterKg,
  }) : appliedOn = calendarDate(appliedOn),
       undoneOn = undoneOn == null ? null : calendarDate(undoneOn),
       evidenceSessionIds = List.unmodifiable(evidenceSessionIds),
       evidenceRirGaps = List.unmodifiable(evidenceRirGaps),
       evidenceRecords = Map.unmodifiable(evidenceRecords),
       beforeKg = Map.unmodifiable(beforeKg),
       afterKg = Map.unmodifiable(afterKg) {
    for (final value in [id, planId, exerciseKey, exerciseName, policyId]) {
      _id(value);
    }
    _unique(evidenceSessionIds);
    _check(
      evidenceRirGaps.length == evidenceSessionIds.length &&
          evidenceRirGaps.every((gap) => gap.isFinite),
      'Invalid adjustment evidence',
    );
    _check(
      evidenceRecords.isNotEmpty &&
          beforeKg.isNotEmpty &&
          _sameKeys(afterKg.keys, beforeKg.keys.toSet()),
      'Incomplete adjustment',
    );
    for (final key in beforeKg.keys) {
      _positive(beforeKg[key]!);
      _positive(afterKg[key]!);
      _check(afterKg[key]! < beforeKg[key]!, 'Adjustment must reduce load');
    }
    _check(
      this.undoneOn == null || !this.undoneOn!.isBefore(this.appliedOn),
      'Undo precedes application',
    );
  }
  bool get isUndone => undoneOn != null;
  TargetLoadAdjustment undone(DateTime asOf) => TargetLoadAdjustment(
    id: id,
    planId: planId,
    exerciseKey: exerciseKey,
    exerciseName: exerciseName,
    policyId: policyId,
    appliedOn: appliedOn,
    undoneOn: asOf,
    evidenceSessionIds: evidenceSessionIds,
    evidenceRirGaps: evidenceRirGaps,
    evidenceRecords: evidenceRecords,
    beforeKg: beforeKg,
    afterKg: afterKg,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'planId': planId,
    'exerciseKey': exerciseKey,
    'exerciseName': exerciseName,
    'policyId': policyId,
    'appliedOn': isoDate(appliedOn),
    'undoneOn': undoneOn == null ? null : isoDate(undoneOn!),
    'evidenceSessionIds': evidenceSessionIds,
    'evidenceRirGaps': evidenceRirGaps,
    'evidenceRecords': evidenceRecords,
    'beforeKg': beforeKg,
    'afterKg': afterKg,
  };
  factory TargetLoadAdjustment.fromJson(Map<String, dynamic> j) =>
      TargetLoadAdjustment(
        id: j['id'] as String,
        planId: j['planId'] as String,
        exerciseKey: j['exerciseKey'] as String,
        exerciseName: j['exerciseName'] as String,
        policyId: j['policyId'] as String,
        appliedOn: parseCalendarDate(j['appliedOn'] as String),
        undoneOn: j['undoneOn'] == null
            ? null
            : parseCalendarDate(j['undoneOn'] as String),
        evidenceSessionIds: (j['evidenceSessionIds'] as List).cast<String>(),
        evidenceRirGaps: (j['evidenceRirGaps'] as List).map(_number).toList(),
        evidenceRecords: _map(j['evidenceRecords']).cast<String, String>(),
        beforeKg: _map(
          j['beforeKg'],
        ).map((key, value) => MapEntry(key, _number(value))),
        afterKg: _map(
          j['afterKg'],
        ).map((key, value) => MapEntry(key, _number(value))),
      );
}

final class TrainingAppState {
  final bool onboarded;
  final List<RecentLiftRecord> recentRecords;
  final ActiveTrainingPlan? activePlan;
  final List<ActiveTrainingPlan> planHistory;
  final Map<String, SetActual> setActuals;
  final Map<String, Map<String, String>> setDrafts;
  final Map<String, String> sessionNotes;
  final Set<String> completionNotified;
  final List<TargetLoadAdjustment> loadAdjustments;
  TrainingAppState({
    this.onboarded = false,
    List<RecentLiftRecord> recentRecords = const [],
    this.activePlan,
    List<ActiveTrainingPlan> planHistory = const [],
    Map<String, SetActual> setActuals = const {},
    Map<String, Map<String, String>> setDrafts = const {},
    Map<String, String> sessionNotes = const {},
    Set<String> completionNotified = const {},
    List<TargetLoadAdjustment> loadAdjustments = const [],
  }) : recentRecords = List.unmodifiable(recentRecords),
       planHistory = List.unmodifiable(planHistory),
       setActuals = Map.unmodifiable(setActuals),
       setDrafts = Map.unmodifiable(
         setDrafts.map(
           (key, value) =>
               MapEntry(key, Map<String, String>.unmodifiable(value)),
         ),
       ),
       sessionNotes = Map.unmodifiable(sessionNotes),
       completionNotified = Set.unmodifiable(completionNotified),
       loadAdjustments = List.unmodifiable(loadAdjustments) {
    final plans = [...planHistory, if (activePlan != null) activePlan!];
    _check(
      recentRecords.every(
        (record) => record.validate(asOf: record.date).isValid,
      ),
      'Invalid recent lift record',
    );
    _check(
      plans.map((p) => p.id).toSet().length == plans.length,
      'Duplicate plan id',
    );
    final sessionIds = plans.expand((p) => p.sessions).map((s) => s.id).toSet();
    final setIds = plans.expand((p) => p.targetKgBySetId.keys).toSet();
    _check(
      setActuals.keys.every(setIds.contains) &&
          setDrafts.keys.every(setIds.contains) &&
          sessionNotes.keys.every(sessionIds.contains) &&
          completionNotified.every(sessionIds.contains),
      'Orphaned workout record',
    );
    _check(
      setDrafts.values.every(
        (draft) => draft.keys.every(
          const ['weight', 'repetitions', 'rir', 'note', 'unit'].contains,
        ),
      ),
      'Unknown draft field',
    );
    _check(
      loadAdjustments.map((a) => a.id).toSet().length == loadAdjustments.length,
      'Duplicate load adjustment',
    );
    _check(
      loadAdjustments
              .map((a) => jsonEncode([a.exerciseKey, a.evidenceSessionIds]))
              .toSet()
              .length ==
          loadAdjustments.length,
      'Duplicate adjustment evidence',
    );
    final effective = {for (final p in plans) ...p.targetKgBySetId};
    for (final adjustment in loadAdjustments) {
      final matches = plans.where((p) => p.id == adjustment.planId);
      _check(matches.length == 1, 'Orphaned load adjustment');
      final plan = matches.single;
      final dates = {
        for (final s in plan.sessions)
          for (final e in s.exercises)
            for (final set in e.sets) set.id: s.date,
      };
      _check(
        adjustment.evidenceSessionIds.every(
              (id) => plan.sessionDates.containsKey(id),
            ) &&
            adjustment.evidenceRecords.keys.every(
              plan.targetKgBySetId.containsKey,
            ),
        'Orphaned adjustment evidence',
      );
      for (final key in adjustment.afterKg.keys) {
        _check(
          dates.containsKey(key) &&
              dates[key]!.isAfter(adjustment.appliedOn) &&
              plan.targetKgBySetId[key] != null,
          'Invalid adjusted set',
        );
        if (!adjustment.isUndone) {
          _check(
            effective[key] == adjustment.beforeKg[key],
            'Broken adjustment chain',
          );
          effective[key] = adjustment.afterKg[key];
        }
      }
    }
  }
  TrainingAppState copyWith({
    bool? onboarded,
    List<RecentLiftRecord>? recentRecords,
  }) => TrainingAppState(
    onboarded: onboarded ?? this.onboarded,
    recentRecords: recentRecords ?? this.recentRecords,
    activePlan: activePlan,
    planHistory: planHistory,
    setActuals: setActuals,
    setDrafts: setDrafts,
    sessionNotes: sessionNotes,
    completionNotified: completionNotified,
    loadAdjustments: loadAdjustments,
  );
  TrainingAppState withActivePlan(ActiveTrainingPlan plan) => TrainingAppState(
    onboarded: onboarded,
    recentRecords: recentRecords,
    activePlan: plan,
    planHistory: [...planHistory, if (activePlan != null) activePlan!],
    setActuals: setActuals,
    setDrafts: setDrafts,
    sessionNotes: sessionNotes,
    completionNotified: completionNotified,
    loadAdjustments: loadAdjustments,
  );
  TrainingAppState withSetActual(String plannedSetId, SetActual? actual) {
    _check(
      activePlan?.targetKgBySetId.containsKey(plannedSetId) ?? false,
      'Set is not in the active plan',
    );
    final updated = Map.of(setActuals);
    final drafts = Map.of(setDrafts);
    if (actual == null) {
      updated.remove(plannedSetId);
    } else {
      updated[plannedSetId] = actual;
    }
    if (actual != null) drafts.remove(plannedSetId);
    return TrainingAppState(
      onboarded: onboarded,
      recentRecords: recentRecords,
      activePlan: activePlan,
      planHistory: planHistory,
      setActuals: updated,
      setDrafts: drafts,
      sessionNotes: sessionNotes,
      completionNotified: completionNotified,
      loadAdjustments: loadAdjustments,
    );
  }

  TrainingAppState withSetDraft(
    String plannedSetId,
    Map<String, String>? draft,
  ) {
    _check(
      activePlan?.targetKgBySetId.containsKey(plannedSetId) ?? false,
      'Set is not in the active plan',
    );
    final drafts = Map.of(setDrafts);
    if (draft == null) {
      drafts.remove(plannedSetId);
    } else {
      drafts[plannedSetId] = draft;
    }
    return TrainingAppState(
      onboarded: onboarded,
      recentRecords: recentRecords,
      activePlan: activePlan,
      planHistory: planHistory,
      setActuals: setActuals,
      setDrafts: drafts,
      sessionNotes: sessionNotes,
      completionNotified: completionNotified,
      loadAdjustments: loadAdjustments,
    );
  }

  TrainingAppState withSessionNote(String sessionId, String note) =>
      TrainingAppState(
        onboarded: onboarded,
        recentRecords: recentRecords,
        activePlan: activePlan,
        planHistory: planHistory,
        setActuals: setActuals,
        setDrafts: setDrafts,
        sessionNotes: {...sessionNotes, sessionId: note},
        completionNotified: completionNotified,
        loadAdjustments: loadAdjustments,
      );
  TrainingAppState withCompletionNotified(String sessionId) {
    _check(isSessionComplete(sessionId), 'Session is not complete');
    return TrainingAppState(
      onboarded: onboarded,
      recentRecords: recentRecords,
      activePlan: activePlan,
      planHistory: planHistory,
      setActuals: setActuals,
      setDrafts: setDrafts,
      sessionNotes: sessionNotes,
      completionNotified: {...completionNotified, sessionId},
      loadAdjustments: loadAdjustments,
    );
  }

  double? effectiveTargetKg(PlannedSet set) {
    for (final adjustment in loadAdjustments.reversed) {
      if (!adjustment.isUndone && adjustment.afterKg.containsKey(set.id)) {
        return adjustment.afterKg[set.id];
      }
    }
    return set.targetKg;
  }

  void _requireEditableTargets(TargetLoadAdjustment adjustment, DateTime asOf) {
    _check(activePlan?.id == adjustment.planId, '현재 진행 중인 계획에서만 변경할 수 있어요.');
    final dates = {
      for (final s in activePlan!.sessions)
        for (final e in s.exercises)
          for (final set in e.sets) set.id: s.date,
    };
    _check(
      adjustment.afterKg.keys.every(
        (id) =>
            dates.containsKey(id) &&
            dates[id]!.isAfter(calendarDate(asOf)) &&
            !setActuals.containsKey(id) &&
            !setDrafts.containsKey(id),
      ),
      '오늘·지난 세트 또는 기록·초안이 있는 세트는 바꾸지 않아요.',
    );
  }

  TrainingAppState withLoadAdjustment(
    TargetLoadAdjustment adjustment, {
    required DateTime asOf,
  }) {
    _check(
      !adjustment.isUndone && adjustment.appliedOn == calendarDate(asOf),
      '조정 날짜를 다시 확인해 주세요.',
    );
    _check(
      !loadAdjustments.any(
        (a) =>
            a.id == adjustment.id ||
            a.exerciseKey == adjustment.exerciseKey &&
                jsonEncode(a.evidenceSessionIds) ==
                    jsonEncode(adjustment.evidenceSessionIds),
      ),
      '이미 처리한 제안이에요.',
    );
    _requireEditableTargets(adjustment, asOf);
    _check(
      adjustment.evidenceRecords.entries.every(
        (entry) =>
            !setDrafts.containsKey(entry.key) &&
            setActuals[entry.key] != null &&
            jsonEncode(setActuals[entry.key]!.toJson()) == entry.value,
      ),
      '근거 기록이 바뀌었어요. 제안을 다시 확인해 주세요.',
    );
    return _withAdjustments([...loadAdjustments, adjustment]);
  }

  TrainingAppState undoLoadAdjustment(String id, {required DateTime asOf}) {
    final matches = loadAdjustments.where((a) => a.id == id);
    _check(matches.length == 1, '조정 이력을 찾을 수 없어요.');
    final adjustment = matches.single;
    _check(!adjustment.isUndone, '이미 되돌린 제안이에요.');
    _requireEditableTargets(adjustment, asOf);
    final index = loadAdjustments.indexOf(adjustment);
    _check(
      !loadAdjustments
          .skip(index + 1)
          .any(
            (a) =>
                !a.isUndone &&
                a.afterKg.keys.any(adjustment.afterKg.containsKey),
          ),
      '이후 조정을 먼저 되돌려 주세요.',
    );
    return _withAdjustments([
      for (final a in loadAdjustments) a.id == id ? a.undone(asOf) : a,
    ]);
  }

  TrainingAppState _withAdjustments(List<TargetLoadAdjustment> adjustments) =>
      TrainingAppState(
        onboarded: onboarded,
        recentRecords: recentRecords,
        activePlan: activePlan,
        planHistory: planHistory,
        setActuals: setActuals,
        setDrafts: setDrafts,
        sessionNotes: sessionNotes,
        completionNotified: completionNotified,
        loadAdjustments: adjustments,
      );

  bool isSessionComplete(String sessionId) {
    final matching = [
      ...planHistory,
      if (activePlan != null) activePlan!,
    ].expand((p) => p.sessions).where((s) => s.id == sessionId);
    if (matching.isEmpty) return false;
    final requiredSets = matching.single.exercises
        .expand((e) => e.sets)
        .where((set) => set.isRequired)
        .toList();
    return requiredSets.isNotEmpty &&
        requiredSets.every((set) => setActuals.containsKey(set.id));
  }

  Map<String, Object?> toJson() => {
    'onboarded': onboarded,
    'recentRecords': recentRecords.map((r) => r.toJson()).toList(),
    'activePlan': activePlan?.toJson(),
    'planHistory': planHistory.map((p) => p.toJson()).toList(),
    'setActuals': setActuals.map((key, value) => MapEntry(key, value.toJson())),
    'setDrafts': setDrafts,
    'sessionNotes': sessionNotes,
    'completionNotified': completionNotified.toList(),
    'loadAdjustments': loadAdjustments.map((a) => a.toJson()).toList(),
  };
  factory TrainingAppState.fromJson(Map<String, dynamic> j) => TrainingAppState(
    onboarded: j['onboarded'] as bool,
    recentRecords: (j['recentRecords'] as List)
        .map((v) => RecentLiftRecord.fromJson(_map(v)))
        .toList(),
    activePlan: j['activePlan'] == null
        ? null
        : ActiveTrainingPlan.fromJson(_map(j['activePlan'])),
    planHistory: (j['planHistory'] as List)
        .map((v) => ActiveTrainingPlan.fromJson(_map(v)))
        .toList(),
    setActuals: _map(
      j['setActuals'],
    ).map((key, value) => MapEntry(key, SetActual.fromJson(_map(value)))),
    setDrafts: _map(
      j['setDrafts'],
    ).map((key, value) => MapEntry(key, _map(value).cast<String, String>())),
    sessionNotes: _map(j['sessionNotes']).cast<String, String>(),
    completionNotified: (j['completionNotified'] as List)
        .cast<String>()
        .toSet(),
    loadAdjustments: j.containsKey('loadAdjustments')
        ? (j['loadAdjustments'] as List)
              .map((v) => TargetLoadAdjustment.fromJson(_map(v)))
              .toList()
        : const [],
  );
}

DateTime calendarDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
String isoDate(DateTime value) =>
    calendarDate(value).toIso8601String().split('T').first;
DateTime parseCalendarDate(String value) {
  _check(
    RegExp(r'^[+-]?\d{4,6}-\d{2}-\d{2}$').hasMatch(value),
    'Expected calendar date',
  );
  final date = calendarDate(DateTime.parse(value));
  _check(isoDate(date) == value, 'Invalid calendar date');
  return date;
}

void _check(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

void _positive(double value) =>
    _check(value.isFinite && value > 0, 'Expected positive finite number');
void _rir(double? value) =>
    _check(value == null || value.isFinite && value >= 0, 'Invalid RIR');
void _id(String value) =>
    _check(value.trim().isNotEmpty, 'Identifier or label is empty');
void _unique(Iterable<String> ids) {
  final values = ids.toList();
  _check(
    values.isNotEmpty && values.toSet().length == values.length,
    'Empty or duplicate composition ids',
  );
}

void _weekdays(List<int> days, int count) => _check(
  days.length == count &&
      days.toSet().length == count &&
      days.every((day) => day >= 1 && day <= 7),
  'Choose one unique ISO weekday per weekly session',
);
bool _sameKeys(Iterable<String> actual, Set<String> expected) =>
    actual.length == expected.length && actual.every(expected.contains);
Map<String, dynamic> _map(Object? value) =>
    Map<String, dynamic>.from(value as Map);
double _number(Object? value) => (value as num).toDouble();
MainLift _lift(Object? value) => MainLift.values.firstWhere(
  (lift) => lift.key == value,
  orElse: () => throw const FormatException('Unknown main lift'),
);
String _path(List<String> parts) => jsonEncode(parts);
Map<String, ProgramSet> _sets(TrainingProgram program, String planId) => {
  for (final session in program.sessions)
    for (final exercise in session.exercises)
      for (final set in exercise.sets)
        _path([planId, session.id, exercise.id, set.id]): set,
};
