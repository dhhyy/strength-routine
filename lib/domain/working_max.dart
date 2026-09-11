import 'recent_lift_record.dart';
import 'e1rm.dart';

/// 사용자가 채택한 working max. baseline 공급원 후보(Phase 1에서는 표시·채택만).
final class WorkingMax {
  final MainLift lift;
  final double kilograms;
  final String policyId;
  final DateTime adoptedAt;
  final double? sourceWeightKg;
  final int? sourceRepetitions;
  final String? sourceNote;

  WorkingMax({
    required this.lift,
    required this.kilograms,
    required this.adoptedAt,
    this.policyId = e1rmPolicyId,
    this.sourceWeightKg,
    this.sourceRepetitions,
    this.sourceNote,
  }) {
    if (kilograms <= 0) {
      throw ArgumentError.value(kilograms, 'kilograms');
    }
  }

  Map<String, Object?> toJson() => {
    'lift': lift.key,
    'kilograms': kilograms,
    'policyId': policyId,
    'adoptedAt': adoptedAt.toUtc().toIso8601String(),
    'sourceWeightKg': sourceWeightKg,
    'sourceRepetitions': sourceRepetitions,
    'sourceNote': sourceNote,
  };

  factory WorkingMax.fromJson(Map<String, dynamic> j) => WorkingMax(
    lift: MainLift.values.firstWhere((l) => l.key == j['lift']),
    kilograms: (j['kilograms'] as num).toDouble(),
    policyId: j['policyId'] as String? ?? e1rmPolicyId,
    adoptedAt: DateTime.parse(j['adoptedAt'] as String),
    sourceWeightKg: (j['sourceWeightKg'] as num?)?.toDouble(),
    sourceRepetitions: j['sourceRepetitions'] as int?,
    sourceNote: j['sourceNote'] as String?,
  );
}

final class WorkingMaxState {
  final Map<MainLift, WorkingMax> byLift;
  const WorkingMaxState([this.byLift = const {}]);

  WorkingMax? operator [](MainLift lift) => byLift[lift];

  WorkingMaxState adopt(WorkingMax value) {
    final next = Map<MainLift, WorkingMax>.of(byLift);
    next[value.lift] = value;
    return WorkingMaxState(Map.unmodifiable(next));
  }

  WorkingMaxState clear(MainLift lift) {
    final next = Map<MainLift, WorkingMax>.of(byLift)..remove(lift);
    return WorkingMaxState(Map.unmodifiable(next));
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'byLift': {
      for (final e in byLift.entries) e.key.key: e.value.toJson(),
    },
  };

  factory WorkingMaxState.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unsupported working-max schema');
    }
    final raw = Map<String, dynamic>.from(j['byLift'] as Map? ?? {});
    return WorkingMaxState(
      Map.unmodifiable({
        for (final e in raw.entries)
          MainLift.values.firstWhere((l) => l.key == e.key):
              WorkingMax.fromJson(Map<String, dynamic>.from(e.value as Map)),
      }),
    );
  }
}
