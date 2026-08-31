local Home = assert(loadfile("mod/kanto_gear/home_layout.lua"))()

local catalog = {
  explorer = { installed = true, kind = "explorer", columns = 7 },
  party = { installed = true, kind = "party", columns = 5 },
  bag = { installed = true, columns = 3, label = "BAG" },
  notes = { installed = true, columns = 3, label = "NOTES" },
}
local layout = { tiles = {
  { id = "explorer", page = 1, column = 1, row = 1 },
  { id = "party", page = 1, column = 8, row = 1 },
  { id = "bag", page = 1, column = 1, row = 2 },
} }

assert(Home.canPlace(layout, catalog, "notes", 1, 4, 2))
assert(not Home.canPlace(layout, catalog, "notes", 1, 2, 2))
assert(not Home.canPlace(layout, catalog, "party", 1, 10, 2))
assert(Home.place(layout, catalog, "notes", 3, 10, 2))
assert(Home.pageCount(layout) == 3)
assert(not Home.place(layout, catalog, "notes", 1, 1, 1))
local notes = assert(Home.find(layout, "notes"))
assert(notes.page == 3 and notes.column == 10 and notes.row == 2)
assert(Home.place(layout, catalog, "notes", 2, 1, 1))
assert(#layout.tiles == 4)
assert(Home.remove(layout, "notes") and not Home.find(layout, "notes"))
local library = Home.library(layout, catalog, 1, 4, 2)
local available = {}
for _, item in ipairs(library) do available[item.id] = item end
assert(available.notes.available)
assert(available.bag.reason == "on_home")
assert(not available.party.available)
assert(#Home.plusSlots(layout, catalog, 2) == 8)
assert(not Home.longPress(0.44, 0, 0)
  and Home.longPress(0.45, 6, 0)
  and not Home.longPress(0.45, 7, 0))
assert(Home.swipeDirection(-24, 2) == 1
  and Home.swipeDirection(24, 2) == -1
  and not Home.swipeDirection(23, 0)
  and not Home.swipeDirection(30, 30))

print("Kanto Gear Home layout: OK")
