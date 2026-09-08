// 예시 화면의 상태만 다룬다. 실제 프로그램이나 훈련 처방을 생성하지 않는다.
const fields = ['weight', 'reps', 'rir'];
const statuses = new Set(['pending', 'completed', 'skipped']);
const maxInputLength = 256;

function requireCondition(condition, message) {
  if (!condition) throw new TypeError(message);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function dateParts(value) {
  requireCondition(typeof value === 'string', '날짜는 문자열이어야 합니다.');
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  requireCondition(match !== null, '날짜 형식을 확인해 주세요.');
  const [, year, month, day] = match.map(Number);
  requireCondition(year >= 1, '날짜를 확인해 주세요.');
  // Date.UTC의 0~99년 보정을 피하고 현지 시각/DST와 독립적으로 계산한다.
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  requireCondition(
    date.getUTCFullYear() === year &&
      date.getUTCMonth() === month - 1 &&
      date.getUTCDate() === day,
    '존재하지 않는 날짜입니다.',
  );
  return date;
}

function requireWeekday(weekday) {
  requireCondition(
    Number.isInteger(weekday) && weekday >= 1 && weekday <= 7,
    '운동요일은 1부터 7까지의 정수여야 합니다.',
  );
}

function localDate(now) {
  requireCondition(now instanceof Date && Number.isFinite(now.getTime()), '현재 날짜를 확인해 주세요.');
  const text = [
    String(now.getFullYear()).padStart(4, '0'),
    String(now.getMonth() + 1).padStart(2, '0'),
    String(now.getDate()).padStart(2, '0'),
  ].join('-');
  dateParts(text);
  return text;
}

export function createState(now = new Date()) {
  return {
    version: 1,
    step: 0,
    startDate: localDate(now),
    weekday: now.getDay() || 7,
    sets: Array.from({ length: 2 }, () => ({
      weight: '', reps: '', rir: '', status: 'pending',
    })),
  };
}

/** 시작일을 포함해 처음 만나는 ISO 요일의 달력 날짜를 반환한다. */
export function plannedDate(startDate, weekday) {
  const date = dateParts(startDate);
  requireWeekday(weekday);
  const offset = (weekday - (date.getUTCDay() || 7) + 7) % 7;
  date.setUTCDate(date.getUTCDate() + offset);
  requireCondition(date.getUTCFullYear() <= 9999, '계획 날짜가 지원 범위를 벗어났습니다.');
  return date.toISOString().slice(0, 10);
}

function numericValue(value) {
  if (typeof value === 'number') return value;
  if (typeof value !== 'string' || value.trim() === '' || value.length > maxInputLength) return NaN;
  // JS의 16진수·2진수 리터럴을 사용자 중량 입력으로 해석하지 않는다.
  if (!/^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/.test(value.trim())) return NaN;
  return Number(value);
}

export function validateSet(set) {
  const errors = {};
  const weight = numericValue(set?.weight);
  const reps = numericValue(set?.reps);
  const rir = set?.rir;
  if (!Number.isFinite(weight) || weight < 0) {
    errors.weight = '중량은 0 이상의 유한한 수로 입력해 주세요.';
  }
  if (
    !Number.isSafeInteger(reps) || reps <= 0 ||
    (typeof set?.reps === 'string' && !/^\+?\d+$/.test(set.reps.trim()))
  ) {
    errors.reps = '반복 횟수는 1 이상의 정수로 입력해 주세요.';
  }
  if (rir !== undefined && rir !== null && !(typeof rir === 'string' && rir.trim() === '')) {
    const value = numericValue(rir);
    if (!Number.isFinite(value) || value < 0 || value > 10) {
      errors.rir = 'RIR은 0부터 10 사이의 수로 입력하거나 비워 주세요.';
    }
  }
  return { valid: Object.keys(errors).length === 0, errors };
}

function validateState(state) {
  requireCondition(isObject(state), '저장된 상태를 확인해 주세요.');
  requireCondition(state.version === 1, '지원하지 않는 저장 버전입니다.');
  requireCondition(Number.isInteger(state.step) && state.step >= 0 && state.step <= 2, '체험 단계를 확인해 주세요.');
  dateParts(state.startDate);
  requireWeekday(state.weekday);
  requireCondition(Array.isArray(state.sets) && state.sets.length === 2, '예시 세트는 정확히 2개여야 합니다.');
  for (const set of state.sets) {
    requireCondition(isObject(set) && statuses.has(set.status), '세트 상태를 확인해 주세요.');
    for (const field of fields) {
      requireCondition(
        typeof set[field] === 'string' && set[field].length <= maxInputLength,
        '세트 입력은 256자 이하의 문자열이어야 합니다.',
      );
    }
    if (set.status === 'completed') {
      requireCondition(validateSet(set).valid, '완료한 세트의 입력을 확인해 주세요.');
    }
  }
  return state;
}

export function parseStoredState(raw) {
  requireCondition(typeof raw === 'string', '저장된 상태는 JSON 문자열이어야 합니다.');
  return validateState(JSON.parse(raw));
}

export function serializeState(state) {
  validateState(state);
  const raw = JSON.stringify(state);
  // toJSON 등이 있는 호출자 객체도 실제 저장되는 결과를 검증한다.
  parseStoredState(raw);
  return raw;
}

export function computeSummary(state) {
  validateState(state);
  return state.sets.reduce((summary, set) => {
    if (set.status === 'completed') summary.performed += 1;
    else if (set.status === 'skipped') summary.skipped += 1;
    else if (fields.some((field) => set[field].length > 0)) summary.drafts += 1;
    return summary;
  }, { performed: 0, skipped: 0, drafts: 0 });
}
