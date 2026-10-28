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

local h = N.new()
local first = { title = "FIRST", detail = "ORIGINAL", onOpen = function() end }
check(N.remember(h, first, 200) and not N.remember(h, first, 201), "one history entry per displayed card")
first.detail = "CHANGED"
N.remember(h, { title = "SECOND" }, 100)
check(h.history[1].title == "FIRST" and h.history[2].title == "SECOND",
  "display order survives a backwards wall-clock change")
check(h.history[1].detail == "ORIGINAL" and h.history[1].onOpen == nil,
  "history is a presentation snapshot without live callbacks")
for index = 1, 105 do N.remember(h, { title = tostring(index) }, index) end
check(#h.history == 100 and h.history[1].title == "6" and h.history[100].title == "105",
  "history retains the latest 100 displayed messages")
local loaded = N.history({ false, {title="SAFE", timestamp=0/0, game={}}, {title="LAST", timestamp=120} })
check(#loaded == 2 and loaded[1].timestamp == nil and loaded[1].game == nil and loaded[2].timestamp == 120,
  "stored history rejects malformed entries and unsafe fields")
check(#N.history(false) == 0, "invalid stored history starts empty")

local read = N.new()
local a, b = {title="A",app="shiny"}, {title="B",app="shiny"}
N.remember(read,a,1); N.remember(read,b,2); N.markUnread(read,"shiny")
read.current = a
local firstEntry, secondEntry = read.history[1], read.history[2]
check(N.readHistory(read,firstEntry) and read.current == nil,
  "reading a displayed notice removes its paused card too")
check(read.unread.shiny and #read.history==1 and read.history[1]==secondEntry,
  "reading one notice preserves another unread notice from the same app")
check(not N.readHistory(read,firstEntry) and #read.history==1,
  "a stale row cannot remove the notification that moved into its position")
read.queue={{title="WAITING",app="shiny"}}
check(N.readHistory(read,secondEntry) and read.unread.shiny,
  "an unseen queued notice retains the app dot")
read.queue={}; N.remember(read,{title="C",app="shiny"},3)
read.unreadOnly.shiny=true
check(N.readHistory(read,read.history[1]) and read.unread.shiny,
  "a dot-only notice is independent of the displayed list")
N.remember(read,{title="D",app="shiny"},4)
check(N.markRead(read,"shiny") and read.history[1].read and not read.unreadOnly.shiny,
  "opening the app marks all its stored records read and clears dot-only news")
check(N.history(read.history)[1].read, "per-entry read state survives storage normalization")

io.write(string.format("%d/%d checks passed  (notices model)\n", passed, passed + failed))
if failed > 0 then os.exit(1) end
