import 'dart:convert';

import 'recent_lift_record.dart';

enum ProgramSetKind { work, warmup, drop }

enum LoadKind { manual, fixedKg, percentOfBaseline }

enum BaselineSource { userEntered, recordedWeight, workingMax }

enum SetActualStatus { completed, skipped }

enum SessionLifecycleKind { closed, reopened }

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
  final int? repetitionsMax;
  final ProgramSetKind kind;
  final double? rir;
  final LoadPrescription load;
  final bool isRequired;
  final int? restSeconds;
  final String? tempo;
  final bool isAmrap;
  ProgramSet({
    required this.id,
    required this.repetitions,
    this.repetitionsMax,
    this.kind = ProgramSetKind.work,
    this.rir,
    required this.load,
    this.isRequired = true,
    this.restSeconds,
    this.tempo,
    this.isAmrap = false,
  }) {
    _id(id);
    _check(repetitions > 0, 'Repetitions must be positive');
    _check(
      repetitionsMax == null ||
          repetitionsMax! >= repetitions && repetitionsMax! <= 100,
      'Invalid repetition range',
    );
    _check(
      !isAmrap || repetitionsMax == null,
      'AMRAP cannot have a repetition range',
    );
    _rir(rir);
    _check(
      restSeconds == null || restSeconds! >= 0 && restSeconds! <= 3600,
      'Rest must be 0 to 3600 seconds',
    );
    _check(
      tempo == null || RegExp(r'^[0-9]-[0-9]-[0-9X]-[0-9]$').hasMatch(tempo!),
      'Tempo must contain four phases, for example 3-1-X-0',
    );
  }
  bool get hasExtendedPrescriptions =>
      repetitionsMax != null || kind != ProgramSetKind.work;
  bool get hasAdvancedPrescriptions =>
      restSeconds != null || tempo != null || isAmrap;
  Map<String, Object?> toJson() => {
    'id': id,
    'repetitions': repetitions,
    if (repetitionsMax != null) 'repetitionsMax': repetitionsMax,
    if (kind != ProgramSetKind.work) 'setKind': kind.name,
    'rir': rir,
    'load': load.toJson(),
    'isRequired': isRequired,
    if (restSeconds != null) 'restSeconds': restSeconds,
    if (tempo != null) 'tempo': tempo,
    if (isAmrap) 'isAmrap': isAmrap,
  };
  factory ProgramSet.fromJson(Map<String, dynamic> j) => ProgramSet(
    id: j['id'] as String,
    repetitions: j['repetitions'] as int,
    repetitionsMax: j['repetitionsMax'] as int?,
    kind: j.containsKey('setKind')
        ? ProgramSetKind.values.byName(j['setKind'] as String)
        : ProgramSetKind.work,
    rir: (j['rir'] as num?)?.toDouble(),
    load: LoadPrescription.fromJson(_map(j['load'])),
    isRequired: j['isRequired'] as bool,
    restSeconds: j['restSeconds'] as int?,
    tempo: j['tempo'] as String?,
    isAmrap: j.containsKey('isAmrap') ? j['isAmrap'] as bool : false,
  );
}

final class ProgramExercise {
  final String id, name;
  final MainLift? mainLift;
  final String? supersetGroup;
  final List<ProgramSet> sets;
  ProgramExercise({
    required this.id,
    required this.name,
    this.mainLift,
    this.supersetGroup,
    required List<ProgramSet> sets,
  }) : sets = List.unmodifiable(sets) {
    _id(id);
    _id(name);
    _check(
      supersetGroup == null ||
          supersetGroup!.isNotEmpty &&
              supersetGroup!.trim() == supersetGroup &&
              supersetGroup!.length <= 40,
      'Invalid superset group ID',
    );
    _unique(sets.map((set) => set.id));
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'mainLift': mainLift?.key,
    if (supersetGroup != null) 'supersetGroup': supersetGroup,
    'sets': sets.map((set) => set.toJson()).toList(),
  };
  factory ProgramExercise.fromJson(Map<String, dynamic> j) => ProgramExercise(
    id: j['id'] as String,
    name: j['name'] as String,
    mainLift: j['mainLift'] == null ? null : _lift(j['mainLift']),
    supersetGroup: j['supersetGroup'] as String?,
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
    final groups = <String, List<int>>{};
    for (var i = 0; i < exercises.length; i++) {
      final group = exercises[i].supersetGroup;
      if (group != null) groups.putIfAbsent(group, () => []).add(i);
    }
    for (final entry in groups.entries) {
      final positions = entry.value;
      _check(
        positions.length >= 2 &&
            positions.last - positions.first + 1 == positions.length,
        'Superset ${entry.key} needs at least two consecutive exercises',
      );
    }
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
  bool get hasExtendedPrescriptions => sessions.any(
    (session) => session.exercises.any(
      (exercise) => exercise.sets.any((set) => set.hasExtendedPrescriptions),
    ),
  );
  bool get hasAdvancedPrescriptions => sessions.any(
    (session) => session.exercises.any(
      (exercise) =>
          exercise.supersetGroup != null ||
          exercise.sets.any((set) => set.hasAdvancedPrescriptions),
    ),
  );
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
  int? get repetitionsMax => template.repetitionsMax;
  ProgramSetKind get kind => template.kind;
  double? get rir => template.rir;
  bool get isRequired => template.isRequired;
  int? get restSeconds => template.restSeconds;
  String? get tempo => template.tempo;
  bool get isAmrap => template.isAmrap;
}

final class PlannedExercise {
  final String id, name;
  final List<PlannedSet> sets;
  final String? supersetGroup;
  PlannedExercise._(
    this.id,
    this.name,
    List<PlannedSet> sets,
    this.supersetGroup,
  ) : sets = List.unmodifiable(sets);
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

  /// Exercise order is stable; consecutive superset members alternate by round.
  /// [number] is the one-based set number within its own exercise.
  List<({PlannedExercise exercise, PlannedSet set, int number})>
  get executionSets {
    final result = <({PlannedExercise exercise, PlannedSet set, int number})>[];
    var index = 0;
    while (index < exercises.length) {
      final first = exercises[index];
      final group = first.supersetGroup;
      var end = index + 1;
      if (group != null) {
        while (end < exercises.length &&
            exercises[end].supersetGroup == group) {
          end++;
        }
      }
      final members = exercises.sublist(index, end);
      final rounds = members.fold<int>(
        0,
        (max, e) => e.sets.length > max ? e.sets.length : max,
      );
      for (var round = 0; round < rounds; round++) {
        for (final exercise in members) {
          if (round < exercise.sets.length) {
            result.add((
              exercise: exercise,
              set: exercise.sets[round],
              number: round + 1,
            ));
          }
        }
      }
      index = end;
    }
    return List.unmodifiable(result);
  }
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
                e.supersetGroup,
              ),
            )
            .toList(),
      ),
    ),
  );

  /// 기준 중량만 바꾼다. 이미 박제한 목표 kg(sessionDates/targets)는 그대로다.
  ActiveTrainingPlan withBaseline(LiftBaseline baseline) {
    final next = Map<MainLift, LiftBaseline>.of(baselines);
    next[baseline.lift] = baseline;
    return ActiveTrainingPlan._(
      id: id,
      program: program,
      startDate: startDate,
      weekdays: weekdays,
      incrementKg: incrementKg,
      baselines: next,
      sessionDates: sessionDates,
      targetKgBySetId: targetKgBySetId,
    );
  }

  /// Phase 3: baseline을 갱신하고 **미래·미기록** `%` 목표만 다시 채운다.
  /// 오늘·과거 세션과 [blockedSetIds](기록·초안)는 건드리지 않는다.
  ActiveTrainingPlan refillFuturePercentTargets({
    required MainLift lift,
    required double baselineKg,
    required DateTime asOf,
    required Set<String> blockedSetIds,
    BaselineSource source = BaselineSource.workingMax,
  }) {
    _positive(baselineKg);
    final nextTargets = Map<String, double?>.of(targetKgBySetId);
    final nextBaselines = Map<MainLift, LiftBaseline>.of(baselines);
    nextBaselines[lift] = LiftBaseline(
      lift: lift,
      kilograms: baselineKg,
      source: source,
    );
    final today = calendarDate(asOf);
    for (final session in program.orderedSessions) {
      final sessionKey = _path([id, session.id]);
      final date = sessionDates[sessionKey]!;
      if (!date.isAfter(today)) continue;
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          final setKey = _path([id, session.id, exercise.id, set.id]);
          if (blockedSetIds.contains(setKey)) continue;
          final load = set.load;
          if (load.kind != LoadKind.percentOfBaseline || load.lift != lift) {
            continue;
          }
          final weight = baselineKg * load.value! / 100;
          nextTargets[setKey] = (weight / incrementKg).round() * incrementKg;
        }
      }
    }
    return ActiveTrainingPlan._(
      id: id,
      program: program,
      startDate: startDate,
      weekdays: weekdays,
      incrementKg: incrementKg,
      baselines: nextBaselines,
      sessionDates: sessionDates,
      targetKgBySetId: nextTargets,
    );
  }

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
    return replaceSessionDates(dates);
  }

  /// 세션 날짜 맵을 통째로 교체한다. 순서·요일·시작일 불변식은 생성자가 검증한다.
  ActiveTrainingPlan replaceSessionDates(Map<String, DateTime> dates) {
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
  final DateTime? performedDate, recordedAt, updatedAt;
  SetActual.completed({
    required double this.weight,
    required WeightUnit this.unit,
    required int this.repetitions,
    this.rir,
    this.note = '',
    DateTime? performedDate,
    DateTime? recordedAt,
    DateTime? updatedAt,
  }) : status = SetActualStatus.completed,
       performedDate = performedDate == null
           ? null
           : calendarDate(performedDate),
       recordedAt = recordedAt?.toUtc(),
       updatedAt = updatedAt?.toUtc() {
    _check(
      weight!.isFinite && weight! >= 0,
      'Actual weight must be finite and nonnegative',
    );
    _check(repetitions! > 0, 'Actual repetitions must be positive');
    _rir(rir);
    _check(
      this.recordedAt == null ||
          this.updatedAt == null ||
          !this.updatedAt!.isBefore(this.recordedAt!),
      'Update precedes recording',
    );
  }
  const SetActual.skipped({this.note = ''})
    : status = SetActualStatus.skipped,
      weight = null,
      unit = null,
      repetitions = null,
      rir = null,
      performedDate = null,
      recordedAt = null,
      updatedAt = null;
  Map<String, Object?> toJson() => {
    'status': status.name,
    'weight': weight,
    'unit': unit?.key,
    'repetitions': repetitions,
    'rir': rir,
    'note': note,
    if (performedDate != null) 'performedDate': isoDate(performedDate!),
    if (recordedAt != null) 'recordedAt': recordedAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
  factory SetActual.fromJson(Map<String, dynamic> j) {
    if (j['status'] == 'skipped') {
      _check(
        !['performedDate', 'recordedAt', 'updatedAt'].any(j.containsKey),
        'Skipped set cannot have performance dates',
      );
    }
    return switch (j['status']) {
      'completed' => SetActual.completed(
        weight: _number(j['weight']),
        unit: WeightUnit.values.byName(j['unit'] as String),
        repetitions: j['repetitions'] as int,
        rir: (j['rir'] as num?)?.toDouble(),
        note: j['note'] as String,
        performedDate: j['performedDate'] == null
            ? null
            : parseCalendarDate(j['performedDate'] as String),
        recordedAt: j['recordedAt'] == null
            ? null
            : _parseUtcInstant(j['recordedAt'] as String),
        updatedAt: j['updatedAt'] == null
            ? null
            : _parseUtcInstant(j['updatedAt'] as String),
      ),
      'skipped' => SetActual.skipped(note: j['note'] as String),
      _ => throw const FormatException('Unknown set status'),
    };
  }
}

/// Committed actuals and drafts are counted independently; dates are never inferred.
final class SessionSummary {
  final int totalSets, requiredSets, performedSets, skippedSets;
  final int unrecordedSets, draftSets, unknownDateSets, requiredUnrecordedSets;
  final List<DateTime> performedDates;
  SessionSummary({
    required this.totalSets,
    required this.requiredSets,
    required this.performedSets,
    required this.skippedSets,
    required this.unrecordedSets,
    required this.draftSets,
    required this.unknownDateSets,
    required this.requiredUnrecordedSets,
    required List<DateTime> performedDates,
  }) : performedDates = List.unmodifiable(performedDates) {
    _check(
      [
        totalSets,
        requiredSets,
        performedSets,
        skippedSets,
        unrecordedSets,
        draftSets,
        unknownDateSets,
        requiredUnrecordedSets,
      ].every((n) => n >= 0),
      'Negative session summary count',
    );
    _check(
      totalSets > 0 &&
          performedSets + skippedSets + unrecordedSets == totalSets &&
          requiredSets <= totalSets &&
          draftSets <= totalSets &&
          unknownDateSets <= performedSets &&
          requiredUnrecordedSets <= requiredSets &&
          requiredUnrecordedSets <= unrecordedSets &&
          unrecordedSets - requiredUnrecordedSets <= totalSets - requiredSets,
      'Invalid session summary counts',
    );
    DateTime? previous;
    for (final date in this.performedDates) {
      _check(
        date == calendarDate(date) &&
            (previous == null || date.isAfter(previous)),
        'Performance dates must be sorted unique calendar dates',
      );
      previous = date;
    }
    final datedCount = performedSets - unknownDateSets;
    _check(
      this.performedDates.length <= datedCount &&
          (datedCount == 0) == this.performedDates.isEmpty,
      'Invalid performance date count',
    );
  }
  bool get canClose => requiredUnrecordedSets == 0 && draftSets == 0;
  Map<String, Object?> toJson() => {
    'totalSets': totalSets,
    'requiredSets': requiredSets,
    'performedSets': performedSets,
    'skippedSets': skippedSets,
    'unrecordedSets': unrecordedSets,
    'draftSets': draftSets,
    'unknownDateSets': unknownDateSets,
    'requiredUnrecordedSets': requiredUnrecordedSets,
    'performedDates': performedDates.map(isoDate).toList(),
  };
  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
    totalSets: j['totalSets'] as int,
    requiredSets: j['requiredSets'] as int,
    performedSets: j['performedSets'] as int,
    skippedSets: j['skippedSets'] as int,
    unrecordedSets: j['unrecordedSets'] as int,
    draftSets: j['draftSets'] as int,
    unknownDateSets: j['unknownDateSets'] as int,
    requiredUnrecordedSets: j['requiredUnrecordedSets'] as int,
    performedDates: (j['performedDates'] as List)
        .map((v) => parseCalendarDate(v as String))
        .toList(),
  );
}

final class SessionLifecycleEvent {
  final String id, sessionId;
  final SessionLifecycleKind kind;
  final DateTime at;
  final SessionSummary summary;
  SessionLifecycleEvent({
    required this.id,
    required this.sessionId,
    required this.kind,
    required DateTime at,
    required this.summary,
  }) : at = at.toUtc() {
    _id(id);
    _id(sessionId);
    _check(summary.canClose, 'Lifecycle event requires a resolved session');
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'kind': kind.name,
    'at': at.toIso8601String(),
    'summary': summary.toJson(),
  };
  factory SessionLifecycleEvent.fromJson(Map<String, dynamic> j) =>
      SessionLifecycleEvent(
        id: j['id'] as String,
        sessionId: j['sessionId'] as String,
        kind: switch (j['kind']) {
          'closed' => SessionLifecycleKind.closed,
          'reopened' => SessionLifecycleKind.reopened,
          _ => throw const FormatException('Unknown session lifecycle event'),
        },
        at: _parseUtcInstant(j['at'] as String),
        summary: SessionSummary.fromJson(_map(j['summary'])),
      );
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
  final List<SessionLifecycleEvent> sessionEvents;
  final Set<String> legacySessionIds;
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
    List<SessionLifecycleEvent> sessionEvents = const [],
    Set<String> legacySessionIds = const {},
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
       loadAdjustments = List.unmodifiable(loadAdjustments),
       sessionEvents = List.unmodifiable(sessionEvents),
       legacySessionIds = Set.unmodifiable(legacySessionIds) {
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
          completionNotified.every(sessionIds.contains) &&
          legacySessionIds.every(sessionIds.contains),
      'Orphaned workout record',
    );
    _check(
      setDrafts.values.every(
        (draft) => draft.keys.every(
          const [
            'weight',
            'repetitions',
            'rir',
            'note',
            'unit',
            'performedDate',
          ].contains,
        ),
      ),
      'Unknown draft field',
    );
    _validateSessionEvents();
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
  bool get hasExtendedPrescriptions =>
      (activePlan?.program.hasExtendedPrescriptions ?? false) ||
      planHistory.any((plan) => plan.program.hasExtendedPrescriptions);
  bool get hasAdvancedPrescriptions =>
      (activePlan?.program.hasAdvancedPrescriptions ?? false) ||
      planHistory.any((plan) => plan.program.hasAdvancedPrescriptions);

  PlannedSession _session(String sessionId) {
    final matching = [
      ...planHistory,
      if (activePlan != null) activePlan!,
    ].expand((p) => p.sessions).where((s) => s.id == sessionId);
    _check(matching.length == 1, 'Unknown session');
    return matching.single;
  }

  SessionSummary sessionSummary(String sessionId) {
    final sets = _session(sessionId).exercises.expand((e) => e.sets).toList();
    final performed = sets
        .map((s) => setActuals[s.id])
        .whereType<SetActual>()
        .where((a) => a.status == SetActualStatus.completed)
        .toList();
    final dates =
        performed
            .map((a) => a.performedDate)
            .whereType<DateTime>()
            .toSet()
            .toList()
          ..sort();
    return SessionSummary(
      totalSets: sets.length,
      requiredSets: sets.where((s) => s.isRequired).length,
      performedSets: performed.length,
      skippedSets: sets
          .where((s) => setActuals[s.id]?.status == SetActualStatus.skipped)
          .length,
      unrecordedSets: sets.where((s) => !setActuals.containsKey(s.id)).length,
      draftSets: sets.where((s) => setDrafts.containsKey(s.id)).length,
      unknownDateSets: performed.where((a) => a.performedDate == null).length,
      requiredUnrecordedSets: sets
          .where((s) => s.isRequired && !setActuals.containsKey(s.id))
          .length,
      performedDates: dates,
    );
  }

  bool isSessionClosed(String sessionId) {
    for (final event in sessionEvents.reversed) {
      if (event.sessionId == sessionId) {
        return event.kind == SessionLifecycleKind.closed;
      }
    }
    return false;
  }

  void _validateSessionEvents() {
    _check(
      sessionEvents.map((e) => e.id).toSet().length == sessionEvents.length,
      'Duplicate session event id',
    );
    final latest = <String, SessionLifecycleEvent>{};
    DateTime? previousAt;
    for (final event in sessionEvents) {
      final current = sessionSummary(event.sessionId);
      _check(
        event.summary.totalSets == current.totalSets &&
            event.summary.requiredSets == current.requiredSets,
        'Session event composition mismatch',
      );
      _check(
        previousAt == null || !event.at.isBefore(previousAt),
        'Session event time precedes prior event',
      );
      previousAt = event.at;
      final previous = latest[event.sessionId];
      _check(
        previous == null
            ? event.kind == SessionLifecycleKind.closed
            : previous.kind != event.kind,
        'Invalid session lifecycle order',
      );
      if (event.kind == SessionLifecycleKind.reopened) {
        _check(
          jsonEncode(event.summary.toJson()) ==
              jsonEncode(previous!.summary.toJson()),
          'Reopening cannot alter the closing snapshot',
        );
      }
      latest[event.sessionId] = event;
    }
    for (final event in latest.values.where(
      (e) => e.kind == SessionLifecycleKind.closed,
    )) {
      _check(
        jsonEncode(event.summary.toJson()) ==
            jsonEncode(sessionSummary(event.sessionId).toJson()),
        'Closed session changed without reopening',
      );
    }
  }

  void _requireSessionEditable(String sessionId) {
    _session(sessionId);
    _check(!isSessionClosed(sessionId), '운동을 다시 열고 수정해 주세요.');
  }

  void _requireSetEditable(String setId) {
    final sessions = activePlan!.sessions.where(
      (s) => s.exercises.any((e) => e.sets.any((set) => set.id == setId)),
    );
    _requireSessionEditable(sessions.single.id);
  }

  TrainingAppState closeSession(
    String sessionId, {
    required String eventId,
    required DateTime at,
  }) => _sessionTransition(sessionId, eventId, at, SessionLifecycleKind.closed);

  TrainingAppState reopenSession(
    String sessionId, {
    required String eventId,
    required DateTime at,
  }) =>
      _sessionTransition(sessionId, eventId, at, SessionLifecycleKind.reopened);

  TrainingAppState _sessionTransition(
    String sessionId,
    String eventId,
    DateTime at,
    SessionLifecycleKind kind,
  ) {
    final existing = sessionEvents.where((e) => e.id == eventId);
    if (existing.isNotEmpty) {
      final event = existing.single;
      _check(
        event.sessionId == sessionId &&
            event.kind == kind &&
            event.at == at.toUtc(),
        'Session event id was used for another command',
      );
      return this;
    }
    _session(sessionId);
    _check(
      activePlan?.sessions.any((s) => s.id == sessionId) ?? false,
      'Session is not in the active plan',
    );
    _check(
      isSessionClosed(sessionId) == (kind == SessionLifecycleKind.reopened),
      'Invalid session lifecycle transition',
    );
    final summary = sessionSummary(sessionId);
    _check(summary.canClose, '필수 세트를 기록하고 작성 중인 초안을 정리해 주세요.');
    return TrainingAppState(
      onboarded: onboarded,
      recentRecords: recentRecords,
      activePlan: activePlan,
      planHistory: planHistory,
      setActuals: setActuals,
      setDrafts: setDrafts,
      sessionNotes: sessionNotes,
      completionNotified: completionNotified,
      loadAdjustments: loadAdjustments,
      legacySessionIds: legacySessionIds,
      sessionEvents: [
        ...sessionEvents,
        SessionLifecycleEvent(
          id: eventId,
          sessionId: sessionId,
          kind: kind,
          at: at,
          summary: summary,
        ),
      ],
    );
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
    sessionEvents: sessionEvents,
    legacySessionIds: legacySessionIds,
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
    sessionEvents: sessionEvents,
    legacySessionIds: legacySessionIds,
  );

  /// 활성 계획만 교체한다. 보관함으로 보내지 않는다(baseline 갱신 등).
  TrainingAppState replaceActivePlan(ActiveTrainingPlan plan) {
    _check(activePlan?.id == plan.id, 'Active plan id mismatch');
    return TrainingAppState(
      onboarded: onboarded,
      recentRecords: recentRecords,
      activePlan: plan,
      planHistory: planHistory,
      setActuals: setActuals,
      setDrafts: setDrafts,
      sessionNotes: sessionNotes,
      completionNotified: completionNotified,
      loadAdjustments: loadAdjustments,
      sessionEvents: sessionEvents,
      legacySessionIds: legacySessionIds,
    );
  }
  TrainingAppState withSetActual(String plannedSetId, SetActual? actual) {
    _check(
      activePlan?.targetKgBySetId.containsKey(plannedSetId) ?? false,
      'Set is not in the active plan',
    );
    _requireSetEditable(plannedSetId);
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
      sessionEvents: sessionEvents,
      legacySessionIds: legacySessionIds,
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
    _requireSetEditable(plannedSetId);
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
      sessionEvents: sessionEvents,
      legacySessionIds: legacySessionIds,
    );
  }

  TrainingAppState withSessionNote(String sessionId, String note) {
    _requireSessionEditable(sessionId);
    return TrainingAppState(
      onboarded: onboarded,
      recentRecords: recentRecords,
      activePlan: activePlan,
      planHistory: planHistory,
      setActuals: setActuals,
      setDrafts: setDrafts,
      sessionNotes: {...sessionNotes, sessionId: note},
      completionNotified: completionNotified,
      loadAdjustments: loadAdjustments,
      sessionEvents: sessionEvents,
      legacySessionIds: legacySessionIds,
    );
  }

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
      sessionEvents: sessionEvents,
      legacySessionIds: legacySessionIds,
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
        sessionEvents: sessionEvents,
        legacySessionIds: legacySessionIds,
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
    'sessionEvents': sessionEvents.map((e) => e.toJson()).toList(),
    'legacySessionIds': legacySessionIds.toList()..sort(),
  };
  factory TrainingAppState.fromJson(Map<String, dynamic> j) {
    final hasEvents = j.containsKey('sessionEvents');
    final hasLegacy = j.containsKey('legacySessionIds');
    _check(hasEvents == hasLegacy, 'Incomplete lifecycle state');
    if (!hasEvents) {
      final plans = [
        if (j['activePlan'] != null)
          ActiveTrainingPlan.fromJson(_map(j['activePlan'])),
        ...(j['planHistory'] as List).map(
          (v) => ActiveTrainingPlan.fromJson(_map(v)),
        ),
      ];
      final recordedSets = {
        ..._map(j['setActuals']).keys,
        ..._map(j['setDrafts']).keys,
      };
      final legacy = {
        ..._map(j['sessionNotes']).keys,
        ...(j['completionNotified'] as List).cast<String>(),
      };
      for (final session in plans.expand((p) => p.sessions)) {
        if (session.exercises
            .expand((e) => e.sets)
            .any((s) => recordedSets.contains(s.id))) {
          legacy.add(session.id);
        }
      }
      j = {
        ...j,
        'sessionEvents': <Object?>[],
        'legacySessionIds': legacy.toList(),
      };
    }
    final legacyIds = (j['legacySessionIds'] as List).cast<String>();
    _check(
      legacyIds.toSet().length == legacyIds.length,
      'Duplicate legacy session id',
    );
    return TrainingAppState(
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
      sessionEvents: (j['sessionEvents'] as List)
          .map((v) => SessionLifecycleEvent.fromJson(_map(v)))
          .toList(),
      legacySessionIds: legacyIds.toSet(),
      loadAdjustments: j.containsKey('loadAdjustments')
          ? (j['loadAdjustments'] as List)
                .map((v) => TargetLoadAdjustment.fromJson(_map(v)))
                .toList()
          : const [],
    );
  }
}

DateTime _parseUtcInstant(String value) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?Z$',
  ).firstMatch(value);
  _check(match != null, 'Expected UTC event timestamp');
  parseCalendarDate(match!.group(1)!);
  _check(
    int.parse(match.group(2)!) < 24 &&
        int.parse(match.group(3)!) < 60 &&
        int.parse(match.group(4)!) < 60,
    'Invalid UTC event timestamp',
  );
  return DateTime.parse(value);
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

/// Detects authored extension fields before decoding an older storage envelope.
/// Even an explicit default value requires a reader that understands the field.
bool containsAdvancedPrescriptionFields(Object? value) {
  if (value is Map) {
    return value.keys.any(
          const {'restSeconds', 'tempo', 'isAmrap', 'supersetGroup'}.contains,
        ) ||
        value.values.any(containsAdvancedPrescriptionFields);
  }
  return value is List && value.any(containsAdvancedPrescriptionFields);
}

bool containsExtendedPrescriptionFields(Object? value) {
  if (value is Map) {
    return value.keys.any(const {'repetitionsMax', 'setKind'}.contains) ||
        value.values.any(containsExtendedPrescriptionFields);
  }
  return value is List && value.any(containsExtendedPrescriptionFields);
}
