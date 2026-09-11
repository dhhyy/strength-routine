/// Phase 0/1 정책: e1RM은 추정이다. 실제 1RM 판정이 아니다.
/// 공식: Epley — e1RM = w * (1 + r/30). 참고 계산기 UX와 동일한 계열.
library;

const e1rmPolicyId = 'e1rm-epley-v1';
const e1rmFeatureFlag = bool.fromEnvironment('LIVE_E1RM_V1', defaultValue: true);

/// 작업 세트 추정에 쓰는 반복 상한. 그 이상은 신뢰도 낮아 후보에서 제외.
const e1rmMaxRepsForEstimate = 12;

/// RIR이 이 값을 넘으면(여유 큼) working-max 후보에서 제외.
/// TODO(you): 코치 기준에 맞게 조정 — 예: 3이면 더 보수적, 5면 더 관대.
const e1rmMaxRirForEstimate = 4.0;

/// Epley. [weightKg] > 0, [repetitions] >= 1.
/// reps == 1 이면 weight 그대로.
double estimateE1rmKg({
  required double weightKg,
  required int repetitions,
}) {
  if (weightKg <= 0) {
    throw ArgumentError.value(weightKg, 'weightKg', 'must be positive');
  }
  if (repetitions < 1) {
    throw ArgumentError.value(repetitions, 'repetitions', 'must be >= 1');
  }
  if (repetitions == 1) return weightKg;
  return weightKg * (1 + repetitions / 30.0);
}

/// 갱신 후보로 쓸지. 워밍업/실패 세트는 호출 측에서 걸러낸다.
bool isEligibleE1rmSet({
  required int repetitions,
  double? rir,
}) {
  if (repetitions < 1 || repetitions > e1rmMaxRepsForEstimate) return false;
  if (rir != null && rir > e1rmMaxRirForEstimate) return false;
  return true;
}

/// 표시·비교용으로 0.5kg 단위 반올림(일반적인 바벨 간격의 절반).
double roundE1rmKg(double value, {double increment = 0.5}) {
  if (increment <= 0) return value;
  return (value / increment).round() * increment;
}
