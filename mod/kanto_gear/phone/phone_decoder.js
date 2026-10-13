"use strict";
// Decode and inflate away from touch/layout work. Pixel storage is bounded and reused.
let queue = [], decoding = false, decoded = null, spare = null, pool = [], made = 0, outputSize = 0;
self.onmessage = event => {
  if (event.data.recycle) {
    if (event.data.recycle.byteLength === outputSize) pool.push(event.data.recycle);
    else made--;
    return;
  }
  if (queue.length >= 32) { postMessage({error:"Gear video queue exceeded its limit. Reconnect to refresh it."}); return; }
  queue.push(event.data);
  void decode();
};
async function decode() {
  if (decoding) return;
  decoding = true;
  try {
    while (queue.length) {
      const pending = queue.shift(), packet = pending.bytes;
      const profileStarted = pending.profile ? performance.now() : 0;
      const data = new DataView(packet);
      if (data.byteLength < 12) throw Error("Invalid Gear frame");
      let magic = data.getUint32(0);
      const timed = magic >= 0x4b473131 && magic <= 0x4b473136;
      if (timed) magic -= 0x100;
      const width = data.getUint16(4), height = data.getUint16(6), id = data.getUint32(8);
      const size = width * height * 4;
      const copies = magic === 0x4b473035 || magic === 0x4b473036;
      const delta = copies || magic === 0x4b473033 || magic === 0x4b473034, baseAt = timed ? 16 : 12;
      const offset = baseAt + (delta ? 4 : 0);
      const limit = delta ? size + height * (copies ? 30 : 6) + 2 : size;
      if (!width || !height || width > 240 || height > 216 || !id || data.byteLength < offset
          || data.byteLength > limit + offset) throw Error("Invalid Gear frame");
      if (delta && (!decoded || decoded.id !== data.getUint32(baseAt) || decoded.width !== width || decoded.height !== height))
        throw Error("Gear frame needs a matching previous image. Reconnect to refresh it.");
      let body;
      if (magic === 0x4b473032 || magic === 0x4b473033 || magic === 0x4b473035) {
        if (typeof DecompressionStream !== "function") throw Error("Please use a current browser for compressed Gear frames");
        body = new Uint8Array(limit);
        const reader = new Blob([new Uint8Array(packet, offset)]).stream().pipeThrough(new DecompressionStream("deflate")).getReader();
        let length = 0;
        try {
          for (;;) {
            const {value, done} = await reader.read();
            if (done) break;
            if (length + value.length > limit) throw Error("Invalid Gear frame size");
            body.set(value, length); length += value.length;
          }
          body = body.subarray(0, length);
        } finally { await reader.cancel(); }
      } else if (magic === 0x4b473031 || magic === 0x4b473034 || magic === 0x4b473036) {
        body = new Uint8Array(packet, offset);
      } else throw Error("Invalid Gear frame");

      let pixels;
      if (delta) {
        if (body.length < 2) throw Error("Invalid Gear patch");
        const patches = new DataView(body.buffer, body.byteOffset, body.byteLength), rows = patches.getUint16(0);
        if (!rows || rows > height * (copies ? 3 : 1)) throw Error("Invalid Gear patch");
        pixels = spare && spare.length === size ? spare : new Uint8ClampedArray(size);
        pixels.set(decoded.pixels);
        let at = 2, previousRow = -1, previousEnd = 0;
        for (let row = 0; row < rows; row++) {
          if (at + (copies ? 10 : 6) > body.length) throw Error("Invalid Gear patch");
          const y = patches.getUint16(at), x = patches.getUint16(at + 2), count = patches.getUint16(at + 4); at += 6;
          const sy = copies ? patches.getUint16(at) : 65535, sx = copies ? patches.getUint16(at + 2) : 0;
          if (copies) at += 4;
          const offset = (y * width + x) * 4;
          if ((!copies && y <= previousRow) || offset < previousEnd || y >= height || !count || x + count > width)
            throw Error("Invalid Gear patch");
          if (sy === 65535) {
            if (at + count * 4 > body.length) throw Error("Invalid Gear patch");
            pixels.set(body.subarray(at, at + count * 4), offset); at += count * 4;
          } else {
            if (sy >= height || sx + count > width) throw Error("Invalid Gear patch");
            const source = (sy * width + sx) * 4;
            pixels.set(decoded.pixels.subarray(source, source + count * 4), offset);
          }
          previousEnd = offset + count * 4; previousRow = y;
        }
        if (at !== body.length) throw Error("Invalid Gear patch");
      } else {
        if (body.length !== size) throw Error("Invalid Gear frame size");
        pixels = spare && spare.length === size ? spare : new Uint8ClampedArray(size);
        pixels.set(body);
      }

      spare = decoded && decoded.pixels;
      decoded = {pixels, width, height, id};
      if (outputSize !== size) { made -= pool.length; pool = []; outputSize = size; }
      let output = pool.pop();
      if (!output && made < 10) { output = new ArrayBuffer(size); made++; }
      if (output) new Uint8ClampedArray(output).set(pixels);
      postMessage({id, width, height, pixels:output, stamp:timed ? data.getUint32(12) : null,
        decodeMs:pending.profile ? performance.now() - profileStarted : undefined,
        arrived:pending.arrived}, output ? [output] : []);
    }
  } catch (error) { queue = []; postMessage({error:error.message || "Invalid Gear frame"}); }
  finally { decoding = false; }
}
