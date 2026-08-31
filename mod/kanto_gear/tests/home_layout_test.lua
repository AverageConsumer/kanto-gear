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
    hidden_widget = { package = "party", kind = "widget", columns = 3,
      hidden = true },
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
local packageLayout = { tiles = {
  { id = "party_app", page = 1, column = 1, row = 1 },
  { id = "party_widget", page = 1, column = 4, row = 2 },
} }
assert(Home.removePackage(packageLayout, catalog, "party") == 2
  and #packageLayout.tiles == 0)
local library = Home.library(layout, catalog, 1, 4, 2, "app")
local available = {}
for _, item in ipairs(library) do available[item.id] = item end
assert(available.notes_app.available)
assert(available.bag_app.reason == "on_home")
assert(available.party_app.reason == "on_home")
local widgets = Home.library(layout, catalog, 1, 4, 2, "widget")
for _, item in ipairs(widgets) do assert(item.kind == "widget") end
assert(#widgets == 2 and not available.party_widget)
for _, item in ipairs(widgets) do assert(item.id ~= "hidden_widget") end
catalog.packages.notes.installed = false
assert(#Home.library(layout, catalog, 1, 4, 2, "app") == 2)
catalog.packages.notes.installed = true
local pageTwoSlots = Home.plusSlots(layout, catalog, 2)
assert(#pageTwoSlots == 2
  and pageTwoSlots[1].column == 4 and pageTwoSlots[1].columns == 9
  and pageTwoSlots[2].column == 1 and pageTwoSlots[2].columns == 12)
local appTargets = Home.plusSlots(layout, catalog, 4, "bag_app")
assert(#appTargets == 8)
for index, target in ipairs(appTargets) do
  assert(target.column == ({ 1, 4, 7, 10 })[(index - 1) % 4 + 1]
    and target.row == math.floor((index - 1) / 4) + 1
    and target.columns == 3)
end
local widgetLayout = { tiles = {
  { id = "explorer_widget", page = 1, column = 1, row = 1 },
} }
local widgetSlot = Home.plusSlots(widgetLayout, catalog, 1)[1]
assert(widgetSlot.column == 8 and widgetSlot.columns == 5)
local widgetLibrary = Home.library(widgetLayout, catalog, 1,
  widgetSlot.column, widgetSlot.row, "widget")
local partyWidget
for _, item in ipairs(widgetLibrary) do
  if item.id == "party_widget" then partyWidget = item end
end
assert(partyWidget and partyWidget.available)
local swapLayout = { tiles = {
  { id = "bag_app", page = 1, column = 1, row = 1 },
  { id = "notes_app", page = 2, column = 10, row = 2 },
} }
assert(Home.drop(swapLayout, catalog, "bag_app", 2, 10, 2))
assert(Home.find(swapLayout, "bag_app").page == 2
  and Home.find(swapLayout, "bag_app").column == 10
  and Home.find(swapLayout, "notes_app").page == 1
  and Home.find(swapLayout, "notes_app").column == 1)
local widgetSwapLayout = { tiles = {
  { id = "explorer_widget", page = 1, column = 1, row = 1 },
  { id = "party_widget", page = 1, column = 8, row = 1 },
} }
assert(Home.drop(widgetSwapLayout, catalog,
  "explorer_widget", 1, 8, 1))
assert(Home.find(widgetSwapLayout, "explorer_widget").column == 6
  and Home.find(widgetSwapLayout, "party_widget").column == 1)
assert(Home.drop(widgetSwapLayout, catalog,
  "party_widget", 1, 6, 1))
assert(Home.find(widgetSwapLayout, "explorer_widget").column == 1
  and Home.find(widgetSwapLayout, "party_widget").column == 8)
local incompatibleLayout = { tiles = {
  { id = "explorer_widget", page = 1, column = 1, row = 1 },
  { id = "party_widget", page = 2, column = 8, row = 1 },
} }
assert(not Home.drop(incompatibleLayout, catalog,
  "explorer_widget", 2, 8, 1))
local emptyDropLayout = { tiles = {
  { id = "explorer_widget", page = 1, column = 1, row = 1 },
  { id = "bag_app", page = 1, column = 1, row = 2 },
} }
assert(Home.drop(emptyDropLayout, catalog, "bag_app", 1, 10, 1))
assert(Home.find(emptyDropLayout, "bag_app").column == 9
  and Home.find(emptyDropLayout, "bag_app").row == 1)
assert(Home.drop(emptyDropLayout, catalog, "bag_app", 3, 1, 2))
assert(Home.find(emptyDropLayout, "bag_app").page == 3
  and Home.find(emptyDropLayout, "bag_app").column == 1
  and Home.find(emptyDropLayout, "bag_app").row == 2)
assert(not Home.longPress(0.44, 0, 0)
  and Home.longPress(0.45, 6, 0)
  and not Home.longPress(0.45, 7, 0))
assert(Home.swipeDirection(-24, 2) == 1
  and Home.swipeDirection(24, 2) == -1
  and not Home.swipeDirection(23, 0)
  and not Home.swipeDirection(30, 30))

print("Kanto Gear Home layout: OK")
