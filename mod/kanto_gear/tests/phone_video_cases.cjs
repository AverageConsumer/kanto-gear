const assert = require('node:assert/strict'), {deflateSync} = require('node:zlib');
module.exports = async ({page, pair}) => {
  const send = async bytes => page.evaluate(bytes => testSocket.deliver(Uint8Array.from(bytes).buffer), [...bytes]);
  const frame = (magic,w,h,id,payload,base) => {
    const header=Buffer.alloc(base === undefined ? 12 : 16);
    header.write(magic); header.writeUInt16BE(w,4); header.writeUInt16BE(h,6); header.writeUInt32BE(id,8);
    if(base !== undefined) header.writeUInt32BE(base,12);
    return Buffer.concat([header,payload]);
  };
  const patch = (y,x,rgba) => {
    const header=Buffer.alloc(8); header.writeUInt16BE(1); header.writeUInt16BE(y,2);
    header.writeUInt16BE(x,4); header.writeUInt16BE(rgba.length/4,6);
    return Buffer.concat([header,Buffer.from(rgba)]);
  };
  const command=(y,x,n,sy,sx,rgba=[])=>{
    const header=Buffer.alloc(10);[y,x,n,sy,sx].forEach((v,i)=>header.writeUInt16BE(v,i*2));
    return Buffer.concat([header,Buffer.from(rgba)]);
  };
  const painted = id => page.waitForFunction(id=>testSocket.messages.includes(`a,${id}`),id);
  await pair();
  await page.evaluate(()=>{window.originalInflate=DecompressionStream;window.DecompressionStream=class {constructor(){throw Error('UI-thread inflate is forbidden');}};});
  await send(frame('KG02',4,4,2,deflateSync(Buffer.alloc(64,255)))); await painted(2);
  assert(await page.evaluate(()=>!testSocket.messages.some(s=>s.startsWith('p,'))), 'public connections send no profiling traffic');
  await page.evaluate(()=>testSocket.deliver('p,1'));
  await page.evaluate(()=>{window.DecompressionStream=originalInflate;});
  const red=patch(2,1,[255,0,0,255]), blue=patch(0,3,[0,0,255,255]);
  // Both patches arrive before rAF; decoding still needs the unpainted predecessor.
  await page.evaluate(bytes=>{for(const packet of bytes)testSocket.deliver(Uint8Array.from(packet).buffer);},
    [[...frame('KG03',4,4,3,deflateSync(red),2)],[...frame('KG04',4,4,4,blue,3)]]);
  await painted(4);
  await page.waitForFunction(()=>testSocket.messages.some(s=>s.startsWith('p,4,')));
  const profile = await page.evaluate(()=>testSocket.messages.find(s=>s.startsWith('p,4,')).split(',').slice(2).map(Number));
  assert(profile.length === 10 && profile.every(n=>Number.isFinite(n)&&n>=0&&n<=10000), 'diagnostic clients report bounded stage timings and skipped presentations');
  assert(await page.evaluate(()=>testSocket.messages.filter(s=>s.startsWith('p,')).every(s=>s.length<126)), 'diagnostic messages fit the bounded WebSocket parser');
  const pixels = await page.evaluate(()=>[...document.querySelector('#gear').getContext('2d').getImageData(0,0,4,4).data]);
  assert.deepEqual(pixels.slice(36,40),[255,0,0,255], 'skipping a presentation preserves the earlier patch');
  assert.deepEqual(pixels.slice(12,16),[0,0,255,255], 'raw and compressed patches reconstruct the same image');
  await page.evaluate(()=>testSocket.deliver('c,gb'));
  assert(await page.locator('[data-button=l]').isHidden(), 'capability messages can interleave with incremental video');
  await send(frame('KG01',2,2,5,Buffer.alloc(16,80))); await painted(5);
  assert(await page.locator('#gear').evaluate(el=>el.width===2&&el.height===2), 'a full frame changes resolution safely');
  const moved=Buffer.concat([Buffer.from([0,2]),command(0,0,1,65535,0,[22,33,44,255]),command(1,0,2,0,0)]);
  await send(frame('KG06',2,2,6,moved,5));await painted(6);
  const copied=await page.evaluate(()=>[...document.querySelector('#gear').getContext('2d').getImageData(0,0,2,2).data]);
  assert.deepEqual(copied.slice(0,4),[22,33,44,255]);
  // The opaque canvas composites alpha 80, so compare via the decoder's exact buffer.
  assert(await page.evaluate(()=>decoded.pixels.slice(8).every(n=>n===80)), 'copy commands use the untouched previous frame');
  // Exhaust transferable buffers in one burst, then verify the next frame recovers without changing its pixels.
  await page.evaluate(packets=>{for(const bytes of packets)testSocket.deliver(Uint8Array.from(bytes).buffer);},
    Array.from({length:24},(_,i)=>[...frame('KG01',1,1,100+i,Buffer.from([i,0,0,255]))]));
  await page.waitForFunction(()=>testSocket.messages.includes('r,123'));
  await new Promise(r=>setTimeout(r,150));
  await send(frame('KG01',2,2,124,Buffer.alloc(16,255)));await painted(124);
  assert(await page.evaluate(()=>decoded.pixels.every(v=>v===255)), 'buffer pressure and resolution changes recover exact pixels');
  const bad = [
    frame('KG04',2,2,6,patch(0,0,[1,2,3,255]),99),
    frame('KG04',240,216,6,patch(216,0,[1,2,3,255]),1),
    frame('KG04',240,216,6,patch(0,240,[1,2,3,255]),1),
    frame('KG04',240,216,6,Buffer.concat([patch(0,0,[1,2,3,255]),Buffer.from([0])]),1),
    frame('KG03',240,216,6,deflateSync(Buffer.alloc(240*216*4+216*6+3)),1),
    frame('KG06',240,216,6,Buffer.concat([Buffer.from([0,1]),command(0,0,1,216,0)]),1),
    frame('KG06',240,216,6,Buffer.concat([Buffer.from([0,2]),command(0,1,2,0,0),command(0,2,2,0,0)]),1),
  ];
  for(const bytes of bad){
    if(await page.locator('#pair').isHidden()) await page.evaluate(()=>testSocket.onclose());
    await pair(); await send(bytes);
    await page.waitForFunction(()=>document.querySelector('#controller').hidden);
    assert(await page.locator('#status').evaluate(el=>/Gear (frame|patch)/.test(el.textContent)), 'malformed patches fail closed');
  }
  await pair();
  await page.evaluate(()=>{
    const bytes=new ArrayBuffer(13),v=new DataView(bytes);v.setUint32(0,0x4b473032);v.setUint16(4,1);v.setUint16(6,1);v.setUint32(8,2);
    for(let i=0;i<40;i++)testSocket.deliver(bytes.slice(0));
  });
  await page.waitForFunction(()=>document.querySelector('#controller').hidden);
  assert(await page.locator('#status').evaluate(el=>el.textContent.includes('queue exceeded')), 'decoder cannot accumulate an unbounded backlog');
  await pair();
  const clock=await page.evaluate(()=>{
    timing=[];lastStamp=null;sourceClock=0;playoutOffset=null;lastArrival=0;
    const now=performance.now();presentationTime(4294967290,now);const first=sourceClock;
    const target=presentationTime(6,now+20);
    return {elapsed:sourceClock-first,delay:target-(now+12)};
  });
  assert.equal(clock.elapsed,12,'capture timestamps survive uint32 wrap');
  assert(clock.delay>=59&&clock.delay<=61,'jitter absorption has a fixed upper bound');
  const pacer = await page.evaluate(() => {
    timing=[];lastStamp=null;sourceClock=0;playoutOffset=null;lastArrival=0;
    const due=[];
    for(let i=0;i<240;i++) {
      const stamp=Math.round(i*1000/60);
      // 144 Hz capture opportunities and radio bursts disturb arrivals, not the source cadence.
      const quantized=Math.ceil(stamp/(1000/144))*1000/144;
      due.push(presentationTime(stamp,1000+quantized+(i%30===0?25:0)));
    }
    return due.slice(31).map((v,i)=>v-due[i+30]);
  });
  assert(pacer.every(gap=>gap>=15.8&&gap<=17.2),'arrival jitter cannot become 14/21 ms presentation intervals');
  assert(await page.evaluate(()=>testSocket.messages.some(s=>s.startsWith('r,'))), 'decode receipts are independent of display acknowledgements');
  if(process.env.KANTO_GEAR_VIDEO_FIXTURE){
    const fs=require('node:fs'),crypto=require('node:crypto'),fixture=fs.readFileSync(process.env.KANTO_GEAR_VIDEO_FIXTURE);
    let at=0,count=0;
    await page.evaluate(()=>{window.imageAllocations=0;window.NativeImageData=ImageData;window.ImageData=class extends NativeImageData {constructor(...args){super(...args);imageAllocations++;}};});
    while(at<fixture.length){
      const size=fixture.readUInt32BE(at);at+=4;const packet=fixture.subarray(at,at+size);at+=size;
      const length=fixture.readUInt32BE(at);at+=4;const rgba=fixture.subarray(at,at+length);at+=length;
      const actual=await page.evaluate(async bytes=>{
        const before=decoded;testSocket.deliver(Uint8Array.from(bytes).buffer);
        const deadline=performance.now()+3000;
        while(decoded===before){if(performance.now()>deadline)throw Error('fixture did not decode');await new Promise(r=>setTimeout(r,0));}
        return [...new Uint8Array(await crypto.subtle.digest('SHA-256',decoded.pixels))];
      },[...packet]);
      assert.equal(Buffer.from(actual).toString('hex'),crypto.createHash('sha256').update(rgba).digest('hex'),'actual Lua encoder and browser decoder preserve every RGBA byte');
      count++;
    }
    assert(await page.evaluate(()=>imageAllocations)<=1,'same-resolution playback reuses a single ImageData');
    await page.evaluate(()=>{window.ImageData=NativeImageData;});
    console.log(`PASS ${count} actual LÖVE-encoded frames match browser reconstruction byte for byte`);
  }
  await page.evaluate(()=>stop('diagnostic test')); await pair(); await page.evaluate(()=>testSocket.deliver('p,1'));
  await send(frame('KG01',1,1,125,Buffer.from([1,2,3,255]))); await painted(125);
  await page.evaluate(()=>{profilePaint.painted=performance.now()-400;});
  await send(frame('KG01',1,1,126,Buffer.from([2,3,4,255]))); await painted(126);
  assert(await page.evaluate(()=>Number(testSocket.messages.find(s=>s.startsWith('p,126,')).split(',')[5])>=400), 'long presentation gaps remain visible instead of being discarded as idle');
  await page.evaluate(()=>{window.profileSocket=testSocket;stop('test timeout','contact_timeout');});
  assert(await page.evaluate(()=>profileSocket.messages.some(s=>/^x,contact_timeout,\d+\.\d+,\d+\.\d+,\d+,\d+$/.test(s))), 'browser timeout reasons and queue state are sent before closing');
  console.log('PASS browser lossless delta reconstruction, skipped presentations, resize, validation and bounded decode queue');
};
