import { createState, plannedDate, validateSet, parseStoredState, serializeState, computeSummary } from './demo-state.mjs';

const storageKey = 'strength-landing-demo-v1';
const fields = ['weight', 'reps', 'rir'];
const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
const tabs = [...document.querySelectorAll('[data-step]')];
const forms = [...document.querySelectorAll('[data-set]')];
const dateInput = document.querySelector('#start-date');
const dateError = document.querySelector('#date-error');
const radios = [...document.querySelectorAll('[name="weekday"]')];
const dialog = document.querySelector('#reset-dialog');
let state = createState();
let storageMode = 'ready';
let restored = false;
try {
  const raw = localStorage.getItem(storageKey);
  if (raw !== null) {
    try {
      state = parseStoredState(raw);
      // A boundary date must also produce a supported scheduled date.
      plannedDate(state.startDate, state.weekday);
      restored = true;
    } catch {
      state = createState();
      storageMode = 'corrupt';
    }
  }
} catch {
  storageMode = 'blocked';
}

function showStorage(message) {
  const status = document.querySelector('#save-status');
  status.dataset.state = storageMode === 'ready' ? 'saved' : 'warning';
  document.querySelector('#save-message').textContent = storageMode === 'corrupt'
    ? '이전 체험을 읽지 못했습니다. 초기화 전까지 덮어쓰지 않습니다.'
    : storageMode === 'reset-failed'
      ? '초기화를 저장하지 못했습니다. 다시 열면 이전 기록이 나타날 수 있습니다.'
      : storageMode === 'blocked'
      ? '브라우저 저장을 사용할 수 없습니다. 이 화면에서만 유지됩니다.'
      : message;
}

function persist() {
  if (storageMode === 'corrupt') return showStorage();
  try {
    localStorage.setItem(storageKey, serializeState(state));
    storageMode = 'ready';
    showStorage('이 브라우저에 저장했습니다.');
  } catch {
    storageMode = 'blocked';
    showStorage();
  }
}

function showDateError(message = '') {
  dateError.textContent = message;
  dateError.hidden = !message;
  dateInput.setAttribute('aria-invalid', String(Boolean(message)));
}

function acceptDate() {
  try {
    plannedDate(dateInput.value, state.weekday);
    state.startDate = dateInput.value;
    showDateError();
    return true;
  } catch {
    showDateError('시작일을 올바른 날짜로 선택해 주세요.');
    return false;
  }
}

function showSetErrors(index, errors = {}) {
  const error = document.querySelector(`#set-error-${index}`);
  error.textContent = Object.values(errors).join(' ');
  error.hidden = Object.keys(errors).length === 0;
  for (const name of fields) forms[index].elements[name].setAttribute('aria-invalid', String(Boolean(errors[name])));
}

function render() {
  tabs.forEach((tab, index) => {
    tab.setAttribute('aria-selected', String(index === state.step));
    tab.tabIndex = index === state.step ? 0 : -1;
    document.querySelector(`#panel-${index}`).hidden = index !== state.step;
  });
  document.querySelector('#stage-label').textContent = ['프로그램', '나의 일정', '세트 기록'][state.step];
  const locked = state.sets.some(set => set.status !== 'pending');
  dateInput.disabled = locked;
  radios.forEach(radio => {
    radio.checked = Number(radio.value) === state.weekday;
    radio.disabled = locked;
  });
  document.querySelector('#scheduled-date').textContent = plannedDate(state.startDate, state.weekday).replaceAll('-', '.');
  document.querySelector('#scheduled-day').textContent = `${weekdays[state.weekday - 1]}요일`;
  document.querySelector('#schedule-note').textContent = locked
    ? '기록이 있는 일정은 고정됩니다. 체험 초기화 후 새 일정을 선택할 수 있습니다.'
    : '선택한 요일에 맞춰 날짜가 바뀝니다. 운동·세트 구성은 그대로 유지됩니다.';
  state.sets.forEach((set, index) => {
    const form = forms[index];
    form.dataset.state = set.status;
    for (const name of fields) {
      const input = form.elements[name];
      if (input.value !== set[name]) input.value = set[name];
      input.readOnly = set.status !== 'pending';
    }
    document.querySelector(`[data-status="${index}"]`).textContent = set.status === 'completed'
      ? '수행 완료' : set.status === 'skipped' ? '제외됨'
        : fields.some(name => set[name].length > 0) ? '작성 중' : '미기록';
    document.querySelector(`[data-complete-label="${index}"]`).textContent = set.status === 'pending' ? '세트 완료' : '수정하기';
    document.querySelector(`[data-skip="${index}"]`).hidden = set.status !== 'pending';
  });
  const { performed, skipped, drafts } = computeSummary(state);
  document.querySelector('#completed-count').textContent = performed;
  document.querySelector('.progress-track').setAttribute('aria-valuenow', performed);
  document.querySelector('#workout-progress').style.width = `${performed * 50}%`;
  document.querySelector('#workout-summary').textContent = performed || skipped || drafts
    ? `실제 수행 ${performed}세트 · 제외 ${skipped}세트 · 작성 중 ${drafts}세트`
    : '실제 수행한 값을 입력해 보세요.';
}

function changeStep(step, focus = true) {
  if (step === 2 && !acceptDate()) {
    state.step = 1;
    render();
    dateInput.focus();
    return false;
  }
  state.step = step;
  render();
  persist();
  if (focus) document.querySelector(`#panel-${step}`).focus({ preventScroll: true });
  return true;
}

function focusNextSet(after = -1) {
  const order = [...state.sets.keys()].filter(index => index > after).concat([...state.sets.keys()].filter(index => index <= after));
  const next = order.find(index => state.sets[index].status === 'pending');
  if (next !== undefined) forms[next].elements.weight.focus();
}

dateInput.value = state.startDate;
dateInput.addEventListener('change', () => {
  if (acceptDate()) { render(); persist(); }
});
radios.forEach(radio => radio.addEventListener('change', () => {
  const next = Number(radio.value);
  try { plannedDate(state.startDate, next); }
  catch { showDateError('선택한 요일에 해당하는 날짜가 지원 범위를 벗어납니다. 시작일을 바꿔 주세요.'); render(); return; }
  state.weekday = next;
  render();
  persist();
}));
tabs.forEach(tab => {
  tab.addEventListener('click', () => changeStep(Number(tab.dataset.step), false));
  tab.addEventListener('keydown', event => {
    const index = Number(tab.dataset.step);
    const next = event.key === 'ArrowRight' ? (index + 1) % tabs.length
      : event.key === 'ArrowLeft' ? (index + tabs.length - 1) % tabs.length
        : event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : null;
    if (next === null) return;
    event.preventDefault();
    if (changeStep(next, false)) tabs[next].focus();
  });
});
document.querySelectorAll('[data-next]').forEach(button => button.addEventListener('click', () => changeStep(Number(button.dataset.next))));
document.querySelectorAll('[data-start]').forEach(link => link.addEventListener('click', () => changeStep(0)));
document.querySelector('[data-record]').addEventListener('click', () => { if (changeStep(2)) focusNextSet(); });

forms.forEach((form, index) => {
  form.addEventListener('input', event => {
    if (!fields.includes(event.target.name) || state.sets[index].status !== 'pending') return;
    state.sets[index][event.target.name] = event.target.value;
    showSetErrors(index);
    render();
    persist();
  });
  form.addEventListener('submit', event => {
    event.preventDefault();
    const set = state.sets[index];
    if (set.status !== 'pending') {
      set.status = 'pending';
      render(); persist();
      form.elements.weight.focus();
      return;
    }
    const result = validateSet(set);
    showSetErrors(index, result.errors);
    if (!result.valid) {
      form.elements[Object.keys(result.errors)[0]].focus();
      return;
    }
    set.status = 'completed';
    render(); persist(); focusNextSet(index);
  });
  form.querySelector('[data-skip]').addEventListener('click', () => {
    state.sets[index].status = 'skipped';
    showSetErrors(index);
    render(); persist(); focusNextSet(index);
  });
});

document.querySelector('#reset-demo').addEventListener('click', () => {
  dialog.returnValue = '';
  dialog.showModal();
});
dialog.addEventListener('close', () => {
  if (dialog.returnValue !== 'reset') return;
  state = createState();
  dateInput.value = state.startDate;
  try {
    localStorage.removeItem(storageKey);
    storageMode = 'ready';
  } catch {
    storageMode = 'reset-failed';
  }
  forms.forEach((_, index) => showSetErrors(index));
  showDateError();
  render();
  // Remove only this demo's key; never clear unrelated application data.
  if (storageMode === 'reset-failed') showStorage();
  else persist();
  tabs[0].focus({ preventScroll: true });
});

render();
showStorage(restored ? '저장한 체험을 불러왔습니다.' : '체험은 이 브라우저에만 저장됩니다.');
