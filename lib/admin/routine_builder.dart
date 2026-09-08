import '../domain/recent_lift_record.dart';
import '../domain/training_program.dart';

/// Admin input is retained as text until the operator requests generation.
final class ExerciseBlueprint {
  String id, name, setCount, repetitions, rir, loadValue;
  MainLift? mainLift;
  LoadKind loadKind;
  ExerciseBlueprint({
    this.id = '',
    this.name = '',
    this.setCount = '',
    this.repetitions = '',
    this.rir = '',
    this.loadValue = '',
    this.mainLift,
    this.loadKind = LoadKind.manual,
  });
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'setCount': setCount,
    'repetitions': repetitions,
    'rir': rir,
    'loadValue': loadValue,
    'mainLift': mainLift?.key,
    'loadKind': loadKind.name,
  };
  factory ExerciseBlueprint.fromJson(Map<String, dynamic> j) =>
      ExerciseBlueprint(
        id: j['id'] as String,
        name: j['name'] as String,
        setCount: j['setCount'] as String,
        repetitions: j['repetitions'] as String,
        rir: j['rir'] as String,
        loadValue: j['loadValue'] as String,
        mainLift: j['mainLift'] == null
            ? null
            : MainLift.values.firstWhere((l) => l.key == j['mainLift']),
        loadKind: LoadKind.values.byName(j['loadKind'] as String),
      );
}

final class SessionBlueprint {
  String title;
  final List<ExerciseBlueprint> exercises;
  SessionBlueprint({this.title = '', List<ExerciseBlueprint>? exercises})
    : exercises = exercises ?? [ExerciseBlueprint()];
  Map<String, Object?> toJson() => {
    'title': title,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
  factory SessionBlueprint.fromJson(Map<String, dynamic> j) => SessionBlueprint(
    title: j['title'] as String,
    exercises: (j['exercises'] as List)
        .map(
          (e) =>
              ExerciseBlueprint.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}

final class RoutineBlueprint {
  String id, title, description, version, weeks;
  final List<SessionBlueprint> sessions;
  RoutineBlueprint({
    this.id = '',
    this.title = '',
    this.description = '',
    this.version = '1',
    this.weeks = '',
    List<SessionBlueprint>? sessions,
  }) : sessions = sessions ?? [SessionBlueprint()];
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'version': version,
    'weeks': weeks,
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };
  factory RoutineBlueprint.fromJson(Map<String, dynamic> j) {
    final draft = RoutineBlueprint(
      id: j['id'] as String,
      title: j['title'] as String,
      description: j['description'] as String,
      version: j['version'] as String,
      weeks: j['weeks'] as String,
      sessions: (j['sessions'] as List)
          .map(
            (s) =>
                SessionBlueprint.fromJson(Map<String, dynamic>.from(s as Map)),
          )
          .toList(),
    );
    if (draft.sessions.isEmpty ||
        draft.sessions.length > 7 ||
        draft.sessions.any(
          (s) => s.exercises.isEmpty || s.exercises.length > 20,
        )) {
      throw const FormatException('Invalid draft structure');
    }
    return draft;
  }
}

int _integer(String text, int min, int max, String label) {
  final value = int.tryParse(text.trim());
  if (value == null || value < min || value > max) {
    throw FormatException('$label: $min~$max 사이의 정수를 입력해 주세요.');
  }
  return value;
}

String _required(String text, String label, {int max = 80}) {
  if (text.trim().isEmpty || text.trim().length > max) {
    throw FormatException('$label: 1~$max자로 입력해 주세요.');
  }
  return text.trim();
}

String _slug(String text, String label) {
  final value = _required(text, label);
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(value)) {
    throw FormatException('$label: 영문 소문자·숫자·밑줄·하이픈을 사용해 주세요.');
  }
  return value;
}

/// No training quantities are inferred: authored sessions repeat for the chosen duration.
TrainingProgram generateRoutine(RoutineBlueprint draft) {
  final id = _slug(draft.id, '프로그램 ID');
  final title = _required(draft.title, '프로그램 이름');
  final version = _required(draft.version, '버전', max: 30);
  final description = _required(draft.description, '프로그램 설명', max: 2000);
  final weeks = _integer(draft.weeks, 1, 52, '기간');
  if (draft.sessions.isEmpty || draft.sessions.length > 7) {
    throw const FormatException('주간 세션은 1~7개로 구성해 주세요.');
  }
  final identities = <String, (String, MainLift?)>{};
  final sessions = <ProgramSession>[];
  for (var week = 1; week <= weeks; week++) {
    for (var day = 0; day < draft.sessions.length; day++) {
      final session = draft.sessions[day];
      if (session.exercises.isEmpty || session.exercises.length > 20) {
        throw FormatException('${day + 1}번 세션에는 운동 1~20개가 필요해요.');
      }
      final ids = <String>{};
      final exercises = <ProgramExercise>[];
      for (final exercise in session.exercises) {
        final eid = _slug(exercise.id, '${day + 1}번 세션 운동 ID');
        final name = _required(exercise.name, '운동 이름');
        if (!ids.add(eid)) {
          throw FormatException('$name: 한 세션의 운동 ID는 중복할 수 없어요.');
        }
        final identity = (name, exercise.mainLift);
        if (identities.containsKey(eid) && identities[eid] != identity) {
          throw FormatException('$eid: 같은 운동 ID의 이름과 메인 리프트를 일치시켜 주세요.');
        }
        identities[eid] = identity;
        final count = _integer(exercise.setCount, 1, 10, '$name 세트 수');
        final reps = _integer(exercise.repetitions, 1, 100, '$name 반복 수');
        final rirText = exercise.rir.trim();
        final rir = rirText.isEmpty ? null : double.tryParse(rirText);
        if (rirText.isNotEmpty &&
            (rir == null || !rir.isFinite || rir < 0 || rir > 10)) {
          throw FormatException('$name RIR: 0~10 또는 빈 값으로 입력해 주세요.');
        }
        LoadPrescription load;
        if (exercise.loadKind == LoadKind.manual) {
          load = const LoadPrescription.manual();
        } else {
          final value = double.tryParse(exercise.loadValue.trim());
          if (value == null || !value.isFinite || value <= 0) {
            throw FormatException('$name 중량: 0보다 큰 수를 입력해 주세요.');
          }
          if (exercise.loadKind == LoadKind.percentOfBaseline) {
            if (exercise.mainLift == null) {
              throw FormatException('$name: 기준 중량 비율에는 메인 리프트를 지정해 주세요.');
            }
            load = LoadPrescription.percentOfBaseline(
              exercise.mainLift!,
              value,
            );
          } else {
            load = LoadPrescription.fixedKg(value);
          }
        }
        exercises.add(
          ProgramExercise(
            id: eid,
            name: name,
            mainLift: exercise.mainLift,
            sets: [
              for (var set = 1; set <= count; set++)
                ProgramSet(
                  id: 'set-$set',
                  repetitions: reps,
                  rir: rir,
                  load: load,
                ),
            ],
          ),
        );
      }
      sessions.add(
        ProgramSession(
          id: 'w${week}d${day + 1}',
          week: week,
          dayOrder: day + 1,
          title: _required(session.title, '${day + 1}번 세션 이름'),
          exercises: exercises,
        ),
      );
    }
  }
  return TrainingProgram(
    id: id,
    version: version,
    title: title,
    trainerName: 'Strength',
    description: description,
    weeks: weeks,
    sessions: sessions,
  );
}
