const assert = require('node:assert/strict'), path = require('node:path');

module.exports = async function layoutCases({page, touches, center, pair, out}) {
  const open = async () => { await page.click('#settings-open'); await page.click('#layout-edit'); };
  const vars = () => page.evaluate(() => structuredClone(layouts));
  const gesture = async (from, to, end = true) => {
    await touches('touchStart', [from]); await touches('touchMove', [to]);
    if (end) await touches('touchEnd', []);
  };
  const inputCount = () => page.evaluate(() => testSocket.messages.filter(s => /^(b,|down,|move,|up,|cancel,)/.test(s)).length);
  await page.click('#settings-open'); await page.uncheck('#setting-remember');
  await page.selectOption('#setting-layout','auto'); await page.click('#settings-close');
  await open();
  assert(await page.locator('#layout-editor').isVisible(), 'Arrange opens the editor');
  assert(await page.locator('[data-button=a]').isDisabled(), 'editing disables game controls');
  const beforeInput = await inputCount(), beforeVibration = await page.evaluate(()=>testVibrations.length);
  const a = await center('[data-module=a]');
  await gesture(a, {x:a.x,y:a.y+80});
  let saved = await vars();
  assert(saved.landscape.vars['--a-y'] > .6, 'a real touch drags a disabled button through the controller');
  assert(await page.locator('[data-module=a]').evaluate(el=>el.classList.contains('selected')), 'drag selects the module');
  await gesture(await center('[data-module=a]'), await center('[data-module=b]'), false);
  assert(await page.locator('[data-module=a]').evaluate(el=>el.classList.contains('blocked')), 'overlap is shown before release');
  await touches('touchEnd', []);
  assert.deepEqual(await vars(), saved, 'overlap restores the last accepted layout');
  await gesture(await center('[data-module=a]'), await center('#gear'), false);
  assert(await page.locator('[data-module=a]').evaluate(el=>el.classList.contains('blocked')), 'Gear is a collision obstacle');
  await touches('touchCancel', []);
  assert.deepEqual(await vars(), saved, 'cancelled gestures restore their starting position');
  await gesture(await center('[data-module=a]'), await center('#settings-open'), false);
  assert(await page.locator('[data-module=a]').evaluate(el=>el.classList.contains('blocked')), 'settings corner stays reserved');
  await touches('touchEnd', []);
  assert.deepEqual(await vars(), saved);
  const r = await center('[data-module=r]');
  await gesture(await center('[data-module=a]'), {x:r.x+3,y:400}, false);
  assert(await page.locator('#controller').getAttribute('data-guide-x'), 'nearby alignment shows a guide');
  assert(Math.abs((await center('[data-module=a]')).x-r.x)<1, 'snapping aligns visible centers precisely');
  await touches('touchEnd', []);
  await page.click('#layout-deselect'); await page.uncheck('#layout-snap');
  const unsnapped = await center('[data-module=a]');
  await gesture(unsnapped,{x:unsnapped.x+11,y:unsnapped.y-10},false);
  assert.equal(await page.locator('#controller').getAttribute('data-guide-x'),null, 'Snap off does not show guides');
  await touches('touchEnd',[]);
  await page.click('#layout-deselect'); await page.check('#layout-snap');
  await touches('touchStart',[await center('[data-module=a]')]); await touches('touchEnd',[]);
  await page.locator('#layout-size').fill('0.85'); await page.locator('#layout-size').dispatchEvent('change');
  assert.equal((await vars()).landscape.vars['--a-s'], .85, 'size slider changes the selected button');
  const gear = await center('#gear');
  await gesture(gear,{x:gear.x,y:gear.y-20});
  assert((await center('#gear')).y < gear.y-15, 'the screen moves vertically despite preset letterboxing');
  await page.locator('#layout-size').fill('0.8'); await page.locator('#layout-size').dispatchEvent('change');
  assert(Math.abs((await vars()).landscape.vars['--screen-w']-.4)<.001, 'Gear resizes relative to its preset');
  await page.click('#layout-deselect'); await page.click('#layout-dock');
  assert.equal(await page.locator('#layout-editor').getAttribute('data-dock'),'bottom');
  await page.click('#layout-dock'); await page.click('#layout-reset');
  assert.deepEqual((await vars()).landscape.vars, {}, 'Reset removes overrides');
  assert(await page.locator('#layout-reset').isDisabled(), 'Reset without overrides cannot animate');
  const dpad = await center('[data-module=dpad]');
  await touches('touchStart',[dpad]); await touches('touchEnd',[]);
  await page.locator('#layout-size').evaluate(el=>{el.value='1.6';el.dispatchEvent(new Event('input',{bubbles:true}));});
  assert.equal(await page.locator('#layout-size').getAttribute('aria-invalid'),'true', 'oversized modules cannot overlap the screen');
  await page.locator('#layout-size').dispatchEvent('change');
  assert.deepEqual((await vars()).landscape.vars,{}, 'invalid resizing preserves the accepted layout');
  assert.equal(await inputCount(), beforeInput, 'editing sends no buttons or Gear touches');
  assert.equal(await page.evaluate(()=>testVibrations.length), beforeVibration, 'dragging never produces game haptics');
  await page.click('#layout-cancel');
  assert.equal(await page.locator('#controller').getAttribute('data-layout'),'auto', 'Cancel restores the former layout mode');

  await open(); await page.selectOption('#layout-preset','lefty'); await page.click('#layout-done');
  assert.equal(await page.locator('#controller').getAttribute('data-preset'),'lefty');
  assert.equal(await page.evaluate(()=>localStorage.getItem('kanto-gear-phone-settings')), null, 'Done without opt-in is memory-only');
  await page.reload(); await pair();
  assert.equal(await page.locator('#controller').getAttribute('data-layout'),'auto', 'memory-only layout does not survive reload');
  await page.click('#settings-open'); await page.check('#setting-remember'); await page.click('#layout-edit');
  const start = await center('[data-module=a]');
  await gesture(start, {x:start.x,y:start.y+60});
  const landscape = (await vars()).landscape;
  // Rotate with an unfinished drag: no gesture may bleed into the other orientation.
  await gesture(await center('[data-module=a]'), {x:start.x,y:start.y+90}, false);
  await page.setViewportSize({width:390,height:844}); await page.waitForFunction(() => layoutOrientation === orientation()); await touches('touchEnd',[]);
  assert.deepEqual((await vars()).landscape, landscape, 'rotation rolls back the active drag');
  assert.equal(await page.locator('#controller').getAttribute('data-preset'),'classic');
  await page.selectOption('#layout-preset','one-left');
  const portraitA = await center('[data-module=a]');
  await gesture(portraitA,{x:portraitA.x,y:portraitA.y-30});
  const portrait = (await vars()).portrait;
  assert(Object.keys(portrait.vars).length, 'portrait edits have their own positions');
  await page.click('#layout-done');
  saved = await page.evaluate(()=>JSON.parse(localStorage.getItem('kanto-gear-phone-settings')));
  assert.deepEqual(saved.layouts,{landscape,portrait}, 'Remember stores both orientation sets');
  assert(!JSON.stringify(saved).includes('12345678'), 'layout storage contains no pairing credential');
  await page.reload(); await pair();
  assert.equal(await page.locator('#controller').getAttribute('data-preset'),'one-left', 'reload restores the current orientation');
  await page.click('#settings-open'); await page.uncheck('#setting-controls'); await page.click('#settings-close');
  assert((await page.locator('#gear-slot').boundingBox()).width > (await page.locator('#controller').boundingBox()).width*.9, 'hiding custom controls restores a full-size display');
  await page.click('#settings-open'); await page.check('#setting-controls'); await page.click('#settings-close');
  assert.equal(await page.locator('#controller').getAttribute('data-layout'),'custom', 'showing controls restores the custom layout');
  await page.setViewportSize({width:960,height:540}); await page.waitForFunction(() => layoutOrientation === orientation());
  assert.equal(await page.locator('#controller').getAttribute('data-preset'),'classic');
  assert.deepEqual((await vars()).landscape, landscape, 'rotation restores the landscape override');
  await open(); await page.click('#layout-reset');
  assert.deepEqual((await vars()).portrait, portrait, 'Reset changes only the active orientation');
  await page.click('#layout-cancel');
  assert.deepEqual((await vars()).landscape, landscape, 'Cancel also restores reset overrides');
  await open(); await page.selectOption('#layout-preset','lefty');
  await page.evaluate(()=>testSocket.deliver('c,gb'));
  assert(await page.locator('#layout-editor').isHidden(), 'changing game capability safely cancels editing');
  assert.deepEqual((await vars()).landscape, landscape);
  await page.evaluate(()=>testSocket.deliver('c,gba'));
  await open();
  const mouseA=await center('[data-module=a]');
  await page.mouse.move(mouseA.x,mouseA.y); await page.mouse.down();
  await page.mouse.move(mouseA.x,mouseA.y+25,{steps:3}); await page.mouse.up();
  assert.notDeepEqual((await vars()).landscape, landscape, 'mouse dragging works on disabled modules too');
  await page.keyboard.press('Escape');
  assert.deepEqual((await vars()).landscape,landscape, 'Escape cancels mouse edits');

  // Review actual visible bounds and image alignment across all themes and presets.
  await page.evaluate(()=>testSocket.deliver('c,gba'));
  for (const viewport of [{width:320,height:568},{width:568,height:320},{width:390,height:844},{width:844,height:390},{width:667,height:375},{width:960,height:540},{width:1280,height:800}]) {
    await page.setViewportSize(viewport); await page.waitForFunction(() => layoutOrientation === orientation());
    for (const theme of ['pokegear-light','pokegear-dark','cgear-light','cgear-dark']) {
      await page.click('#settings-open'); await page.selectOption('#setting-theme',theme); await page.click('#layout-edit');
      for (const preset of ['classic','lefty','one-right','one-left']) {
        await page.selectOption('#layout-preset',preset);
        const geometry = await page.evaluate(()=>({
          invalid:visibleModules().filter(el=>!validPlacement(el)).map(el=>el.dataset.module),
          overflow:document.documentElement.scrollWidth>innerWidth || document.documentElement.scrollHeight>innerHeight,
          bar:document.getElementById('layout-editor').getBoundingClientRect().toJSON(),
          tools:[...document.querySelectorAll('#layout-editor button, #layout-editor select, #layout-editor input')].filter(el=>el.getClientRects().length).map(el=>el.getBoundingClientRect().toJSON()),
          canvas:canvas.getBoundingClientRect().toJSON(), slot:screen.getBoundingClientRect().toJSON()
        }));
        assert.deepEqual(geometry.invalid,[], `${theme}/${preset}/${viewport.width}: preset has no collisions`);
        assert(!geometry.overflow, 'editor does not overflow the viewport');
        assert(geometry.bar.left>=0 && geometry.bar.right<=viewport.width && geometry.bar.top>=0 && geometry.bar.bottom<=viewport.height, 'toolbar fits');
        assert(geometry.tools.every(r=>r.left>=geometry.bar.left && r.right<=geometry.bar.right && r.top>=geometry.bar.top && r.bottom<=geometry.bar.bottom), 'every toolbar control stays inside the bar');
        const c=geometry.canvas,s=geometry.slot;
        assert(Math.abs(c.width/c.height-240/216)<.01 && Math.abs(c.x-s.x-(s.width-c.width)/2)<1 && Math.abs(c.y-s.y-(s.height-c.height)/2)<1, 'custom Gear is proportional and centered');
        if (preset==='classic') await page.screenshot({path:path.join(out,`editor-${theme}-${viewport.width}.png`)});
      }
      await page.click('#layout-cancel');
    }
  }
  await page.setViewportSize({width:960,height:540}); await page.waitForFunction(() => layoutOrientation === orientation());
  await open();
  await page.evaluate(()=>testSocket.stalled=true);
  await page.waitForSelector('#pair:not([hidden])');
  assert(await page.locator('#layout-editor').isHidden(), 'connection loss cancels the editor');
  await pair();
  await page.click('#settings-open'); await page.click('#forget-settings');
  await page.check('#setting-remember'); await page.click('#settings-close');
  console.log('PASS layout touch dragging, collisions, snapping, sizes, cancel/reset, per-orientation opt-in storage, rotation and preset geometry');
};
