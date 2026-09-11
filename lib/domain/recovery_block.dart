import 'training_program.dart';

/// 회복 상한: 메인 리프트가 아닌 운동의 필수 작업 세트를 끝에서부터 비필수로 낮춘다.
/// dropCount 0/1/2 = 악세 세트 −0/−1/−2.
TrainingProgram applyAccessorySetCap(
  TrainingProgram program, {
  required int dropCount,
}) {
  if (dropCount <= 0) return program;
  if (dropCount > 2) {
    throw ArgumentError.value(dropCount, 'dropCount', 'must be 0..2');
  }
  final sessions = <ProgramSession>[];
  for (final session in program.sessions) {
    final exercises = <ProgramExercise>[];
    for (final exercise in session.exercises) {
      if (exercise.mainLift != null) {
        exercises.add(exercise);
        continue;
      }
      final workIndexes = <int>[
        for (var i = 0; i < exercise.sets.length; i++)
          if (exercise.sets[i].kind == ProgramSetKind.work &&
              exercise.sets[i].isRequired)
            i,
      ];
      final dropN = dropCount < workIndexes.length
          ? dropCount
          : workIndexes.length;
      final dropIndex = workIndexes.skip(workIndexes.length - dropN).toSet();
      if (dropIndex.isEmpty) {
        exercises.add(exercise);
        continue;
      }
      exercises.add(
        ProgramExercise(
          id: exercise.id,
          name: exercise.name,
          mainLift: exercise.mainLift,
          sets: [
            for (var i = 0; i < exercise.sets.length; i++)
              if (dropIndex.contains(i))
                _asOptional(exercise.sets[i])
              else
                exercise.sets[i],
          ],
          supersetGroup: exercise.supersetGroup,
        ),
      );
    }
    sessions.add(
      ProgramSession(
        id: session.id,
        week: session.week,
        dayOrder: session.dayOrder,
        title: session.title,
        exercises: exercises,
      ),
    );
  }
  return TrainingProgram(
    id: program.id,
    version: '${program.version}+rec$dropCount',
    title: program.title,
    trainerName: program.trainerName,
    description: program.description,
    weeks: program.weeks,
    sessions: sessions,
  );
}

ProgramSet _asOptional(ProgramSet set) => ProgramSet(
  id: set.id,
  repetitions: set.repetitions,
  repetitionsMax: set.repetitionsMax,
  kind: set.kind,
  rir: set.rir,
  load: set.load,
  isRequired: false,
  restSeconds: set.restSeconds,
  tempo: set.tempo,
  isAmrap: set.isAmrap,
);

/// 블록 프리셋: 앞 N주만 사용. N >= 전체면 원본.
TrainingProgram takeFirstWeeks(TrainingProgram program, int weeks) {
  if (weeks <= 0) {
    throw ArgumentError.value(weeks, 'weeks', 'must be positive');
  }
  if (weeks >= program.weeks) return program;
  final sessions = program.sessions.where((s) => s.week <= weeks).toList();
  return TrainingProgram(
    id: program.id,
    version: '${program.version}+w$weeks',
    title: '${program.title} · $weeks주',
    trainerName: program.trainerName,
    description: program.description,
    weeks: weeks,
    sessions: sessions,
  );
}

enum BlockPreset {
  full('전체 블록'),
  weeks4('앞 4주만'),
  weeks8('앞 8주만');

  const BlockPreset(this.label);
  final String label;

  int? get weekLimit => switch (this) {
    BlockPreset.full => null,
    BlockPreset.weeks4 => 4,
    BlockPreset.weeks8 => 8,
  };
}
