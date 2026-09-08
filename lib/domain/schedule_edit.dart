import 'training_program.dart';

/// A session with any user-owned data keeps its original scheduled date.
String? scheduleProtectionReason(
  TrainingAppState state,
  PlannedSession session, {
  required DateTime asOf,
}) {
  if (!session.date.isAfter(calendarDate(asOf))) return '오늘·지난 일정';
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

extension ScheduleEditing on TrainingAppState {
  TrainingAppState withReviewedSchedule(
    Map<String, DateTime> changes, {
    required DateTime asOf,
  }) {
    final plan = activePlan;
    if (plan == null) throw const FormatException('진행 중인 프로그램이 없어요.');
    final sessions = {for (final session in plan.sessions) session.id: session};
    final meaningful = <String, DateTime>{};
    for (final entry in changes.entries) {
      final session = sessions[entry.key];
      if (session == null) throw const FormatException('현재 계획에 없는 운동이에요.');
      final date = calendarDate(entry.value);
      if (date == session.date) continue;
      final reason = scheduleProtectionReason(this, session, asOf: asOf);
      if (reason != null) throw FormatException('${session.title}: $reason');
      if (!date.isAfter(calendarDate(asOf))) {
        throw const FormatException('내일 이후 날짜를 선택해 주세요.');
      }
      if (!plan.weekdays.contains(date.weekday)) {
        throw const FormatException('처음 선택한 훈련 요일 중에서 골라 주세요.');
      }
      meaningful[entry.key] = date;
    }
    DateTime? previous;
    for (final session in plan.sessions) {
      final date = meaningful[session.id] ?? session.date;
      if (date.isBefore(plan.startDate)) {
        throw const FormatException('프로그램 시작일 이후로 선택해 주세요.');
      }
      if (previous != null && !date.isAfter(previous)) {
        throw const FormatException('운동 순서대로 서로 다른 날짜를 선택해 주세요.');
      }
      previous = date;
    }
    final next = plan.rescheduleFuture(meaningful, asOf: asOf);
    // Keep every existing and future state metadata field through its own codec.
    return TrainingAppState.fromJson({
      ...toJson(),
      'activePlan': next.toJson(),
    });
  }
}
