-- Native trainer cards own page order, flip readiness and closing callbacks.
local Page = {}

-- Game path [Gen 1/2/3]: trainer pages are one front, front plus regional badges, or front/back records respectively.
function Page.context(generation, number, pages)
  return { number = number, pages = pages,
    kind = generation == 3 and number == 2 and "records" or generation == 2 and number > 1 and "badges" or "front",
    region = generation == 2 and number > 1 and (number == 3 and "KANTO" or "JOHTO") or nil }
end

function Page.project(top, game, generation, previous)
  local native, number, pages, card, active, nextKey
  -- Game path [Gen 3]: card flips use A/B and timed native phases; Gen 2 changes pages with left/right below.
  if generation == 3 then
    if not top or top.id ~= "trainer" or not top.mod or not top.mod.open then return end
    native, card = top.mod, top.mod._card
    if native._session ~= game.session then return end
    local side = native.side
    number, pages = side == "back" and 2 or 1, 2
    active = function(preview)
      return require("src.ui.game3.stack").top() == top and native.open and native._session == game.session and native._card == card and native.side == side
        and not require("src.ui.game3.message").isOpen() and not require("src.ui.game3.choice").active
        and (preview or not native._flip and (native._phase == nil or native._phase == "wait"))
    end
    nextKey = function() return side == "back" and "b" or "a" end
  else
    if not top or getmetatable(top) ~= require(generation == 2 and "src.ui.gen2.TrainerCard" or "src.ui.TrainerCard") then return end
    native, number, pages = top, generation == 2 and top.page or 1, generation == 2 and top:pages() or 1
    active = function() return game.stack:top() == top and (generation == 1 or top.page == number and top:pages() == pages) end
    nextKey = function(direction) if pages > 1 then return direction < 0 and "left" or "right" end end
  end
  if not active(true) then return end
  local key = tostring(top) .. ":trainer:" .. number .. ":" .. pages .. ":" .. tostring(card)
  local view = previous
  if not view or view.nativeKey ~= key then
    view = { screenId = "CompanionMenu", nativeKey = key, title = "TRAINER", fixedLayout = true,
      index = 1, update = function() end, valid = active, nextKey = nextKey }
  end
  view.trainer = Page.context(generation, number, pages)
  view.trainer.card, view.trainer.native = card, native
  view.items = { { label = "CANCEL" } }
  return view
end

-- A native record consists of a caption and value fragments on one baseline.
-- Keep its translated strings and omission rules rather than inventing a second list.
-- Game path [Emerald vs FireRed/LeafGreen]: native back-text gatherers expose different achievement records; RS uses its separate adapter.
function Page.records(native, card, emerald)
  local fragments = (emerald and native.backTextsRse or native.backTexts)(card)
  local rows, byY = {}, {}
  for _, fragment in ipairs(fragments) do
    if fragment.y >= 40 then
      local row = byY[fragment.y]
      local text = tostring(fragment.text or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if not row then
        row = { label = text, parts = {} }; byY[fragment.y] = row; rows[#rows + 1] = row
      else row.parts[#row.parts + 1] = text end
    end
  end
  for _, row in ipairs(rows) do row.value = table.concat(row.parts, " "); row.parts = nil end
  return rows
end

function Page.hit(x, y, pages)
  if y < 0 or y >= 28 then return end
  if x >= 0 and x < 27 then return "back" end
  if pages > 1 then
    if x >= 27 and x < 45 then return -1 end
    if x >= 120 and x < 138 then return 1 end
  end
end

function Page.key(model)
  local parts = { model.name, model.region, model.idText, model.money, model.time,
    model.pokedex, model.badgeText, model.kind or "front" }
  for index, owned in ipairs(model.badgeOwned) do parts[#parts + 1] = tostring(index) .. tostring(owned) end
  for _, row in ipairs(model.records or {}) do parts[#parts + 1] = row.label .. row.value end
  return table.concat(parts, "\31")
end

return Page
