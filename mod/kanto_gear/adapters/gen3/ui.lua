-- Native Gen 3 menu projections. All activation is routed through the host's
-- normal input handler; Gear never invokes item/switch callbacks itself.
return function(read)
  local UI = {}
  UI.__index = UI
  function UI.new(adapter, layout, choicePage, namingPage, storagePage, itemPage, movePage, keyboardLayout, navigation)
    return setmetatable({ adapter = adapter, layout = layout, choicePage = choicePage, namingPage = namingPage, storagePage = storagePage, itemPage = itemPage, movePage = movePage, keyboardLayout = keyboardLayout, navigation = navigation, Stack = require("src.ui.game3.stack"),
      Message = require("src.ui.game3.message"), Choice = require("src.ui.game3.choice"),
      Stats = require("src.ui.game3.stat_growth") }, UI)
  end
  function UI:navigate(native, battle, input)
    if not self.navigation then return false end
    native = native._nativeDelegate or native
    local view = self:list(battle)
    if not view or view.native ~= native or not view.valid() or view.notice
        or view.quantity or view.nativeStats then return false end
    if not view.fixedLayout and not view.battleTargets then return false end
    for _, key in ipairs({"up","down","left","right"}) do
      if input:wasPressed(key) then
        local index = self.navigation(view, key)
        if index == nil then return false end
        if view.battleTargets then view.target.cursor = view.battleTargets[index] end
        view.index = index
        if view.moveSelection then native._hmNotice = false end
        return true
      end
    end
    return false
  end
  function UI:panel()
    local layer = self.Stack.top()
    return layer and layer.id
  end
  local function labels(items)
    local out = {}
    for _, item in ipairs(items or {}) do
      out[#out + 1] = { label = type(item) == "table" and item.label or tostring(item) }
    end
    return out
  end
  local function install(name, ...)
    local path = "adapters/gen3/ui/" .. name .. ".lua"
    return assert(load(assert(read(path)), "@kanto_gear/" .. path))()(...)
  end
  install("overlays", UI, labels)
  install("pokeblocks", UI, labels)
  install("pokenav", UI)
  install("menus/items", UI, labels)
  install("menus/storage", UI, labels)
  install("menus/shop", UI, labels)
  install("menus/system", UI, labels)
  install("menus/moves", UI, labels)
  install("menus/party", UI, labels)
  install("menus", UI, labels)
  install("bag", UI)
  return UI
end
