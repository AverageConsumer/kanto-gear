return function(H, G, tr, fmt)
  local versions = { red = "RED", blue = "BLUE", yellow = "YELLOW", gold = "GOLD",
    silver = "SILVER", crystal = "CRYSTAL", firered = "FIRERED", leafgreen = "LEAFGREEN", emerald = "EMERALD" }
  local places = { launcher = "RECOMP MENU", game = "IN GAME", union = "UNION ROOM", direct = "DIRECT CORNER" }
  local shortVersions = { red = "R", blue = "B", yellow = "Y", gold = "G",
    silver = "S", crystal = "C", firered = "FR", leafgreen = "LG", emerald = "EM" }
  local statuses = { idle = "AVAILABLE", busy = "NOT AVAILABLE", trading = "TRADING",
    battling = "BATTLING", chatting = "CHATTING", recruiting = "RECRUITING", waiting = "WAITING" }
  local states = { offline = "OFFLINE", online = "ONLINE", connecting = "CONNECTING",
    reconnecting = "RECONNECTING", ticket = "CONNECTING", error = "CONNECTION FAILED",
    unavailable = "HOST UPDATE NEEDED" }
  function H:homePss(model, tile, selected)
    local c, state = self.colors, model.pss or { state = "offline", rows = {} }
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, c.blueLight, selected)
    self:homeWidgetHeader(x, y, w, "SILPH CONNECT", c.blue, c.blueLight, model.editing)
    local function centered(text, left, top, width, tint)
      local shown = self:fitPartyInfo(text, width)
      self:partyInfo(shown, left + math.floor((width - self:partyInfoWidth(shown)) / 2), top, tint)
    end
    local online = state.state == "online"
    if not online or #state.rows == 0 then
      centered(tr(states[state.state] or "OFFLINE"), x + 6, y + 32, w - 12,
        online and c.green or c.mutedInk)
      local message = online and "NO PLAYERS VISIBLE"
        or (state.state == "offline" or state.state == "error") and "CONNECT TO SEE PLAYERS"
        or "SILPH CONNECT"
      centered(tr(message), x + 6, y + 54, w - 12, c.ink)
      return
    end
    local count = tostring(#state.rows)
    self:label(count, x + 6 + math.floor((48 - self:labelWidth(count)) / 2), y + 26, c.ink)
    self:partyType(self:fitPartyType(tr("VISIBLE"), 48), x + 6, y + 44, c.mutedInk, 48)
    self:partyType(self:fitPartyType(tr("ONLINE"), 48), x + 6, y + 62, c.green, 48)
    G.setColor(c.outline); G.rectangle("fill", x + 60, y + 25, 1, 50)
    local countShown = math.min(3, #state.rows)
    local top = y + 25 + math.floor((50 - countShown * 16) / 2)
    for i = 1, countShown do
      local row = state.rows[i]
      local rowY = top + (i - 1) * 16
      centered(row.name, x + 67, rowY + 2, 74, c.ink)
      local status = row.where == "launcher" and "IN MENU" or statuses[row.status] or "ONLINE"
      self:partyType(self:fitPartyType(tr(status), w - 151), x + 145, rowY + 2,
        row.status == "idle" and c.green or c.mutedInk, w - 151)
    end
  end
  function H:pss(state)
    local c = self.colors
    state.hits = {}
    local function hit(x,y,w,h,action,value)
      state.hits[#state.hits+1]={x=x,y=y,w=w,h=h,action=action,value=value}
    end
    local function label(text,x,y,w,h,tint)
      self:partyInfo(self:fitPartyInfo(text,w-4),x+1,y+math.floor((h-7)/2)-2,tint or c.ink,w,"center")
    end
    local function button(text,x,y,w,h,action,value)
      local pressed=self:beginPress(x,y,w,h,action~=nil)
      self:panel(x,y,w,h)
      label(tr(text),x,y,w,h,action and c.green or c.disabledInk)
      self:endPress(pressed)
      if action then hit(x,y,w,h,action,value) end
    end
    local function person(cx,y,tint)
      G.setColor(tint);G.rectangle("fill",cx-3,y,6,6)
      G.rectangle("fill",cx-5,y+8,10,6)
      G.setColor(c.surface);G.rectangle("fill",cx-1,y+11,2,3)
    end
    if state.selected then
      local row=state.selectedRow
      self:panel(7,33,226,143)
      person(120,46,row and c.blue or c.disabledInk)
      label(row and row.name or tr(state.state == "online" and "PLAYER LEFT"
        or states[state.state] or "OFFLINE"),15,67,210,20)
      if row then
        label(tr(versions[row.version] or "UNKNOWN GAME"),15,93,210,15,c.green)
        label(tr(places[row.where] or "ONLINE"),15,114,210,15,c.mutedInk)
        label(tr(statuses[row.status] or "ONLINE"),15,135,210,15,c.mutedInk)
      end
      button("BACK",7,188,226,23,"back")
      return
    end
    self:panel(7,33,226,32)
    label(state.name or tr("YOUR TRAINER"),10,34,132,14)
    label(tr(states[state.state] or "OFFLINE"),10,48,132,14,
      state.state=="online" and c.green or c.mutedInk)
    local pending=state.state=="connecting" or state.state=="reconnecting" or state.state=="ticket"
    local action
    if state.state~="unavailable" and not pending and not state.inUse then
      action=state.state=="online" and "disconnect" or "connect"
    end
    button(state.inUse and "IN USE" or state.state=="online" and "DISCONNECT"
      or pending and "WAITING" or "CONNECT",147,37,82,24,action)
    label(tr("PASSERSBY"),7,70,110,12,c.green)
    label(fmt("%d VISIBLE",#state.rows),123,70,110,12,c.mutedInk)
    if #state.rows==0 then
      self:panel(7,87,226,93)
      person(120,100,c.disabledInk)
      local message=state.error and "CONNECTION FAILED" or state.state=="online" and "NO PLAYERS VISIBLE"
        or pending and "CONNECTING" or state.state=="unavailable" and "HOST UPDATE NEEDED"
        or "CONNECT TO SEE PLAYERS"
      label(tr(message),12,124,216,20,c.mutedInk)
      label(tr("SILPH CONNECT"),12,149,216,16,c.green)
    end
    for i=1,6 do
      local row=state.rows[(state.page-1)*6+i]
      if row then
        local x=7+((i-1)%3)*77;local y=87+math.floor((i-1)/3)*49
        self:panel(x,y,72,44)
        person(x+12,y+6,c.blue)
        label(shortVersions[row.version] or "?",x+23,y+3,45,13,c.green)
        label(tr(row.where == "launcher" and "IN MENU" or places[row.where] or "ONLINE"),x+23,y+16,45,10,c.mutedInk)
        label(row.name,x+3,y+29,66,12)
        hit(x,y,72,44,"player",row.id)
      end
    end
    button("PREV",7,190,58,21,state.page>1 and "page" or nil,-1)
    label(state.page.."/"..(state.pages or 1),70,190,100,21,c.green)
    button("NEXT",175,190,58,21,state.page<(state.pages or 1) and "page" or nil,1)
  end
end
