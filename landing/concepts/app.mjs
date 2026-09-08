import { createState, parseStoredState, serializeState, validateSet, plannedDate } from '../demo-state.mjs';

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const mode = document.body.dataset.mode;
const names = ['중량을 직접 조절하는 무대', '프로그램을 고르는 공간', '요일로 만드는 훈련 일정', '한 세트씩 완성하는 기록', '변경 전후가 보이는 조절'];
const routes = ['01-load.html', '02-atlas.html', '03-schedule.html', '04-session.html', '05-insights.html'];
const motion = matchMedia('(prefers-reduced-motion: reduce)');
let scene, sceneTicket = 0, scenePatch = {}, selectScene = () => {};

function header() {
  return `<a class="skip-link" href="#main">본문 바로가기</a><header class="topbar"><div class="wrap"><a class="brand" href="./" aria-label="Strength 시안 목록"><span class="brand-mark" aria-hidden="true"><i></i><i></i><i></i></span>STRENGTH</a><nav class="toplinks" aria-label="페이지 탐색"><a class="secondary-link" href="02-atlas.html">프로그램</a><a class="secondary-link" href="04-session.html">운동 기록</a><a href="./">시안 목록 <span aria-hidden="true">↗</span></a></nav></div></header>`;
}
function footer() {
  return `<footer class="wrap footer"><p>개발 중인 Strength의 웹 체험입니다.<br>앱 기록과 연결되지 않습니다.</p><div><a href="../">기존 랜딩 보기</a><span aria-hidden="true"> · </span><a href="./">5개 시안 비교</a></div></footer>`;
}
function features() {
  return `<section class="feature-strip" aria-label="Strength 기능"><article><span class="mono">01</span><h3>프로그램 선택</h3><p class="note">등록된 프로그램 5개에서 운동 구성을 확인하세요.</p></article><article><span class="mono">02</span><h3>일정과 중량 맞춤</h3><p class="note">운동·세트 구성은 유지하고 시작일과 요일을 맞춥니다.</p></article><article><span class="mono">03</span><h3>세트별 기록</h3><p class="note">실제 중량·반복·RIR을 기록하고 기기에 저장합니다.</p></article></section>`;
}
function stage(label) {
  return `<div class="scene" role="img" aria-label="${label}"><div class="scene-status" role="status"><span></span>입체 화면을 준비하고 있어요.</div></div>`;
}
function sceneControls() {
  return `<div class="scene-controls"><span>드래그해서 돌려보세요.</span><div class="actions"><button class="btn icon-btn" data-rotate="-0.3" aria-label="장면 왼쪽으로 회전">↶</button><button class="btn icon-btn" data-rotate="0.3" aria-label="장면 오른쪽으로 회전">↷</button><button class="btn reset-view" data-reset-view>시점 초기화</button></div></div>`;
}
function setScene(patch) { scenePatch = {...scenePatch, ...patch}; scene?.update(scenePatch); }
async function mountScene() {
  const host = $('.scene'); if (!host) return;
  const ticket = ++sceneTicket;
  scene?.dispose(); scene = undefined;
  host.classList.remove('failed');
  $('.scene-status', host).innerHTML = '<span></span>입체 화면을 준비하고 있어요.';
  const fail = () => {
    if (ticket !== sceneTicket) return;
    host.classList.add('failed');
    $('.scene-status', host).textContent = '입체 화면을 열 수 없어요. 아래 조작으로 체험을 계속할 수 있습니다.';
    $$('[data-rotate], [data-reset-view]').forEach(button => { button.disabled = true; });
  };
  host.onSceneError = fail;
  try {
    const { createScene } = await import('./scenes.mjs');
    if (ticket !== sceneTicket) return;
    scene = await createScene(host, {mode, reducedMotion:motion.matches, onSelect:index => selectScene(index)});
    if (ticket !== sceneTicket) { scene.dispose(); return; }
    scene.update(scenePatch);
    $$('[data-rotate], [data-reset-view]').forEach(button => { button.disabled = false; });
  } catch { fail(); }
}
document.addEventListener('scene-error', event => event.target.onSceneError?.());
document.addEventListener('scene-ready', event => {
  event.target.classList.remove('failed');
  $$('[data-rotate], [data-reset-view]').forEach(button => { button.disabled = false; });
});
document.addEventListener('click', event => {
  const rotate = event.target.closest('[data-rotate]'); if (rotate) scene?.rotate(Number(rotate.dataset.rotate));
  if (event.target.closest('[data-reset-view]')) scene?.resetView();
});
motion.addEventListener('change', () => { if ($('.scene')) mountScene(); });
window.addEventListener('pagehide', () => { ++sceneTicket; scene?.dispose(); scene = undefined; });
window.addEventListener('pageshow', event => { if (event.persisted) mountScene(); });

function showPage(content) { $('#app').innerHTML = `${header()}<main id="main">${content}</main>${footer()}`; }

function loadPage() {
  showPage(`<div class="wrap"><section class="load-hero"><div class="load-heading"><p class="eyebrow">나의 중량으로</p><h1>한 세트씩.<br><span class="accent">기록하세요.</span></h1><p class="intro">운동·세트 구성은 그대로.<br>나의 일정과 중량을 맞추고.</p></div><div class="load-readout"><output id="load-value" for="load-range">60</output><span class="unit">kg</span><p class="note">봉 포함 · 중량 체험</p></div><div class="load-stage">${stage('중량 조작에 반응하는 바벨')}${sceneControls()}</div></section><section class="load-controls" aria-label="중량 체험"><div><label for="load-range">중량을 바꿔 원판의 변화를 확인하세요.</label><div class="load-control-row"><button class="btn icon-btn" id="load-minus" aria-label="중량 2.5kg 줄이기">−</button><input id="load-range" type="range" min="20" max="120" step="2.5" value="60" aria-label="체험 중량 kg"><button class="btn icon-btn" id="load-plus" aria-label="중량 2.5kg 늘리기">+</button></div><div class="range-labels"><span>20 kg</span><span>120 kg</span></div></div><div class="actions"><button class="text-button" id="load-reset">60 kg로 초기화</button><a class="btn primary" href="04-session.html">기록 체험하기 <span aria-hidden="true">↗</span></a></div></section>${features()}</div>`);
  const input = $('#load-range');
  const update = value => { const weight = Math.max(20, Math.min(120, value)); input.value = weight; $('#load-value').textContent = weight; input.setAttribute('aria-valuetext', `${weight} kg`); $('#load-minus').disabled = weight === 20; $('#load-plus').disabled = weight === 120; setScene({weight}); };
  input.addEventListener('input', () => update(Number(input.value)));
  $('#load-minus').onclick = () => update(Number(input.value) - 2.5);
  $('#load-plus').onclick = () => update(Number(input.value) + 2.5);
  $('#load-reset').onclick = () => update(60);
  update(60); mountScene();
}

async function getPrograms() {
  const response = await fetch('../../assets/programs.json');
  if (!response.ok) throw new Error('프로그램을 불러오지 못했어요.');
  const data = await response.json();
  if (!Array.isArray(data.programs) || data.programs.length !== 5 || data.programs.some(p => !p.title || !Array.isArray(p.sessions) || !p.sessions.length)) throw new Error('프로그램 구성을 확인할 수 없어요.');
  return data.programs;
}
function programError(host, retry) { host.innerHTML = '<div class="info-state" role="alert"><h2>프로그램을 불러오지 못했어요.</h2><p>연결을 확인하고 다시 시도해 주세요.</p><button class="btn" id="catalog-retry">다시 불러오기</button></div>'; $('#catalog-retry').onclick = retry; }
function weeklySessions(program) { return program.sessions.filter(s => s.week === 1); }

async function atlasPage() {
  showPage(`<div class="wrap"><header class="section-heading"><div><p class="eyebrow">프로그램 선택</p><h1>운동 구성부터.<br><span class="accent">직접 확인하세요.</span></h1></div><p class="note">같은 구성, 나의 일정.<br>기간과 훈련 횟수를 비교하세요.</p></header><div id="catalog-content"><div class="info-state" role="status">프로그램을 불러오고 있어요.</div></div>${features()}</div>`);
  const host = $('#catalog-content');
  try {
    const programs = await getPrograms();
    host.innerHTML = `<section class="catalog-layout"><div class="catalog-list" role="group" aria-label="프로그램 선택">${programs.map((p,i) => `<button class="program-choice" data-program="${i}" aria-pressed="${i===0}"><span class="program-index">0${i+1}</span><span><strong>${escape(p.title.split(' · ')[0])}</strong><small>${p.weeks}주 · 주 ${weeklySessions(p).length}일</small></span><span class="choice-arrow" aria-hidden="true">↗</span></button>`).join('')}</div><div class="catalog-stage">${stage('프로그램 5개를 선택하는 공간 전시')}${sceneControls()}<div class="catalog-detail"><div aria-live="polite"><h2 id="program-title"></h2><div class="meta-line" id="program-meta"></div><a class="btn primary" id="program-schedule" href="03-schedule.html">요일 맞춰보기 <span aria-hidden="true">↗</span></a><p class="description" id="program-description"></p><ul class="exercise-list" id="program-exercises"></ul></div><div class="catalog-pagination"><button class="btn icon-btn" id="program-prev" aria-label="이전 프로그램">←</button><span class="mono" id="program-count"></span><button class="btn icon-btn" id="program-next" aria-label="다음 프로그램">→</button></div></div></div></section>`;
    let selected = 0;
    const choose = index => {
      selected = (index + programs.length) % programs.length;
      const p = programs[selected], sessions = weeklySessions(p);
      $$('[data-program]').forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset.program)===selected)));
      $('#program-title').textContent = p.title;
      $('#program-meta').innerHTML = `<span><b class="mono">${p.weeks}</b>주</span><span>주 <b class="mono">${sessions.length}</b>일</span><span>첫 운동 <b class="mono">${sessions[0].exercises.length}</b>종목</span>`;
      $('#program-description').textContent = p.description.split('\n')[0];
      $('#program-exercises').innerHTML = sessions[0].exercises.map(e => `<li>${escape(e.name)}</li>`).join('');
      $('#program-count').textContent = `0${selected+1} / 05`;
      $('#program-schedule').href = `03-schedule.html?program=${encodeURIComponent(p.id)}`;
      setScene({selected});
    };
    $$('[data-program]').forEach(button => { button.onclick=()=>choose(Number(button.dataset.program)); });
    $('#program-prev').onclick=()=>choose(selected-1); $('#program-next').onclick=()=>choose(selected+1);
    selectScene=choose; choose(0); mountScene();
  } catch { programError(host, atlasPage); }
}

function scheduleDates(startDate, days, sessions) {
  if (!days.length) return [];
  // Use the same sequential selected-weekday assignment as createActivePlan.
  const first = plannedDate(startDate, days[0]+1);
  const day = new Date(`${startDate}T12:00:00Z`);
  if (!first || !Number.isFinite(day.getTime())) throw new Error('날짜를 확인해 주세요.');
  const result = [];
  for (const session of [...sessions].sort((a,b)=>a.week-b.week||a.dayOrder-b.dayOrder)) {
    while (!days.includes((day.getUTCDay()+6)%7)) day.setUTCDate(day.getUTCDate()+1);
    if (day.getUTCFullYear()>9999) throw new Error('날짜 범위를 확인해 주세요.');
    result.push({date:day.toISOString().slice(0,10), title:session.title, week:session.week});
    day.setUTCDate(day.getUTCDate()+1);
  }
  return result;
}

async function schedulePage() {
  showPage(`<div class="wrap"><div id="calendar-content"><div class="info-state" role="status">프로그램을 불러오고 있어요.</div></div>${features()}</div>`);
  const host=$('#calendar-content');
  try {
    const programs=await getPrograms();
    const program=programs.find(p=>p.id===new URLSearchParams(location.search).get('program'))||programs[1];
    const count=weeklySessions(program).length;
    let days=count===2?[0,3]:count===3?[0,2,4]:[0,1,3,4];
    const dayNames=['월','화','수','목','금','토','일'];
    host.innerHTML=`<header class="calendar-heading"><p class="eyebrow">${escape(program.title)}</p><h1>훈련 요일을 고르면.<br><span class="accent">4주의 일정이 보입니다.</span></h1><p class="note">운동·세트 구성은 유지합니다.</p></header><div class="calendar-stage"><div class="calendar-corner"><p class="mono">04 <small>WEEKS</small></p><span>선택한 요일의 주간 패턴</span></div>${stage('선택한 요일이 올라오는 4주 달력')}</div>${sceneControls()}<section class="calendar-console"><div><p class="field-label" id="weekday-label">운동 요일 · ${count}일 선택</p><div class="weekdays" role="group" aria-labelledby="weekday-label">${dayNames.map((name,i)=>`<button class="day" data-day="${i}" aria-pressed="${days.includes(i)}">${name}</button>`).join('')}</div><div id="schedule-result" class="schedule-result" aria-live="polite"></div><button class="text-button" id="days-reset">기본 요일로 초기화</button></div><div><label class="field-label" for="schedule-start">시작일</label><input type="date" id="schedule-start" value="${createState().startDate}" max="9998-12-31"><button class="btn primary" id="schedule-show">4주 일정 확인 <span aria-hidden="true">↗</span></button></div></section><dialog id="schedule-dialog"><h2>예정된 운동 일정</h2><p class="note">웹 미리보기이며 앱에 저장하지 않습니다.</p><table class="schedule-table"><thead><tr><th>주차</th><th>예정일</th><th>운동</th></tr></thead><tbody id="schedule-table-body"></tbody></table><div class="actions"><button class="btn" data-close-schedule>닫기</button></div></dialog>`;
    let scheduled=[];
    const update=()=>{
      $$('[data-day]').forEach(button=>button.setAttribute('aria-pressed',String(days.includes(Number(button.dataset.day)))));
      setScene({days}); scheduled=[];
      const result=$('#schedule-result');
      if(days.length!==count){result.innerHTML=`<span class="error">${days.length}일 선택됨 · 이 프로그램은 ${count}일을 선택해 주세요.</span>`;$('#schedule-show').disabled=true;return;}
      try{scheduled=scheduleDates($('#schedule-start').value,days,program.sessions); result.innerHTML=scheduled.slice(0,count).map(item=>`<span>첫 주 <b class="mono">${item.date.slice(5).replace('-','.')}</b></span>`).join(''); $('#schedule-show').disabled=false;}
      catch{result.innerHTML='<span class="error">시작일을 확인해 주세요.</span>';$('#schedule-show').disabled=true;}
    };
    const toggle=index=>{ days=days.includes(index)?days.filter(d=>d!==index):[...days,index].sort((a,b)=>a-b); update(); };
    $$('[data-day]').forEach(button=>{button.onclick=()=>toggle(Number(button.dataset.day));});
    $('#schedule-start').oninput=update;
    $('#days-reset').onclick=()=>{days=count===2?[0,3]:count===3?[0,2,4]:[0,1,3,4];$('#schedule-start').value=createState().startDate;update();};
    $('#schedule-show').onclick=()=>{$('#schedule-table-body').innerHTML=scheduled.map(s=>`<tr><td class="mono">${s.week}</td><td class="mono">${s.date}</td><td>${escape(s.title)}</td></tr>`).join('');$('#schedule-dialog').showModal();};
    $('[data-close-schedule]').onclick=()=>$('#schedule-dialog').close();
    selectScene=toggle;update();mountScene();
  }catch{programError(host,schedulePage);}
}

function sessionPage(){
  const key='strength-concept-session-v1'; let state=createState(),corrupt=false,saveMessage='이 체험은 브라우저에만 저장됩니다.';
  try{const raw=localStorage.getItem(key);if(raw!==null){state=parseStoredState(raw);saveMessage='이 브라우저에 저장된 체험을 불러왔어요.';}}catch{corrupt=true;saveMessage='저장된 체험을 읽지 못했어요. 초기화 전에는 기존 값을 덮어쓰지 않습니다.';}
  showPage(`<div class="wrap"><section class="session-hero"><div class="session-copy"><p class="eyebrow">세트별 운동 기록</p><h1>한 세트,<br><span class="accent">직접 기록해 보세요.</span></h1><p class="note">실제 중량·반복·RIR을 입력하고<br>완료되는 세트를 확인하세요.</p><div class="session-visual"><div class="session-counter"><output id="session-count">0<span></span></output><small>완료 / 전체 2세트</small></div>${stage('두 세트의 기록 완료 상태')}</div>${sceneControls()}</div><div class="record-workspace"><header class="record-heading"><h2>스쿼트</h2><span class="note">체험용 예시 · 2세트</span></header><div id="record-sets">${state.sets.map((s,i)=>`<form class="record-set" data-set="${i}" novalidate><header><span class="set-number">SET 0${i+1}</span><span class="set-badge" data-badge>입력 전</span></header><div class="record-fields">${[['weight','중량 (kg)'],['reps','반복'],['rir','RIR (선택)']].map(([name,label])=>`<label>${label}<input name="${name}" inputmode="${name==='reps'?'numeric':'decimal'}" autocomplete="off" maxlength="256" value="${escape(s[name])}" aria-label="${i+1}세트 ${label}"></label>`).join('')}</div><p class="error" data-error role="alert"></p><div class="actions"><p class="note">목표 예시 · 5회 / RIR 2</p><button class="btn primary" type="submit" data-save>세트 완료 <span aria-hidden="true">✓</span></button></div></form>`).join('')}</div><p class="record-status" id="record-status" role="status"></p><div class="actions"><button class="text-button" id="record-reset">체험 초기화</button><a class="text-button" href="05-insights.html">기록 조절 체험 →</a></div></div></section>${features()}</div><dialog id="record-reset-dialog"><h2>이 체험을 초기화할까요?</h2><p>이 시안에서 입력한 두 세트만 지워집니다.</p><div class="actions"><button class="btn" id="record-reset-cancel">취소</button><button class="btn primary" id="record-reset-confirm">초기화</button></div></dialog>`);
  const status=(text,failed=false)=>{saveMessage=text;$('#record-status').textContent=text;$('#record-status').classList.toggle('failed',failed);};
  const persist=()=>{if(corrupt){status(saveMessage,true);return;}try{localStorage.setItem(key,serializeState(state));status('이 브라우저에 저장했어요.');}catch{status('저장하지 못했어요. 현재 화면에서 체험을 계속할 수 있습니다.',true);}};
  const render=()=>{
    const completed=state.sets.filter(s=>s.status==='completed').length;
    $('#session-count').textContent=`0${completed}`;setScene({completed,completedSets:state.sets.map(s=>s.status==='completed')});
    $$('.record-set').forEach((form,i)=>{const done=state.sets[i].status==='completed';form.dataset.completed=done;$('[data-badge]',form).textContent=done?'수행 완료':Object.values(state.sets[i]).some(v=>v&&v!=='pending')?'작성 중':'입력 전';$('[data-save]',form).innerHTML=done?'수정하기':'세트 완료 <span aria-hidden="true">✓</span>';$$('input',form).forEach(input=>{input.readOnly=done;});});
  };
  $$('.record-set').forEach((form,i)=>{
    form.addEventListener('input',event=>{if(!event.target.name)return;state.sets[i][event.target.name]=event.target.value;state.sets[i].status='pending';$('[data-error]',form).textContent='';event.target.removeAttribute('aria-invalid');persist();render();});
    form.onsubmit=event=>{event.preventDefault();if(state.sets[i].status==='completed'){state.sets[i].status='pending';persist();render();$('input',form).focus();return;}
      const result=validateSet(state.sets[i]);$$('input',form).forEach(input=>input.setAttribute('aria-invalid',String(!!result.errors[input.name])));
      if(!result.valid){$('[data-error]',form).textContent=Object.values(result.errors)[0];$('input[aria-invalid=true]',form).focus();return;}
      state.sets[i].status='completed';$('[data-error]',form).textContent='';persist();render();
      const next=$(`.record-set[data-set="${i+1}"] input`);if(next&&!next.readOnly)next.focus();
    };
  });
  $('#record-reset').onclick=()=>$('#record-reset-dialog').showModal();$('#record-reset-cancel').onclick=()=>$('#record-reset-dialog').close();
  $('#record-reset-confirm').onclick=()=>{try{localStorage.removeItem(key);corrupt=false;state=createState();$$('.record-set').forEach(form=>{$$('input',form).forEach(input=>{input.value='';input.removeAttribute('aria-invalid');});$('[data-error]',form).textContent='';});persist();render();$('#record-reset-dialog').close();}catch{status('초기화하지 못했어요. 입력을 유지했습니다.',true);$('#record-reset-dialog').close();}};
  status(saveMessage,corrupt);render();mountScene();
}

function insightsPage(){
  let applied=false,undone=false;
  showPage(`<div class="wrap"><header class="insights-heading"><div><p class="eyebrow">기록 추세 · 중량 조절</p><h1>기록을 보고.<br><span class="accent">변경을 확인하세요.</span></h1></div><p class="intro">최근 기록을 기준으로 제안을 확인하고,<br>미래 목표에 직접 적용합니다.</p></header><section class="insights-stage"><div class="chart-legend"><span><i></i>과거·오늘 기록</span><span><i id="future-key"></i>미래 목표</span></div>${stage('과거 기록을 보존하고 미래 두 회차의 목표를 비교하는 그래프')}<div class="chart-readout"><span class="note">다음 운동 목표</span><output id="target-value">60</output><span class="mono"> kg</span></div></section>${sceneControls()}<section class="insights-console"><div><h2>변경할 중량을 먼저 확인하세요.</h2><p class="note">합성 기록의 예시입니다. 최근 3회 목표 RIR 3, 실제 RIR 1.<br>오늘과 과거는 유지하고 미래 2회의 목표만 조절합니다.</p><div class="actions"><button class="btn primary" id="adjust-review">변경 내용 확인 <span aria-hidden="true">↗</span></button><button class="btn" id="adjust-undo" disabled>되돌리기</button><button class="text-button" id="adjust-reset">처음부터</button></div><p class="history-note" id="adjust-history" role="status"></p></div><div aria-live="polite"><div class="change-row"><span>과거·오늘 실제 기록</span><span class="mono">60 kg</span></div><div class="change-row"><span>다음 운동 · 2세트</span><span class="mono" data-future-value>60 kg</span></div><div class="change-row"><span>그다음 운동 · 2세트</span><span class="mono" data-future-value>60 kg</span></div><p class="note">화면 체험이며 개인별 제안·앱 기록으로 저장하지 않습니다.</p></div></section>${features()}</div><dialog id="adjust-dialog"><h2>미래 목표를 변경할까요?</h2><p class="note">스쿼트 · 합성 검증 데이터</p><div class="change-row"><span>다음 운동 · 2세트</span><span class="mono">60 → 57.5 kg</span></div><div class="change-row"><span>그다음 운동 · 2세트</span><span class="mono">60 → 57.5 kg</span></div><p class="note">원래 계획과 실제 기록은 유지합니다.</p><div class="actions"><button class="btn" id="adjust-cancel">취소</button><button class="btn primary" id="adjust-apply">적용하기</button></div></dialog>`);
  const update=()=>{$('#target-value').textContent=applied?'57.5':'60';$$('[data-future-value]').forEach(el=>{el.textContent=applied?'57.5 kg':'60 kg';});$('#adjust-review').disabled=applied||undone;$('#adjust-undo').disabled=!applied;$('#adjust-history').textContent=applied?'미래 4세트에 적용했어요.':undone?'원래 목표로 되돌렸어요. 같은 근거로 다시 제안하지 않습니다.':'';$('#future-key').style.background=applied?'var(--good)':'var(--accent)';setScene({applied});};
  $('#adjust-review').onclick=()=>$('#adjust-dialog').showModal();$('#adjust-cancel').onclick=()=>$('#adjust-dialog').close();
  $('#adjust-apply').onclick=()=>{applied=true;update();$('#adjust-dialog').close();};
  $('#adjust-undo').onclick=()=>{applied=false;undone=true;update();};
  $('#adjust-reset').onclick=()=>{applied=false;undone=false;update();};
  update();mountScene();
}

function gallery(){
  const descriptions=['원판을 바꾸며 중량 입력을 체험합니다.','실제 프로그램 5개를 골라 구성을 비교합니다.','요일 선택이 입체 달력과 날짜에 반영됩니다.','입력한 두 세트가 완료되며 화면이 달라집니다.','미래 목표의 변경과 되돌리기를 확인합니다.'];
  showPage(`<div class="wrap"><header class="gallery-intro"><div><p class="eyebrow">인터랙티브 랜딩 · 디자인 시안</p><h1>다섯 가지 방식으로.<br><span class="accent">직접 체험하세요.</span></h1></div><p>중량, 프로그램, 일정, 기록, 조절.<br>각 시안에서 다른 대상을 조작하고<br>결과를 확인할 수 있습니다.</p></header><section class="concept-grid" aria-label="5개 디자인 시안">${routes.map((route,i)=>`<a class="concept-link" href="${route}"><div class="concept-thumbnail"><img src="previews/${route.replace('.html','.png')}" alt="${names[i]} 시안 미리보기" loading="${i===0?'eager':'lazy'}" width="1440" height="1000"></div><div class="concept-caption"><span class="mono">0${i+1}</span><div><h2>${names[i]}</h2><p>${descriptions[i]}</p></div><span class="arrow" aria-hidden="true">↗</span></div></a>`).join('')}</section></div>`);
}

({load:loadPage,atlas:atlasPage,schedule:schedulePage,session:sessionPage,insights:insightsPage,gallery})[mode]?.();
