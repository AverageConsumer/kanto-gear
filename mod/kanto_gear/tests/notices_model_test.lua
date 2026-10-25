-- Gear notices model: one card at a time, merging, pacing and unread dots.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local N = assert(loadfile(root .. "/features/notices.lua"))()
local passed, failed = 0, 0
local function check(condition, label)
  if condition then passed = passed + 1 else failed = failed + 1; io.stderr:write("FAIL " .. label .. "\n") end
end

local s = N.new()
check(not N.pending(s), "a new queue is empty")
N.post(s, { key = "a", title = "A" }, 0)
N.post(s, { key = "b", title = "B" }, 0)
check(N.advance(s, 0, false) == nil, "nothing shows while the screen is busy")
local card = N.advance(s, 1, true)
check(card and card.title == "A" and card.fresh, "the oldest card shows first once the screen is free")
check(N.presence(card, 1) == 0 and N.presence(card, 1 + N.ENTER / 2) > 0 and N.presence(card, 1 + N.ENTER + 0.001) == 1,
  "a card slides in")
check(N.advance(s, 2, true) == card, "one card at a time")
local leave = 1 + N.ENTER + N.SHOW + N.EXIT
check(N.presence(card, leave - N.EXIT / 2) < 1, "a card slides out")
local next = N.advance(s, leave + 0.001, true)
check(next and next.title == "B", "the next card follows")

-- The same key merges and refreshes instead of stacking.
local m = N.new()
N.post(m, { key = "shiny", title = "SHINY", detail = "ZUBAT" }, 0)
N.post(m, { key = "shiny", title = "SHINY", detail = "GEODUDE" }, 0)
check(#m.queue == 1 and m.queue[1].detail == "GEODUDE", "a waiting card takes the newer text")
local shown = N.advance(m, 0, true)
N.post(m, { key = "shiny", title = "SHINY", detail = "ONIX" }, 3)
check(shown.detail == "ONIX" and N.presence(shown, 3 + N.SHOW - 0.1) == 1, "a showing card refreshes and stays up")

-- Dismiss lets the card leave at once.
check(N.dismiss(m, 4) and N.presence(shown, 4 + N.EXIT + 0.01) == 0, "a tapped card leaves")
check(N.advance(m, 4 + N.EXIT + 0.01, true) == nil and not N.pending(m), "nothing is left after it")

-- The queue stays bounded, keeping the newest.
local q = N.new()
for index = 1, N.LIMIT + 3 do N.post(q, { key = "k" .. index, title = "T" }, 0) end
check(#q.queue == N.LIMIT and q.queue[#q.queue].key == "k" .. (N.LIMIT + 3), "the newest cards are kept")
check(N.post(q, { key = "x" }, 0) == nil, "a card needs a title")

-- Unread dots.
N.markUnread(q, "shiny")
check(q.unread.shiny and N.markRead(q, "shiny") and not q.unread.shiny, "opening an app clears its dot")
check(not N.markRead(q, "shiny"), "a clear dot stays clear")

io.write(string.format("%d/%d checks passed  (notices model)\n", passed, passed + failed))
if failed > 0 then os.exit(1) end
