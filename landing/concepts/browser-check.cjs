#!/usr/bin/env node
'use strict';
// Independent browser regression harness. This file does not start a web server.
// Run from any directory after serving the Strength app root on port 4175.
// PLAYWRIGHT_MODULE may point to an installed playwright module directory.
// STRENGTH_CHECK_BASE_URL and STRENGTH_CHECK_OUTPUT override the defaults below.
// No screenshots, app files, deployment, or Git operations are performed.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const BASE = new URL(process.env.STRENGTH_CHECK_BASE_URL || 'http://127.0.0.1:4175/landing/concepts/');
const OUT = path.resolve(process.env.STRENGTH_CHECK_OUTPUT || path.join(__dirname, '../../research/2026-09-08/concepts/browser-check.json'));
const START = Date.now();
const DEADLINE = START + 210000;
const SESSION_KEY = 'strength-concept-session-v1';
const OTHER_KEY = 'strength-existing-landing-preservation-probe';
const OTHER_VALUE = 'unrelated-record-must-survive';
const routes = [
  ['load', '01-load.html'], ['atlas', '02-atlas.html'], ['schedule', '03-schedule.html'],
  ['session', '04-session.html'], ['insights', '05-insights.html'],
];
const report = {
  startedAt: new Date(START).toISOString(), baseUrl: BASE.href,
  environment: { browser: 'Chromium headless', desktop: [1440, 1000], narrow: [390, 320], webgl: 'SwiftShader', screenshots: false },
  scope: 'Public local landing demo; isolated browser storage. No app backend, native simulator, real workout records, or payment operations.',
  checks: [], diagnostics: [], fontResponses: [], limitations: [
    'data-scene-state validates published scene state, not a visual pixel comparison; root performs visual screenshot QA separately.',
    'WebGL failure and storage failure are injected test conditions. Hidden-host pause is synthetic; operating-system background suspension is not tested.',
    'Resource checks inspect reported geometry/texture counts across changes, not total GPU or process memory.',
    'Narrow viewport checks detect horizontal layout overflow; they do not substitute for visual or screen-reader review.',
  ],
};
let browser;
let fatal = null;
const contexts = [];
const normalPageErrors = [];

function writeReport() {
  report.finishedAt = new Date().toISOString();
  report.durationMs = Date.now() - START;
  report.summary = {
    total: report.checks.length,
    passed: report.checks.filter(c => c.status === 'passed').length,
    failed: report.checks.filter(c => c.status === 'failed').length,
    fatal,
  };
  report.ok = !fatal && report.summary.failed === 0;
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify(report, null, 2) + '\n');
}

const watchdog = setTimeout(async () => {
  fatal = 'Hard timeout: browser checks exceeded 225 seconds.';
  writeReport();
  console.error(JSON.stringify({ output: OUT, ...report.summary }));
  try { await browser?.close(); } finally { process.exit(2); }
}, 225000);

async function check(id, name, fn) {
  if (Date.now() > DEADLINE) throw new Error('210-second execution budget exhausted; remaining checks were not run.');
  const started = Date.now();
  try {
    const evidence = await fn();
    report.checks.push({ id, name, status: 'passed', durationMs: Date.now() - started, evidence: evidence ?? null });
    console.log(`PASS ${id} ${name}`);
  } catch (error) {
    report.checks.push({ id, name, status: 'failed', durationMs: Date.now() - started, error: String(error.stack || error) });
    console.error(`FAIL ${id} ${name}: ${error.message}`);
  }
}

async function context(options = {}, initScript) {
  const c = await browser.newContext({ viewport: { width: 1440, height: 1000 }, ...options });
  c.setDefaultTimeout(4000);
  c.setDefaultNavigationTimeout(12000);
  if (initScript) await c.addInitScript(initScript);
  contexts.push(c);
  return c;
}

async function pageIn(c, label, expectedErrors = false) {
  const p = await c.newPage();
  p.on('pageerror', e => {
    report.diagnostics.push({ kind: 'pageerror', label, expectedErrors, message: e.message });
    if (!expectedErrors) normalPageErrors.push({ label, message: e.message });
  });
  p.on('console', m => {
    if (m.type() === 'error') report.diagnostics.push({ kind: 'console-error', label, expectedErrors, message: m.text() });
  });
  p.on('requestfailed', r => report.diagnostics.push({ kind: 'requestfailed', label, expectedErrors, url: r.url(), error: r.failure()?.errorText }));
  p.on('response', r => {
    if (/\/assets\/fonts\/.*\.ttf(?:\?|$)/.test(r.url())) report.fontResponses.push({ label, url: r.url(), status: r.status() });
  });
  return p;
}

async function goto(p, route, sceneExpected = true) {
  const response = await p.goto(new URL(route, BASE).href, { waitUntil: 'domcontentloaded' });
  assert.equal(response?.status(), 200, 'HTML route must return HTTP 200');
  await p.locator('#main h1').waitFor();
  if (sceneExpected) await ready(p);
  return response;
}

async function ready(p) {
  // The initial KR font load can change the hero's height; wait before asking
  // Playwright to consider its scroll target stable, especially under SwiftShader.
  await p.evaluate(() => document.fonts.ready);
  await p.locator('.scene').scrollIntoViewIfNeeded({ timeout: 12000 });
  await p.waitForFunction(() => document.querySelector('.scene')?.dataset.sceneReady === 'true', null, { timeout: 7000 });
  const s = await scene(p);
  assert(s.ready && s.calls > 0 && s.geometries > 0, 'WebGL must have rendered geometry');
  return s;
}

async function scene(p) {
  return p.locator('.scene').evaluate(el => JSON.parse(el.dataset.sceneState || '{}'));
}

async function sceneMatches(p, expected) {
  await p.waitForFunction(values => {
    const s = JSON.parse(document.querySelector('.scene')?.dataset.sceneState || '{}');
    return Object.entries(values).every(([k, v]) => JSON.stringify(s[k]) === JSON.stringify(v));
  }, expected);
  return scene(p);
}

async function textIs(p, selector, expected) {
  assert.equal((await p.locator(selector).textContent()).trim(), expected);
}

const form = (p, i) => p.locator(`.record-set[data-set="${i}"]`);
const field = (p, i, name) => form(p, i).locator(`[name="${name}"]`);
async function fillSet(p, i, values) {
  for (const [name, value] of Object.entries(values)) await field(p, i, name).fill(value);
}
async function submitSet(p, i) { await form(p, i).locator('[data-save]').click(); }
async function stored(p) { return p.evaluate(key => JSON.parse(localStorage.getItem(key)), SESSION_KEY); }
async function snapshotSet(p, i) {
  return form(p, i).evaluate(el => ({
    completed: el.dataset.completed,
    badge: el.querySelector('[data-badge]').textContent,
    values: Object.fromEntries([...el.querySelectorAll('input')].map(n => [n.name, n.value])),
    readOnly: [...el.querySelectorAll('input')].every(n => n.readOnly),
    error: el.querySelector('[data-error]').textContent,
  }));
}

async function main() {
  browser = await chromium.launch({ headless: true, args: ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  report.environment.browserVersion = browser.version();
  const mainContext = await context();
  const page = await pageIn(mainContext, 'normal');
  const programsResponse = await mainContext.request.get(new URL('../../assets/programs.json', BASE).href);
  assert.equal(programsResponse.status(), 200, 'Program catalog must be available for independent expected-data comparisons');
  const { programs } = await programsResponse.json();
  assert.equal(programs.length, 5);
  const threeDayProgram = programs.find(p => p.sessions.filter(s => s.week === 1).length === 3);
  assert(threeDayProgram, 'At least one actual 3-day program is required for weekday validation');
  report.programs = programs.map(p => ({ id: p.id, title: p.title, weeks: p.weeks, sessions: p.sessions.length }));

  for (const [mode, route] of routes) {
    await check(`route-${mode}`, `${mode}: HTTP, document mode, visible main, rendered WebGL`, async () => {
      await goto(page, route);
      assert.equal(await page.locator('body').getAttribute('data-mode'), mode);
      assert(await page.locator('#main h1').isVisible());
      const s = await scene(page); assert.equal(s.mode, mode);
      assert.equal(await page.locator('.scene canvas').count(), 1);
      return { url: page.url(), scene: s };
    });
  }

  await check('fonts', 'Local KR/Mono fonts load and are assigned to Korean body and numeric output', async () => {
    const fonts = await page.evaluate(async () => {
      await Promise.all([document.fonts.load('400 16px "IBM Plex Sans KR"', '운동'), document.fonts.load('400 16px "IBM Plex Mono"', '0123')]);
      await document.fonts.ready;
      return {
        loaded: [...document.fonts].filter(f => f.status === 'loaded').map(f => ({ family: f.family, weight: f.weight })),
        kr: document.fonts.check('400 16px "IBM Plex Sans KR"', '운동'),
        mono: document.fonts.check('400 16px "IBM Plex Mono"', '0123'),
        body: getComputedStyle(document.body).fontFamily,
        number: getComputedStyle(document.querySelector('output')).fontFamily,
      };
    });
    assert(fonts.kr && fonts.mono);
    assert(fonts.loaded.some(f => f.family.includes('IBM Plex Sans KR')) && fonts.loaded.some(f => f.family.includes('IBM Plex Mono')));
    assert.match(fonts.body, /IBM Plex Sans KR/); assert.match(fonts.number, /IBM Plex Mono/);
    assert(report.fontResponses.some(r => /SansKR/.test(r.url) && r.status === 200));
    assert(report.fontResponses.some(r => /Mono/.test(r.url) && r.status === 200));
    return fonts;
  });

  await goto(page, '01-load.html');
  await check('load-step', 'Plus/minus update total, range, and 3D weight together', async () => {
    await page.locator('#load-plus').click(); await textIs(page, '#load-value', '62.5');
    assert.equal(await page.locator('#load-range').inputValue(), '62.5'); await sceneMatches(page, { weight: 62.5 });
    await page.locator('#load-minus').click(); await textIs(page, '#load-value', '60');
    return sceneMatches(page, { weight: 60 });
  });
  await check('load-keyboard', 'Range keyboard input changes accessible value and scene', async () => {
    await page.locator('#load-range').focus(); await page.keyboard.press('ArrowRight');
    await textIs(page, '#load-value', '62.5'); assert.equal(await page.locator('#load-range').getAttribute('aria-valuetext'), '62.5 kg');
    return sceneMatches(page, { weight: 62.5 });
  });
  await check('load-bounds-reset', '20/120 bounds disable only the unavailable step; reset restores 60', async () => {
    await page.locator('#load-range').press('Home'); await textIs(page, '#load-value', '20'); assert(await page.locator('#load-minus').isDisabled());
    await page.locator('#load-range').press('End'); await textIs(page, '#load-value', '120'); assert(await page.locator('#load-plus').isDisabled());
    await page.locator('#load-reset').click(); await textIs(page, '#load-value', '60');
    assert(await page.locator('#load-minus').isEnabled() && await page.locator('#load-plus').isEnabled());
    return sceneMatches(page, { weight: 60 });
  });
  await check('load-pointer', 'Pointer drag changes angle while pointer is held; reset restores zero', async () => {
    await ready(page); const before = await scene(page); const box = await page.locator('.scene canvas').boundingBox(); assert(box);
    await page.mouse.move(box.x + box.width * .5, box.y + box.height * .5); await page.mouse.down();
    let during;
    try { await page.mouse.move(box.x + box.width * .5 + 90, box.y + box.height * .5 + 4, { steps: 6 }); during = await scene(page); }
    finally { await page.mouse.up(); }
    assert(Math.abs(during.rotation - before.rotation) > .3, 'Angle must change before pointerup');
    await page.locator('[data-reset-view]').click(); const reset = await sceneMatches(page, { rotation: 0 });
    return { before: before.rotation, during: during.rotation, reset: reset.rotation };
  });

  await goto(page, '02-atlas.html');
  for (let i = 0; i < 5; i++) {
    await check(`atlas-${i + 1}`, `Program ${i + 1}: selected button, full title, exercises, and scene match catalog`, async () => {
      await page.locator(`[data-program="${i}"]`).click();
      assert.equal(await page.locator('[data-program][aria-pressed="true"]').count(), 1);
      assert.equal(await page.locator(`[data-program="${i}"]`).getAttribute('aria-pressed'), 'true');
      await textIs(page, '#program-title', programs[i].title);
      assert.deepEqual(await page.locator('#program-exercises li').allTextContents(), programs[i].sessions.find(s => s.week === 1).exercises.map(e => e.name));
      await textIs(page, '#program-count', `0${i + 1} / 05`);
      return sceneMatches(page, { selected: i });
    });
  }
  await check('atlas-pagination', 'Program next/previous wrap with title and 3D selection', async () => {
    await page.locator('#program-next').click(); await textIs(page, '#program-title', programs[0].title); await sceneMatches(page, { selected: 0 });
    await page.locator('#program-prev').click(); await textIs(page, '#program-title', programs[4].title);
    return sceneMatches(page, { selected: 4 });
  });
  await check('atlas-schedule-link', 'Selected program ID survives the real schedule navigation link', async () => {
    const i = programs.indexOf(threeDayProgram); await page.locator(`[data-program="${i}"]`).click();
    const link = new URL(await page.locator('#program-schedule').getAttribute('href'), page.url());
    assert.equal(link.searchParams.get('program'), threeDayProgram.id);
    await page.locator('#program-schedule').click(); await ready(page);
    assert.equal(new URL(page.url()).searchParams.get('program'), threeDayProgram.id);
    await textIs(page, '.calendar-heading .eyebrow', threeDayProgram.title);
    return { url: page.url(), title: threeDayProgram.title };
  });

  await check('schedule-default', 'Three-day program starts with three matching DOM and 3D weekdays', async () => {
    const days = await page.locator('[data-day][aria-pressed="true"]').evaluateAll(nodes => nodes.map(n => Number(n.dataset.day)));
    assert.deepEqual(days, [0, 2, 4]); assert(await page.locator('#schedule-show').isEnabled());
    return sceneMatches(page, { days });
  });
  await check('schedule-invalid-count', 'Removing one weekday exposes 2/3 error and blocks schedule dialog', async () => {
    await page.locator('[data-day="2"]').click();
    assert.equal(await page.locator('[data-day][aria-pressed="true"]').count(), 2);
    assert.match(await page.locator('#schedule-result').textContent(), /2일 선택됨.*3일/);
    assert(await page.locator('#schedule-show').isDisabled());
    assert.equal(await page.locator('#schedule-dialog').evaluate(el => el.open), false);
    return sceneMatches(page, { days: [0, 4] });
  });
  await check('schedule-restore', 'Restoring the weekday clears error and enables schedule preview', async () => {
    await page.locator('[data-day="2"]').click(); assert(await page.locator('#schedule-show').isEnabled());
    assert.equal(await page.locator('#schedule-result .error').count(), 0);
    return sceneMatches(page, { days: [0, 2, 4] });
  });
  await check('schedule-four-weeks', 'Changed start date yields every trainer session in order on selected weekdays', async () => {
    await page.locator('#schedule-start').fill('2026-09-09'); await page.locator('#schedule-show').click();
    assert.equal(await page.locator('#schedule-dialog').evaluate(el => el.open), true);
    const rows = await page.locator('#schedule-table-body tr').evaluateAll(nodes => nodes.map(n => [...n.cells].map(c => c.textContent)));
    const expectedSessions = [...threeDayProgram.sessions].sort((a, b) => a.week - b.week || a.dayOrder - b.dayOrder);
    assert.equal(rows.length, expectedSessions.length); assert.deepEqual([...new Set(rows.map(r => Number(r[0])))], [1, 2, 3, 4]);
    assert.deepEqual(rows.map(r => r[2]), expectedSessions.map(s => s.title));
    const selectedDays = await page.locator('[data-day][aria-pressed="true"]').evaluateAll(ns => ns.map(n => Number(n.dataset.day)));
    assert.equal(rows[0][1], '2026-09-09');
    rows.forEach((row, i) => {
      const day = new Date(`${row[1]}T12:00:00Z`); assert(Number.isFinite(day.getTime()));
      assert(selectedDays.includes((day.getUTCDay() + 6) % 7)); assert(row[1] >= '2026-09-09');
      if (i) assert(row[1] > rows[i - 1][1]);
    });
    const expectedDates = []; const cursor = new Date('2026-09-09T12:00:00Z');
    for (let i = 0; i < rows.length; i++) { while (!selectedDays.includes((cursor.getUTCDay() + 6) % 7)) cursor.setUTCDate(cursor.getUTCDate() + 1); expectedDates.push(cursor.toISOString().slice(0, 10)); cursor.setUTCDate(cursor.getUTCDate() + 1); }
    assert.deepEqual(rows.map(r => r[1]), expectedDates);
    await page.locator('[data-close-schedule]').click(); assert.equal(await page.locator('#schedule-dialog').evaluate(el => el.open), false);
    return { selectedDays, rows };
  });

  await goto(page, '04-session.html');
  await page.evaluate(([k, v]) => localStorage.setItem(k, v), [OTHER_KEY, OTHER_VALUE]);
  await check('session-empty-invalid', 'Empty completion is rejected without creating performed sets', async () => {
    await submitSet(page, 0); const s = await snapshotSet(page, 0); assert.equal(s.completed, 'false'); assert(s.error.length > 0);
    assert.equal(await field(page, 0, 'weight').getAttribute('aria-invalid'), 'true'); await textIs(page, '#session-count', '00');
    return sceneMatches(page, { completed: 0, completedSets: [false, false] });
  });
  await check('session-negative-invalid', 'Negative weight and zero repetitions remain editable drafts', async () => {
    await fillSet(page, 0, { weight: '-1', reps: '0', rir: '0' }); await submitSet(page, 0);
    assert.equal(await field(page, 0, 'weight').getAttribute('aria-invalid'), 'true');
    assert.equal(await field(page, 0, 'reps').getAttribute('aria-invalid'), 'true');
    const s = await snapshotSet(page, 0); assert.equal(s.completed, 'false'); assert(!s.readOnly); return s;
  });
  await check('session-rir-invalid', 'RIR above ten blocks completion with an RIR field error', async () => {
    await fillSet(page, 0, { weight: '0', reps: '5', rir: '11' }); await submitSet(page, 0);
    assert.equal(await field(page, 0, 'rir').getAttribute('aria-invalid'), 'true'); assert.equal((await snapshotSet(page, 0)).completed, 'false');
    return snapshotSet(page, 0);
  });
  await check('session-zero-valid', 'Zero kg and RIR zero complete, persist exact strings, and focus next set', async () => {
    await field(page, 0, 'rir').fill('0'); await submitSet(page, 0);
    const s = await snapshotSet(page, 0); assert(s.readOnly); assert.equal(s.completed, 'true');
    assert.deepEqual(s.values, { weight: '0', reps: '5', rir: '0' }); await textIs(page, '#session-count', '01');
    assert.equal(await page.evaluate(() => document.activeElement?.getAttribute('aria-label')), '2세트 중량 (kg)');
    assert.equal((await stored(page)).sets[0].status, 'completed');
    return sceneMatches(page, { completed: 1, completedSets: [true, false] });
  });
  await check('session-second-complete', 'Two valid completions produce count two and matching 3D state', async () => {
    await fillSet(page, 1, { weight: '60', reps: '5', rir: '' }); await submitSet(page, 1);
    await textIs(page, '#session-count', '02'); assert.equal((await stored(page)).sets.filter(s => s.status === 'completed').length, 2);
    assert.equal(await page.locator('.record-set[data-completed="true"]').count(), 2);
    return sceneMatches(page, { completed: 2, completedSets: [true, true] });
  });
  await check('session-edit', 'Editing a completed set reopens only that set and reduces completion count', async () => {
    await submitSet(page, 0); const s = await snapshotSet(page, 0); assert(!s.readOnly); assert.equal(s.completed, 'false');
    assert.equal((await snapshotSet(page, 1)).completed, 'true'); await textIs(page, '#session-count', '01');
    assert.equal((await stored(page)).sets[0].status, 'pending'); return sceneMatches(page, { completed: 1, completedSets: [false, true] });
  });
  const rawDraft = { weight: ' 060.50 ', reps: '005', rir: '0.0' };
  await check('session-reload-draft', 'Reload preserves raw unfinished input alongside completed second set', async () => {
    await fillSet(page, 0, rawDraft); assert.deepEqual((await snapshotSet(page, 0)).values, rawDraft);
    await page.reload({ waitUntil: 'domcontentloaded' }); await ready(page);
    const draft = await snapshotSet(page, 0); assert.deepEqual(draft.values, rawDraft); assert.equal(draft.completed, 'false');
    const actual = await snapshotSet(page, 1); assert.equal(actual.completed, 'true'); assert.deepEqual(actual.values, { weight: '60', reps: '5', rir: '' });
    assert.match(await page.locator('#record-status').textContent(), /불러왔어요/); await textIs(page, '#session-count', '01');
    await sceneMatches(page, { completed: 1, completedSets: [false, true] });
    return { draft, actual, stored: await stored(page) };
  });
  await check('session-reset-cancel', 'Cancel reset leaves draft, completed set, and local storage unchanged', async () => {
    const before = await stored(page); await page.locator('#record-reset').click(); assert.equal(await page.locator('#record-reset-dialog').evaluate(el => el.open), true);
    await page.locator('#record-reset-cancel').click(); assert.equal(await page.locator('#record-reset-dialog').evaluate(el => el.open), false);
    assert.deepEqual(await stored(page), before); assert.deepEqual((await snapshotSet(page, 0)).values, rawDraft); return before;
  });
  await check('session-reset-confirm', 'Confirmed reset clears only this demo key, preserving unrelated storage', async () => {
    await page.locator('#record-reset').click(); await page.locator('#record-reset-confirm').click();
    await textIs(page, '#session-count', '00'); await sceneMatches(page, { completed: 0, completedSets: [false, false] });
    for (let i = 0; i < 2; i++) assert.deepEqual((await snapshotSet(page, i)).values, { weight: '', reps: '', rir: '' });
    assert((await stored(page)).sets.every(s => s.status === 'pending' && s.weight === '' && s.reps === '' && s.rir === ''));
    assert.equal(await page.evaluate(key => localStorage.getItem(key), OTHER_KEY), OTHER_VALUE);
    return { demo: await stored(page), unrelatedKeyPreserved: true };
  });
  await check('session-second-only', 'Completing only set two marks the second 3D record, not the first', async () => {
    await fillSet(page, 1, { weight: '60', reps: '5', rir: '0' }); await submitSet(page, 1);
    assert.equal((await snapshotSet(page, 0)).completed, 'false');
    assert.equal((await snapshotSet(page, 1)).completed, 'true'); await textIs(page, '#session-count', '01');
    assert.deepEqual((await stored(page)).sets.map(s => s.status), ['pending', 'completed']);
    return sceneMatches(page, { completed: 1, completedSets: [false, true] });
  });

  await goto(page, '05-insights.html');
  const pastValue = () => page.locator('.insights-console .change-row').first().locator('.mono').textContent();
  await check('insights-review-cancel', 'Review alone and cancel preserve future target 60 and original past value', async () => {
    await page.locator('#adjust-review').click(); assert.equal(await page.locator('#adjust-dialog').evaluate(el => el.open), true);
    await textIs(page, '#target-value', '60'); await sceneMatches(page, { applied: false });
    await page.locator('#adjust-cancel').click(); assert.equal(await page.locator('#adjust-dialog').evaluate(el => el.open), false);
    assert.equal(await pastValue(), '60 kg'); assert(await page.locator('#adjust-undo').isDisabled());
  });
  await check('insights-apply', 'Apply changes both future targets to 57.5; past remains 60', async () => {
    await page.locator('#adjust-review').click(); await page.locator('#adjust-apply').click();
    await textIs(page, '#target-value', '57.5'); assert.deepEqual(await page.locator('[data-future-value]').allTextContents(), ['57.5 kg', '57.5 kg']);
    assert.equal(await pastValue(), '60 kg'); assert(await page.locator('#adjust-review').isDisabled() && await page.locator('#adjust-undo').isEnabled());
    assert.match(await page.locator('#adjust-history').textContent(), /4세트/); return sceneMatches(page, { applied: true });
  });
  await check('insights-undo', 'Undo restores 60, preserves past, and prevents repeating the same suggestion', async () => {
    await page.locator('#adjust-undo').click(); await textIs(page, '#target-value', '60');
    assert.deepEqual(await page.locator('[data-future-value]').allTextContents(), ['60 kg', '60 kg']); assert.equal(await pastValue(), '60 kg');
    assert(await page.locator('#adjust-review').isDisabled() && await page.locator('#adjust-undo').isDisabled());
    assert.match(await page.locator('#adjust-history').textContent(), /되돌렸어요/); return sceneMatches(page, { applied: false });
  });
  await check('insights-reset', 'Start over resets demo controls and allows a fresh review', async () => {
    await page.locator('#adjust-reset').click(); assert(await page.locator('#adjust-review').isEnabled());
    assert(await page.locator('#adjust-undo').isDisabled()); await textIs(page, '#target-value', '60'); await textIs(page, '#adjust-history', '');
  });

  for (const width of [390, 320]) {
    await page.setViewportSize({ width, height: 844 });
    for (const [mode, route] of routes) {
      await check(`overflow-${width}-${mode}`, `${mode}: no horizontal document overflow at ${width}px`, async () => {
        await goto(page, route); await page.evaluate(() => document.fonts.ready);
        const measurement = await page.evaluate(() => ({
          viewport: innerWidth, document: document.documentElement.scrollWidth, body: document.body.scrollWidth,
          offenders: [...document.querySelectorAll('#main *')].map(el => ({ tag: el.tagName, selector: el.id || el.className, rect: el.getBoundingClientRect() }))
            .filter(({ rect }) => rect.width > 0 && (rect.right > innerWidth + 1 || rect.left < -1))
            .map(({ tag, selector, rect }) => ({ tag, selector: String(selector), left: rect.left, right: rect.right })).slice(0, 12),
        }));
        assert(measurement.document <= width + 1 && measurement.body <= width + 1, JSON.stringify(measurement));
        return measurement;
      });
    }
    await check(`dialog-width-${width}`, `Schedule and adjustment dialogs keep content and controls inside ${width}px viewport`, async () => {
      const measureDialog = async selector => {
        const size = await page.locator(selector).evaluate(el => {
          const r = el.getBoundingClientRect();
          return { open: el.open, left: r.left, right: r.right, viewport: innerWidth, client: el.clientWidth, scroll: el.scrollWidth };
        });
        assert(size.open && size.left >= -1 && size.right <= size.viewport + 1, JSON.stringify(size));
        assert(size.scroll <= size.client + 1, `Dialog content overflows: ${JSON.stringify(size)}`);
        return size;
      };
      await page.locator('#adjust-review').click(); const adjustment = await measureDialog('#adjust-dialog');
      assert(await page.locator('#adjust-apply').isVisible()); await page.locator('#adjust-cancel').click();
      await goto(page, `03-schedule.html?program=${encodeURIComponent(threeDayProgram.id)}`);
      await page.locator('#schedule-show').click(); const schedule = await measureDialog('#schedule-dialog');
      assert.equal(await page.locator('#schedule-table-body tr').count(), threeDayProgram.sessions.length);
      await page.locator('[data-close-schedule]').click();
      return { adjustment, schedule };
    });
  }
  await page.setViewportSize({ width: 1440, height: 1000 });

  const reducedContext = await context({ reducedMotion: 'reduce' });
  const reduced = await pageIn(reducedContext, 'reduced-motion');
  await check('reduced-selection', 'Reduced motion keeps program selection and scene synchronization usable', async () => {
    await goto(reduced, '02-atlas.html'); assert(await reduced.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches));
    await reduced.locator('[data-program="3"]').click(); await textIs(reduced, '#program-title', programs[3].title);
    const s = await sceneMatches(reduced, { selected: 3 });
    assert.equal(await reduced.locator('[data-program="3"]').getAttribute('aria-pressed'), 'true'); return s;
  });
  await reducedContext.close();

  const failedGLContext = await context({}, () => {
    const original = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function(type, ...args) {
      if (['webgl', 'webgl2', 'experimental-webgl'].includes(type)) return null;
      return original.call(this, type, ...args);
    };
  });
  const failedGL = await pageIn(failedGLContext, 'injected-webgl-failure', true);
  await check('webgl-fallback-load', 'WebGL creation failure shows fallback and keeps real load DOM controls working', async () => {
    await goto(failedGL, '01-load.html', false); await failedGL.locator('.scene.failed').waitFor();
    assert.match(await failedGL.locator('.scene-status').textContent(), /체험을 계속/);
    assert(await failedGL.locator('[data-reset-view]').isDisabled());
    await failedGL.locator('#load-plus').click(); await textIs(failedGL, '#load-value', '62.5');
    await failedGL.locator('#load-reset').click(); await textIs(failedGL, '#load-value', '60');
    return { fallback: true, controlResult: await failedGL.locator('#load-value').textContent() };
  });
  await check('webgl-fallback-atlas', 'Catalog selection and schedule link work without WebGL', async () => {
    await goto(failedGL, '02-atlas.html', false); await failedGL.locator('.scene.failed').waitFor();
    await failedGL.locator('[data-program="4"]').click(); await textIs(failedGL, '#program-title', programs[4].title);
    assert.equal(await failedGL.locator('[data-program="4"]').getAttribute('aria-pressed'), 'true');
    assert.equal(new URL(await failedGL.locator('#program-schedule').getAttribute('href'), failedGL.url()).searchParams.get('program'), programs[4].id);
  });
  await failedGLContext.close();

  const networkContext = await context();
  await networkContext.route('**/assets/programs.json', route => route.abort('failed'));
  const network = await pageIn(networkContext, 'injected-catalog-abort', true);
  await check('catalog-abort', 'Catalog fetch failure exposes retry rather than fabricated programs', async () => {
    await goto(network, '02-atlas.html', false); await network.locator('#catalog-retry').waitFor();
    assert.equal(await network.locator('[data-program]').count(), 0);
    assert.match(await network.locator('#catalog-content [role="alert"]').textContent(), /불러오지 못했어요/);
  });
  await check('catalog-retry', 'Removing the network fault and clicking retry restores five usable programs', async () => {
    await networkContext.unroute('**/assets/programs.json'); await network.locator('#catalog-retry').click(); await ready(network);
    assert.equal(await network.locator('[data-program]').count(), 5);
    await network.locator('[data-program="2"]').click(); await textIs(network, '#program-title', programs[2].title);
    return sceneMatches(network, { selected: 2 });
  });
  await networkContext.close();

  const writeFailContext = await context({}, () => {
    const original = Storage.prototype.setItem;
    Storage.prototype.setItem = function(key, value) {
      if (key === 'strength-concept-session-v1') throw new DOMException('Injected quota error', 'QuotaExceededError');
      return original.call(this, key, value);
    };
  });
  const writeFail = await pageIn(writeFailContext, 'injected-storage-write-failure');
  await check('storage-write-failure', 'Write failure retains typed values and accurately reports unsaved state', async () => {
    await goto(writeFail, '04-session.html'); await fillSet(writeFail, 0, { weight: '63.5', reps: '5', rir: '0' });
    assert.deepEqual((await snapshotSet(writeFail, 0)).values, { weight: '63.5', reps: '5', rir: '0' });
    assert.match(await writeFail.locator('#record-status').textContent(), /저장하지 못했어요/);
    assert(await writeFail.locator('#record-status').evaluate(el => el.classList.contains('failed')));
    assert.equal(await writeFail.evaluate(k => localStorage.getItem(k), SESSION_KEY), null);
  });
  await check('storage-memory-continue', 'After write failure, in-memory edit and completion remain usable without claiming save', async () => {
    await field(writeFail, 0, 'weight').fill('0'); await submitSet(writeFail, 0);
    await textIs(writeFail, '#session-count', '01'); await sceneMatches(writeFail, { completed: 1, completedSets: [true, false] });
    assert.match(await writeFail.locator('#record-status').textContent(), /저장하지 못했어요/);
    await submitSet(writeFail, 0); await field(writeFail, 0, 'weight').fill('64.25');
    assert.equal(await field(writeFail, 0, 'weight').inputValue(), '64.25'); assert.equal((await snapshotSet(writeFail, 0)).completed, 'false');
    return { inMemory: await snapshotSet(writeFail, 0), persisted: await writeFail.evaluate(k => localStorage.getItem(k), SESSION_KEY) };
  });
  await writeFailContext.close();

  const corruptContext = await context();
  const corrupt = await pageIn(corruptContext, 'corrupt-storage');
  await check('corrupt-storage-preserved', 'Unreadable saved demo remains untouched while new input stays in memory', async () => {
    await goto(corrupt, '04-session.html'); const raw = '{not valid JSON';
    await corrupt.evaluate(([key, value]) => localStorage.setItem(key, value), [SESSION_KEY, raw]);
    await corrupt.reload({ waitUntil: 'domcontentloaded' }); await ready(corrupt);
    assert.match(await corrupt.locator('#record-status').textContent(), /덮어쓰지 않습니다/);
    await fillSet(corrupt, 0, { weight: '61', reps: '4', rir: '' });
    assert.equal(await corrupt.evaluate(k => localStorage.getItem(k), SESSION_KEY), raw);
    assert.equal(await field(corrupt, 0, 'weight').inputValue(), '61');
  });
  await corruptContext.close();

  await goto(page, '01-load.html');
  await check('webgl-context-restore', 'Real context loss/recovery restores scene and rotation controls while preserving DOM changes', async () => {
    const supported = await page.locator('.scene canvas').evaluate(canvas => {
      const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
      window.__strengthContextLossTest = gl?.getExtension('WEBGL_lose_context');
      if (!window.__strengthContextLossTest) return false;
      window.__strengthContextLossTest.loseContext(); return true;
    });
    assert(supported, 'WEBGL_lose_context must be supported in the test renderer; no silent skip');
    await page.locator('.scene.failed').waitFor(); assert(await page.locator('[data-reset-view]').isDisabled());
    await page.locator('#load-plus').click(); await textIs(page, '#load-value', '62.5');
    await page.evaluate(() => window.__strengthContextLossTest.restoreContext()); await ready(page);
    assert.equal(await page.locator('.scene.failed').count(), 0); assert(await page.locator('[data-reset-view]').isEnabled());
    await sceneMatches(page, { weight: 62.5 });
    const before = await scene(page); await page.locator('[data-rotate="0.3"]').click(); const after = await scene(page);
    assert(Math.abs(after.rotation - before.rotation - .3) < .0001);
    await page.locator('[data-reset-view]').click(); await page.locator('#load-reset').click();
    await page.evaluate(() => { delete window.__strengthContextLossTest; });
    return sceneMatches(page, { weight: 60, rotation: 0 });
  });
  await check('scene-pause-resume', 'Hidden scene pauses while DOM controls still change data; restoring visibility resumes', async () => {
    try {
      await page.locator('.scene').evaluate(el => { el.style.visibility = 'hidden'; });
      await sceneMatches(page, { paused: true }); await page.locator('#load-plus').click(); await textIs(page, '#load-value', '62.5');
      await sceneMatches(page, { weight: 62.5, paused: true });
    } finally { await page.locator('.scene').evaluate(el => { el.style.visibility = ''; }); }
    await ready(page); return sceneMatches(page, { weight: 62.5, paused: false });
  });
  await check('scene-resize-resources', 'Repeated weight changes and resize keep one canvas and bounded reported resources', async () => {
    await page.locator('#load-reset').click(); await ready(page); const baseline = await scene(page);
    for (let i = 0; i < 4; i++) { await page.locator('#load-plus').click(); await page.locator('#load-reset').click(); }
    await page.setViewportSize({ width: 390, height: 844 }); await ready(page);
    await page.setViewportSize({ width: 1440, height: 1000 }); await ready(page);
    await page.waitForFunction(maximum => {
      const s = JSON.parse(document.querySelector('.scene')?.dataset.sceneState || '{}');
      return s.weight === 60 && s.ready && s.geometries <= maximum;
    }, baseline.geometries + 2);
    const end = await sceneMatches(page, { weight: 60 });
    assert.equal(await page.locator('.scene canvas').count(), 1);
    assert(end.geometries <= baseline.geometries + 2, `Geometry count grew: ${baseline.geometries} -> ${end.geometries}`);
    assert(end.textures <= baseline.textures + 1);
    await page.locator('#load-minus').click(); await textIs(page, '#load-value', '57.5'); await sceneMatches(page, { weight: 57.5 });
    return { baseline, end };
  });
  await check('no-uncaught-normal-errors', 'Normal, reduced-motion, and handled storage paths have no uncaught page exceptions', async () => {
    assert.deepEqual(normalPageErrors, []); return { pageErrors: normalPageErrors };
  });
}

(async () => {
  try { await main(); }
  catch (error) { fatal = String(error.stack || error); console.error(fatal); }
  finally {
    clearTimeout(watchdog);
    try { await browser?.close(); } catch (error) { report.diagnostics.push({ kind: 'browser-close', message: error.message }); }
    writeReport();
    console.log(JSON.stringify({ output: OUT, ok: report.ok, ...report.summary, durationMs: report.durationMs }));
    process.exitCode = report.ok ? 0 : 1;
  }
})();
