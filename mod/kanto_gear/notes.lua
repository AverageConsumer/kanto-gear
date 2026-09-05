-- Personal notes live outside normal-save rollback, in playthrough-scoped storage.
local Notes = {}
Notes.__index = Notes
Notes.MAX_NOTES, Notes.MAX_TASKS, Notes.MAX_TEXT = 100, 100, 8192
Notes.MAX_POINTS, Notes.MAX_STROKES = 32768, 1024
Notes.colors = {
  { id = "ink", label = "INK" },
  { id = "red", label = "RED", tint = { .80, .29, .29, 1 } },
  { id = "blue", label = "BLUE", tint = { .21, .50, .76, 1 } },
  { id = "green", label = "GREEN", tint = { .19, .53, .35, 1 } },
  { id = "gold", label = "GOLD", tint = { .74, .52, .14, 1 } },
  { id = "purple", label = "PURPLE", tint = { .61, .38, .74, 1 } },
}
local function chars(s)
  local out = {}
  for c in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = c end
  return out
end
local function clean(s, limit)
  local list = chars(type(s) == "string" and s or "")
  return table.concat(list, "", 1, math.min(#list, limit or Notes.MAX_TEXT))
end
local function inside(x, y, r)
  return x and y and x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h
end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
function Notes.new(ctx)
  return setmetatable({ ctx = ctx, records = {}, nextId = 1, view = "list",
    filter = "here", page = 1, hits = {}, dirtyNotes = {}, color = 1, penWidth = 2,
    tool = "pen", inkRevision = 0, undo = {}, changed = false }, Notes)
end
function Notes:now() return self.ctx.time() end
function Notes:note() return self.records[self.selected] end
function Notes:invalidate() self.changed = true end
function Notes:takeChanged() local value = self.changed; self.changed = false; return value end
function Notes:touchData(n)
  if n then self.dirtyNotes[n.id] = n end
  self.saveAt = self:now() + .6
  self:invalidate()
end
function Notes:bind(game, storage)
  self:suspend(); self:flush(true)
  -- Keep failed writes attached to their original playthrough until they save.
  if self.saveAt then self.pendingBind = { game = game, storage = storage }; return end
  self.game, self.storage = { save = game and game.save }, storage
  self.records, self.dirtyNotes, self.nextId, self.selected = {}, {}, 1, nil
  self.view, self.page, self.undo, self.deleted = "list", 1, {}, nil
  self.saveAt, self.catalogDirty, self.error = nil, false, nil
  self.inkRevision = self.inkRevision + 1
  self.readFailed = false
  if not storage or not storage.read or not storage.write then
    self.error, self.readFailed = "NOTES STORAGE UNAVAILABLE", true; return
  end
  local ok, catalog, code = pcall(storage.read, storage, game, "notes/catalog")
  if not ok or (catalog == nil and code and code ~= "not_found") then
    self.error = "NOTES COULD NOT BE LOADED"; self.readFailed = true; return
  end
  self.readFailed = false
  if catalog == nil then return end
  if type(catalog) ~= "table" or type(catalog.ids) ~= "table" or catalog.format ~= 1 then
    self.error, self.readFailed = "NOTES COULD NOT BE LOADED", true; return
  end
  self.nextId = math.max(1, math.floor(tonumber(catalog.nextId) or 1))
  for _, id in ipairs(type(catalog.ids) == "table" and catalog.ids or {}) do
    if #self.records >= self.MAX_NOTES then break end
    if type(id) == "number" and id >= 1 and id == math.floor(id) then
      local loaded, value = pcall(storage.read, storage, game, "notes/n" .. id)
      if loaded and type(value) == "table" then
        local n = { id = id, title = clean(value.title, 64), text = clean(value.text),
          area = type(value.area) == "string" and value.area or nil,
          areaName = clean(value.areaName, 100), tasks = {}, strokes = {}, pointCount = 0 }
        for _, task in ipairs(type(value.tasks) == "table" and value.tasks or {}) do
          if #n.tasks >= self.MAX_TASKS then break end
          if type(task) == "table" then n.tasks[#n.tasks + 1] = { text = clean(task.text, 256), done = task.done == true } end
        end
        for _, stroke in ipairs(type(value.strokes) == "table" and value.strokes or {}) do
          if #n.strokes >= self.MAX_STROKES then break end
          if type(stroke) == "table" and type(stroke.points) == "table" then
            local s = { color = clamp(math.floor(tonumber(stroke.color) or 1), 1, #self.colors),
              width = clamp(tonumber(stroke.width) or 2, 1, 4), points = {} }
            for i = 1, #stroke.points - 1, 2 do
              if n.pointCount >= self.MAX_POINTS then break end
              local x, y = stroke.points[i], stroke.points[i + 1]
              if type(x) == "number" and type(y) == "number" and x == x and y == y then
                s.points[#s.points + 1], s.points[#s.points + 2] = clamp(x, 0, 220), clamp(y, 0, 136)
                n.pointCount = n.pointCount + 1
              end
            end
            if #s.points > 0 then n.strokes[#n.strokes + 1] = s end
          end
        end
        self.records[#self.records + 1] = n
        self.nextId = math.max(self.nextId, id + 1)
      else
        self.error, self.readFailed = "NOTES COULD NOT BE LOADED", true
      end
    end
  end
end
function Notes:flush(force)
  if self.readFailed or not self.saveAt or self.stroke or self.eraseUndo or (not force and self:now() < self.saveAt) then return end
  if not self.storage or not self.storage.write then self.error = "NOTES STORAGE UNAVAILABLE"; return end
  for id, n in pairs(self.dirtyNotes) do
    local ok, written = pcall(self.storage.write, self.storage, self.game, "notes/n" .. id, n)
    if not ok or not written then self.error = "NOT SAVED - TRY AGAIN"; self.saveAt = self:now() + 3; self:invalidate(); return end
    self.dirtyNotes[id] = nil
  end
  if self.catalogDirty then
    local ids = {}; for _, n in ipairs(self.records) do ids[#ids + 1] = n.id end
    local ok, written = pcall(self.storage.write, self.storage, self.game, "notes/catalog", { format = 1, nextId = self.nextId, ids = ids })
    if not ok or not written then self.error = "NOT SAVED - TRY AGAIN"; self.saveAt = self:now() + 3; self:invalidate(); return end
  end
  self.saveAt, self.catalogDirty = nil, false
  if self.error == "NOT SAVED - TRY AGAIN" then self.error = nil; self:invalidate() end
  if self.pendingBind then
    local pending = self.pendingBind; self.pendingBind = nil
    self:bind(pending.game, pending.storage); self:invalidate()
  end
end
function Notes:list()
  local area = self.ctx.area()
  local out = {}
  for i, n in ipairs(self.records) do if self.filter == "all" or n.area == area then out[#out + 1] = { index = i, note = n } end end
  return out
end
function Notes:open()
  self.view, self.page, self.selected = "list", 1, nil
  self:invalidate()
end
function Notes:wrapped(value, width)
  local list, rows, first = chars(value), {}, 1
  while first <= #list do
    local last, size, space = first, 0, nil
    while last <= #list and list[last] ~= "\n" do
      local w = self.ctx.measure(list[last])
      if size + w > width and last > first then break end
      size = size + w
      if list[last] == " " then space = last end
      last = last + 1
    end
    if last <= #list and list[last] ~= "\n" and space and space > first then last = space + 1 end
    rows[#rows + 1] = { text = table.concat(list, "", first, last - 1), first = first - 1, last = last - 1 }
    first = last + (list[last] == "\n" and 1 or 0)
  end
  if #rows == 0 or list[#list] == "\n" then rows[#rows + 1] = { text = "", first = #list, last = #list } end
  return rows
end
function Notes:edit(target, index)
  local n = self:note(); if not n then return end
  self.returnView, self.editTarget, self.editIndex = self.view, target, index
  self.draft = target == "task" and n.tasks[index].text or n[target]
  self.cursor, self.view = #chars(self.draft), "edit"
end
function Notes:finishEdit()
  local n = self:note(); if not n then return end
  if self.editTarget == "task" and n.tasks[self.editIndex] and n.tasks[self.editIndex].text:match("^%s*$") then
    table.remove(n.tasks, self.editIndex)
  end
  if n.title:match("^%s*$") then n.title = self.ctx.translate("NEW NOTE") end
  self.view = self.returnView or "text"
  self:touchData(n); self:flush(true)
end
function Notes:type(value, backspace)
  local n = self:note(); if not n then return end
  local list = chars(self.draft)
  if backspace then
    if self.cursor == 0 then return end
    table.remove(list, self.cursor); self.cursor = self.cursor - 1
  else
    local limit = self.editTarget == "title" and 64 or self.editTarget == "task" and 256 or self.MAX_TEXT
    for _, c in ipairs(chars(value)) do
      if #list >= limit then self.error = "TEXT LIMIT REACHED"; break end
      self.cursor = self.cursor + 1; table.insert(list, self.cursor, c)
    end
  end
  self.draft = table.concat(list)
  if self.editTarget == "task" then n.tasks[self.editIndex].text = self.draft else n[self.editTarget] = self.draft end
  self:touchData(n)
end
function Notes:action(action, value)
  local n = self:note()
  if self.readFailed or self.pendingBind then if action == "back" then self.ctx.leave() end; return end
  if self.error ~= "NOT SAVED - TRY AGAIN" then self.error = nil end
  if action == "back" then
    if self.colorOpen then self.colorOpen = false
    elseif self.view == "edit" then self:finishEdit()
    elseif self.view == "draw" then self:suspend(); self.view = "sketch"; self:flush(true)
    elseif self.view == "list" then self:flush(true); self.ctx.leave()
    else self.view, self.page = "list", 1; self:flush(true) end
  elseif action == "filter" then self.filter, self.page = value, 1
  elseif action == "open" then self.selected, self.view, self.page, self.undo = value, "text", 1, {}; self.inkRevision = self.inkRevision + 1
  elseif action == "new" then
    if #self.records >= self.MAX_NOTES then self.error = "NOTE LIMIT REACHED"
    else
      local area, name = self.ctx.area()
      n = { id = self.nextId, title = "", text = "", area = self.filter == "here" and area or nil,
        areaName = self.filter == "here" and name or "", tasks = {}, strokes = {}, pointCount = 0 }
      self.nextId = self.nextId + 1; self.records[#self.records + 1] = n
      self.selected, self.view, self.page, self.undo = #self.records, "text", 1, {}
      self.catalogDirty = true; self:touchData(n); self:edit("title")
    end
  elseif action == "restore" and self.deleted and #self.records < self.MAX_NOTES then
    table.insert(self.records, self.deleted.index, self.deleted.note)
    self.selected, self.deleted, self.view = self.deleted.index, nil, "text"
    self.catalogDirty = true; self:touchData(self:note()); self:flush(true)
  elseif n then
    if action == "view" then self.view, self.page = value, 1
    elseif action == "edit" then self:edit(value)
    elseif action == "area" then
      if n.area then n.area, n.areaName = nil, "" else n.area, n.areaName = self.ctx.area() end
      self:touchData(n)
    elseif action == "delete" then
      self.deleted = { index = self.selected, note = n }; table.remove(self.records, self.selected)
      self.selected, self.view, self.page = nil, "list", 1
      self.catalogDirty = true; self:touchData(); self:flush(true)
    elseif action == "addTask" then
      if #n.tasks >= self.MAX_TASKS then self.error = "TASK LIMIT REACHED"
      else n.tasks[#n.tasks + 1] = { text = "", done = false }; self:touchData(n); self:edit("task", #n.tasks) end
    elseif action == "task" then self:edit("task", value)
    elseif action == "deleteTask" then table.remove(n.tasks, self.editIndex); self.view = "tasks"; self:touchData(n); self:flush(true)
    elseif action == "check" then n.tasks[value].done = not n.tasks[value].done; self:touchData(n)
    elseif action == "char" then self:type(value)
    elseif action == "space" then self:type(" ")
    elseif action == "newline" then self:type("\n")
    elseif action == "backspace" then self:type("", true)
    elseif action == "shift" then self.shift = not self.shift
    elseif action == "symbols" then self.symbols = not self.symbols
    elseif action == "cursor" then self.cursor = clamp(self.cursor + value, 0, #chars(self.draft))
    elseif action == "finish" then self:finishEdit()
    elseif action == "pen" then self.tool = value
    elseif action == "width" then self.penWidth = self.penWidth == 2 and 4 or 2
    elseif action == "colors" then self.colorOpen = not self.colorOpen
    elseif action == "color" then self.color, self.tool, self.colorOpen = value, "pen", false
    elseif action == "undo" then
      local last = table.remove(self.undo)
      if last then
        if last.kind == "add" then table.remove(n.strokes)
        else for i = #last.removed, 1, -1 do local entry = last.removed[i]; table.insert(n.strokes, entry.index, entry.stroke) end end
        n.pointCount = 0; for _, s in ipairs(n.strokes) do n.pointCount = n.pointCount + #s.points / 2 end
        self.inkRevision = self.inkRevision + 1; self:touchData(n)
      end
    end
  end
  if action == "page" then self.page = math.max(1, math.min(self.pages or 1, self.page + value)) end
  self:invalidate()
end
function Notes:hit(x, y)
  if y < 30 and x < 26 then return "back" end
  for _, h in ipairs(self.hits) do if inside(x, y, h) then return h.action, h.value end end
end
function Notes:addPoint(x, y)
  local n, s = self:note(), self.stroke
  if not n or not s then return end
  x, y = clamp(x - 10, 0, 220), clamp(y - 36, 0, 136)
  -- Retain subpixel input; stationary pointers do not schedule work.
  local p = s.points
  if #p > 0 and (p[#p - 1] - x)^2 + (p[#p] - y)^2 < .04 then return end
  if n.pointCount >= self.MAX_POINTS then self.error = "DRAWING LIMIT REACHED"; return end
  p[#p + 1], p[#p + 2] = x, y; n.pointCount = n.pointCount + 1
  self:invalidate()
end
local function distance(px, py, ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  local t = dx == 0 and dy == 0 and 0 or clamp(((px-ax)*dx+(py-ay)*dy)/(dx*dx+dy*dy),0,1)
  return (px-ax-t*dx)^2+(py-ay-t*dy)^2
end
function Notes:erase(x, y)
  local n = self:note(); x, y = x - 10, y - 36
  for i = #n.strokes, 1, -1 do
    local s, found = n.strokes[i], false
    for j = 1, #s.points, 2 do
      local k = math.max(1, j - 2)
      if distance(x,y,s.points[k],s.points[k+1],s.points[j],s.points[j+1]) <= (5+s.width)^2 then found = true; break end
    end
    if found then
      self.eraseUndo.removed[#self.eraseUndo.removed + 1] = { index = i, stroke = table.remove(n.strokes, i) }
      n.pointCount = n.pointCount - #s.points / 2
      self.inkRevision = self.inkRevision + 1; self:invalidate()
    end
  end
end
function Notes:suspend()
  if self.stroke then
    self.stroke = nil; self.undo[#self.undo + 1] = { kind = "add" }; self:touchData(self:note())
  elseif self.eraseUndo then
    if #self.eraseUndo.removed > 0 then self.undo[#self.undo + 1] = self.eraseUndo; self:touchData(self:note()) end
    self.eraseUndo = nil
  end
  if #self.undo > 32 then table.remove(self.undo, 1) end
  self.down = nil
end
function Notes:pointer(action, x, y)
  if self.error and action ~= "cancel" then
    self:suspend()
    if action == "up" or action == "tap" then
      local a, v = self:hit(x, y); if a then self:action(a, v) end
    end
    self.down = nil; return
  end
  if action == "down" then
    self.down = { x = x, y = y }
    if self.view == "draw" and not self.colorOpen and inside(x, y, { x = 9, y = 35, w = 222, h = 138 }) then
      if self.tool == "eraser" then self.eraseUndo = { kind = "erase", removed = {} }; self:erase(x, y)
      elseif self:note().pointCount < self.MAX_POINTS and #self:note().strokes < self.MAX_STROKES then
        self.liveMoves = 0
        self.stroke = { color = self.color, width = self.penWidth, points = {} }
        self:note().strokes[#self:note().strokes + 1] = self.stroke; self:addPoint(x, y)
      else self.error = "DRAWING LIMIT REACHED"; self:invalidate() end
    end
  elseif action == "move" or action == "moved" then
    if self.stroke then self.liveMoves = self.liveMoves + 1; self:addPoint(x, y) elseif self.eraseUndo then self:erase(x, y) end
  elseif action == "up" then
    if self.stroke then
      if self.liveMoves == 0 and self.down and (x-self.down.x)^2+(y-self.down.y)^2 > 16 then
        -- Older Android secondary views emit only down/up. Do not pretend the
        -- straight chord between them is the user's drawing.
        local n = self:note(); n.pointCount = n.pointCount - #self.stroke.points/2
        table.remove(n.strokes); self.stroke, self.down = nil, nil
        self.inkRevision = self.inkRevision + 1
        self.error = "HOST MISSING LIVE DRAWING INPUT"; self:touchData(n)
      else self:addPoint(x, y); self:suspend() end
    elseif self.eraseUndo then self:erase(x, y); self:suspend()
    elseif self.down then
      local down = self.down; self.down = nil
      if math.abs(x-down.x)<8 and math.abs(y-down.y)<8 then local a,v=self:hit(x,y);if a then self:action(a,v) end end
    end
  elseif action == "cancel" then self:suspend()
  elseif action == "tap" then local a,v=self:hit(x,y);if a then self:action(a,v) end end
end
return Notes
