const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');

module.exports = async ({browser, root, out}) => {
  for (const dpi of [1, 3]) {
    const session = await browser.newContext({viewport:{width:915,height:412}, deviceScaleFactor:dpi, hasTouch:true, isMobile:true});
    const page = await session.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.route('http://127.0.0.1:8765/**', route => {
      const name = ['phone_decoder.js','phone.js'].find(name => route.request().url().endsWith('/'+name)) || 'phone.html';
      return route.fulfill({contentType:name.endsWith('.js')?'text/javascript':'text/html', body:fs.readFileSync(path.join(root,name))});
    });
    await page.addInitScript(() => {
      class Socket {
        static OPEN = 1;
        constructor() {
          this.messages = []; this.readyState = 0; window.testSocket = this;
          setTimeout(() => { this.readyState = 1; this.onopen?.(); }, 0);
        }
        send(text) {
          this.messages.push(text);
          if (text.startsWith('auth,')) queueMicrotask(() => this.deliver('ok'));
          if (text.startsWith('h,')) queueMicrotask(() => this.deliver('h'));
        }
        deliver(data) { this.onmessage?.({data}); }
        close() { this.readyState = 3; }
      }
      window.WebSocket = Socket;
      window.nextFrame = () => {
        const w=240,h=216,bytes=new ArrayBuffer(12+w*h*4),header=new DataView(bytes);
        header.setUint32(0,0x4b473031); header.setUint16(4,w); header.setUint16(6,h);
        header.setUint32(8,window.frameId=(window.frameId||0)+1);
        new Uint8Array(bytes,12).fill(255);
        testSocket.deliver(bytes);
      };
    });
    await page.goto('http://127.0.0.1:8765/');
    await page.fill('#pin','12345678'); await page.click('#connect');
    await page.waitForFunction(() => testSocket?.messages.includes('h,0'));
    await page.evaluate(() => {testSocket.deliver('c,gba'); nextFrame();});
    await page.waitForSelector('#controller:not([hidden])');

    const checkControls = async label => {
      const state = await page.evaluate(() => ({
        modal:settings.open, hidden:controller.hidden,
        buttons:[...controller.querySelectorAll('[data-button]')].filter(b=>b.getClientRects().length).map(b=>{
          const r=b.getBoundingClientRect(), hit=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);
          return {button:b.dataset.button, disabled:b.disabled, hit:hit?.closest('[data-button]')?.dataset.button,
            x:r.x+r.width/2,y:r.y+r.height/2};
        }),
      }));
      assert(!state.modal && !state.hidden, label+': controller owns input');
      assert(state.buttons.length>=8, label+': game controls remain visible');
      for (const b of state.buttons) {
        assert(!b.disabled && b.hit===b.button, label+': '+b.button+' is the topmost input target');
        const start = await page.evaluate(()=>testSocket.messages.length);
        await page.mouse.click(b.x,b.y);
        const messages = await page.evaluate(start=>testSocket.messages.slice(start),start);
        assert(messages.includes(`b,${b.button},1`) && messages.includes(`b,${b.button},0`),label+': '+b.button+' reaches the game');
        assert(!messages.some(text=>/^(down|up),/.test(text)),label+': controls never send a Gear-screen touch');
      }
    };
    await checkControls('before fullscreen');
    await page.click('#settings-open'); await page.click('#fullscreen');
    assert(await page.locator('#settings').evaluate(el=>!el.open), 'fullscreen must close the modal before changing top-layer ownership');
    await page.waitForFunction(()=>!!document.fullscreenElement);
    await checkControls('after fullscreen');

    const raster = await page.evaluate(() => {
      const box=output.getBoundingClientRect(), slot=screen.getBoundingClientRect(), style=getComputedStyle(output);
      return {width:output.clientWidth,height:output.clientHeight,box:box.toJSON(),slot:slot.toJSON(),transform:style.transform};
    });
    assert.equal(raster.transform,'none','physical raster uses CSS dimensions without an oversized transformed layer');
    assert(Math.abs(raster.width-raster.box.width)<1 && Math.abs(raster.height-raster.box.height)<1,
      'raster layout bounds match its visible area');
    assert(raster.box.left>=raster.slot.left-1 && raster.box.right<=raster.slot.right+1,
      'video remains in its allocated screen region');
    for (const viewport of [{width:412,height:915},{width:915,height:360},{width:915,height:412}]) {
      await page.setViewportSize(viewport); await page.waitForTimeout(100);
      await checkControls('fullscreen resize '+viewport.width+'x'+viewport.height);
    }

    if (dpi===3) {
      await page.evaluate(()=>{window.streamTimer=setInterval(nextFrame,100);});
      // The reported regression appeared only after roughly a minute of video.
      for (let i=0;i<7;i++) {await page.waitForTimeout(10000); await checkControls('stream '+(i+1)*10+'s');}
      await page.evaluate(()=>clearInterval(streamTimer));
      await page.screenshot({path:path.join(out,'fullscreen-stream-dpr3.png')});
    }
    await page.click('#settings-open'); await page.click('#fullscreen');
    await page.waitForFunction(()=>!document.fullscreenElement);
    await checkControls('after leaving fullscreen');
    assert.deepEqual(errors,[]); await session.close();
  }
  console.log('PASS fullscreen modal ownership, raster bounds, rotation, button hit testing and 70-second stream');
};
