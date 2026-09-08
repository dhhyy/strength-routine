import 'dart:convert';
import 'training_program.dart';

final class PreviousSetRecord {
  final String planId,
      programTitle,
      sessionId,
      sessionTitle,
      setId,
      exerciseName;
  final int number;
  final SetActual actual;
  const PreviousSetRecord({
    required this.planId,
    required this.programTitle,
    required this.sessionId,
    required this.sessionTitle,
    required this.setId,
    required this.exerciseName,
    required this.number,
    required this.actual,
  });
  String get fingerprint =>
      jsonEncode([planId, sessionId, setId, actual.toJson()]);

  Map<String, String> copyInto(Map<String, String> draft) => {
    ...draft,
    'weight': _number(actual.weight!),
    'unit': actual.unit!.key,
    'repetitions': '${actual.repetitions}',
  };
}

String _number(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

/// Conservative identity: never infer exercise equivalence from display names.
List<PreviousSetRecord> previousSetRecords(
  TrainingAppState state, {
  required String targetSetId,
  required DateTime? performedBefore,
  required DateTime asOf,
}) {
  final active = state.activePlan;
  if (active == null ||
      performedBefore == null ||
      performedBefore.isAfter(calendarDate(asOf))) {
    return const [];
  }
  ProgramExercise? targetExercise;
  ProgramSet? targetSet;
  var ordinal = -1;
  final activeSessions = active.sessions;
  final templates = active.program.orderedSessions;
  for (var s = 0; s < activeSessions.length; s++) {
    for (var e = 0; e < activeSessions[s].exercises.length; e++) {
      final sets = activeSessions[s].exercises[e].sets;
      final index = sets.indexWhere((set) => set.id == targetSetId);
      if (index >= 0) {
        targetExercise = templates[s].exercises[e];
        targetSet = targetExercise.sets[index];
        ordinal = index;
      }
    }
  }
  if (targetExercise == null || targetSet == null) return const [];
  final identity = targetExercise;
  final allIdentities = templates
      .expand((s) => s.exercises)
      .where((e) => e.id == identity.id);
  if (allIdentities.any(
    (e) => e.name != identity.name || e.mainLift != identity.mainLift,
  )) {
    return const [];
  }
  final programContent = jsonEncode(active.program.toJson());
  final result = <PreviousSetRecord>[];
  for (final plan in [...state.planHistory, active]) {
    if (plan.program.id != active.program.id ||
        plan.program.version != active.program.version ||
        jsonEncode(plan.program.toJson()) != programContent) {
      continue;
    }
    final sourceTemplates = plan.program.orderedSessions;
    final planned = plan.sessions;
    for (var s = 0; s < planned.length; s++) {
      for (var e = 0; e < sourceTemplates[s].exercises.length; e++) {
        final source = sourceTemplates[s].exercises[e];
        if (source.id != identity.id ||
            source.name != identity.name ||
            source.mainLift != identity.mainLift ||
            source.sets.length <= ordinal) {
          continue;
        }
        final sourceSet = source.sets[ordinal];
        if (sourceSet.id != targetSet.id ||
            sourceSet.toJson()['setKind'] != targetSet.toJson()['setKind']) {
          continue;
        }
        final setId = planned[s].exercises[e].sets[ordinal].id;
        final actual = state.setActuals[setId];
        if (setId == targetSetId ||
            state.setDrafts.containsKey(setId) ||
            actual?.status != SetActualStatus.completed ||
            actual?.performedDate == null ||
            !actual!.performedDate!.isBefore(calendarDate(performedBefore)) ||
            actual.performedDate!.isAfter(calendarDate(asOf))) {
          continue;
        }
        result.add(
          PreviousSetRecord(
            planId: plan.id,
            programTitle: plan.program.title,
            sessionId: planned[s].id,
            sessionTitle: planned[s].title,
            setId: setId,
            exerciseName: identity.name,
            number: ordinal + 1,
            actual: actual,
          ),
        );
      }
    }
  }
  result.sort((a, b) {
    final date = b.actual.performedDate!.compareTo(a.actual.performedDate!);
    return date == 0 ? a.setId.compareTo(b.setId) : date;
  });
  return List.unmodifiable(result.take(10));
}
