local Home = assert(loadfile("mod/kanto_gear/home_layout.lua"))()

local catalog = {
  packages = {
    explorer = { installed = true }, party = { installed = true },
    bag = { installed = true }, notes = { installed = true },
  },
  surfaces = {
    explorer_widget = { package = "explorer", kind = "widget", columns = 7 },
    party_app = { package = "party", kind = "app", columns = 3 },
    party_widget = { package = "party", kind = "widget", columns = 5 },
    bag_app = { package = "bag", kind = "app", columns = 3, label = "BAG" },
    notes_app = { package = "notes", kind = "app", columns = 3,
      label = "NOTES" },
  },
}
local layout = { tiles = {
  { id = "explorer_widget", page = 1, column = 1, row = 1 },
  { id = "party_widget", page = 1, column = 8, row = 1 },
  { id = "bag_app", page = 1, column = 1, row = 2 },
} }

assert(Home.canPlace(layout, catalog, "notes_app", 1, 4, 2))
assert(not Home.canPlace(layout, catalog, "notes_app", 1, 2, 2))
assert(not Home.canPlace(layout, catalog, "party_widget", 1, 10, 2))
assert(Home.place(layout, catalog, "notes_app", 3, 10, 2))
assert(Home.pageCount(layout) == 3)
assert(not Home.place(layout, catalog, "notes_app", 1, 1, 1))
local notes = assert(Home.find(layout, "notes_app"))
assert(notes.page == 3 and notes.column == 10 and notes.row == 2)
assert(Home.place(layout, catalog, "notes_app", 2, 1, 1))
assert(#layout.tiles == 4)
assert(Home.remove(layout, "notes_app") and not Home.find(layout, "notes_app"))
assert(Home.place(layout, catalog, "party_app", 2, 1, 1))
assert(Home.find(layout, "party_app") and Home.find(layout, "party_widget"))
local library = Home.library(layout, catalog, 1, 4, 2, "app")
local available = {}
for _, item in ipairs(library) do available[item.id] = item end
assert(available.notes_app.available)
assert(available.bag_app.reason == "on_home")
assert(available.party_app.reason == "on_home")
local widgets = Home.library(layout, catalog, 1, 4, 2, "widget")
for _, item in ipairs(widgets) do assert(item.kind == "widget") end
assert(#widgets == 2 and not available.party_widget)
catalog.packages.notes.installed = false
assert(#Home.library(layout, catalog, 1, 4, 2, "app") == 2)
catalog.packages.notes.installed = true
assert(#Home.plusSlots(layout, catalog, 2) == 7)
assert(not Home.longPress(0.44, 0, 0)
  and Home.longPress(0.45, 6, 0)
  and not Home.longPress(0.45, 7, 0))
assert(Home.swipeDirection(-24, 2) == 1
  and Home.swipeDirection(24, 2) == -1
  and not Home.swipeDirection(23, 0)
  and not Home.swipeDirection(30, 30))

print("Kanto Gear Home layout: OK")
