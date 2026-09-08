import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createState, plannedDate, validateSet, parseStoredState, serializeState, computeSummary,
} from './demo-state.mjs';

const fresh = () => createState(new Date(2026, 8, 8, 12));
const completed = (overrides = {}) => ({ weight: '0', reps: '5', rir: '', status: 'completed', ...overrides });

test('처음 상태는 현지 오늘과 ISO 요일, 독립된 빈 세트 2개를 가진다', () => {
  const state = fresh();
  assert.equal(state.startDate, '2026-09-08');
  assert.equal(state.weekday, 2);
  assert.equal(state.step, 0);
  assert.equal(state.version, 1);
  assert.equal(state.sets.length, 2);
  state.sets[0].weight = '42.';
  assert.equal(state.sets[1].weight, '');
  assert.equal(createState(new Date(2026, 8, 6)).weekday, 7);
  assert.throws(() => createState(new Date(NaN)));
});

test('요일 계산은 시작일을 포함하고 월·연도·윤년 경계를 넘는다', () => {
  for (const [start, weekday, expected] of [
    ['2026-09-08', 2, '2026-09-08'],
    ['2026-09-08', 1, '2026-09-14'],
    ['2026-01-31', 1, '2026-02-02'],
    ['2026-12-31', 1, '2027-01-04'],
    ['2024-02-28', 4, '2024-02-29'],
    ['2025-02-28', 6, '2025-03-01'],
    ['2024-03-09', 1, '2024-03-11'],
    ['2024-11-02', 1, '2024-11-04'],
    ['0099-12-31', 5, '0100-01-01'],
  ]) assert.equal(plannedDate(start, weekday), expected, `${start} / ${weekday}`);
});

test('잘못된 달력 날짜와 ISO 요일은 거부한다', () => {
  for (const date of ['2025-02-29', '2024-02-30', '2026-04-31', '2026-13-01', '2026-00-01', '2026-09-00', '2026-9-08', '0000-01-01', '2026-09-08T00:00:00Z']) {
    assert.throws(() => plannedDate(date, 1), undefined, date);
  }
  for (const weekday of [0, 8, 1.5, '1', NaN, undefined]) {
    assert.throws(() => plannedDate('2026-09-08', weekday));
  }
  assert.throws(() => plannedDate('9999-12-31', 1));
});

test('중량 0과 JS 숫자 0은 유효하고 RIR은 선택 입력이다', () => {
  for (const set of [completed(), completed({ weight: 0, reps: 1 }), completed({ weight: '42.5', rir: '0' }), completed({ rir: '10' }), completed({ rir: '  ' })]) {
    assert.deepEqual(validateSet(set), { valid: true, errors: {} });
  }
});

test('빈 중량·무한값·소수 반복·범위 밖 RIR을 필드별로 거부한다', () => {
  for (const weight of ['', '  ', '-1', 'Infinity', 'NaN', '0x10', true, '1'.repeat(257)]) {
    assert.ok(validateSet(completed({ weight })).errors.weight);
  }
  for (const reps of ['', '  ', '0', '-1', '1.5', '3.0', '1e2', Infinity, '9007199254740992']) {
    assert.ok(validateSet(completed({ reps })).errors.reps);
  }
  for (const rir of ['-0.1', '10.1', 'Infinity', 'NaN', true]) {
    assert.ok(validateSet(completed({ rir })).errors.rir);
  }
  assert.equal(validateSet(null).valid, false);
});

test('미완성 초안의 원문과 추가 키는 정규화하거나 삭제하지 않는다', () => {
  const state = fresh();
  state.step = 1;
  state.startDate = '2020-02-29';
  state.sets[0] = { weight: '42.', reps: '  ', rir: '-', status: 'pending', extra: '유지' };
  state.extra = { sample: true };
  const before = structuredClone(state);
  const restored = parseStoredState(serializeState(state));
  assert.deepEqual(restored, before);
  assert.deepEqual(state, before);
  assert.deepEqual(computeSummary(restored), { performed: 0, skipped: 0, drafts: 1 });
});

test('완료와 빈 제외 세트는 왕복 저장하고 수행·제외를 따로 집계한다', () => {
  const state = fresh();
  state.step = 2;
  state.sets[0] = completed({ weight: '0', rir: '2' });
  state.sets[1].status = 'skipped';
  const restored = parseStoredState(serializeState(state));
  assert.deepEqual(restored, state);
  assert.deepEqual(computeSummary(restored), { performed: 1, skipped: 1, drafts: 0 });
  state.sets[0] = { weight: '-', reps: '', rir: '??', status: 'skipped' };
  assert.deepEqual(parseStoredState(serializeState(state)), state);
  assert.deepEqual(computeSummary(state), { performed: 0, skipped: 2, drafts: 0 });
});

test('공백 초안도 작성 중이며 빈 pending이나 제외는 초안 집계에 넣지 않는다', () => {
  const state = fresh();
  assert.deepEqual(computeSummary(state), { performed: 0, skipped: 0, drafts: 0 });
  state.sets[0].weight = ' ';
  state.sets[1] = { weight: '42.', reps: '', rir: '-', status: 'skipped' };
  assert.deepEqual(computeSummary(state), { performed: 0, skipped: 1, drafts: 1 });
});

test('손상 JSON·미지원 버전·잘못된 단계·요일·날짜·세트 구조를 거부한다', () => {
  for (const raw of ['{broken', 'null', '[]', '{}', null]) assert.throws(() => parseStoredState(raw));
  const mutations = [
    (s) => { s.version = 2; },
    (s) => { s.version = '1'; },
    (s) => { s.step = -1; },
    (s) => { s.step = 3; },
    (s) => { s.step = 0.5; },
    (s) => { s.weekday = '2'; },
    (s) => { s.weekday = 8; },
    (s) => { s.startDate = '2026-02-29'; },
    (s) => { s.sets.pop(); },
    (s) => { s.sets.push({ ...s.sets[0] }); },
    (s) => { s.sets[0] = null; },
    (s) => { s.sets[0].status = 'done'; },
    (s) => { delete s.sets[0].rir; },
    (s) => { s.sets[0].weight = 0; },
    (s) => { s.sets[0].weight = '1'.repeat(257); },
  ];
  for (const mutate of mutations) {
    const state = fresh();
    mutate(state);
    assert.throws(() => parseStoredState(JSON.stringify(state)));
    assert.throws(() => serializeState(state));
  }
});

test('미완성 값을 완료 상태로 저장하거나 잘못된 완료 상태를 복원할 수 없다', () => {
  for (const set of [completed({ weight: '' }), completed({ reps: '1.5' }), completed({ rir: '11' })]) {
    const state = fresh();
    state.sets[0] = set;
    assert.throws(() => serializeState(state));
    assert.throws(() => parseStoredState(JSON.stringify(state)));
  }
  const state = fresh();
  state.sets[0].weight = '1'.repeat(256);
  assert.deepEqual(parseStoredState(serializeState(state)), state);
});

test('직렬화 결과도 검증해 toJSON으로 잘못된 상태를 저장하지 않는다', () => {
  const state = fresh();
  state.toJSON = () => ({ version: 2 });
  assert.throws(() => serializeState(state));
});
