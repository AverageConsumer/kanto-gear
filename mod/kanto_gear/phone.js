"use strict";
const screen = document.getElementById("gear-slot"), form = document.getElementById("pair");
const canvas = document.getElementById("gear"), context = canvas.getContext("2d", { alpha: false });
const status = document.getElementById("status"), connect = document.getElementById("connect");
let socket, frame = 0, pointer = null, lastContact = 0, heartbeat, generation = 0;
const controller = document.getElementById("controller"), settings = document.getElementById("settings");
const buttons = [...document.querySelectorAll("[data-button]")];
const pointers = new Map(), held = new Set();
let capability = "none", authenticated = false;
// Fragments are not sent in HTTP requests. Remove the bearer key before rendering
// or opening a socket; it lives only in this page's memory until Connect.
function readPairingLink() {
  const key = /^#pair=([a-f0-9]{32})$/.exec(location.hash)?.[1] || null;
  if (location.hash) history.replaceState(null, "", location.pathname);
  return key;
}
let qrCredential = readPairingLink();
let remember = false, hapticActive = false;
const canVibrate = typeof navigator.vibrate === "function";
const defaults = { controls: true, motion: true, haptics: true, frame: true, layout: "auto", size: "1", theme: "pokegear-dark" };
const choices = { layout: ["auto", "wide", "stacked"], size: ["0.8", "1", "1.2", "1.4"],
  theme: ["pokegear-light", "pokegear-dark", "cgear-light", "cgear-dark"] };
let preferences = { ...defaults };
try {
  const saved = JSON.parse(localStorage.getItem("kanto-gear-phone-settings"));
  if (saved && saved.remember === true) {
    remember = true;
    for (const key of ["controls", "motion", "haptics", "frame"]) if (typeof saved[key] === "boolean") preferences[key] = saved[key];
    for (const key of Object.keys(choices)) if (choices[key].includes(saved[key])) preferences[key] = saved[key];
  }
} catch (_) { /* Private browsing may refuse persistent storage. */ }
function applyPreferences() {
  document.body.dataset.theme = preferences.theme;
  controller.dataset.layout = preferences.layout;
  controller.dataset.controls = String(preferences.controls);
  controller.style.setProperty("--button-scale", preferences.size);
  for (const key of Object.keys(defaults)) {
    const field = document.getElementById(`setting-${key}`);
    if (typeof defaults[key] === "boolean") field.checked = preferences[key]; else field.value = preferences[key];
  }
  document.getElementById("setting-remember").checked = remember;
  document.getElementById("forget-settings").disabled = !remember;
  const haptics = document.getElementById("setting-haptics");
  haptics.closest("label").hidden = !canVibrate;
  haptics.disabled = !canVibrate;
  refreshControls(); fit();
}
function usable(button) {
  return frame > 0 && socket && socket.readyState === WebSocket.OPEN && !settings.open
    && preferences.controls && capability !== "none"
    && (button !== "l" && button !== "r" || capability === "gba");
}
function refreshControls() {
  for (const button of buttons) {
    button.disabled = !usable(button.dataset.button);
    if (button.dataset.shoulder !== undefined) button.hidden = capability !== "gba";
  }
}
function pulse() {
  if (!canVibrate || !preferences.haptics || document.hidden) return;
  try { hapticActive = navigator.vibrate(8) === true; } catch (_) { /* Input must still work if vibration is denied. */ }
}
function releaseAll() {
  if (hapticActive) {
    try { navigator.vibrate(0); } catch (_) {}
    hapticActive = false;
  }
  send("release");
  pointers.clear(); held.clear(); pointer = null;
  for (const button of buttons) button.classList.remove("held");
}
function updateHeld() {
  const next = new Set([...pointers.values()].filter(Boolean));
  for (const button of held) if (!next.has(button)) send(`b,${button},0`);
  let pressed = false;
  for (const button of next) if (!held.has(button)) { send(`b,${button},1`); pressed = true; }
  if (pressed) pulse();
  held.clear(); for (const button of next) held.add(button);
  for (const button of buttons) button.classList.toggle("held", held.has(button.dataset.button));
}
let pendingPacket = null, decoding = false, paint = null, animation = 0;
let paintedAt = 0, fpsAt = 0, paintedFrames = 0, fps = 0;
function fit() {
  if (!canvas.width || !canvas.height) return;
  const scale = Math.max(0, Math.min(screen.clientWidth / canvas.width, screen.clientHeight / canvas.height));
  canvas.style.width = `${canvas.width * scale}px`;
  canvas.style.height = `${canvas.height * scale}px`;
}
function send(text) { if (socket && socket.readyState === WebSocket.OPEN) socket.send(text); }
function stop(message) {
  releaseAll(); generation++;
  if (socket) { socket.onclose = socket.onopen = socket.onerror = socket.onmessage = null; socket.close(); socket = null; }
  clearInterval(heartbeat);
  cancelAnimationFrame(animation);
  pendingPacket = paint = null; decoding = false; animation = 0;
  paintedAt = fpsAt = paintedFrames = fps = 0;
  frame = 0; pointer = null;
  authenticated = false; capability = "none"; controller.hidden = true; refreshControls();
  canvas.style.display = "none"; form.hidden = false; connect.disabled = false;
  status.textContent = message;
  if (!qrCredential) {
    document.getElementById("pin").required = true;
    document.querySelector(".code").hidden = false;
    document.querySelector(".pin-label").hidden = false;
    document.querySelector("#pair h1").textContent = "Pair your Gear";
  }
}
function paintFrame(current) {
  animation = requestAnimationFrame(() => {
    animation = 0;
    if (current !== generation || document.hidden) return;
    if (paint) {
      const image = paint; paint = null;
      const resized = canvas.width !== image.width || canvas.height !== image.height;
      if (resized) { canvas.width = image.width; canvas.height = image.height; }
      context.putImageData(new ImageData(image.pixels, image.width, image.height), 0, 0);
      frame = image.id; lastContact = performance.now();
      if (lastContact - paintedAt > 250) { fpsAt = lastContact; paintedFrames = 0; fps = 0; }
      paintedFrames++;
      if (lastContact - fpsAt >= 1000) {
        fps = Math.round((paintedFrames - 1) * 1000 / (lastContact - fpsAt));
        fpsAt = lastContact; paintedFrames = 1;
      }
      paintedAt = lastContact;
      const first = controller.hidden;
      form.hidden = true; controller.hidden = false; canvas.style.display = "block";
      if (first) refreshControls();
      if (first || resized) fit();
      status.textContent = `Connected${fps ? ` · ${fps} FPS` : ""} · tap or swipe Gear`;
      send(`a,${frame}`);
    }
    paintFrame(current);
  });
}
async function decodeFrames(current) {
  if (decoding) return;
  decoding = true;
  try {
    while (pendingPacket && current === generation) {
      const packet = pendingPacket; pendingPacket = null;
      const data = new DataView(packet);
      if (data.byteLength < 12) throw Error("Invalid Gear frame");
      const magic = data.getUint32(0), width = data.getUint16(4), height = data.getUint16(6), id = data.getUint32(8);
      const size = width * height * 4;
      if (!width || !height || width > 240 || height > 216 || !id || data.byteLength > size + 12) throw Error("Invalid Gear frame");
      let pixels;
      if (magic === 0x4b473032) {
        if (typeof DecompressionStream !== "function") throw Error("Please use a current browser for compressed Gear frames");
        pixels = new Uint8ClampedArray(size);
        const reader = new Blob([packet.slice(12)]).stream().pipeThrough(new DecompressionStream("deflate")).getReader();
        let offset = 0;
        try {
          for (;;) {
            const {value, done} = await reader.read();
            if (done) break;
            if (offset + value.length > size) throw Error("Invalid Gear frame size");
            pixels.set(value, offset); offset += value.length;
          }
          if (offset !== size) throw Error("Invalid Gear frame size");
        } finally { await reader.cancel(); }
      } else if (magic === 0x4b473031 && data.byteLength === size + 12) {
        pixels = new Uint8ClampedArray(packet, 12);
      } else throw Error("Invalid Gear frame");
      if (current !== generation) return;
      if (pendingPacket) continue;
      paint = {pixels, width, height, id};
    }
  } catch (error) {
    if (current === generation) stop(error.message || "Invalid Gear frame");
  } finally { if (current === generation) decoding = false; }
}
form.addEventListener("submit", event => {
  event.preventDefault();
  if (!form.reportValidity()) return;
  let credential = qrCredential || document.getElementById("pin").value;
  qrCredential = null;
  document.getElementById("pin").value = "";
  stop("Connecting…"); connect.disabled = true;
  const current = generation;
  socket = new WebSocket(`ws://${location.host}/gear`);
  socket.binaryType = "arraybuffer";
  socket.onopen = () => {
    lastContact = performance.now();
    send(`auth,${credential}`); credential = null;
    heartbeat = setInterval(() => {
      if (performance.now() - lastContact > 1500) { stop("Connection lost. Check the game, then reconnect."); return; }
      if (authenticated) send(`h,${frame}`);
      if (frame && performance.now() - paintedAt > 500) status.textContent = "Connected · idle · tap or swipe Gear";
    }, 250);
    status.textContent = "Connected · waiting for Gear";
  };
  socket.onmessage = event => {
    if (current !== generation) return;
    if (event.data === "ok" && !authenticated) {
      authenticated = true; lastContact = performance.now();
      paintFrame(current); send("h,0");
      status.textContent = "Connected · waiting for Gear"; return;
    }
    if (!authenticated) return;
    if (event.data === "h") { lastContact = performance.now(); return; }
    if (["c,gb", "c,gba", "c,none"].includes(event.data)) {
      releaseAll(); capability = event.data.slice(2); refreshControls(); fit(); return;
    }
    if (!(event.data instanceof ArrayBuffer)) return;
    pendingPacket = event.data;
    void decodeFrames(current);
  };
  socket.onclose = () => stop("Disconnected. Scan the current QR or enter its code. Codes expire after 5 minutes and work once.");
  socket.onerror = () => stop("Could not connect. Check the code, Wi-Fi and game. After repeated attempts, wait one minute.");
});
function touch(action, event) {
  const rect = canvas.getBoundingClientRect();
  const x = Math.max(0, Math.min(canvas.width - 1, Math.floor((event.clientX - rect.left) * canvas.width / rect.width)));
  const y = Math.max(0, Math.min(canvas.height - 1, Math.floor((event.clientY - rect.top) * canvas.height / rect.height)));
  send(`${action},${x},${y},${frame}`);
}
canvas.addEventListener("pointerdown", event => {
  if (!frame || settings.open || pointer !== null || event.button !== 0) return;
  event.preventDefault(); pointer = event.pointerId;
  canvas.setPointerCapture(pointer); touch("down", event);
});
canvas.addEventListener("pointermove", event => {
  if (pointer === event.pointerId) { event.preventDefault(); touch("move", event); }
});
for (const [name, action] of [["pointerup", "up"], ["pointercancel", "cancel"], ["lostpointercapture", "cancel"]]) {
  canvas.addEventListener(name, event => {
    if (pointer !== event.pointerId) return;
    event.preventDefault(); touch(action, event); pointer = null;
  });
}
document.addEventListener("visibilitychange", () => { if (document.hidden) stop("Page paused. Return to the game, then reconnect."); });
new ResizeObserver(fit).observe(screen);

// Each finger owns a button; multiple fingers on one button still make one hold.
for (const button of buttons) {
  button.addEventListener("pointerdown", event => {
    if (event.button !== 0 || !usable(button.dataset.button)) return;
    event.preventDefault();
    pointers.set(event.pointerId, button.dataset.button);
    button.setPointerCapture(event.pointerId); updateHeld();
  });
  button.addEventListener("pointermove", event => {
    if (!pointers.has(event.pointerId)) return;
    event.preventDefault();
    // Slide between direction keys without lifting the thumb. A gap releases it.
    if (button.dataset.dpad !== undefined) {
      const target = document.elementFromPoint(event.clientX, event.clientY)?.closest("[data-dpad][data-button]");
      pointers.set(event.pointerId, target && usable(target.dataset.button) ? target.dataset.button : null);
      updateHeld();
    }
  });
  for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) {
    button.addEventListener(name, event => {
      if (!pointers.has(event.pointerId)) return;
      event.preventDefault(); pointers.delete(event.pointerId); updateHeld();
    });
  }
  // Keyboard/screen-reader activation is a bounded tap, not a latched hold.
  button.addEventListener("click", event => {
    if (event.detail !== 0 || !usable(button.dataset.button) || held.has(button.dataset.button)) return;
    send(`b,${button.dataset.button},1`); send(`b,${button.dataset.button},0`); pulse();
  });
}
document.getElementById("settings-open").addEventListener("click", () => {
  releaseAll(); settings.showModal(); refreshControls();
});
document.getElementById("settings-close").addEventListener("click", () => settings.close());
settings.addEventListener("close", refreshControls);
settings.addEventListener("change", event => {
  const key = event.target.id.replace("setting-", "");
  if (key === "remember") {
    remember = event.target.checked; savePreferences(); applyPreferences(); return;
  }
  if (!Object.hasOwn(defaults, key)) return;
  const toggle = typeof defaults[key] === "boolean";
  const value = toggle ? event.target.checked : event.target.value;
  if (!toggle && !choices[key].includes(value)) return;
  releaseAll(); preferences[key] = value; savePreferences(); applyPreferences();
});
function savePreferences() {
  try {
    if (remember) localStorage.setItem("kanto-gear-phone-settings", JSON.stringify({ ...preferences, remember: true }));
    else localStorage.removeItem("kanto-gear-phone-settings");
  } catch (_) {
    remember = false; status.textContent = "This browser could not save settings. They stay in memory.";
  }
}
document.getElementById("forget-settings").addEventListener("click", () => {
  if (!remember) return;
  releaseAll(); remember = false; preferences = { ...defaults }; savePreferences(); applyPreferences();
});
document.getElementById("disconnect").addEventListener("click", () => {
  settings.close(); stop("Disconnected. Enter the code to reconnect.");
});
const fullscreen = document.getElementById("fullscreen");
fullscreen.disabled = !document.documentElement.requestFullscreen;
fullscreen.addEventListener("click", async () => {
  releaseAll();
  try {
    if (document.fullscreenElement) await document.exitFullscreen();
    else await document.documentElement.requestFullscreen();
  } catch (_) { status.textContent = "Fullscreen is unavailable in this browser."; }
});
window.addEventListener("blur", releaseAll);
window.addEventListener("pagehide", () => stop("Page closed. Reconnect to play."));
window.addEventListener("resize", releaseAll);
applyPreferences();

function showPairingLink() {
  document.getElementById("pin").required = false;
  document.querySelector(".code").hidden = true;
  document.querySelector(".pin-label").hidden = true;
  document.querySelector("#pair h1").textContent = "Ready to pair";
  status.textContent = "QR received \u00b7 tap Connect to share Gear and enable controls";
}

if (qrCredential) showPairingLink();
window.addEventListener("hashchange", () => {
  const key = readPairingLink();
  if (!key) return;
  qrCredential = key; stop("QR received"); showPairingLink();
});
