// Capture actual rendered concepts and their changed states; no external assets or native simulator.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const base = process.env.STRENGTH_CHECK_BASE_URL || 'http://127.0.0.1:4175/landing/concepts/';
const output = path.resolve(__dirname, '../../research/2026-09-08/concepts');
const previews = path.join(__dirname, 'previews');
const routes = ['01-load','02-atlas','03-schedule','04-session','05-insights'];
(async () => {
  await fs.mkdir(output,{recursive:true}); await fs.mkdir(previews,{recursive:true});
  const browser = await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const results=[];
  try {
    for(const viewport of [{width:1440,height:1000},{width:390,height:844},{width:320,height:844}]) {
      const context=await browser.newContext({viewport});
      for(const route of routes) {
        const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
        await page.goto(new URL(`${route}.html`,base).href);
        await page.evaluate(()=>document.fonts.ready);
        await page.waitForSelector('.scene[data-scene-ready=true]');await page.waitForTimeout(400);
        const suffix=viewport.width===1440?'desktop':viewport.width===390?'mobile':'narrow';
        const state=()=>page.locator('.scene').evaluate(el=>JSON.parse(el.dataset.sceneState));
        const before=await state();
        await page.screenshot({path:path.join(output,`${route}-${suffix}-final.png`),fullPage:viewport.width!==1440});
        if(viewport.width===1440) await page.screenshot({path:path.join(previews,`${route}.png`)});
        if(viewport.width!==320) {
          if(route==='01-load') { await page.locator('#load-range').fill('90'); }
          if(route==='02-atlas') { await page.locator('[data-program="3"]').click(); }
          if(route==='03-schedule') { for(const i of [0,2,4,1,3,5]) await page.locator(`[data-day="${i}"]`).click(); }
          if(route==='04-session') {
            for(const i of [1,0]) {
              const form=page.locator(`[data-set="${i}"]`);
              for(const [name,value] of Object.entries({weight:'60',reps:'5',rir:'1'})) await form.locator(`[name="${name}"]`).fill(value);
              await form.locator('[data-save]').click();
            }
          }
          if(route==='05-insights') {
            await page.locator('#adjust-review').click();
            await page.screenshot({path:path.join(output,`${route}-${suffix}-review.png`),fullPage:viewport.width!==1440});
            await page.locator('#adjust-apply').click();
          }
          await page.evaluate(()=>scrollTo(0,0));await page.waitForTimeout(500);
          await page.screenshot({path:path.join(output,`${route}-${suffix}-changed.png`),fullPage:viewport.width!==1440});
        }
        const after=await state();
        const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
        results.push({route,viewport,before,after,overflow,errors});await page.close();
      }
      const gallery=await context.newPage();await gallery.goto(base);await gallery.evaluate(()=>document.fonts.ready);
      await gallery.locator('img').evaluateAll(images=>Promise.all(images.map(image=>image.decode())));
      await gallery.screenshot({path:path.join(output,`gallery-${viewport.width}.png`),fullPage:true});
      results.push({route:'gallery',viewport,overflow:await gallery.evaluate(()=>document.documentElement.scrollWidth>innerWidth),links:await gallery.locator('.concept-link').count()});
      await context.close();
    }
    await fs.writeFile(path.join(output,'render-evidence.json'),JSON.stringify(results,null,2)+'\n');
    if(results.some(r=>r.overflow||r.errors?.length)) throw new Error('Inspect render-evidence.json for overflow/runtime errors.');
    console.log('Rendered 5 concepts at 1440/390/320px, changed states at 1440/390px, and the gallery.');
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
