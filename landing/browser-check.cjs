// Run with Playwright supplied by the local tooling environment; no app dependency.
const { chromium } = require(process.env.STRENGTH_PLAYWRIGHT || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const url = process.env.STRENGTH_LANDING_URL || 'http://127.0.0.1:4175/landing/';
const output = path.resolve(__dirname, '../research/2026-09-08/landing');
const key = 'strength-landing-demo-v1';
const checks = [];
function check(name, actual, expected = true) { assert.deepEqual(actual, expected, name); checks.push(name); }
(async () => {
  await fs.mkdir(output, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('response', response => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
    await page.goto(url);
    await page.evaluate(() => document.fonts.ready);
    check('첫 화면 프로그램 탭', await page.locator('#panel-0').isVisible());
    check('한글·숫자 폰트 로드', await page.evaluate(() => document.fonts.check('400 16px "IBM Plex Sans KR"') && document.fonts.check('400 16px "IBM Plex Mono"')));
    await page.screenshot({ path: path.join(output, 'desktop-final.png'), fullPage: false });
    await page.locator('[data-next="1"]').click();
    await page.locator('#start-date').fill('2026-09-08');
    await page.locator('[name=weekday][value="5"]').check();
    check('금요일 선택 → 9월 11일', await page.locator('#scheduled-date').textContent(), '2026.09.11');
    await page.locator('#start-date').fill('');
    await page.locator('[data-next="2"]').click();
    check('빈 날짜 진행 차단', await page.locator('#panel-1').isVisible() && await page.locator('#date-error').isVisible());
    await page.locator('#start-date').fill('2026-09-08');
    await page.locator('[data-next="2"]').click();
    const first = page.locator('[data-set="0"]');
    const second = page.locator('[data-set="1"]');
    await first.locator('[type=submit]').click();
    check('빈 세트 완료 차단', await first.locator('[name=weight]').getAttribute('aria-invalid'), 'true');
    await first.locator('[name=weight]').fill('0');
    await first.locator('[name=reps]').fill('1.5');
    await first.locator('[name=rir]').fill('11');
    await first.locator('[type=submit]').click();
    check('소수 반복·범위 밖 RIR 오류', await first.locator('[name=reps]').getAttribute('aria-invalid') === 'true' && await first.locator('[name=rir]').getAttribute('aria-invalid') === 'true');
    await first.locator('[name=reps]').fill('5');
    await first.locator('[name=rir]').fill('0');
    await first.locator('[type=submit]').click();
    check('0kg·RIR 0 정상 완료', await page.locator('#completed-count').textContent(), '1');
    check('다음 미기록 세트 포커스', await second.locator('[name=weight]').evaluate(el => document.activeElement === el));
    await second.locator('[name=weight]').fill('42.');
    await page.reload();
    check('완료·초안·단계 복원', await page.locator('#panel-2').isVisible() && await first.locator('[name=weight]').inputValue() === '0' && await first.locator('[name=rir]').inputValue() === '0' && await second.locator('[name=weight]').inputValue() === '42.');
    await page.locator('#tab-1').click();
    check('완료 후 일정 잠금·복원', await page.locator('#start-date').isDisabled() && await page.locator('#scheduled-date').textContent() === '2026.09.11');
    await page.locator('#tab-2').click();
    await second.locator('[data-skip]').click();
    check('제외는 실제 수행에 미포함', await page.locator('#completed-count').textContent() === '1' && (await page.locator('#workout-summary').textContent()).includes('제외 1세트'));
    await second.locator('[type=submit]').click();
    check('제외 수정시 초안 원문 보존', await second.locator('[name=weight]').inputValue(), '42.');
    await page.locator('#reset-demo').click();
    await page.getByRole('button', { name: '취소', exact: true }).click();
    check('초기화 취소시 보존', await second.locator('[name=weight]').inputValue(), '42.');
    await page.locator('#reset-demo').click();
    await page.keyboard.press('Escape');
    check('Esc 취소시 보존', await second.locator('[name=weight]').inputValue(), '42.');
    await page.evaluate(() => localStorage.setItem('unrelated-test', 'keep'));
    await page.locator('#reset-demo').click();
    await page.getByRole('button', { name: '다시 시작', exact: true }).click();
    await page.locator('#panel-0').waitFor({ state: 'visible' });
    check('확인 후 체험만 초기화', await page.locator('#panel-0').isVisible() && await page.evaluate(() => localStorage.getItem('unrelated-test')) === 'keep');
    await page.locator('#tab-0').focus();
    await page.keyboard.press('ArrowRight');
    check('키보드 탭 이동', await page.locator('#tab-1').getAttribute('aria-selected'), 'true');
    await page.keyboard.press('End');
    check('키보드 End로 기록 이동', await page.locator('#tab-2').getAttribute('aria-selected'), 'true');
    await first.locator('[name=weight]').fill('60');
    await first.locator('[name=reps]').fill('5');
    await first.locator('[name=rir]').fill('2');
    await first.locator('[type=submit]').click();
    await second.locator('[name=weight]').fill('62.5');
    await page.locator('#experience').screenshot({ path: path.join(output, 'record-desktop.png') });
    const faq = page.locator('.faq-list details').first();
    await faq.locator('summary').click();
    check('FAQ 내용 열림', await faq.getAttribute('open') !== null);
    await page.locator('[data-record]').click();
    check('하단 CTA 실제 기록 화면 연결', await page.locator('#panel-2').isVisible());
    for (const width of [390, 320]) {
      await page.setViewportSize({ width, height: 844 });
      for (const step of [0, 1, 2]) {
        await page.locator(`#tab-${step}`).click();
        check(`${width}px 단계 ${step + 1} 가로 넘침 없음`, await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
        await page.waitForTimeout(300); // Let the intentional tab/panel transition settle before visual evidence.
        if (width === 390) {
          // Taller capture canvas avoids Chromium clipping the footer of a long element screenshot.
          // Overflow assertions above still run at the actual 390 × 844 viewport.
          await page.setViewportSize({ width, height: 1100 });
          await page.locator('#experience').screenshot({ path: path.join(output, `mobile-step-${step + 1}.png`) });
          await page.setViewportSize({ width, height: 844 });
        }
      }
    }
    await page.setViewportSize({ width: 390, height: 844 });
    await page.locator('#tab-0').click();
    await page.evaluate(() => window.scrollTo({ top: 0, behavior: 'instant' }));
    await page.screenshot({ path: path.join(output, 'mobile-final.png'), fullPage: true });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    check('동작 줄이기 적용', await page.locator('#panel-0').evaluate(el => getComputedStyle(el).animationName), 'none');
    check('페이지 오류·실패 리소스 없음', errors, []);
    await context.close();

    const corruptContext = await browser.newContext();
    const corrupt = await corruptContext.newPage();
    await corrupt.goto(url);
    await corrupt.evaluate(k => localStorage.setItem(k, '{broken'), key);
    await corrupt.reload();
    await corrupt.locator('#tab-2').click();
    await corrupt.locator('[data-set="0"] [name=weight]').fill('30');
    check('손상 저장 원본 덮어쓰기 방지', await corrupt.evaluate(k => localStorage.getItem(k), key), '{broken');
    check('손상 저장 안내', (await corrupt.locator('#save-message').textContent()).includes('덮어쓰지 않습니다'));
    await corruptContext.close();
    const blockedContext = await browser.newContext();
    await blockedContext.addInitScript(() => { Object.defineProperty(window, 'localStorage', { get() { throw new DOMException('blocked', 'SecurityError'); } }); });
    const blocked = await blockedContext.newPage();
    await blocked.goto(url);
    await blocked.locator('#tab-2').click();
    await blocked.locator('[data-set="0"] [name=weight]').fill('10');
    await blocked.locator('[data-set="0"] [name=reps]').fill('5');
    await blocked.locator('[data-set="0"] [type=submit]').click();
    check('저장 차단시 화면 체험 가능', await blocked.locator('#completed-count').textContent(), '1');
    check('저장 차단 안내', (await blocked.locator('#save-message').textContent()).includes('이 화면에서만 유지'));
    await blocked.locator('#reset-demo').click();
    await blocked.getByRole('button', { name: '다시 시작', exact: true }).click();
    await blocked.locator('#panel-0').waitFor({ state: 'visible' });
    check('초기화 실패를 구분해 안내', (await blocked.locator('#save-message').textContent()).includes('다시 열면 이전 기록'));
    check('저장 차단시 메모리 체험 초기화', await blocked.locator('#panel-0').isVisible());
    await blockedContext.close();
    const quotaContext = await browser.newContext();
    const quota = await quotaContext.newPage();
    await quota.goto(url);
    await quota.locator('#tab-2').click();
    await quota.locator('[data-set="0"] [name=weight]').fill('99');
    await quota.evaluate(() => { Storage.prototype.setItem = function () { throw new DOMException('quota', 'QuotaExceededError'); }; });
    await quota.locator('#reset-demo').click();
    await quota.getByRole('button', { name: '다시 시작', exact: true }).click();
    await quota.locator('#panel-0').waitFor({ state: 'visible' });
    check('쓰기 실패해도 초기화한 이전 데이터 제거', await quota.evaluate(k => localStorage.getItem(k), key), null);
    await quota.reload();
    await quota.locator('#tab-2').click();
    check('초기화 후 이전 기록 부활 방지', await quota.locator('[data-set="0"] [name=weight]').inputValue(), '');
    await quotaContext.close();
    await fs.writeFile(path.join(output, 'browser-check.json'), JSON.stringify({ browser: await browser.version(), url, checkedAt: new Date().toISOString(), passed: checks.length, checks }, null, 2) + '\n');
    console.log(`${checks.length} browser checks passed`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
