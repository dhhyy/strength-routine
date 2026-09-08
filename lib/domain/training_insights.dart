import 'dart:convert';
import 'dart:math' as math;

import 'recent_lift_record.dart';
import 'training_program.dart';

/// 초기 제품 정책이다. 연구로 검증된 보편적 임계값이나 의료 판단이 아니다.
const d5PolicyId = 'd5-3x1-5pct-v1';
const d5SessionWindow = 3;
const d5RirGap = 1.0;
const d5ReductionFraction = 0.05;

double actualKilograms(SetActual actual) =>
    actual.weight! * (actual.unit == WeightUnit.lb ? 0.45359237 : 1);

final class TrainingTrendPoint {
  final String sessionId;
  final DateTime plannedDate;
  final int performedSets, skippedSets, draftSets, repetitions, rirCount;
  final double? maxWeightKg, averageRir, comparableRirGap;
  const TrainingTrendPoint({
    required this.sessionId,
    required this.plannedDate,
    required this.performedSets,
    required this.skippedSets,
    required this.draftSets,
    required this.repetitions,
    required this.rirCount,
    required this.maxWeightKg,
    required this.averageRir,
    required this.comparableRirGap,
  });
}

final class ExerciseTrend {
  final String key, name;
  final List<TrainingTrendPoint> points;
  final TargetLoadAdjustment? suggestion;
  ExerciseTrend({
    required this.key,
    required this.name,
    required List<TrainingTrendPoint> points,
    this.suggestion,
  }) : points = List.unmodifiable(points);
}

final class _Occurrence {
  final PlannedSession session;
  final ProgramExercise authored;
  final PlannedExercise planned;
  const _Occurrence(this.session, this.authored, this.planned);
}

/// 글로벌 종목 ID를 추정하지 않는다. 계획 안에서 작성자가 유지한 ID·이름·
/// 명시 mainLift가 모두 같은 운동만 묶고 baseline용 lift는 사용하지 않는다.
String exerciseInsightKey(String planId, ProgramExercise exercise) =>
    jsonEncode([planId, exercise.id, exercise.name, exercise.mainLift?.key]);

List<ExerciseTrend> buildTrainingInsights(
  TrainingAppState state, {
  required String planId,
  required DateTime asOf,
}) {
  final plans = [
    ...state.planHistory,
    if (state.activePlan != null) state.activePlan!,
  ];
  final found = plans.where((plan) => plan.id == planId);
  if (found.isEmpty) return const [];
  final plan = found.single;
  final groups = <String, List<_Occurrence>>{};
  final sessions = plan.sessions;
  final authored = plan.program.orderedSessions;
  for (var s = 0; s < sessions.length; s++) {
    for (var e = 0; e < sessions[s].exercises.length; e++) {
      final exercise = authored[s].exercises[e];
      final key = exerciseInsightKey(plan.id, exercise);
      groups
          .putIfAbsent(key, () => [])
          .add(_Occurrence(sessions[s], exercise, sessions[s].exercises[e]));
    }
  }
  return List.unmodifiable(
    groups.entries.map((entry) {
      final past = entry.value
          .where((o) => !o.session.date.isAfter(calendarDate(asOf)))
          .toList();
      final points = past.map((o) => _point(state, o)).toList();
      return ExerciseTrend(
        key: entry.key,
        name: entry.value.first.authored.name,
        points: points,
        suggestion: state.activePlan?.id == plan.id
            ? _suggestion(state, plan, entry.key, entry.value, points, asOf)
            : null,
      );
    }),
  );
}

TrainingTrendPoint _point(TrainingAppState state, _Occurrence occurrence) {
  final sets = occurrence.planned.sets;
  final actuals = <SetActual>[];
  var skipped = 0;
  var drafts = 0;
  for (final set in sets) {
    if (state.setDrafts.containsKey(set.id)) {
      drafts++;
      continue;
    }
    final actual = state.setActuals[set.id];
    if (actual?.status == SetActualStatus.completed) actuals.add(actual!);
    if (actual?.status == SetActualStatus.skipped) skipped++;
  }
  final rirs = actuals.map((a) => a.rir).whereType<double>().toList();
  final sessionRequired = occurrence.session.exercises
      .expand((e) => e.sets)
      .where((s) => s.isRequired)
      .toList();
  // AMRAP's displayed repetition count is a reference, not a fixed target.
  final required = sets.where((s) => s.isRequired && !s.isAmrap).toList();
  final comparable =
      sessionRequired.isNotEmpty &&
      required.isNotEmpty &&
      sessionRequired.every(
        (s) =>
            !state.setDrafts.containsKey(s.id) &&
            state.setActuals[s.id]?.status == SetActualStatus.completed,
      ) &&
      required.every(
        (s) =>
            s.rir != null &&
            state.setActuals[s.id]?.rir != null &&
            state.setActuals[s.id]?.repetitions == s.repetitions,
      );
  return TrainingTrendPoint(
    sessionId: occurrence.session.id,
    plannedDate: occurrence.session.date,
    performedSets: actuals.length,
    skippedSets: skipped,
    draftSets: drafts,
    repetitions: actuals.fold(0, (sum, a) => sum + a.repetitions!),
    rirCount: rirs.length,
    maxWeightKg: actuals.isEmpty
        ? null
        : actuals.map(actualKilograms).reduce(math.max),
    averageRir: rirs.isEmpty
        ? null
        : rirs.reduce((a, b) => a + b) / rirs.length,
    comparableRirGap: comparable
        ? required
                  .map((s) => s.rir! - state.setActuals[s.id]!.rir!)
                  .reduce((a, b) => a + b) /
              required.length
        : null,
  );
}

TargetLoadAdjustment? _suggestion(
  TrainingAppState state,
  ActiveTrainingPlan plan,
  String key,
  List<_Occurrence> occurrences,
  List<TrainingTrendPoint> points,
  DateTime asOf,
) {
  // 적용 또는 되돌린 뒤에는 새로운 세션 3개를 기다려 같은 근거의 반복 감량을 막는다.
  final previous = state.loadAdjustments
      .where((a) => a.exerciseKey == key)
      .toList();
  final eligibleDates = previous.isEmpty
      ? points
      : points
            .where(
              (point) => point.plannedDate.isAfter(previous.last.appliedOn),
            )
            .toList();
  if (eligibleDates.length < d5SessionWindow) return null;
  final window = eligibleDates.sublist(eligibleDates.length - d5SessionWindow);
  // 누락·제외·초안·RIR 미입력은 오래된 기록으로 건너뛰지 않고 연속 신호를 끊는다.
  if (window.any(
    (point) =>
        point.comparableRirGap == null || point.comparableRirGap! < d5RirGap,
  )) {
    return null;
  }
  final id = jsonEncode([d5PolicyId, key, ...window.map((p) => p.sessionId)]);
  if (state.loadAdjustments.any((a) => a.id == id)) return null;
  final before = <String, double>{};
  final after = <String, double>{};
  for (final occurrence in occurrences.where(
    (o) => o.session.date.isAfter(calendarDate(asOf)),
  )) {
    for (final set in occurrence.planned.sets) {
      if (set.isAmrap ||
          state.setActuals.containsKey(set.id) ||
          state.setDrafts.containsKey(set.id)) {
        continue;
      }
      final current = state.effectiveTargetKg(set);
      if (current == null) continue;
      final reduced =
          (current * (1 - d5ReductionFraction) / plan.incrementKg).ceil() *
          plan.incrementKg;
      // 최소 증량 단위 때문에 변화가 없거나 0이 되면 억지로 한 틱을 감량하지 않는다.
      if (!reduced.isFinite || reduced <= 0 || reduced >= current) continue;
      before[set.id] = current;
      after[set.id] = reduced;
    }
  }
  if (after.isEmpty) return null;
  final evidenceIds = window.map((p) => p.sessionId).toList();
  final evidenceRecords = <String, String>{};
  for (final session in plan.sessions.where(
    (s) => evidenceIds.contains(s.id),
  )) {
    for (final set
        in session.exercises.expand((e) => e.sets).where((s) => s.isRequired)) {
      evidenceRecords[set.id] = jsonEncode(state.setActuals[set.id]!.toJson());
    }
  }
  return TargetLoadAdjustment(
    id: id,
    planId: plan.id,
    exerciseKey: key,
    exerciseName: occurrences.first.authored.name,
    policyId: d5PolicyId,
    appliedOn: asOf,
    evidenceSessionIds: evidenceIds,
    evidenceRirGaps: window.map((p) => p.comparableRirGap!).toList(),
    evidenceRecords: evidenceRecords,
    beforeKg: before,
    afterKg: after,
  );
}
