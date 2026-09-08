enum RestDurationSource { prescription, userDefault }

/// Explicit zero is a prescription to take no rest, never a missing value.
int? resolveRestSeconds(int? prescribed, int? defaultSeconds) =>
    prescribed ?? defaultSeconds;

/// One explicit rest interval. Countdown uses an absolute UTC deadline, so
/// backgrounding the UI never extends the interval by missed frame ticks.
final class RestTimerSnapshot {
  final String planId, sessionId, setId, exerciseName, sourceStamp;
  final int setNumber, durationSeconds;
  final RestDurationSource durationSource;
  final DateTime? endsAt;
  final int? pausedMilliseconds;

  RestTimerSnapshot({
    required this.planId,
    required this.sessionId,
    required this.setId,
    required this.exerciseName,
    required this.sourceStamp,
    required this.setNumber,
    required this.durationSeconds,
    this.durationSource = RestDurationSource.prescription,
    this.endsAt,
    this.pausedMilliseconds,
  }) {
    if ([
          planId,
          sessionId,
          setId,
          exerciseName,
          sourceStamp,
        ].any((v) => v.trim().isEmpty) ||
        setNumber < 1 ||
        durationSeconds < 1 ||
        durationSeconds > 3600 ||
        (endsAt == null) == (pausedMilliseconds == null) ||
        (endsAt != null && !endsAt!.isUtc) ||
        (pausedMilliseconds != null &&
            (pausedMilliseconds! < 1 ||
                pausedMilliseconds! > durationSeconds * 1000))) {
      throw const FormatException('Invalid rest timer');
    }
  }

  bool get isPaused => pausedMilliseconds != null;
  int remainingMilliseconds(DateTime now) =>
      pausedMilliseconds ??
      endsAt!
          .difference(now.toUtc())
          .inMilliseconds
          .clamp(0, durationSeconds * 1000);
  int remainingSeconds(DateTime now) =>
      (remainingMilliseconds(now) / 1000).ceil();

  RestTimerSnapshot pause(DateTime now) {
    final remaining = remainingMilliseconds(now);
    if (isPaused || remaining == 0) {
      throw const FormatException('Timer is not running');
    }
    return _copy(pausedMilliseconds: remaining);
  }

  RestTimerSnapshot resume(DateTime now) {
    if (!isPaused) throw const FormatException('Timer is not paused');
    return _copy(
      endsAt: now.toUtc().add(Duration(milliseconds: pausedMilliseconds!)),
    );
  }

  RestTimerSnapshot _copy({DateTime? endsAt, int? pausedMilliseconds}) =>
      RestTimerSnapshot(
        planId: planId,
        sessionId: sessionId,
        setId: setId,
        exerciseName: exerciseName,
        sourceStamp: sourceStamp,
        setNumber: setNumber,
        durationSeconds: durationSeconds,
        durationSource: durationSource,
        endsAt: endsAt,
        pausedMilliseconds: pausedMilliseconds,
      );

  Map<String, Object?> toJson() => {
    'planId': planId,
    'sessionId': sessionId,
    'setId': setId,
    'exerciseName': exerciseName,
    'sourceStamp': sourceStamp,
    'setNumber': setNumber,
    'durationSeconds': durationSeconds,
    if (durationSource != RestDurationSource.prescription)
      'durationSource': durationSource.name,
    'endsAt': endsAt?.toIso8601String(),
    'pausedMilliseconds': pausedMilliseconds,
  };

  factory RestTimerSnapshot.fromJson(Map<String, dynamic> json) {
    const keys = {
      'planId',
      'sessionId',
      'setId',
      'exerciseName',
      'sourceStamp',
      'setNumber',
      'durationSeconds',
      'endsAt',
      'pausedMilliseconds',
    };
    final allowed = {...keys, 'durationSource'};
    if (!keys.every(json.containsKey) || !json.keys.every(allowed.contains)) {
      throw const FormatException('Incomplete rest timer');
    }
    DateTime? endsAt;
    if (json['endsAt'] != null) {
      final raw = json['endsAt'] as String;
      endsAt = DateTime.parse(raw);
      // Reject normalized impossible dates and local/offset timestamps.
      if (!raw.endsWith('Z') || endsAt.toIso8601String() != raw) {
        throw const FormatException('Invalid timer deadline');
      }
    }
    return RestTimerSnapshot(
      planId: json['planId'] as String,
      sessionId: json['sessionId'] as String,
      setId: json['setId'] as String,
      exerciseName: json['exerciseName'] as String,
      sourceStamp: json['sourceStamp'] as String,
      setNumber: json['setNumber'] as int,
      durationSeconds: json['durationSeconds'] as int,
      durationSource: !json.containsKey('durationSource')
          ? RestDurationSource.prescription
          : switch (json['durationSource']) {
              'prescription' => RestDurationSource.prescription,
              'userDefault' => RestDurationSource.userDefault,
              _ => throw const FormatException('Invalid rest duration source'),
            },
      endsAt: endsAt,
      pausedMilliseconds: json['pausedMilliseconds'] as int?,
    );
  }
}
