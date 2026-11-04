const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
module.exports=async function({browser,root,out}) {
  let checks=0;
  for(const dpi of [1,1.25,2,3]) {
    const session=await browser.newContext({viewport:{width:640,height:480},deviceScaleFactor:dpi});
    const page=await session.newPage(); const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.route('http://127.0.0.1:8765/**',route=>{
      const file=route.request().url().endsWith('/phone.js')?'phone.js':'phone.html';
      return route.fulfill({contentType:file.endsWith('.js')?'text/javascript':'text/html',body:fs.readFileSync(path.join(root,file))});
    });
    await page.goto('http://127.0.0.1:8765/');
    for(const source of [{w:240,h:216},{w:160,h:144}]) {
      for(const viewport of [{width:640,height:480},{width:390,height:844},{width:721,height:649}]) {
        await page.setViewportSize(viewport);
        for(const enabled of [false,true]) {
          const r=await page.evaluate(({enabled,source})=>{
            frame=1;capability='gba';integerScaling=enabled;form.hidden=true;controller.hidden=false;
            socket={readyState:WebSocket.OPEN,send:text=>window.scalingTouches.push(text)};
            window.scalingTouches=[];
            canvas.width=source.w;canvas.height=source.h;canvas.style.display='block';
            const pixels=new ImageData(source.w,source.h);
            for(let y=0;y<source.h;y++)for(let x=0;x<source.w;x++) {
              const i=(y*source.w+x)*4,v=(x+y)%2?255:0;
              pixels.data[i]=pixels.data[i+1]=pixels.data[i+2]=v;pixels.data[i+3]=255;
            }
            context.putImageData(pixels,0,0);refreshControls();fit();
            const box=output.getBoundingClientRect(),well=screen.getBoundingClientRect(),s=outputPlacement.scale;
            const available=Math.min((Math.floor(well.right*devicePixelRatio+1e-7)-Math.ceil(well.left*devicePixelRatio-1e-7))/source.w,
              (Math.floor(well.bottom*devicePixelRatio+1e-7)-Math.ceil(well.top*devicePixelRatio-1e-7))/source.h);
            const data=outputContext.getImageData(0,0,output.width,output.height).data;
            let mixed=false;for(let i=0;i<data.length;i+=4)if(data[i+3]===255&&data[i]!==0&&data[i]!==255)mixed=true;
            return {s,available,x:box.left*devicePixelRatio,y:box.top*devicePixelRatio,mixed,
              point:{x:box.left+(source.w/2+.25)*s/devicePixelRatio,y:box.top+(source.h/2+.25)*s/devicePixelRatio}};
          },{enabled,source});
          const expected=enabled&&r.available>=1?Math.floor(r.available+1e-7):r.available;
          assert(Math.abs(r.s-expected)<1e-7,'browser applies the selected scale in physical pixels');
          assert(Math.abs(r.x-Math.round(r.x))<.001&&Math.abs(r.y-Math.round(r.y))<.001,'output origin is on physical pixels');
          assert(!r.mixed,'nearest output introduces no blended checkerboard colors');
          await page.mouse.click(r.point.x,r.point.y);
          assert((await page.evaluate(()=>scalingTouches)).includes(`down,${source.w/2},${source.h/2},1`),'touch maps to the same source pixel after scaling');
          checks++;
        }
      }
    }
    if(dpi===3)await page.screenshot({path:path.join(out,'phone-physical-scaling-dpr3.png')});
    assert.deepEqual(errors,[]);await session.close();
  }
  console.log(`PASS ${checks} browser scale, physical origin, checkerboard and touch cases`);
};
