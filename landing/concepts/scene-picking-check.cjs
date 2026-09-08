// Real pointer picking against coordinates observed in the final 1440px renders.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const base = process.env.STRENGTH_CHECK_BASE_URL || 'http://127.0.0.1:4175/landing/concepts/';
(async () => {
  const browser = await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const results=[];
  try {
    const page=await browser.newPage({viewport:{width:1440,height:1000}});
    for(const [route,x,y] of [['02-atlas',1120,520],['03-schedule',493,540]]) {
      await page.goto(new URL(`${route}.html`,base).href);
      await page.evaluate(()=>document.fonts.ready);
      await page.waitForSelector('.scene[data-scene-ready=true]');
      const read=()=>page.locator('.scene').evaluate(el=>JSON.parse(el.dataset.sceneState));
      const before=await read();
      await page.mouse.click(x,y);
      await page.waitForFunction(prior=>document.querySelector('.scene').dataset.sceneState!==prior,JSON.stringify(before));
      const after=await read();
      if(route==='02-atlas') {
        assert.equal(after.selected,4);
        assert.equal(await page.locator('[data-program="4"]').getAttribute('aria-pressed'),'true');
        assert.match(await page.locator('#program-title').textContent(),/덤벨로 전신/);
      } else {
        assert.deepEqual(after.days,[2,4]);
        assert.equal(await page.locator('[data-day="0"]').getAttribute('aria-pressed'),'false');
        assert.equal(await page.locator('#schedule-show').isDisabled(),true);
      }
      results.push({route,pointer:{x,y},before,after,status:'passed'});
    }
    const output=path.resolve(__dirname,'../../research/2026-09-08/concepts/scene-picking.json');
    await fs.writeFile(output,JSON.stringify({browser:browser.version(),viewport:[1440,1000],checks:results},null,2)+'\n');
    console.log('PASS: 2 actual 3D object picks update their DOM controls and content.');
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
