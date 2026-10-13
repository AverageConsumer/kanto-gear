const { chromium } = require(process.env.KANTO_GEAR_NODE_MODULES + '/playwright');
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..', 'phone');
// Decode exactly as UTF-8 before the browser could hide invalid bytes with U+FFFD.
for (const file of ['phone.js','phone_decoder.js','phone.html']) new TextDecoder('utf-8', {fatal:true}).decode(fs.readFileSync(path.join(root,file)));
(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: process.env.KANTO_GEAR_CHROMIUM });
  const context = await browser.newContext({ viewport: { width: 960, height: 540 }, hasTouch: true, deviceScaleFactor: 1 });
  const page = await context.newPage();
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.route('http://127.0.0.1:8765/**', route => {
    const file = route.request().url().endsWith('/phone_decoder.js') ? 'phone_decoder.js' : route.request().url().endsWith('/phone.js') ? 'phone.js' : 'phone.html';
    return route.fulfill({ contentType: file.endsWith('.js') ? 'text/javascript' : 'text/html', body: fs.readFileSync(path.join(root,file)) });
  });
  await page.addInitScript(() => {
    window.testVibrations = [];
    Object.defineProperty(navigator,'vibrate',{configurable:true,value(duration) {
      if (window.vibrationMode === 'throw') throw new Error('Vibration denied');
      window.testVibrations.push(duration);
      return window.vibrationMode !== 'deny';
    }});
    class Socket {
      static OPEN = 1;
      constructor(url) {
        this.url = url;
        this.readyState = 0; this.messages = []; window.testSocket = this;
        setTimeout(() => { this.readyState = 1; this.onopen?.(); }, 0);
      }
      send(text) {
        this.messages.push(text);
        if (text.startsWith('auth,')) queueMicrotask(() => this.deliver('ok'));
        if (text.startsWith('h,') && !this.stalled) queueMicrotask(() => this.deliver('h'));
      }
      close() { this.readyState = 3; }
      deliver(data) { this.onmessage?.({ data }); }
    }
    window.WebSocket = Socket;
    window.testFrame = () => {
      const width = 240, height = 216, bytes = new ArrayBuffer(12 + width * height * 4), header = new DataView(bytes);
      header.setUint32(0, 0x4b473031); header.setUint16(4, width); header.setUint16(6, height); header.setUint32(8, 1);
      const rgba = new Uint8Array(bytes, 12);
      for (let i = 0; i < rgba.length; i += 4) { rgba[i] = 24; rgba[i+1] = 58 + Math.floor(i / 960) % 70; rgba[i+2] = 52; rgba[i+3] = 255; }
      window.testSocket.deliver('c,gba'); window.testSocket.deliver(bytes);
    };
  });
  await page.goto('http://127.0.0.1:8765/');
  const pair = async () => {
    await page.fill('#pin', '12345678'); await page.click('#connect');
    await page.waitForFunction(() => window.testSocket?.readyState === 1);
    await page.evaluate(() => window.testFrame());
    await page.waitForSelector('#controller:not([hidden])');
  };
  assert(await page.locator('#setting-haptics').evaluate(el=>!el.closest('label').hidden), 'supported browsers expose Haptics');
  await pair();
  assert(await page.evaluate(() => testSocket.url === 'ws://127.0.0.1:8765/gear'), 'credentials never enter WebSocket URLs');
  assert(await page.evaluate(() => testSocket.messages[0] === 'auth,12345678'), 'authentication is the first message');
  const messages = () => page.evaluate(() => window.testSocket.messages.filter(s => s.startsWith('b,')));
  const center = async selector => {
    const b = await page.locator(selector).boundingBox();
    return { x: b.x+b.width/2, y: b.y+b.height/2 };
  };
  const left = await center('[data-button=left]'), b = await center('[data-button=b]'), gear = await center('#gear');
  const cdp = await context.newCDPSession(page);
  const touches = async (type, points) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points.map((p,i) => ({...p, id:i+1})) });
  await touches('touchStart', [left]);
  await touches('touchStart', [left,b]);
  let sent = await messages(); assert(sent.includes('b,left,1') && sent.includes('b,b,1'), 'walking and B are held simultaneously');
  await touches('touchStart', [left,b,gear]);
  assert(await page.evaluate(()=>testVibrations.filter(n=>n===8).length===2), 'new controller holds pulse once; held fingers and Gear touch do not repeat');
  assert(await page.evaluate(() => testSocket.messages.some(s => s.startsWith('down,'))), 'Gear accepts a third finger');
  await touches('touchEnd', []);
  sent = await messages(); assert(sent.includes('b,left,0') && sent.includes('b,b,0'), 'lifting fingers releases buttons');
  const right = await center('[data-button=right]');
  await touches('touchStart', [left]); await touches('touchMove', [right]); await touches('touchEnd', []);
  sent = await messages(); assert(sent.slice(-4).join('|') === 'b,left,1|b,left,0|b,right,1|b,right,0', 'Dpad slides between directions');
  const before = sent.length;
  await page.evaluate(() => {
    const button=document.querySelector('[data-button=a]');
    // Synthetic capture is not used here; these are accessible keyboard clicks.
    button.click();
  });
  assert((await messages()).slice(before).join('|') === 'b,a,1|b,a,0', 'accessible activation makes a bounded tap');
  await page.click('#settings-open');
  assert(await page.locator('[data-button=a]').isDisabled(), 'modal disables game buttons');
  const pulses=await page.evaluate(()=>testVibrations.length);
  await page.evaluate(()=>document.querySelector('[data-button=a]').dispatchEvent(new PointerEvent('pointerdown',{button:0,pointerId:999})));
  assert(await page.evaluate(()=>testVibrations.length)===pulses, 'a modal-covered button never vibrates');
  await page.uncheck('#setting-haptics'); await page.click('#settings-close');
  await page.evaluate(()=>document.querySelector('[data-button=a]').click());
  assert(await page.evaluate(()=>testVibrations.length)===pulses, 'disabling Haptics silences active buttons');
  await page.click('#settings-open'); await page.check('#setting-haptics');

  await page.check('#setting-remember'); await page.uncheck('#setting-motion'); await page.uncheck('#setting-haptics');
  await page.uncheck('#setting-controls'); await page.selectOption('#setting-theme', 'cgear-light');
  await page.selectOption('#setting-size','1.4'); await page.click('#settings-close');
  assert(await page.locator('#left-controls').isHidden(), 'controls may be hidden');
  const full = await page.locator('#gear-slot').boundingBox(), shell=await page.locator('#controller').boundingBox();
  assert(full.width > shell.width * .9, 'display-only mode gives Gear the available width');
  await page.reload(); await pair();
  assert(await page.locator('#left-controls').isHidden(), 'browser preferences survive reload');
  assert(!(await page.locator('#setting-motion').isChecked()), 'press-motion preference survives reload');
  assert(!(await page.locator('#setting-haptics').isChecked()), 'Haptics preference survives reload with opt-in');
  assert(await page.locator('body').getAttribute('data-theme') === 'cgear-light');
  await page.click('#settings-open'); await page.check('#setting-controls'); await page.check('#setting-haptics'); await page.selectOption('#setting-size','1'); await page.click('#settings-close');
  await page.evaluate(() => testSocket.deliver('c,gb'));
  assert(await page.locator('[data-button=l]').isHidden(), 'GB games hide GBA shoulders');
  await page.evaluate(() => testSocket.deliver('c,none'));
  const inactive=await page.evaluate(()=>testVibrations.length);
  await page.evaluate(()=>document.querySelector('[data-button=a]').dispatchEvent(new PointerEvent('pointerdown',{button:0,pointerId:998})));
  assert(await page.evaluate(()=>testVibrations.length)===inactive, 'unsupported game controls do not vibrate');
  assert(await page.locator('[data-button=a]').isDisabled(), 'display-only hosts cannot animate game buttons');
  await page.evaluate(() => testSocket.deliver('c,gba'));
  const beforeDenied=(await messages()).length;
  await page.evaluate(()=>{vibrationMode='throw';document.querySelector('[data-button=a]').click();vibrationMode='deny';document.querySelector('[data-button=b]').click();vibrationMode=null;});
  assert((await messages()).length===beforeDenied+4, 'denied or throwing vibration never blocks game input');
  const out = path.resolve(__dirname, '../../../diagnostics/browser-previews'); fs.mkdirSync(out,{recursive:true});
  await require('./phone_layout_cases.cjs')({page,touches,center,pair,out});
  for (const generation of [1,2]) for (const theme of ['pokegear-light','pokegear-dark','cgear-light','cgear-dark']) {
    await page.click('#settings-open'); await page.selectOption('#setting-theme',theme);
    await page.screenshot({path:path.join(out,`settings-gen${generation}-${theme}.png`)});
    await page.click('#settings-close');
    await page.evaluate(()=>testSocket.deliver('c,gb'));
    await page.screenshot({path:path.join(out,`gen${generation}-${theme}.png`)});
  }
  for (const viewport of [{width:390,height:844},{width:844,height:390},{width:667,height:375},{width:1280,height:800}]) {
    await page.setViewportSize(viewport);
    await page.waitForTimeout(50);
    const geometry=await page.evaluate(() => {
      const canvas=document.getElementById('gear').getBoundingClientRect(), slot=document.getElementById('gear-slot').getBoundingClientRect();
      return { canvas:{x:canvas.x,y:canvas.y,w:canvas.width,h:canvas.height}, slot:{x:slot.x,y:slot.y,w:slot.width,h:slot.height},
        overflow:document.documentElement.scrollWidth>innerWidth, tall:document.documentElement.scrollHeight>innerHeight,
        controls:[...document.querySelectorAll('[data-button]:not([hidden])')].map(el=>{const r=el.getBoundingClientRect(); return {x:r.x,y:r.y,w:r.width,h:r.height};}) };
    });
    assert(!geometry.overflow && !geometry.tall, `no page overflow at ${viewport.width}x${viewport.height}`);
    const c=geometry.canvas,s=geometry.slot;
    assert(Math.abs(c.w/c.h-240/216)<.01 && Math.abs(c.x-s.x-(s.w-c.w)/2)<1 && Math.abs(c.y-s.y-(s.h-c.h)/2)<1, 'Gear remains proportional and centered');
    assert(geometry.controls.every(r=>r.x>=0 && r.y>=0 && r.x+r.w<=viewport.width && r.y+r.h<=viewport.height), 'all buttons fit the viewport');
    await page.screenshot({path:path.join(out,`${viewport.width}x${viewport.height}.png`)});
  }
  await page.evaluate(() => testSocket.stalled=true);
  await page.waitForSelector('#pair:not([hidden])');
  assert(await page.locator('[data-button=a]').isDisabled(), 'a silent host disables controls');
  await pair();
  await touches('touchStart', [await center('[data-button=b]')]);
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  assert(await page.locator('[data-button=b]').evaluate(el=>!el.classList.contains('held')), 'losing focus clears visual holds');
  assert(await page.evaluate(() => testSocket.messages.at(-1)==='release'), 'losing focus releases host buttons');
  assert(await page.evaluate(()=>testVibrations.at(-1)===0), 'losing focus cancels vibration');
  await touches('touchEnd', []);
  await page.click('#settings-open'); await page.click('#disconnect');
  assert(await page.locator('#pair').isVisible());
  assert(await page.evaluate(() => testSocket.messages.includes('release')), 'disconnect resets all holds');
  await page.click('#settings-open'); await page.click('#forget-settings'); await page.click('#settings-close');
  assert(await page.evaluate(() => localStorage.getItem('kanto-gear-phone-settings') === null), 'forget deletes saved preferences');
  await page.goto('about:blank');
  await page.goto('http://127.0.0.1:8765/#pair=0123456789abcdef0123456789abcdef');
  assert(await page.evaluate(() => location.hash === ''), 'QR key is removed from the address immediately');
  assert((await page.locator('#status').textContent()).includes('QR received \u00b7 tap Connect'), 'QR status renders the intended separator');
  assert(!(await page.locator('#status').textContent()).includes('\ufffd'), 'QR status has no replacement characters');
  assert(await page.locator('#pin').isHidden(), 'scanning skips manual code entry');
  assert(await page.locator('.privacy summary').isVisible(), 'connection information is available before consent');
  assert(await page.evaluate(() => !window.testSocket), 'QR scanning does not connect before the user confirms');
  await page.click('#connect');
  await page.waitForFunction(() => testSocket?.messages[0] === 'auth,0123456789abcdef0123456789abcdef');
  await page.evaluate(() => testFrame()); await page.waitForSelector('#controller:not([hidden])');
  await page.click('#settings-open'); await page.selectOption('#setting-theme','cgear-light'); await page.click('#settings-close');
  assert(await page.evaluate(() => localStorage.getItem('kanto-gear-phone-settings') === null), 'preferences remain memory-only without opt-in');
  await page.reload();
  assert(await page.locator('body').getAttribute('data-theme') === 'pokegear-dark', 'memory-only settings reset on reload');
  assert(await page.evaluate(() => !window.testSocket), 'reloading cannot reuse the consumed QR credential');
  for (const viewport of [{width:390,height:844},{width:844,height:390},{width:667,height:375}]) {
    await page.setViewportSize(viewport); await page.screenshot({path:path.join(out,`pair-${viewport.width}x${viewport.height}.png`)});
    await page.locator('.privacy summary').click();
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'privacy details fit narrow screens');
    await page.locator('.privacy summary').click();
  }
  await require('./phone_video_cases.cjs')({page,pair});
  const unsupported = await browser.newContext();
  const noHaptics = await unsupported.newPage();
  await noHaptics.route('http://127.0.0.1:8765/**',route=>{
    const js=route.request().url().endsWith('/phone.js');
    return route.fulfill({contentType:js?'text/javascript':'text/html',body:fs.readFileSync(path.join(root,js?'phone.js':'phone.html'))});
  });
  await noHaptics.addInitScript(()=>Object.defineProperty(navigator,'vibrate',{value:undefined}));
  await noHaptics.goto('http://127.0.0.1:8765/');
  await noHaptics.click('#settings-open');
  assert(await noHaptics.locator('#setting-haptics').isHidden(), 'browsers without vibration hide the option');
  assert(await noHaptics.locator('#setting-haptics').isDisabled(), 'unsupported vibration cannot be toggled');
  await unsupported.close();
  assert.deepEqual(errors,[]);
  await browser.close();
  console.log('PASS browser pairing, multitouch, Dpad slide, Gear touch, modal, settings persistence, capabilities, haptics, UTF-8 and responsive geometry');
})().catch(error => { console.error(error); process.exit(1); });
