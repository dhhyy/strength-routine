import 'training_program.dart';

/// 오늘·미래 세션을 **기록이 없을 때만** 다음 훈련 요일로 미룬다.
/// 해당 세션 이후의 빈 세션도 요일 슬롯을 유지하며 함께 밀어 순서를 지킨다.
String? postponeProtectionReason(
  TrainingAppState state,
  PlannedSession session, {
  required DateTime asOf,
}) {
  if (session.date.isBefore(calendarDate(asOf))) return '지난 일정';
  final sets = session.exercises.expand((exercise) => exercise.sets);
  if (sets.any((set) => state.setActuals.containsKey(set.id))) {
    return '완료·제외 기록 있음';
  }
  if (sets.any((set) => state.setDrafts.containsKey(set.id))) {
    return '작성 중인 입력 있음';
  }
  if (state.sessionNotes.containsKey(session.id)) return '세션 메모 있음';
  if (state.sessionEvents.any((event) => event.sessionId == session.id) ||
      state.legacySessionIds.contains(session.id) ||
      state.completionNotified.contains(session.id)) {
    return '기록 상태 이력 있음';
  }
  return null;
}

DateTime nextTrainingDay(DateTime after, List<int> weekdays) {
  var day = calendarDate(after).add(const Duration(days: 1));
  while (!weekdays.contains(day.weekday)) {
    day = day.add(const Duration(days: 1));
  }
  return day;
}

extension PostponeEditing on TrainingAppState {
  TrainingAppState withPostponedSession(
    String sessionId, {
    required DateTime asOf,
  }) {
    final plan = activePlan;
    if (plan == null) throw const FormatException('진행 중인 프로그램이 없어요.');
    final sessions = plan.sessions;
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) throw const FormatException('현재 계획에 없는 운동이에요.');
    final reason = postponeProtectionReason(
      this,
      sessions[index],
      asOf: asOf,
    );
    if (reason != null) {
      throw FormatException('${sessions[index].title}: $reason');
    }

    final dates = Map<String, DateTime>.of(plan.sessionDates);
    final anchor = sessions[index].date.isAfter(calendarDate(asOf))
        ? sessions[index].date
        : calendarDate(asOf);
    var cursor = nextTrainingDay(anchor, plan.weekdays);
    for (var i = index; i < sessions.length; i++) {
      final session = sessions[i];
      if (i > index) {
        final blocked = postponeProtectionReason(this, session, asOf: asOf);
        if (blocked != null) break;
      }
      dates[session.id] = cursor;
      cursor = nextTrainingDay(cursor, plan.weekdays);
    }

    DateTime? previous;
    for (final session in sessions) {
      final date = dates[session.id]!;
      if (previous != null && !date.isAfter(previous)) {
        throw const FormatException('운동 순서대로 서로 다른 날짜를 선택해 주세요.');
      }
      previous = date;
    }

    final next = plan.replaceSessionDates(dates);
    return TrainingAppState.fromJson({
      ...toJson(),
      'activePlan': next.toJson(),
    });
  }
}
