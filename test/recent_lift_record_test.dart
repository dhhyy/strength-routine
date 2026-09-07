import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';

final asOf = DateTime.utc(2026, 9, 7);

RecentLiftRecord record({
  MainLift lift = MainLift.squat,
  double weight = 100,
  WeightUnit unit = WeightUnit.kg,
  int repetitions = 5,
  DateTime? date,
  double? rir,
}) => RecentLiftRecord(
  lift: lift,
  weight: weight,
  unit: unit,
  repetitions: repetitions,
  date: date ?? asOf,
  rir: rir,
);

void expectInvalid(RecentLiftRecord record, RecentLiftRecordErrorCode code) {
  final result = record.validate(asOf: asOf);
  expect(result.isValid, isFalse);
  expect(result.value, isNull);
  expect(result.errors.map((error) => error.code), contains(code));
}

void main() {
  test('a usable record is validated for the supplied date', () {
    final candidate = record();
    final result = candidate.validate(asOf: asOf);
    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
    expect(result.value!.record, same(candidate));
    expect(result.value!.asOf, asOf);
  });

  test('weight must be positive and finite', () {
    for (final weight in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expectInvalid(
        record(weight: weight),
        RecentLiftRecordErrorCode.invalidWeight,
      );
    }
    expect(record(weight: 0.5).validate(asOf: asOf).isValid, isTrue);
  });

  test('repetitions must be positive', () {
    for (final repetitions in [0, -1]) {
      expectInvalid(
        record(repetitions: repetitions),
        RecentLiftRecordErrorCode.invalidRepetitions,
      );
    }
    expect(record(repetitions: 1).validate(asOf: asOf).isValid, isTrue);
  });

  test(
    'optional RIR accepts zero but rejects negative and nonfinite values',
    () {
      for (final rir in [
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expectInvalid(record(rir: rir), RecentLiftRecordErrorCode.invalidRir);
      }
      for (final rir in [null, 0.0, 4.5]) {
        expect(record(rir: rir).validate(asOf: asOf).isValid, isTrue);
      }
    },
  );

  test('dates compare calendar days using the injected cutoff', () {
    final candidate = record(date: DateTime(2026, 9, 7, 23, 59));
    final result = candidate.validate(asOf: DateTime(2026, 9, 7, 1));
    expect(result.isValid, isTrue);
    expect(result.value!.asOf, DateTime.utc(2026, 9, 7));
    expect(candidate.date, DateTime.utc(2026, 9, 7));
    expectInvalid(
      record(date: DateTime.utc(2026, 9, 8)),
      RecentLiftRecordErrorCode.futureDate,
    );
    expect(candidate.validate(asOf: DateTime.utc(2026, 9, 6)).isValid, isFalse);
  });

  test('validation reports all invalid fields without changing the record', () {
    final candidate = record(
      weight: -10,
      repetitions: 0,
      rir: -1,
      date: DateTime.utc(2026, 9, 8),
    );
    final result = candidate.validate(asOf: asOf);
    expect(result.value, isNull);
    expect(result.errors.map((error) => error.field), [
      'weight',
      'repetitions',
      'rir',
      'date',
    ]);
    expect(candidate.weight, -10);
    expect(candidate.repetitions, 0);
    expect(candidate.rir, -1);
    expect(() => result.errors.clear(), throwsUnsupportedError);
  });

  test(
    'JSON preserves units, decimal values, optional RIR and calendar dates',
    () {
      for (final unit in WeightUnit.values) {
        for (final rir in [null, 2.5]) {
          final original = record(
            weight: 82.5,
            unit: unit,
            repetitions: 3,
            rir: rir,
          );
          final encoded = jsonEncode(original.toJson());
          expect(encoded, contains('"date":"2026-09-07"'));
          expect(
            encoded,
            contains(unit == WeightUnit.kg ? '"unit":"kg"' : '"unit":"lb"'),
          );
          final restored = RecentLiftRecord.fromJson(
            jsonDecode(encoded) as Map<String, dynamic>,
          );
          expect(restored.toJson(), original.toJson());
          expect(restored.unit, unit);
          expect(restored.validate(asOf: asOf).isValid, isTrue);
        }
      }
    },
  );

  test('restoring a record does not bypass validation', () {
    final encoded = jsonEncode(record(weight: 0).toJson());
    final restored = RecentLiftRecord.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    expectInvalid(restored, RecentLiftRecordErrorCode.invalidWeight);
  });

  test('JSON preserves the lift identity used to match program exercises', () {
    const keys = {
      MainLift.squat: 'squat',
      MainLift.benchPress: 'bench_press',
      MainLift.deadlift: 'deadlift',
      MainLift.overheadPress: 'overhead_press',
    };
    for (final entry in keys.entries) {
      final original = record(lift: entry.key);
      final json =
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      expect(json['lift'], entry.value);
      expect(RecentLiftRecord.fromJson(json).lift, entry.key);
    }
  });

  test('JSON rejects unknown lifts or units, invalid dates and timestamps', () {
    expect(
      () =>
          RecentLiftRecord.fromJson({...record().toJson(), 'lift': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => RecentLiftRecord.fromJson({...record().toJson(), 'unit': 'stone'}),
      throwsFormatException,
    );
    for (final date in [
      '2026-02-30',
      '2026-13-01',
      '2026-09-07T00:00:00Z',
      '2026-9-7',
    ]) {
      expect(
        () => RecentLiftRecord.fromJson({...record().toJson(), 'date': date}),
        throwsFormatException,
      );
    }
  });

  test('JSON roundtrip preserves leap days and extended calendar years', () {
    for (final date in [DateTime.utc(2024, 2, 29), DateTime.utc(10000, 1, 1)]) {
      final original = record(date: date);
      final restored = RecentLiftRecord.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.date, date);
      expect(restored.validate(asOf: date).isValid, isTrue);
    }
  });
}
