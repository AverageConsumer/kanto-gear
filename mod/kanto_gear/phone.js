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
const choices = { layout: ["auto", "wide", "stacked", "custom"], size: ["0.8", "1", "1.2", "1.4"],
  theme: ["pokegear-light", "pokegear-dark", "cgear-light", "cgear-dark"] };
let preferences = { ...defaults };
const presets = ["classic", "lefty", "one-right", "one-left"];
const modules = [...controller.querySelectorAll("[data-module]")];
const layoutVars = modules.flatMap(el => {
  const name = el.dataset.module;
  return (name === "screen" ? ["x", "y", "w", "h"] : ["x", "y", "s"]).map(axis => `--${name}-${axis}`);
});
const freshLayouts = () => ({ landscape: { preset: "classic", vars: {} }, portrait: { preset: "classic", vars: {} } });
let layouts = freshLayouts(), editing = null, selected = null, drag = null;
const editor = document.getElementById("layout-editor"), arrange = document.getElementById("layout-edit");
const sizeField = document.getElementById("layout-size"), presetField = document.getElementById("layout-preset");
const orientation = () => matchMedia("(max-aspect-ratio: 1/1)").matches ? "portrait" : "landscape";
let layoutOrientation = orientation();
function readLayouts(saved) {
  const result = freshLayouts();
  for (const direction of Object.keys(result)) {
    const entry = saved?.[direction];
    if (!entry || !presets.includes(entry.preset)) continue;
    result[direction].preset = entry.preset;
    for (const key of layoutVars) {
      const value = entry.vars?.[key], scale = key.endsWith("-s");
      const minimum = scale ? .7 : /-(w|h)$/.test(key) ? .1 : 0;
      if (typeof value === "number" && Number.isFinite(value) && value >= minimum && value <= (scale ? 1.6 : 1)) {
        result[direction].vars[key] = value;
      }
    }
  }
  return result;
}
try {
  const saved = JSON.parse(localStorage.getItem("kanto-gear-phone-settings"));
  if (saved && saved.remember === true) {
    remember = true;
    for (const key of ["controls", "motion", "haptics", "frame"]) if (typeof saved[key] === "boolean") preferences[key] = saved[key];
    for (const key of Object.keys(choices)) if (choices[key].includes(saved[key])) preferences[key] = saved[key];
    layouts = readLayouts(saved.layouts);
  }
} catch (_) { /* Private browsing may refuse persistent storage. */ }
function applyPreferences() {
  document.body.dataset.theme = preferences.theme;
  controller.dataset.layout = preferences.controls ? preferences.layout : "auto";
  controller.dataset.controls = String(preferences.controls);
  controller.style.setProperty("--button-scale", preferences.size);
  applyLayout();
  for (const key of Object.keys(defaults)) {
    const field = document.getElementById(`setting-${key}`);
    if (typeof defaults[key] === "boolean") field.checked = preferences[key]; else field.value = preferences[key];
  }
  document.getElementById("setting-remember").checked = remember;
  document.getElementById("forget-settings").disabled = !remember;
  const haptics = document.getElementById("setting-haptics");
  haptics.closest("label").hidden = !canVibrate;
  haptics.disabled = !canVibrate;
  document.querySelector('#setting-layout option[value="custom"]').hidden = false;
  arrange.closest(".row").hidden = false;
  const buttonSize = document.getElementById("setting-size");
  buttonSize.disabled = preferences.layout === "custom";
  buttonSize.title = buttonSize.disabled ? "Set each module's size in Arrange" : "";
  refreshControls(); fit();
}
function usable(button) {
  return frame > 0 && socket && socket.readyState === WebSocket.OPEN && !settings.open
    && !editing && preferences.controls && capability !== "none"
    && (button !== "l" && button !== "r" || capability === "gba");
}
function refreshControls() {
  arrange.disabled = !frame || !preferences.controls || capability === "none";
  for (const button of buttons) {
    button.disabled = !usable(button.dataset.button);
    // Arrange all modules even in GB games, so the same layout also fits GBA shoulders.
    if (button.dataset.shoulder !== undefined) button.hidden = capability !== "gba" && !editing;
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
  if (editing) finishLayout(false);
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
      if (editing) finishLayout(false);
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
  if (!frame || settings.open || editing || pointer !== null || event.button !== 0) return;
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
  if (editing) finishLayout(false);
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
    if (remember) localStorage.setItem("kanto-gear-phone-settings", JSON.stringify({ ...preferences, layouts, remember: true }));
    else localStorage.removeItem("kanto-gear-phone-settings");
  } catch (_) {
    remember = false; status.textContent = "This browser could not save settings. They stay in memory.";
  }
}
document.getElementById("forget-settings").addEventListener("click", () => {
  if (!remember) return;
  releaseAll(); remember = false; preferences = { ...defaults }; layouts = freshLayouts(); savePreferences(); applyPreferences();
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

// Layout work happens only on gestures/resizes, never in the frame decoder.
function applyLayout() {
  layoutOrientation = orientation();
  const layout = layouts[layoutOrientation];
  controller.dataset.preset = layout.preset;
  for (const key of layoutVars) controller.style.removeProperty(key);
  if (controller.dataset.layout === "custom") {
    for (const [key, value] of Object.entries(layout.vars)) controller.style.setProperty(key, value);
  }
  presetField.value = layout.preset;
  document.getElementById("layout-reset").disabled = !Object.keys(layout.vars).length;
}
function clearGuides() {
  delete controller.dataset.guideX; delete controller.dataset.guideY;
  controller.style.removeProperty("--guide-x"); controller.style.removeProperty("--guide-y");
}
function selectModule(el) {
  sizeField.removeAttribute("aria-invalid");
  selected = el;
  for (const module of modules) module.classList.toggle("selected", module === el);
  editor.dataset.selection = String(!!el);
  if (!el) return;
  const name = el.dataset.module, values = getComputedStyle(controller);
  if (name === "screen") {
    // Screen dimensions are relative to the preset, not compounded on each selection.
    const w = controller.style.getPropertyValue("--screen-w"), h = controller.style.getPropertyValue("--screen-h");
    controller.style.removeProperty("--screen-w"); controller.style.removeProperty("--screen-h");
    el.layoutBase = { w: parseFloat(values.getPropertyValue("--screen-w")), h: parseFloat(values.getPropertyValue("--screen-h")) };
    if (w) controller.style.setProperty("--screen-w", w);
    if (h) controller.style.setProperty("--screen-h", h);
    sizeField.value = parseFloat(values.getPropertyValue("--screen-w")) / el.layoutBase.w;
  } else sizeField.value = parseFloat(values.getPropertyValue(`--${name}-s`)) || 1;
  sizeField.setAttribute("aria-label", `${name === "screen" ? "Gear screen" : name} size`);
}
function visibleModules() { return modules.filter(el => el.getClientRects().length && !el.hidden); }
function bounds(el) {
  // The fitted image is the visible screen; its allocation may contain empty space.
  const r = (el.dataset.module === "screen" ? canvas : el).getBoundingClientRect();
  const pad = el.dataset.module === "screen" ? 10 : 2;
  return { left: r.left - pad, right: r.right + pad, top: r.top - pad, bottom: r.bottom + pad };
}
function overlaps(a, b) {
  return a.left < b.right - .5 && a.right > b.left + .5 && a.top < b.bottom - .5 && a.bottom > b.top + .5;
}
function collides(el, other) {
  const a = bounds(el), b = bounds(other);
  const round = module => ["a", "b"].includes(module.dataset.module);
  if (!round(el) && !round(other)) return overlaps(a, b);
  const circle = round(el) ? a : b, obstacle = round(el) ? b : a;
  const x = (circle.left + circle.right) / 2, y = (circle.top + circle.bottom) / 2, radius = (circle.right - circle.left) / 2;
  if (round(el) && round(other)) {
    return Math.hypot(x - (obstacle.left + obstacle.right) / 2, y - (obstacle.top + obstacle.bottom) / 2) < radius + (obstacle.right - obstacle.left) / 2;
  }
  return Math.hypot(x - Math.max(obstacle.left, Math.min(x, obstacle.right)), y - Math.max(obstacle.top, Math.min(y, obstacle.bottom))) < radius;
}
function validPlacement(el) {
  const r = bounds(el), area = controller.getBoundingClientRect();
  if (r.left < area.left || r.right > area.right || r.top < area.top || r.bottom > area.bottom) return false;
  if (el.dataset.module === "screen") {
    const allocation = el.getBoundingClientRect();
    if (allocation.left < area.left || allocation.right > area.right || allocation.top < area.top || allocation.bottom > area.bottom) return false;
  }
  const corner = document.getElementById("settings-open").getBoundingClientRect();
  if (overlaps(r, { left: corner.left - 6, right: corner.right + 6, top: corner.top - 6, bottom: corner.bottom + 6 })) return false;
  return visibleModules().every(other => other === el || !collides(el, other));
}
function setLayoutVars(vars) {
  layouts[layoutOrientation].vars = vars;
  applyLayout(); fit();
}
function endDrag(cancel = false) {
  if (!drag) return;
  const { id, vars, el } = drag;
  if (cancel || el.classList.contains("blocked")) setLayoutVars(vars);
  drag = null;
  el.classList.remove("dragging", "blocked"); clearGuides();
  if (controller.hasPointerCapture(id)) controller.releasePointerCapture(id);
  selectModule(el);
}
function finishLayout(save) {
  if (!editing) return;
  endDrag(true);
  if (!save) { preferences.layout = editing.layout; layouts = editing.layouts; }
  editing = null; selectModule(null); clearGuides();
  delete controller.dataset.editing; editor.hidden = true;
  for (const module of modules) module.classList.remove("blocked", "dragging");
  releaseAll();
  if (save) savePreferences();
  applyPreferences();
}
arrange.addEventListener("click", () => {
  if (arrange.disabled || editing) return;
  releaseAll();
  editing = { layout: preferences.layout, layouts: structuredClone(layouts) };
  preferences.layout = "custom";
  settings.close(); controller.dataset.editing = "true"; editor.hidden = false;
  selectModule(null); applyPreferences();
  document.getElementById("layout-cancel").focus();
});
document.getElementById("layout-cancel").addEventListener("click", () => finishLayout(false));
document.getElementById("layout-done").addEventListener("click", () => finishLayout(true));
document.getElementById("layout-deselect").addEventListener("click", () => selectModule(null));
document.getElementById("layout-dock").addEventListener("click", () => {
  editor.dataset.dock = editor.dataset.dock === "top" ? "bottom" : "top";
});
presetField.addEventListener("change", () => {
  if (!editing || !presets.includes(presetField.value)) return;
  endDrag(true); selectModule(null);
  layouts[layoutOrientation] = { preset: presetField.value, vars: {} };
  applyLayout(); fit();
});
document.getElementById("layout-reset").addEventListener("click", () => {
  if (!editing) return;
  endDrag(true); selectModule(null); setLayoutVars({});
});
sizeField.addEventListener("input", () => {
  if (!editing || !selected) return;
  const scale = Number(sizeField.value), name = selected.dataset.module;
  if (!Number.isFinite(scale) || scale < .7 || scale > 1.6) return;
  const previous = { ...layouts[layoutOrientation].vars }, next = { ...previous };
  if (name === "screen") {
    const values = getComputedStyle(controller);
    const w = parseFloat(values.getPropertyValue("--screen-w")), h = parseFloat(values.getPropertyValue("--screen-h"));
    next["--screen-w"] = selected.layoutBase.w * scale;
    next["--screen-h"] = selected.layoutBase.h * scale;
    next["--screen-x"] = parseFloat(values.getPropertyValue("--screen-x")) + (w - next["--screen-w"]) / 2;
    next["--screen-y"] = parseFloat(values.getPropertyValue("--screen-y")) + (h - next["--screen-h"]) / 2;
  } else next[`--${name}-s`] = scale;
  setLayoutVars(next);
  const valid = validPlacement(selected);
  if (!valid) setLayoutVars(previous);
  selected.classList.toggle("blocked", !valid);
  sizeField.setAttribute("aria-invalid", String(!valid));
});
sizeField.addEventListener("change", () => {
  selected?.classList.remove("blocked"); sizeField.removeAttribute("aria-invalid"); selectModule(selected);
});

// Disabled buttons cannot own drags: capture at the work surface and hit-test modules.
controller.addEventListener("pointerdown", event => {
  if (!editing) return;
  event.preventDefault(); event.stopImmediatePropagation();
  if (event.button !== 0 || drag) return;
  const el = visibleModules().reverse().find(module => {
    const r = bounds(module);
    return event.clientX >= r.left && event.clientX <= r.right && event.clientY >= r.top && event.clientY <= r.bottom;
  });
  selectModule(el || null);
  if (!el) return;
  const values = getComputedStyle(controller), name = el.dataset.module;
  drag = { id: event.pointerId, el, vars: { ...layouts[layoutOrientation].vars },
    x: event.clientX, y: event.clientY,
    mx: parseFloat(values.getPropertyValue(`--${name}-x`)), my: parseFloat(values.getPropertyValue(`--${name}-y`)) };
  drag.base = { ...drag.vars };
  if (name === "screen") {
    // Remove the preset's invisible letterbox space before moving the screen.
    // Otherwise a full-height allocation could never move vertically.
    const area = controller.getBoundingClientRect(), image = canvas.getBoundingClientRect(), style = getComputedStyle(el);
    const left = parseFloat(style.paddingLeft), right = parseFloat(style.paddingRight);
    const top = parseFloat(style.paddingTop), bottom = parseFloat(style.paddingBottom);
    drag.mx = (image.left - left - area.left) / area.width;
    drag.my = (image.top - top - area.top) / area.height;
    drag.base["--screen-w"] = (image.width + left + right) / area.width;
    drag.base["--screen-h"] = (image.height + top + bottom) / area.height;
  }
  controller.setPointerCapture(event.pointerId);
}, true);
controller.addEventListener("pointermove", event => {
  if (!editing) return;
  event.preventDefault(); event.stopImmediatePropagation();
  if (!drag || event.pointerId !== drag.id) return;
  if (!drag.el.classList.contains("dragging") && Math.hypot(event.clientX - drag.x, event.clientY - drag.y) < 4) return;
  drag.el.classList.add("dragging");
  const area = controller.getBoundingClientRect(), name = drag.el.dataset.module;
  const next = { ...drag.base,
    [`--${name}-x`]: drag.mx + (event.clientX - drag.x) / area.width,
    [`--${name}-y`]: drag.my + (event.clientY - drag.y) / area.height };
  setLayoutVars(next); clearGuides();
  let r = name === "screen" ? drag.el.getBoundingClientRect() : bounds(drag.el);
  // Clamp visible bounds to the work surface. Other controls and the gear corner
  // remain hard collisions; releasing there restores the pre-drag position.
  for (const [axis, start, end, length] of [["x", "left", "right", "width"], ["y", "top", "bottom", "height"]]) {
    const correction = r[start] < area[start] ? area[start] - r[start] : r[end] > area[end] ? area[end] - r[end] : 0;
    next[`--${name}-${axis}`] += correction / area[length];
  }
  setLayoutVars(next); r = bounds(drag.el);
  if (document.getElementById("layout-snap").checked) {
    const others = visibleModules().filter(el => el !== drag.el).map(bounds);
    for (const [axis, start, end, length] of [["x", "left", "right", "width"], ["y", "top", "bottom", "height"]]) {
      const targets = [area[start], (area[start] + area[end]) / 2, area[end],
        ...others.flatMap(other => [other[start], (other[start] + other[end]) / 2, other[end]])];
      let best = null;
      for (const edge of [r[start], (r[start] + r[end]) / 2, r[end]]) for (const target of targets) {
        const delta = target - edge;
        if (Math.abs(delta) <= 8 && (!best || Math.abs(delta) < Math.abs(best.delta))) best = { delta, target };
      }
      if (!best) continue;
      next[`--${name}-${axis}`] += best.delta / area[length];
      controller.setAttribute(`data-guide-${axis}`, "true");
      controller.style.setProperty(`--guide-${axis}`, (best.target - area[start]) / area[length]);
    }
    setLayoutVars(next);
  }
  drag.el.classList.toggle("blocked", !validPlacement(drag.el));
}, true);
for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) controller.addEventListener(name, event => {
  if (!editing) return;
  event.preventDefault(); event.stopImmediatePropagation();
  if (drag?.id === event.pointerId) endDrag(name !== "pointerup");
}, true);
controller.addEventListener("click", event => {
  if (editing) { event.preventDefault(); event.stopImmediatePropagation(); }
}, true);
window.addEventListener("keydown", event => {
  if (editing && event.key === "Escape") { event.preventDefault(); finishLayout(false); }
});
window.addEventListener("resize", () => {
  endDrag(true); selectModule(null); applyLayout(); fit();
});
window.addEventListener("blur", () => endDrag(true));
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
