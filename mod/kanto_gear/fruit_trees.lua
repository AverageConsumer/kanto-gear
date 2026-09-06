local Trees = {}
local ok, fruits = pcall(require, "src.core.gen2.Apricorns")
if not ok then fruits = nil end

-- The daily reset clears this gate before the first interaction actually
-- clears the picked-tree table. Read both; never run the mutating reset here.
function Trees.picked(save, tree)
  return fruits ~= nil and save ~= nil
    and (save.engineFlags or {})[fruits.ENGINE_ALL_FRUIT_TREES] == true
    and (save.fruitTrees or {})[tree] == true
end

function Trees.rows(data, mapId)
  local rows = {}
  if not fruits then return rows end
  local map = data and data.gen2Maps and data.gen2Maps[mapId]
  local scripts = data and data.gen2Scripts or {}
  for _, object in ipairs(map and map.objects or {}) do
    local commands = type(object.scriptKey) == "table" and object.scriptKey
      or scripts[object.scriptKey]
    for _, command in ipairs(commands or {}) do
      if command.op == "fruittree" then
        local tree = command.args and command.args[1]
        local item = tree and fruits.treeFruit(tree)
        local def = item and data.items and data.items[item]
        if def and object.x ~= nil and object.y ~= nil then
          rows[#rows + 1] = { kind = "fruit", tree = tree, item = item,
            label = def.name or item, x = object.x, y = object.y,
            key = "fruit:" .. tostring(mapId) .. ":" .. tostring(tree) }
        end
        break
      end
    end
  end
  return rows
end

function Trees.stateKey(save, rows)
  local parts = {}
  for _, row in ipairs(rows or {}) do
    parts[#parts + 1] = Trees.picked(save, row.tree) and "1" or "0"
  end
  return table.concat(parts)
end

return Trees
