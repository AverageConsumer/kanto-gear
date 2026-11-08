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
      window.nextFrame = (w=240,h=216) => {
        const bytes=new ArrayBuffer(12+w*h*4),header=new DataView(bytes);
        header.setUint32(0,0x4b473031); header.setUint16(4,w); header.setUint16(6,h);
        header.setUint32(8,window.frameId=(window.frameId||0)+1);
        new Uint8Array(bytes,12).fill(255);
        testSocket.deliver(bytes);
        return window.frameId;
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
      const box=output.getBoundingClientRect(), slot=screen.getBoundingClientRect();
      return {width:output.clientWidth,height:output.clientHeight,box:box.toJSON(),slot:slot.toJSON()};
    });
    assert(Math.abs(raster.width-raster.box.width*dpi)<.001 && Math.abs(raster.height-raster.box.height*dpi)<.001,
      'output raster maps one backing pixel to one physical display pixel');
    assert(raster.box.left>=raster.slot.left-1 && raster.box.right<=raster.slot.right+1,
      'video remains in its allocated screen region');
    for (const viewport of [{width:412,height:915},{width:915,height:360},{width:915,height:412}]) {
      await page.setViewportSize(viewport); await page.waitForTimeout(100);
      await checkControls('fullscreen resize '+viewport.width+'x'+viewport.height);
    }

    const cdp=await session.newCDPSession(page);
    const touches=(type,points)=>cdp.send('Input.dispatchTouchEvent',{
      type,touchPoints:points.map((p,i)=>({...p,id:i+1})),
    });
    const center=async selector=>{const r=await page.locator(selector).boundingBox();return{x:r.x+r.width/2,y:r.y+r.height/2};};
    for(const event of ['blur','resize','fullscreenchange','visualViewport']) {
      await touches('touchStart',[await center('[data-button=a]'),await center('[data-button=left]')]);
      assert(await page.evaluate(()=>held.has('a')&&held.has('left')),event+': simultaneous real touches are held');
      await page.evaluate(event=>{
        if(event==='visualViewport')visualViewport.dispatchEvent(new Event('resize'));
        else (event==='fullscreenchange'?document:window).dispatchEvent(new Event(event));
      },event);
      assert(await page.evaluate(()=>held.size===0&&pointers.size===0&&pointer===null),event+': old holds are released');
      await touches('touchEnd',[]);await checkControls('fresh input after '+event);
    }
    await page.click('#settings-open');await page.keyboard.press('Escape');
    await checkControls('modal cancellation');
    if(!await page.evaluate(()=>!!document.fullscreenElement)) {
      await page.click('#settings-open');await page.click('#fullscreen');
      await page.waitForFunction(()=>!!document.fullscreenElement);
    }
    for(const [w,h] of [[160,144],[240,160],[240,216]]) {
      const id=await page.evaluate(([w,h])=>nextFrame(w,h),[w,h]);
      await page.waitForFunction(id=>testSocket.messages.includes('a,'+id),id);
      await checkControls('new stream resolution '+w+'x'+h);
    }
    await touches('touchStart',[await center('[data-button=l]')]);
    await page.evaluate(()=>testSocket.deliver('c,gb'));
    assert(await page.evaluate(()=>held.size===0&&document.querySelector('[data-button=l]').hidden),
      'changing game capability releases an owned shoulder');
    await touches('touchEnd',[]);await checkControls('GB controls');
    await page.evaluate(()=>testSocket.deliver('c,gba'));await checkControls('restored GBA controls');
    await page.evaluate(()=>{window.staleMessage=testSocket.onmessage;window.staleDecode=decoder.onmessage;testSocket.onclose();});
    assert(await page.locator('#controller').isHidden(),'disconnect hides stale controls');
    await page.fill('#pin','12345678');await page.click('#connect');
    await page.waitForFunction(()=>testSocket?.messages.includes('h,0'));
    await page.evaluate(()=>{testSocket.deliver('c,gba');nextFrame();});
    await page.waitForSelector('#controller:not([hidden])');
    await page.evaluate(()=>{staleMessage({data:'c,none'});staleDecode({data:{error:'stale decoder'}});});
    await checkControls('stale callbacks after reconnect');

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
  console.log('PASS fullscreen, held touches, focus/viewport changes, resolution/capability changes, reconnect isolation and 70-second stream');
};
