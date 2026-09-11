import 'e1rm.dart';
import 'recent_lift_record.dart';
import 'training_program.dart';

/// Phase 2: 목표×주당일수 → 코치 템플릿 ID. 추측 생성 금지.
const generatorFeatureFlag = bool.fromEnvironment(
  'GENERATOR_V1',
  defaultValue: true,
);

enum RoutineGoal {
  strength('strength', '힘·기량'),
  hypertrophy('hypertrophy', '근비대'),
  habit('habit', '습관 만들기');

  const RoutineGoal(this.key, this.label);
  final String key;
  final String label;
}

/// 코치가 채운 매칭 표. 없는 조합은 null(생성 불가).
const Map<(RoutineGoal, int), String> kRoutineTemplateMatches = {
  (RoutineGoal.strength, 2): 'strength-full-body-2d',
  (RoutineGoal.strength, 3): 'strength-barbell-basics-3d',
  (RoutineGoal.strength, 4): 'strength-upper-lower-4d',
  (RoutineGoal.hypertrophy, 2): 'strength-full-body-2d',
  (RoutineGoal.hypertrophy, 3): 'strength-full-body-3d',
  (RoutineGoal.hypertrophy, 4): 'strength-upper-lower-4d',
  (RoutineGoal.habit, 2): 'strength-dumbbell-2d',
  (RoutineGoal.habit, 3): 'strength-full-body-3d',
  (RoutineGoal.habit, 4): 'strength-upper-lower-4d',
};

Set<int> availableDaysForGoal(RoutineGoal goal) => {
  for (final entry in kRoutineTemplateMatches.entries)
    if (entry.key.$1 == goal) entry.key.$2,
};

String? matchedProgramId(RoutineGoal goal, int daysPerWeek) =>
    kRoutineTemplateMatches[(goal, daysPerWeek)];

TrainingProgram? matchProgram({
  required RoutineGoal goal,
  required int daysPerWeek,
  required Iterable<TrainingProgram> programs,
}) {
  final id = matchedProgramId(goal, daysPerWeek);
  if (id == null) return null;
  final found = programs.where((p) => p.id == id);
  return found.isEmpty ? null : found.first;
}

/// % 처방에 필요한 기준 리프트.
Set<MainLift> requiredBaselineLifts(TrainingProgram program) {
  final lifts = <MainLift>{};
  for (final load
      in program.sessions
          .expand((s) => s.exercises)
          .expand((e) => e.sets)
          .map((s) => s.load)) {
    if (load.kind == LoadKind.percentOfBaseline && load.lift != null) {
      lifts.add(load.lift!);
    }
  }
  for (final exercise in program.sessions.expand((s) => s.exercises)) {
    if (exercise.mainLift != null) lifts.add(exercise.mainLift!);
  }
  return lifts;
}

/// working max·수동 입력을 baseline 맵으로 만든다.
Map<MainLift, LiftBaseline> baselinesForGenerator({
  required Set<MainLift> lifts,
  required Map<MainLift, double> kilograms,
}) {
  final out = <MainLift, LiftBaseline>{};
  for (final lift in lifts) {
    final kg = kilograms[lift];
    if (kg == null || kg <= 0) {
      throw FormatException('${lift.key} 기준 중량이 필요해요.');
    }
    out[lift] = LiftBaseline(
      lift: lift,
      kilograms: roundE1rmKg(kg),
      source: BaselineSource.workingMax,
    );
  }
  return out;
}
