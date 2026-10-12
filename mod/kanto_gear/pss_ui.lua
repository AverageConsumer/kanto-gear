return function(H, G, tr, fmt)
  local versions = { red = "RED", blue = "BLUE", yellow = "YELLOW", gold = "GOLD",
    silver = "SILVER", crystal = "CRYSTAL", firered = "FIRERED", leafgreen = "LEAFGREEN", emerald = "EMERALD",
    ruby = "RUBY", sapphire = "SAPPHIRE" }
  local places = { launcher = "RECOMP MENU", game = "IN GAME", union = "UNION ROOM", direct = "DIRECT CORNER" }
  local shortVersions = { red = "R", blue = "B", yellow = "Y", gold = "G",
    silver = "S", crystal = "C", firered = "FR", leafgreen = "LG", emerald = "EM", ruby = "RU", sapphire = "SA" }
  local statuses = { idle = "ONLINE", busy = "NOT AVAILABLE", trading = "TRADING",
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
    if state.incoming then
      centered(tr(state.incoming.mode == "trade" and "TRADE INVITATION" or "BATTLE INVITATION"),
        x + 6, y + 30, w - 12, c.green)
      centered(state.incoming.from and state.incoming.from.name or tr("YOUR TRAINER"),
        x + 6, y + 52, w - 12, c.ink)
      return
    end
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
      local status = row.ready and "READY" or row.where == "launcher" and "IN MENU" or statuses[row.status] or "ONLINE"
      self:partyType(self:fitPartyType(tr(status), w - 151), x + 145, rowY + 2,
        row.ready and c.green or c.mutedInk, w - 151)
    end
  end
  function H:pss(state)
    local c = self.colors
    state.hits = {}
    -- the skin draws real trainer sprites through this hook (see main.lua)
    self.pssDrawTrainer = state.drawTrainer
    local function hit(x,y,w,h,action,value)
      state.hits[#state.hits+1]={x=x,y=y,w=w,h=h,action=action,value=value}
    end
    local function label(text,x,y,w,h,tint)
      self:partyInfoCentered(self:fitPartyInfo(text,w-4),x,y,w,h,tint or c.ink)
    end
    local function button(text,x,y,w,h,action,value)
      local pressed=self:beginPress(x,y,w,h,action~=nil)
      local tone = self.v4Choice and ({ BATTLE = "battle", TRADE = "trade", ACCEPT = "positive", CONNECT = "positive",
        DECLINE = "negative", DISCONNECT = "negative" })[text]
      if tone and action then
        self:v4Choice(x,y,w,h,tone,true)
        if self.v4ToneLabel then self:v4ToneLabel(tr(text),x,y,w,h,tone) else label(tr(text),x,y,w,h-3,c.white) end
      elseif self.v4PssButton then
        self:v4PssButton(text,x,y,w,h,action~=nil,tone)
      else
        if self.v4ActionPanel then self:v4ActionPanel(x,y,w,h,action~=nil) else self:panel(x,y,w,h) end
        label(tr(text),x,y,w,h,action and c.green or c.disabledInk)
      end
      self:endPress(pressed)
      if action then hit(x,y,w,h,action,value) end
    end
    local function person(cx,y,tint)
      if self.v4Person then return self:v4Person(cx,y,tint) end
      G.setColor(tint);G.rectangle("fill",cx-3,y,6,6)
      G.rectangle("fill",cx-5,y+8,10,6)
      G.setColor(c.surface);G.rectangle("fill",cx-1,y+11,2,3)
    end
    if state.incoming then
      local inv = state.incoming
      if self.v4PssCard then
        self:v4PssCard(inv.from and inv.from.name or tr("YOUR TRAINER"), nil,
          tr(inv.mode == "trade" and "TRADE INVITATION" or "BATTLE INVITATION"), inv.mode,
          tr(state.canAccept and "ACCEPT TO OPEN LINK SETUP" or "FINISH YOUR CURRENT ACTION"), 110, nil, inv.from)
      else
      self:panel(7,33,226,110)
      person(120,45,c.blue)
      label(inv.from and inv.from.name or tr("YOUR TRAINER"),15,67,210,20)
      label(tr(inv.mode == "trade" and "TRADE INVITATION" or "BATTLE INVITATION"),15,92,210,18,c.green)
      label(tr(state.canAccept and "ACCEPT TO OPEN LINK SETUP" or "FINISH YOUR CURRENT ACTION"),15,118,210,16,c.mutedInk)
      end
      button("DECLINE",7,154,109,28,"decline",inv.id)
      button("ACCEPT",124,154,109,28,state.canAccept and "accept" or nil,inv.id)
      if self.v4PssFooter then self:v4PssFooter(tr("SILPH CONNECT")) else label(tr("SILPH CONNECT"),7,190,226,21,c.mutedInk) end
      return
    end
    if state.pending or state.activity then
      local pending = state.pending or state.activity
      if self.v4PssCard then
        self:v4PssCard(pending.peer and pending.peer.name or tr("YOUR TRAINER"), nil,
          tr(pending.mode == "trade" and "TRADE" or "BATTLE"), pending.mode,
          tr(state.activity and "LINK SESSION OPEN" or pending.room
            and "FINISH YOUR CURRENT ACTION" or "INVITATION SENT"), 145, not state.activity, pending.peer)
      else
      self:panel(7,33,226,145)
      person(120,48,c.blue)
      label(pending.peer and pending.peer.name or tr("YOUR TRAINER"),15,72,210,20)
      label(tr(pending.mode == "trade" and "TRADE" or "BATTLE"),15,99,210,18,c.green)
      label(tr(state.activity and "LINK SESSION OPEN" or pending.room
        and "FINISH YOUR CURRENT ACTION" or "INVITATION SENT"),15,127,210,18,c.mutedInk)
      end
      if self.v4PssFooter then self:v4PssFooter(tr("YOU CAN KEEP PLAYING")) else label(tr("YOU CAN KEEP PLAYING"),7,190,226,21,c.mutedInk) end
      return
    end
    if state.selected then
      local row=state.selectedRow
      local available = row and row.canInvite
      local reason = state.notice or (not state.session and "HOST UPDATE NEEDED"
        or not state.ready and "SET YOUR STATUS TO READY" or not available and "PLAYER NOT READY")
      if self.v4PssCard then
        self:v4PssCard(row and row.name or tr(state.state == "online" and "PLAYER LEFT"
            or states[state.state] or "OFFLINE"), row and tr(versions[row.version] or "UNKNOWN GAME"),
          row and tr(row.ready and "READY" or statuses[row.status] or "ONLINE"), row and (row.ready and "ready" or "online") or "offline",
          reason and tr(reason), 110, nil, row)
      else
      self:panel(7,33,226,110)
      person(120,43,row and c.blue or c.disabledInk)
      label(row and row.name or tr(state.state == "online" and "PLAYER LEFT"
        or states[state.state] or "OFFLINE"),15,62,210,20)
      if row then
        label(tr(versions[row.version] or "UNKNOWN GAME"),15,85,210,15,c.green)
        label(tr(row.ready and "READY" or statuses[row.status] or "ONLINE"),15,102,210,15,
          row.ready and c.green or c.mutedInk)
      end
      if reason then label(tr(reason),12,121,216,16,c.mutedInk) end
      end
      button("BATTLE",7,154,109,28,available and "battle" or nil)
      button("TRADE",124,154,109,28,available and "trade" or nil)
      button("BACK",7,188,226,23,"back")
      return
    end
    if self.v4PssLobby then
      self:v4PssLobby(state, hit, { versions = versions, short = shortVersions, states = states })
      return
    end
    self:panel(7,33,226,32)
    label(state.name or tr("YOUR TRAINER"),10,34,132,14)
    label(tr(state.ready and "READY" or states[state.state] or "OFFLINE"),10,48,132,14,
      state.ready and c.green or c.mutedInk)
    local pending=state.state=="connecting" or state.state=="reconnecting" or state.state=="ticket"
    local action
    if state.state~="unavailable" and not pending and not state.inUse then
      action=state.state=="online" and "disconnect" or "connect"
    end
    button(state.inUse and "IN USE" or state.state=="online" and "DISCONNECT"
      or pending and "WAITING" or "CONNECT",147,37,82,24,action)
    local readyAction = state.state == "online" and state.session and not state.inUse
      and not state.onlineUnavailable and "ready" or nil
    local readyLabel = state.notice or state.enabled and (state.ready and "GO BUSY" or "FINISH YOUR CURRENT ACTION")
      or state.session and "GO READY" or "HOST UPDATE NEEDED"
    button(readyLabel,7,70,226,18,readyAction)
    if #state.rows==0 then
      self:panel(7,94,226,93)
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
        local x=7+((i-1)%3)*77;local y=94+math.floor((i-1)/3)*47
        local pressed=self:beginPress(x,y,72,44,true)
        self:panel(x,y,72,44)
        person(x+12,y+6,row.ready and c.green or c.blue)
        label(shortVersions[row.version] or "?",x+23,y+3,45,13,c.green)
        label(tr(row.ready and "READY" or row.where == "launcher" and "IN MENU" or "ONLINE"),
          x+23,y+16,45,10,row.ready and c.green or c.mutedInk)
        label(row.name,x+3,y+29,66,12)
        self:endPress(pressed)
        hit(x,y,72,44,"player",row.id)
      end
    end
    button("PREV",7,190,58,21,state.page>1 and "page" or nil,-1)
    label(state.page.."/"..(state.pages or 1),70,190,100,21,c.green)
    button("NEXT",175,190,58,21,state.page<(state.pages or 1) and "page" or nil,1)
  end
end
