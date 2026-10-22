(function () {
  "use strict";

  var root = document.documentElement;

  function store(key, value) {
    try {
      if (value === undefined) return localStorage.getItem(key);
      localStorage.setItem(key, value);
    } catch (e) { return null; }
  }

  /* ---------- Look and theme, like Gear's Options ---------- */

  var look = root.dataset.look || "pokegear";
  var theme = root.dataset.theme || "auto";
  var shot = document.getElementById("home-shot");
  var screen = document.getElementById("screen");

  function isDay() {
    var h = new Date().getHours();
    return h >= 6 && h < 18;
  }

  function applySkin(animate) {
    var mode = theme === "auto" ? (isDay() ? "light" : "dark") : theme;
    var skin = look + "-" + mode;
    var changed = root.dataset.skin !== skin;
    root.dataset.skin = skin;
    root.dataset.look = look;
    root.dataset.theme = theme;
    shot.src = "img/4.0-home-" + skin + ".png";
    document.querySelectorAll("[data-look]").forEach(function (b) {
      if (b.tagName === "BUTTON") {
        b.setAttribute("aria-checked", String(b.dataset.look === look));
        b.tabIndex = b.dataset.look === look ? 0 : -1;
      }
    });
    document.querySelectorAll("button[data-theme]").forEach(function (b) {
      b.setAttribute("aria-checked", String(b.dataset.theme === theme));
      b.tabIndex = b.dataset.theme === theme ? 0 : -1;
    });
    if (animate && changed) {
      screen.classList.remove("swap");
      void screen.offsetWidth;
      screen.classList.add("swap");
    }
    tickClock();
  }

  document.getElementById("look").addEventListener("click", function (e) {
    var b = e.target.closest("button");
    if (!b || b.getAttribute("aria-checked") === "true") return;
    if (b.dataset.look) { look = b.dataset.look; store("kg-look", look); }
    if (b.dataset.theme) { theme = b.dataset.theme; store("kg-theme", theme); }
    applySkin(true);
  });
  document.getElementById("look").addEventListener("keydown", function (e) {
    if (e.altKey || e.ctrlKey || e.metaKey) return;
    var group = e.target.closest('[role="radiogroup"]');
    if (!group) return;
    var buttons = Array.prototype.slice.call(group.querySelectorAll("button"));
    var i = buttons.indexOf(e.target);
    if (i < 0) return;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") i = (i + 1) % buttons.length;
    else if (e.key === "ArrowLeft" || e.key === "ArrowUp") i = (i - 1 + buttons.length) % buttons.length;
    else if (e.key === "Home") i = 0;
    else if (e.key === "End") i = buttons.length - 1;
    else return;
    e.preventDefault();
    var b = buttons[i];
    if (b.dataset.look) { look = b.dataset.look; store("kg-look", look); }
    if (b.dataset.theme) { theme = b.dataset.theme; store("kg-theme", theme); }
    applySkin(true);
    b.focus();
  });

  /* Options on the Home screen jumps to the look controls */
  var lookBox = document.getElementById("look");
  document.getElementById("hot-options").addEventListener("click", function () {
    lookBox.classList.remove("flash");
    void lookBox.offsetWidth;
    lookBox.classList.add("flash");
    var first = lookBox.querySelector('button[aria-checked="true"]');
    if (first) first.focus({ preventScroll: false });
  });

  /* ---------- Screen tips ---------- */

  var tip = document.getElementById("screen-tip");
  var tipDefault = tip.textContent;
  document.querySelectorAll(".hotspots [data-tip]").forEach(function (el) {
    function show() { tip.textContent = el.dataset.tip; }
    function hide() { tip.textContent = tipDefault; }
    el.addEventListener("mouseenter", show);
    el.addEventListener("focus", show);
    el.addEventListener("mouseleave", hide);
    el.addEventListener("blur", hide);
  });

  /* ---------- Clock and battery ---------- */

  var ch = document.getElementById("clock-h");
  var cm = document.getElementById("clock-m");
  var sky = document.getElementById("sky");
  function pad(n) { return (n < 10 ? "0" : "") + n; }
  function tickClock() {
    var d = new Date();
    ch.textContent = pad(d.getHours());
    cm.textContent = pad(d.getMinutes());
    sky.className = "sky " + (isDay() ? "sun" : "moon");
  }
  setInterval(function () {
    if (theme === "auto") applySkin(false); else tickClock();
  }, 15000);

  var cells = document.querySelectorAll(".battery i");
  var back = document.querySelector(".bar-back");
  function onScroll() {
    var max = document.documentElement.scrollHeight - innerHeight;
    var left = max > 0 ? 1 - scrollY / max : 1;
    var on = Math.max(1, Math.ceil(left * cells.length));
    cells.forEach(function (c, i) { c.classList.toggle("on", i < on); });
    back.hidden = scrollY < innerHeight * 0.6;
  }
  addEventListener("scroll", onScroll, { passive: true });
  addEventListener("resize", onScroll);

  /* header title follows the section you are in, like the app name on Gear */
  var title = document.getElementById("bar-title");
  var sections = document.querySelectorAll("[data-title]");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) title.textContent = en.target.dataset.title;
      });
    }, { rootMargin: "-40% 0px -55% 0px" });
    sections.forEach(function (s) { io.observe(s); });
  }

  /* ---------- Pickers ---------- */

  function picker(id, initial, render) {
    var group = document.getElementById(id);
    var buttons = group.querySelectorAll("button");
    function select(k, focus) {
      buttons.forEach(function (b) {
        var on = b.dataset.k === k;
        b.setAttribute("aria-checked", String(on));
        b.tabIndex = on ? 0 : -1;
        if (on && focus) b.focus();
      });
      render(k);
    }
    group.addEventListener("click", function (e) {
      var b = e.target.closest("button");
      if (b && b.getAttribute("aria-checked") !== "true") select(b.dataset.k);
    });
    group.addEventListener("keydown", function (e) {
      if (e.altKey || e.ctrlKey || e.metaKey) return;
      var list = Array.prototype.slice.call(buttons);
      var i = list.findIndex(function (b) { return b.getAttribute("aria-checked") === "true"; });
      if (e.key === "ArrowRight" || e.key === "ArrowDown") i = (i + 1) % list.length;
      else if (e.key === "ArrowLeft" || e.key === "ArrowUp") i = (i - 1 + list.length) % list.length;
      else if (e.key === "Home") i = 0;
      else if (e.key === "End") i = list.length - 1;
      else return;
      e.preventDefault();
      select(list[i].dataset.k, true);
    });
    select(initial);
  }

  var discovery = {
    vanilla: [1, "Strictly the original game. No live area map, encounter guide, battle hints or completion totals. Touch controls, caught Pokédex entries and your notes stay."],
    guide: [4, "Help for places you have visited, wild encounters, Pokédex research and battles. Hidden items still need a scan, and unvisited places stay hidden."],
    everything: [8, "Everything Gear knows, including hidden items, unvisited places, future tasks, genes and egg contents. Nothing in the game gets unlocked."],
    custom: [5, "Start from any preset and flip single switches for exploration, Pokédex, battle, partner data and Stamps. Each switch explains what it shows."]
  };
  var dOut = document.getElementById("disc-out");
  var dCells = document.querySelectorAll("#disc-meter i");
  picker("disc", "guide", function (k) {
    dOut.textContent = discovery[k][1];
    dCells.forEach(function (c, i) { c.classList.toggle("on", i < discovery[k][0]); });
  });

  var battle = {
    companion: ["The original battle with HP, text and menus.", "You, VS and Foe, DS-style commands and touch menus. The D-pad stays with the game."],
    info: ["The original battle and menus.", "What you are up against. Pick either foe in a double battle."],
    gear: ["The battle scene and HP bars.", "Menus, moves, party, Bag and battle text, with D-pad focus down here."],
    full: ["Just the battle scene.", "Every control plus all HP bars, for all four battlers in doubles."]
  };
  var bGame = document.getElementById("b-game");
  var bGear = document.getElementById("b-gear");
  picker("battle", "gear", function (k) {
    bGame.textContent = battle[k][0];
    bGear.textContent = battle[k][1];
  });

  var layouts = {
    swap: "One screen that flips between the game and Gear. Auto Battle Screen can switch to Gear for choices and back for animations.",
    combined: "Both in one window: stacked, side by side, or Gear as a corner overlay.",
    separate: "Gear in its own window. Made for dual-screen handhelds, a second desktop window or another monitor.",
    phone: "Gear on your phone over local Wi-Fi, with optional touch controls. Experimental."
  };
  var stage = document.getElementById("stage");
  var lText = document.getElementById("layout-txt");
  picker("layout", "separate", function (k) {
    stage.dataset.k = k;
    lText.textContent = layouts[k];
  });

  applySkin(false);
  onScroll();
})();
