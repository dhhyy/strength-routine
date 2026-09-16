/// D8 충돌 사다리. 숫자가 작을수록 이긴다.
enum EnginePriority {
  injury(1),
  recovery(2),
  volume(3),
  intensity(4);

  const EnginePriority(this.rank);
  final int rank;
}

final class FiredRule {
  final String id;
  final String reason;
  final EnginePriority priority;
  const FiredRule({
    required this.id,
    required this.reason,
    required this.priority,
  });
}

/// 출시 규칙 목록. 보류 규칙은 여기 추가만 한다.
const kRegisteredRules = <String>{
  'match_template',
  'take_weeks',
  'accessory_cap',
  'start_plan',
  'live_working_max',
  'conflict_recovery',
  'apply_working_max',
  'd5_inspect',
  'd5_apply',
  'd5_undo',
  'review_schedule',
  'postpone_session',
};
