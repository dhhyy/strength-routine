enum MainLift {
  squat('squat'),
  benchPress('bench_press'),
  deadlift('deadlift'),
  overheadPress('overhead_press');

  const MainLift(this.key);
  final String key;
}

enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.key);
  final String key;
}

/// 프로그램 처방과 독립된 사용자 기록. 중량 단위는 각 기록이 보유한다.
/// 날짜는 입력된 연·월·일을 UTC 자정으로 보관하며 시간대 변환하지 않는다.
final class RecentLiftRecord {
  final MainLift lift;
  final double weight;
  final WeightUnit unit;
  final int repetitions;
  final DateTime date;
  final double? rir;

  RecentLiftRecord({
    required this.lift,
    required this.weight,
    required this.unit,
    required this.repetitions,
    required DateTime date,
    this.rir,
  }) : date = _calendarDate(date);

  RecentLiftRecordValidation validate({required DateTime asOf}) {
    final errors = <RecentLiftRecordError>[];
    final cutoff = _calendarDate(asOf);
    if (!weight.isFinite || weight <= 0) {
      errors.add(
        const RecentLiftRecordError(
          RecentLiftRecordErrorCode.invalidWeight,
          'weight',
        ),
      );
    }
    if (repetitions <= 0) {
      errors.add(
        const RecentLiftRecordError(
          RecentLiftRecordErrorCode.invalidRepetitions,
          'repetitions',
        ),
      );
    }
    if (rir != null && (!rir!.isFinite || rir! < 0)) {
      errors.add(
        const RecentLiftRecordError(
          RecentLiftRecordErrorCode.invalidRir,
          'rir',
        ),
      );
    }
    if (date.isAfter(cutoff)) {
      errors.add(
        const RecentLiftRecordError(
          RecentLiftRecordErrorCode.futureDate,
          'date',
        ),
      );
    }
    return RecentLiftRecordValidation._(
      errors: errors,
      value: errors.isEmpty ? ValidatedRecentLiftRecord._(this, cutoff) : null,
    );
  }

  Map<String, Object?> toJson() => {
    'lift': lift.key,
    'weight': weight,
    'unit': unit.key,
    'repetitions': repetitions,
    'date': _dateKey(date),
    'rir': rir,
  };

  /// 복원 자체는 기록의 유효성을 보장하지 않는다. 사용 전 기준일로 재검증한다.
  factory RecentLiftRecord.fromJson(Map<String, dynamic> json) =>
      RecentLiftRecord(
        lift: MainLift.values.firstWhere(
          (lift) => lift.key == json['lift'],
          orElse: () =>
              throw FormatException('Unknown main lift', json['lift']),
        ),
        weight: (json['weight'] as num).toDouble(),
        unit: WeightUnit.values.firstWhere(
          (unit) => unit.key == json['unit'],
          orElse: () =>
              throw FormatException('Unknown weight unit', json['unit']),
        ),
        repetitions: json['repetitions'] as int,
        date: _parseDate(json['date'] as String),
        rir: (json['rir'] as num?)?.toDouble(),
      );
}

enum RecentLiftRecordErrorCode {
  invalidWeight,
  invalidRepetitions,
  invalidRir,
  futureDate,
}

final class RecentLiftRecordError {
  final RecentLiftRecordErrorCode code;
  final String field;
  const RecentLiftRecordError(this.code, this.field);
}

final class RecentLiftRecordValidation {
  final List<RecentLiftRecordError> errors;
  final ValidatedRecentLiftRecord? value;
  bool get isValid => value != null;

  RecentLiftRecordValidation._({
    required List<RecentLiftRecordError> errors,
    required this.value,
  }) : errors = List.unmodifiable(errors);
}

/// 검증 성공 경로에서만 생성된다. 1RM 추정이나 프로그램 적합성을 뜻하지 않는다.
final class ValidatedRecentLiftRecord {
  final RecentLiftRecord record;
  final DateTime asOf;
  const ValidatedRecentLiftRecord._(this.record, this.asOf);
}

DateTime _calendarDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

String _dateKey(DateTime value) => value.toIso8601String().split('T').first;

DateTime _parseDate(String value) {
  if (!RegExp(r'^[+-]?\d{4,6}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('Expected an ISO calendar date', value);
  }
  final date = _calendarDate(DateTime.parse(value));
  if (_dateKey(date) != value) {
    throw FormatException('Invalid calendar date', value);
  }
  return date;
}
