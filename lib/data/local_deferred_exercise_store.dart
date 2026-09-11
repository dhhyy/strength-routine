import 'dart:convert';
import 'dart:io';

/// 세션 안 종목을 다음으로 미룬 큐. 운동 스키마와 분리.
final class DeferredExercise {
  final String planId;
  final String sessionId;
  final String exerciseId;
  final String exerciseName;
  final DateTime deferredAt;

  DeferredExercise({
    required this.planId,
    required this.sessionId,
    required this.exerciseId,
    required this.exerciseName,
    required this.deferredAt,
  });

  Map<String, Object?> toJson() => {
    'planId': planId,
    'sessionId': sessionId,
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'deferredAt': deferredAt.toUtc().toIso8601String(),
  };

  factory DeferredExercise.fromJson(Map<String, dynamic> j) => DeferredExercise(
    planId: j['planId'] as String,
    sessionId: j['sessionId'] as String,
    exerciseId: j['exerciseId'] as String,
    exerciseName: j['exerciseName'] as String,
    deferredAt: DateTime.parse(j['deferredAt'] as String),
  );
}

final class DeferredExerciseState {
  final List<DeferredExercise> items;
  const DeferredExerciseState([this.items = const []]);

  DeferredExerciseState defer(DeferredExercise value) {
    final next = [
      for (final item in items)
        if (item.exerciseId != value.exerciseId) item,
      value,
    ];
    return DeferredExerciseState(List.unmodifiable(next));
  }

  DeferredExerciseState clearExercise(String exerciseId) =>
      DeferredExerciseState(
        List.unmodifiable([
          for (final item in items)
            if (item.exerciseId != exerciseId) item,
        ]),
      );

  DeferredExerciseState clearPlan(String planId) => DeferredExerciseState(
    List.unmodifiable([
      for (final item in items)
        if (item.planId != planId) item,
    ]),
  );

  List<DeferredExercise> forPlan(String planId) => [
    for (final item in items)
      if (item.planId == planId) item,
  ];

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory DeferredExerciseState.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unsupported deferred-exercise schema');
    }
    final raw = j['items'] as List? ?? const [];
    return DeferredExerciseState(
      List.unmodifiable([
        for (final v in raw)
          DeferredExercise.fromJson(Map<String, dynamic>.from(v as Map)),
      ]),
    );
  }
}

final class LocalDeferredExerciseStore {
  final File file;
  LocalDeferredExerciseStore(this.file);

  Future<DeferredExerciseState> load() async {
    if (!await file.exists()) return const DeferredExerciseState();
    final raw = jsonDecode(await file.readAsString());
    return DeferredExerciseState.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> save(DeferredExerciseState state) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(state.toJson()));
  }
}
