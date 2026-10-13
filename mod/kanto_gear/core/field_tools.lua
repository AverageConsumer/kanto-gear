return function(THEME)
-- Game path [Gen 1]: field permissions use badge items; Gen 2 below uses player badge flags and Gen 3 delegates to its native adapter.
local FIELD_MOVES = {
  CUT = "CASCADEBADGE", SURF = "SOULBADGE",
  STRENGTH = "RAINBOWBADGE", FLASH = "BOULDERBADGE",
  FLY = "THUNDERBADGE", DIG = false, TELEPORT = false,
  SOFTBOILED = false,
}

-- Game path [Gen 1/2/3]: widget gen tags describe supported host actions; availability and badge checks still belong to the active engine.
THEME.fieldTools = { widgets = {
  { key = "bicycle", action = "bicycle", item = "BICYCLE", icon = "bicycle" },
  { key = "old_rod", action = "fish", item = "OLD_ROD", rod = "OLD_ROD",
    icon = "fish" },
  { key = "good_rod", action = "fish", item = "GOOD_ROD", rod = "GOOD_ROD",
    icon = "fish" },
  { key = "super_rod", action = "fish", item = "SUPER_ROD", rod = "SUPER_ROD",
    icon = "fish" },
  { key = "cut", action = "cut", move = "CUT", icon = "cut", gen = "both" },
  { key = "surf", action = "surf", move = "SURF", icon = "surf", gen = "both" },
  { key = "strength", action = "strength", move = "STRENGTH",
    icon = "strength", gen = "both" },
  { key = "flash", action = "flash", move = "FLASH", icon = "flash",
    gen = "both" },
  { key = "headbutt", action = "headbutt", move = "HEADBUTT",
    icon = "headbutt", gen = 2 },
  { key = "whirlpool", action = "whirlpool", move = "WHIRLPOOL",
    icon = "whirlpool", gen = 2 },
  { key = "waterfall", action = "waterfall", move = "WATERFALL",
    icon = "waterfall", gen = 2 },
  { key = "sweet_scent", action = "sweet_scent", move = "SWEET_SCENT",
    icon = "sweet_scent", gen = 2 },
  { key = "dig", action = "dig", move = "DIG", icon = "dig", gen = "both" },
  { key = "teleport", action = "teleport", move = "TELEPORT",
    icon = "teleport", gen = "both" },
  { key = "fly", action = "fly", move = "FLY", icon = "teleport", gen = 3 },
  { key = "softboiled", action = "softboiled", move = "SOFTBOILED",
    icon = "softboiled", gen = 1 },
  { key = "squirtbottle", action = "squirtbottle", item = "SQUIRTBOTTLE",
    icon = "squirtbottle", gen = 2 },
} }

THEME.fieldTools.gen2Badges = {
  CUT = "HIVE", FLASH = "ZEPHYR", SURF = "FOG", STRENGTH = "PLAIN",
  WHIRLPOOL = "GLACIER", WATERFALL = "RISING",
}

THEME.fieldTools.badgeOrder = {
  "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL", "GLACIER",
  "RISING",
}

function THEME.fieldTools.partyKnows(save, moveId)
  for _, mon in ipairs(save and save.party or {}) do
    for _, move in ipairs(mon.moves or {}) do
      if move.id == moveId then return true end
    end
  end
  return false
end

function THEME.fieldTools.gen2Badge(save, badge)
  if not badge then return true end
  local owned = save and save.player and save.player.badges
  if type(owned) ~= "table" then return false end
  if owned[badge] then return true end
  for index, name in ipairs(THEME.fieldTools.badgeOrder) do
    if name == badge then return owned[index] == true end
  end
  return false
end

function THEME.fieldTools.unlocked(def, save, gen2)
  if def.gen ~= nil and def.gen ~= "both" and def.gen ~= (gen2 and 2 or 1) then
    return false
  end
  local inventory = save and save.inventory or {}
  if def.item then return (inventory[def.item] or 0) > 0 end
  if not THEME.fieldTools.partyKnows(save, def.move) then return false end
  if gen2 then return THEME.fieldTools.gen2Badge(
    save, THEME.fieldTools.gen2Badges[def.move]) end
  local badge = FIELD_MOVES[def.move]
  return badge == false or badge ~= nil and (inventory[badge] or 0) > 0
end

local function hasUnlockedTool(save)
  local inv = save and save.inventory or {}
  for _, item in ipairs({ "BICYCLE", "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }) do
    if (inv[item] or 0) > 0 then return true end
  end
  for _, mon in ipairs(save and save.party or {}) do
    for _, move in ipairs(mon.moves or {}) do
      local badge = FIELD_MOVES[move.id]
      if badge ~= nil and (badge == false or inv[badge]) then return true end
    end
  end
  return false
end
  return hasUnlockedTool
end
