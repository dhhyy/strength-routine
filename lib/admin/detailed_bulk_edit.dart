import 'dart:convert';

import '../domain/training_program.dart';
import 'detailed_routine.dart';

enum DetailedBulkScope { exercise, session, week, program }

enum DetailedBulkField {
  repetitions,
  repetitionsMax,
  rir,
  restSeconds,
  fixedKg,
  kind,
}

String bulkScopeLabel(DetailedBulkScope scope) => switch (scope) {
  DetailedBulkScope.exercise => '현재 운동',
  DetailedBulkScope.session => '현재 세션',
  DetailedBulkScope.week => '현재 주차',
  DetailedBulkScope.program => '전체 프로그램',
};
String bulkFieldLabel(DetailedBulkField field) => switch (field) {
  DetailedBulkField.repetitions => '반복 하한',
  DetailedBulkField.repetitionsMax => '반복 상한',
  DetailedBulkField.rir => '목표 RIR',
  DetailedBulkField.restSeconds => '휴식 초',
  DetailedBulkField.fixedKg => '고정 중량 kg',
  DetailedBulkField.kind => '세트 종류',
};

final class DetailedBulkChange {
  final String location, before, after;
  const DetailedBulkChange(this.location, this.before, this.after);
}

final class DetailedBulkPreview {
  final DetailedRoutineDraft candidate;
  final String sourceFingerprint;
  final List<DetailedBulkChange> changes;
  final int targetCount;
  DetailedBulkPreview(
    this.candidate,
    this.sourceFingerprint,
    List<DetailedBulkChange> changes,
    this.targetCount,
  ) : changes = List.unmodifiable(changes);
  bool matches(DetailedRoutineDraft current) =>
      sourceFingerprint == jsonEncode(current.toJson());
}

/// Validates a deep candidate before publishing; the raw source is never edited.
DetailedBulkPreview previewDetailedBulkEdit({
  required DetailedRoutineDraft source,
  required int weekIndex,
  required int sessionIndex,
  required int exerciseIndex,
  required DetailedBulkScope scope,
  required DetailedBulkField field,
  String value = '',
  ProgramSetKind kind = ProgramSetKind.work,
}) {
  RangeError.checkValidIndex(weekIndex, source.weeks);
  RangeError.checkValidIndex(sessionIndex, source.weeks[weekIndex].sessions);
  RangeError.checkValidIndex(
    exerciseIndex,
    source.weeks[weekIndex].sessions[sessionIndex].exercises,
  );
  final candidate = source.copy();
  final changes = <DetailedBulkChange>[];
  var targetCount = 0;
  for (var wi = 0; wi < candidate.weeks.length; wi++) {
    if (scope != DetailedBulkScope.program && wi != weekIndex) continue;
    final week = candidate.weeks[wi];
    for (var si = 0; si < week.sessions.length; si++) {
      if ((scope == DetailedBulkScope.exercise ||
              scope == DetailedBulkScope.session) &&
          si != sessionIndex) {
        continue;
      }
      final session = week.sessions[si];
      for (var ei = 0; ei < session.exercises.length; ei++) {
        if (scope == DetailedBulkScope.exercise && ei != exerciseIndex) {
          continue;
        }
        final exercise = session.exercises[ei];
        for (var ti = 0; ti < exercise.sets.length; ti++) {
          final set = exercise.sets[ti];
          targetCount++;
          final before = _value(set, field);
          switch (field) {
            case DetailedBulkField.repetitions:
              set.repetitions = value;
            case DetailedBulkField.repetitionsMax:
              set.repetitionsMax = value;
            case DetailedBulkField.rir:
              set.rir = value;
            case DetailedBulkField.restSeconds:
              set.restSeconds = value;
            case DetailedBulkField.fixedKg:
              set.loadKind = LoadKind.fixedKg;
              set.loadValue = value;
              set.loadLift = null;
            case DetailedBulkField.kind:
              set.kind = kind;
          }
          final after = _value(set, field);
          if (before != after) {
            changes.add(
              DetailedBulkChange(
                '${wi + 1}주 · ${si + 1}회 · ${exercise.name} · ${ti + 1}세트',
                before,
                after,
              ),
            );
          }
        }
      }
    }
  }
  generateDetailedRoutine(candidate);
  return DetailedBulkPreview(
    candidate,
    jsonEncode(source.toJson()),
    changes,
    targetCount,
  );
}

String _value(DetailedSetDraft set, DetailedBulkField field) => switch (field) {
  DetailedBulkField.repetitions => set.repetitions,
  DetailedBulkField.repetitionsMax =>
    set.repetitionsMax.isEmpty ? '미지정' : set.repetitionsMax,
  DetailedBulkField.rir => set.rir.isEmpty ? '미지정' : set.rir,
  DetailedBulkField.restSeconds =>
    set.restSeconds.isEmpty ? '미지정' : set.restSeconds,
  DetailedBulkField.fixedKg => switch (set.loadKind) {
    LoadKind.manual => '운동할 때 직접 입력',
    LoadKind.fixedKg => '${set.loadValue} kg',
    LoadKind.percentOfBaseline =>
      '${set.loadLift?.key ?? '미지정'} 기준 ${set.loadValue}%',
  },
  DetailedBulkField.kind => switch (set.kind) {
    ProgramSetKind.work => '작업 세트',
    ProgramSetKind.warmup => '워밍업',
    ProgramSetKind.drop => '드롭세트',
  },
};
