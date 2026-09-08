import '../domain/recent_lift_record.dart';
import '../domain/training_program.dart';

/// Raw operator input. Validation happens only when a preview is generated.
/// Exercises identify the movement; each set independently identifies its load
/// baseline. Those two lifts are deliberately not inferred from each other.
final class DetailedSetDraft {
  String id, repetitions, repetitionsMax, rir, loadValue, restSeconds, tempo;
  ProgramSetKind kind;
  LoadKind loadKind;
  MainLift? loadLift;
  bool isRequired, isAmrap;

  DetailedSetDraft({
    this.id = '',
    this.repetitions = '',
    this.repetitionsMax = '',
    this.kind = ProgramSetKind.work,
    this.rir = '',
    this.loadValue = '',
    this.loadKind = LoadKind.manual,
    this.loadLift,
    this.isRequired = true,
    this.restSeconds = '',
    this.tempo = '',
    this.isAmrap = false,
  });

  factory DetailedSetDraft.fromProgram(ProgramSet set) => DetailedSetDraft(
    id: set.id,
    repetitions: set.repetitions.toString(),
    repetitionsMax: set.repetitionsMax?.toString() ?? '',
    kind: set.kind,
    rir: set.rir?.toString() ?? '',
    loadValue: set.load.value?.toString() ?? '',
    loadKind: set.load.kind,
    loadLift: set.load.lift,
    isRequired: set.isRequired,
    restSeconds: set.restSeconds?.toString() ?? '',
    tempo: set.tempo ?? '',
    isAmrap: set.isAmrap,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'repetitions': repetitions,
    if (repetitionsMax.isNotEmpty) 'repetitionsMax': repetitionsMax,
    if (kind != ProgramSetKind.work) 'setKind': kind.name,
    'rir': rir,
    'loadValue': loadValue,
    'loadKind': loadKind.name,
    'loadLift': loadLift?.key,
    'isRequired': isRequired,
    if (restSeconds.isNotEmpty) 'restSeconds': restSeconds,
    if (tempo.isNotEmpty) 'tempo': tempo,
    if (isAmrap) 'isAmrap': isAmrap,
  };

  factory DetailedSetDraft.fromJson(Map<String, dynamic> json) {
    _keys(
      json,
      {
        'id',
        'repetitions',
        'rir',
        'loadValue',
        'loadKind',
        'loadLift',
        'isRequired',
      },
      '세트 초안',
      optional: {
        'restSeconds',
        'tempo',
        'isAmrap',
        'repetitionsMax',
        'setKind',
      },
    );
    final required = json['isRequired'];
    if (required is! bool) {
      throw const FormatException('세트 초안: 필수 여부가 올바르지 않아요.');
    }
    final amrap = json.containsKey('isAmrap') ? json['isAmrap'] : false;
    if (amrap is! bool) {
      throw const FormatException('세트 초안: AMRAP 여부가 올바르지 않아요.');
    }
    return DetailedSetDraft(
      id: _text(json, 'id'),
      repetitions: _text(json, 'repetitions'),
      repetitionsMax: json.containsKey('repetitionsMax')
          ? _text(json, 'repetitionsMax')
          : '',
      kind: json.containsKey('setKind')
          ? ProgramSetKind.values.byName(json['setKind'] as String)
          : ProgramSetKind.work,
      rir: _text(json, 'rir'),
      loadValue: _text(json, 'loadValue'),
      loadKind: _loadKind(json['loadKind']),
      loadLift: _lift(json['loadLift']),
      isRequired: required,
      restSeconds: json.containsKey('restSeconds')
          ? _text(json, 'restSeconds')
          : '',
      tempo: json.containsKey('tempo') ? _text(json, 'tempo') : '',
      isAmrap: amrap,
    );
  }

  DetailedSetDraft copy() => DetailedSetDraft.fromJson(toJson());
}

final class DetailedExerciseDraft {
  String id, name, supersetGroup;
  MainLift? mainLift;
  final List<DetailedSetDraft> sets;

  DetailedExerciseDraft({
    this.id = '',
    this.name = '',
    this.mainLift,
    this.supersetGroup = '',
    List<DetailedSetDraft>? sets,
  }) : sets = sets ?? [DetailedSetDraft()];

  factory DetailedExerciseDraft.fromProgram(ProgramExercise exercise) =>
      DetailedExerciseDraft(
        id: exercise.id,
        name: exercise.name,
        mainLift: exercise.mainLift,
        supersetGroup: exercise.supersetGroup ?? '',
        sets: exercise.sets.map(DetailedSetDraft.fromProgram).toList(),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'mainLift': mainLift?.key,
    if (supersetGroup.isNotEmpty) 'supersetGroup': supersetGroup,
    'sets': sets.map((set) => set.toJson()).toList(),
  };

  factory DetailedExerciseDraft.fromJson(Map<String, dynamic> json) {
    _keys(
      json,
      {'id', 'name', 'mainLift', 'sets'},
      '운동 초안',
      optional: {'supersetGroup'},
    );
    return DetailedExerciseDraft(
      id: _text(json, 'id'),
      name: _text(json, 'name'),
      mainLift: _lift(json['mainLift']),
      supersetGroup: json.containsKey('supersetGroup')
          ? _text(json, 'supersetGroup')
          : '',
      sets: _children(json, 'sets').map(DetailedSetDraft.fromJson).toList(),
    );
  }

  DetailedExerciseDraft copy() => DetailedExerciseDraft.fromJson(toJson());
}

final class DetailedSessionDraft {
  String id, title;
  final List<DetailedExerciseDraft> exercises;

  DetailedSessionDraft({
    this.id = '',
    this.title = '',
    List<DetailedExerciseDraft>? exercises,
  }) : exercises = exercises ?? [DetailedExerciseDraft()];

  factory DetailedSessionDraft.fromProgram(ProgramSession session) =>
      DetailedSessionDraft(
        id: session.id,
        title: session.title,
        exercises: session.exercises
            .map(DetailedExerciseDraft.fromProgram)
            .toList(),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };

  factory DetailedSessionDraft.fromJson(Map<String, dynamic> json) {
    _keys(json, {'id', 'title', 'exercises'}, '세션 초안');
    return DetailedSessionDraft(
      id: _text(json, 'id'),
      title: _text(json, 'title'),
      exercises: _children(
        json,
        'exercises',
      ).map(DetailedExerciseDraft.fromJson).toList(),
    );
  }

  DetailedSessionDraft copy() => DetailedSessionDraft.fromJson(toJson());
}

final class DetailedWeekDraft {
  final List<DetailedSessionDraft> sessions;

  DetailedWeekDraft({List<DetailedSessionDraft>? sessions})
    : sessions = sessions ?? [DetailedSessionDraft()];

  Map<String, Object?> toJson() => {
    'sessions': sessions.map((session) => session.toJson()).toList(),
  };

  factory DetailedWeekDraft.fromJson(Map<String, dynamic> json) {
    _keys(json, {'sessions'}, '주차 초안');
    return DetailedWeekDraft(
      sessions: _children(
        json,
        'sessions',
      ).map(DetailedSessionDraft.fromJson).toList(),
    );
  }

  DetailedWeekDraft copy() => DetailedWeekDraft.fromJson(toJson());
}

final class DetailedRoutineDraft {
  String id, title, description, version, trainerName;
  final List<DetailedWeekDraft> weeks;

  /// Imported JSON may list sessions out of order. Keep its serialization order
  /// without changing the explicit week/day ordering used by the consumer.
  final List<String>? sourceSessionOrder;

  DetailedRoutineDraft({
    this.id = '',
    this.title = '',
    this.description = '',
    this.version = '1',
    this.trainerName = 'Strength',
    List<DetailedWeekDraft>? weeks,
    List<String>? sourceSessionOrder,
  }) : weeks = weeks ?? [DetailedWeekDraft()],
       sourceSessionOrder = sourceSessionOrder == null
           ? null
           : List.of(sourceSessionOrder);

  factory DetailedRoutineDraft.fromProgram(TrainingProgram program) =>
      DetailedRoutineDraft(
        id: program.id,
        title: program.title,
        description: program.description,
        version: program.version,
        trainerName: program.trainerName,
        weeks: [
          for (var week = 1; week <= program.weeks; week++)
            DetailedWeekDraft(
              sessions: program.orderedSessions
                  .where((session) => session.week == week)
                  .map(DetailedSessionDraft.fromProgram)
                  .toList(),
            ),
        ],
        sourceSessionOrder: program.sessions
            .map((session) => session.id)
            .toList(),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'version': version,
    'trainerName': trainerName,
    'weeks': weeks.map((week) => week.toJson()).toList(),
    if (sourceSessionOrder != null)
      'sourceSessionOrder': List.of(sourceSessionOrder!),
  };

  factory DetailedRoutineDraft.fromJson(Map<String, dynamic> json) {
    _keys(
      json,
      {'id', 'title', 'description', 'version', 'trainerName', 'weeks'},
      '상세 루틴 초안',
      optional: {'sourceSessionOrder'},
    );
    List<String>? order;
    if (json.containsKey('sourceSessionOrder')) {
      final value = json['sourceSessionOrder'];
      if (value is! List || value.any((id) => id is! String)) {
        throw const FormatException('상세 루틴 초안: 원본 세션 순서가 올바르지 않아요.');
      }
      order = value.cast<String>();
      if (order.toSet().length != order.length) {
        throw const FormatException('상세 루틴 초안: 원본 세션 ID가 중복돼요.');
      }
    }
    return DetailedRoutineDraft(
      id: _text(json, 'id'),
      title: _text(json, 'title'),
      description: _text(json, 'description'),
      version: _text(json, 'version'),
      trainerName: _text(json, 'trainerName'),
      weeks: _children(json, 'weeks').map(DetailedWeekDraft.fromJson).toList(),
      sourceSessionOrder: order,
    );
  }

  bool get hasExtendedPrescriptions => weeks.any(
    (week) => week.sessions.any(
      (session) => session.exercises.any(
        (exercise) => exercise.sets.any(
          (set) =>
              set.repetitionsMax.isNotEmpty || set.kind != ProgramSetKind.work,
        ),
      ),
    ),
  );

  bool get hasAdvancedPrescriptions => weeks.any(
    (week) => week.sessions.any(
      (session) => session.exercises.any(
        (exercise) =>
            exercise.supersetGroup.isNotEmpty ||
            exercise.sets.any(
              (set) =>
                  set.restSeconds.isNotEmpty ||
                  set.tempo.isNotEmpty ||
                  set.isAmrap,
            ),
      ),
    ),
  );

  DetailedRoutineDraft copy() => DetailedRoutineDraft.fromJson(toJson());

  String nextSessionId({String prefix = 'session'}) => _nextId(
    weeks.expand((week) => week.sessions).map((session) => session.id).toSet(),
    prefix,
  );

  /// Appends a deep copy. Exercise and set IDs stay local to their new session;
  /// every new session ID is unique across the whole program.
  int appendWeekCopy(int sourceWeekIndex) {
    RangeError.checkValidIndex(sourceWeekIndex, weeks, 'sourceWeekIndex');
    if (weeks.length >= 52) {
      throw const FormatException('기간은 최대 52주까지 추가할 수 있어요.');
    }
    final copy = weeks[sourceWeekIndex].copy();
    final used = weeks
        .expand((week) => week.sessions)
        .map((session) => session.id)
        .toSet();
    for (final session in copy.sessions) {
      session.id = _nextId(used, 'session');
      used.add(session.id);
    }
    weeks.add(copy);
    return weeks.length - 1;
  }

  /// Explicitly replaces one week's composition. Matching target ordinals keep
  /// their session IDs; extra source sessions receive fresh IDs. Other weeks,
  /// including the source, are untouched.
  void copyWeekOnto(int sourceWeekIndex, int targetWeekIndex) {
    RangeError.checkValidIndex(sourceWeekIndex, weeks, 'sourceWeekIndex');
    RangeError.checkValidIndex(targetWeekIndex, weeks, 'targetWeekIndex');
    if (sourceWeekIndex == targetWeekIndex) return;
    final copy = weeks[sourceWeekIndex].copy();
    final target = weeks[targetWeekIndex];
    final used = weeks
        .expand((week) => week.sessions)
        .map((session) => session.id)
        .toSet();
    for (var index = 0; index < copy.sessions.length; index++) {
      copy.sessions[index].id = index < target.sessions.length
          ? target.sessions[index].id
          : _nextId(used, 'session');
      used.add(copy.sessions[index].id);
    }
    weeks[targetWeekIndex] = copy;
  }
}

/// [to] is the final index, including when moving an item toward the end.
/// Moving preserves the item itself and every nested ID/raw input value.
void moveDetailedItem<T>(List<T> items, int from, int to) {
  RangeError.checkValidIndex(from, items, 'from');
  RangeError.checkValidIndex(to, items, 'to');
  if (from == to) return;
  items.insert(to, items.removeAt(from));
}

/// Generates one immutable consumer snapshot. No edits or inferred prescriptions
/// are written back into the raw draft, including after a failed validation.
TrainingProgram generateDetailedRoutine(DetailedRoutineDraft draft) {
  final id = _required(draft.id, '프로그램 ID');
  final title = _required(draft.title, '프로그램 이름');
  final version = _required(draft.version, '버전', max: 30);
  final trainer = _required(draft.trainerName, '작성자');
  final description = _required(draft.description, '프로그램 설명', max: 2000);
  if (draft.weeks.isEmpty || draft.weeks.length > 52) {
    throw const FormatException('기간: 1~52주로 구성해 주세요.');
  }
  final weeklyCount = draft.weeks.first.sessions.length;
  if (weeklyCount < 1 || weeklyCount > 7) {
    throw const FormatException('1주차: 세션은 1~7개로 구성해 주세요.');
  }
  final sessionIds = <String>{};
  final identities = <String, (String, MainLift?)>{};
  final sessions = <ProgramSession>[];
  for (var wi = 0; wi < draft.weeks.length; wi++) {
    final week = draft.weeks[wi];
    if (week.sessions.length != weeklyCount) {
      throw FormatException('${wi + 1}주차: 모든 주의 세션 수를 $weeklyCount개로 맞춰 주세요.');
    }
    for (var si = 0; si < week.sessions.length; si++) {
      final session = week.sessions[si];
      final context = '${wi + 1}주차 · ${si + 1}번 세션';
      final sid = _required(session.id, '$context ID');
      if (!sessionIds.add(sid)) {
        throw FormatException('$context: 프로그램 전체에서 세션 ID "$sid"가 중복돼요.');
      }
      final sessionTitle = _required(session.title, '$context 이름');
      if (session.exercises.isEmpty || session.exercises.length > 20) {
        throw FormatException('$context: 운동 1~20개가 필요해요.');
      }
      final exerciseIds = <String>{};
      final exercises = <ProgramExercise>[];
      for (var ei = 0; ei < session.exercises.length; ei++) {
        final exercise = session.exercises[ei];
        final exerciseContext = '$context · ${ei + 1}번 운동';
        final eid = _required(exercise.id, '$exerciseContext ID');
        final name = _required(exercise.name, '$exerciseContext 이름');
        if (!exerciseIds.add(eid)) {
          throw FormatException('$exerciseContext: 한 세션에서 운동 ID "$eid"가 중복돼요.');
        }
        final group = exercise.supersetGroup.isEmpty
            ? null
            : exercise.supersetGroup;
        if (group != null && (group.trim() != group || group.length > 40)) {
          throw FormatException(
            '$exerciseContext 슈퍼세트 그룹: 앞뒤 공백 없이 1~40자로 입력해 주세요.',
          );
        }
        final identity = (name, exercise.mainLift);
        if (identities.containsKey(eid) && identities[eid] != identity) {
          throw FormatException(
            '$exerciseContext: 같은 운동 ID "$eid"의 이름과 메인 리프트를 일치시켜 주세요.',
          );
        }
        identities[eid] = identity;
        if (exercise.sets.isEmpty || exercise.sets.length > 10) {
          throw FormatException('$exerciseContext: 세트 1~10개가 필요해요.');
        }
        final setIds = <String>{};
        final sets = <ProgramSet>[];
        for (var ti = 0; ti < exercise.sets.length; ti++) {
          final set = exercise.sets[ti];
          final setContext = '$exerciseContext · ${ti + 1}번 세트';
          final setId = _required(set.id, '$setContext ID');
          if (!setIds.add(setId)) {
            throw FormatException('$setContext: 한 운동에서 세트 ID "$setId"가 중복돼요.');
          }
          final repetitions = int.tryParse(set.repetitions.trim());
          if (repetitions == null || repetitions < 1 || repetitions > 100) {
            throw FormatException('$setContext 반복 수: 1~100 사이의 정수를 입력해 주세요.');
          }
          final upperText = set.repetitionsMax.trim();
          final upper = upperText.isEmpty ? null : int.tryParse(upperText);
          if (upperText.isNotEmpty &&
              (upper == null || upper < repetitions || upper > 100)) {
            throw FormatException(
              '$setContext 반복 상한: 하한 이상 100 이하의 정수 또는 빈 값으로 입력해 주세요.',
            );
          }
          if (set.isAmrap && upper != null) {
            throw FormatException('$setContext: AMRAP과 반복 범위는 함께 지정할 수 없어요.');
          }
          final rirText = set.rir.trim();
          final rir = rirText.isEmpty ? null : double.tryParse(rirText);
          if (rirText.isNotEmpty &&
              (rir == null || !rir.isFinite || rir < 0 || rir > 10)) {
            throw FormatException('$setContext RIR: 0~10 또는 빈 값으로 입력해 주세요.');
          }
          final restText = set.restSeconds.trim();
          final restSeconds = restText.isEmpty ? null : int.tryParse(restText);
          if (restText.isNotEmpty &&
              (restSeconds == null || restSeconds < 0 || restSeconds > 3600)) {
            throw FormatException(
              '$setContext 휴식: 0~3600초 정수 또는 빈 값으로 입력해 주세요.',
            );
          }
          final tempoText = set.tempo.trim();
          final tempo = tempoText.isEmpty ? null : tempoText;
          if (tempo != null &&
              !RegExp(r'^[0-9]-[0-9]-[0-9X]-[0-9]$').hasMatch(tempo)) {
            throw FormatException(
              '$setContext 템포: 3-1-X-0처럼 네 구간을 입력해 주세요. X는 세 번째 구간만 가능해요.',
            );
          }
          LoadPrescription load;
          if (set.loadKind == LoadKind.manual) {
            load = const LoadPrescription.manual();
          } else {
            final value = double.tryParse(set.loadValue.trim());
            if (value == null || !value.isFinite || value <= 0) {
              throw FormatException('$setContext 중량: 0보다 큰 유한한 수를 입력해 주세요.');
            }
            if (set.loadKind == LoadKind.percentOfBaseline) {
              if (set.loadLift == null) {
                throw FormatException('$setContext: 기준 중량을 가져올 리프트를 선택해 주세요.');
              }
              load = LoadPrescription.percentOfBaseline(set.loadLift!, value);
            } else {
              load = LoadPrescription.fixedKg(value);
            }
          }
          sets.add(
            ProgramSet(
              id: setId,
              repetitions: repetitions,
              repetitionsMax: upper,
              kind: set.kind,
              rir: rir,
              load: load,
              isRequired: set.isRequired,
              restSeconds: restSeconds,
              tempo: tempo,
              isAmrap: set.isAmrap,
            ),
          );
        }
        exercises.add(
          ProgramExercise(
            id: eid,
            name: name,
            mainLift: exercise.mainLift,
            supersetGroup: group,
            sets: sets,
          ),
        );
      }
      final groups = <String, List<int>>{};
      for (var ei = 0; ei < exercises.length; ei++) {
        final group = exercises[ei].supersetGroup;
        if (group != null) groups.putIfAbsent(group, () => []).add(ei);
      }
      for (final entry in groups.entries) {
        final positions = entry.value;
        if (positions.length < 2 ||
            positions.last - positions.first + 1 != positions.length) {
          throw FormatException(
            '$context 슈퍼세트 ${entry.key}: 같은 그룹 운동을 연속해서 2개 이상 배치해 주세요.',
          );
        }
      }
      sessions.add(
        ProgramSession(
          id: sid,
          week: wi + 1,
          dayOrder: si + 1,
          title: sessionTitle,
          exercises: exercises,
        ),
      );
    }
  }
  final originalOrder = draft.sourceSessionOrder;
  if (originalOrder != null) {
    final ranks = {
      for (var i = 0; i < originalOrder.length; i++) originalOrder[i]: i,
    };
    final fallback = {
      for (var i = 0; i < sessions.length; i++) sessions[i].id: i,
    };
    sessions.sort((a, b) {
      final left = ranks[a.id] ?? originalOrder.length + fallback[a.id]!;
      final right = ranks[b.id] ?? originalOrder.length + fallback[b.id]!;
      return left.compareTo(right);
    });
  }
  return TrainingProgram(
    id: id,
    version: version,
    title: title,
    trainerName: trainer,
    description: description,
    weeks: draft.weeks.length,
    sessions: sessions,
  );
}

String _nextId(Set<String> used, String prefix) {
  var suffix = 1;
  while (used.contains('$prefix-$suffix')) {
    suffix++;
  }
  return '$prefix-$suffix';
}

String _required(String value, String label, {int max = 80}) {
  if (value.trim().isEmpty || value.length > max) {
    throw FormatException('$label: 1~$max자로 입력해 주세요.');
  }
  return value;
}

void _keys(
  Map<String, dynamic> json,
  Set<String> required,
  String context, {
  Set<String> optional = const {},
}) {
  if (!required.every(json.containsKey) ||
      json.keys.any(
        (key) => !required.contains(key) && !optional.contains(key),
      )) {
    throw FormatException('$context: 누락되었거나 지원하지 않는 필드가 있어요.');
  }
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('초안의 $key 값은 문자열이어야 해요.');
  return value;
}

Iterable<Map<String, dynamic>> _children(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) throw FormatException('초안의 $key 값은 목록이어야 해요.');
  return value.map((child) {
    if (child is! Map || child.keys.any((key) => key is! String)) {
      throw FormatException('초안의 $key 항목이 올바르지 않아요.');
    }
    return Map<String, dynamic>.from(child);
  });
}

MainLift? _lift(Object? value) {
  if (value == null) return null;
  for (final lift in MainLift.values) {
    if (value == lift.key) return lift;
  }
  throw const FormatException('초안의 리프트 값이 올바르지 않아요.');
}

LoadKind _loadKind(Object? value) {
  for (final kind in LoadKind.values) {
    if (value == kind.name) return kind;
  }
  throw const FormatException('초안의 중량 방식이 올바르지 않아요.');
}
