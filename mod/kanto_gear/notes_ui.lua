return function(H, G, translate)
  local cache
  function H:releaseNotesInk()
    if cache and cache.canvas and cache.canvas.release then cache.canvas:release() end
    cache = nil
  end
  -- Only new line segments are painted during a stroke. The 4x transparent
  -- surface supplies antialiased ink; the surrounding HGSS UI stays pixel exact.
  function H:notesInk(state, x, y, w, h)
    local n = state:note(); if not n then return end
    if not cache or cache.note ~= n or cache.revision ~= state.inkRevision or cache.dark ~= self.dark then
      self:releaseNotesInk()
      cache = { canvas = G.newCanvas(880, 544, { dpiscale = 1 }), note = n,
        revision = state.inkRevision, dark = self.dark, counts = {}, fresh = true }
      cache.canvas:setFilter("linear", "linear")
    end
    local pending = cache.fresh
    for i, s in ipairs(n.strokes) do if cache.counts[i] ~= #s.points then pending = true; break end end
    if pending then
      local previous = G.getCanvas()
      G.push("all"); G.setCanvas(cache.canvas); G.origin(); G.setScissor(); G.setShader()
      if cache.fresh then G.clear(0, 0, 0, 0); cache.fresh = false end
      G.setBlendMode("alpha"); G.scale(4, 4)
      if G.setLineStyle then G.setLineStyle("smooth") end
      for i, s in ipairs(n.strokes) do
        local p, count = s.points, cache.counts[i] or 0
        if #p > count then
          G.setColor(state.colors[s.color].tint or self.colors.ink); G.setLineWidth(s.width)
          if count == 0 then G.circle("fill", p[1], p[2], s.width / 2) end
          for j = math.max(3, count + 1), #p - 1, 2 do
            G.line(p[j-2], p[j-1], p[j], p[j+1])
            G.circle("fill", p[j], p[j+1], s.width / 2)
          end
          cache.counts[i] = #p
        end
      end
      G.setCanvas(previous); G.pop()
    end
    local scale = math.min(w / 220, h / 136)
    G.push("all"); G.setColor(1, 1, 1, 1); G.setBlendMode("alpha", "premultiplied")
    G.draw(cache.canvas, x + (w - 220*scale)/2, y + (h - 136*scale)/2, 0, scale/4, scale/4)
    G.pop()
  end
  function H:notes(state)
    local c, n = self.colors, state:note()
    state.hits = {}
    local function hit(x,y,w,h,action,value)
      state.hits[#state.hits+1] = {x=x,y=y,w=w,h=h,action=action,value=value}
    end
    local function label(value,x,y,w,h,tint)
      self:partyInfo(self:fitPartyInfo(value,w),x,y+math.floor((h-8)/2)-2,tint or c.ink,w,"center")
    end
    local function button(value,x,y,w,h,action,arg,selected,raw)
      self:panel(x,y,w,h,false,nil)
      if selected then
        G.setColor(c.green);G.rectangle("fill",x+2,y+1,w-4,h-2)
      end
      label(raw and value or translate(value),x+3,y,w-6,h,selected and c.white or c.ink)
      if action then hit(x,y,w,h,action,arg) end
    end
    local function pager(count,y)
      state.pages=math.max(1,count);state.page=math.max(1,math.min(state.page,state.pages))
      self:panel(83,y,74,13)
      self:pageChevron(92,y+6,false,state.page>1)
      self:pageChevron(149,y+6,true,state.page<state.pages)
      label(state.page.."/"..state.pages,103,y,34,13,c.green)
      if state.page>1 then hit(83,y,20,13,"page",-1) end
      if state.page<state.pages then hit(137,y,20,13,"page",1) end
    end
    if state.view == "list" then
      button("HERE",7,33,110,19,"filter","here",state.filter=="here")
      button("ALL NOTES",123,33,110,19,"filter","all",state.filter=="all")
      local list=state:list();pager(math.ceil(#list/3),154)
      for row=1,3 do
        local entry=list[(state.page-1)*3+row]
        if entry then
          local y=59+(row-1)*31
          self:panel(7,y,226,26)
          self:partyInfo(self:fitPartyInfo(entry.note.title,210),15,y+3,c.ink)
          self:partyInfo(self:fitPartyInfo(entry.note.area and entry.note.areaName or translate("GENERAL"),210),15,y+15,c.green)
          hit(7,y,226,26,"open",entry.index)
        end
      end
      if #list==0 then label(translate("NO NOTES YET"),7,81,226,28,c.green) end
      if state.deleted then
        self:panel(7,172,226,17);label(translate("NOTE DELETED"),10,172,126,17,c.green)
        button("UNDO",141,172,92,17,"restore")
      end
      button("NEW NOTE",7,194,226,17,"new",nil,true)
    elseif state.view == "edit" then
      local keyY,areaH=88,39
      self:panel(7,33,226,areaH)
      local rows=state:wrapped(state.draft,210);local rowIndex=#rows
      for i,r in ipairs(rows) do if state.cursor>=r.first and state.cursor<=r.last then rowIndex=i;break end end
      local first=math.max(1,rowIndex-1)
      for i=first,math.min(#rows,first+1) do self:partyInfo(rows[i].text,15,36+(i-first)*12,c.ink) end
      local cursorText={};for char in rows[rowIndex].text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do cursorText[#cursorText+1]=char end
      local before=table.concat(cursorText,"",1,math.max(0,state.cursor-rows[rowIndex].first))
      G.setColor(c.ink);G.rectangle("fill",math.min(224,15+self:partyInfoWidth(before)),38+(rowIndex-first)*12,1,9)
      button("←",7,keyY-14,25,12,"cursor",-1,false,true)
      button("→",36,keyY-14,25,12,"cursor",1,false,true)
      label(rowIndex.."/"..#rows,67,keyY-14,60,12,c.green)
      if state.editTarget=="task" then button("DELETE",128,keyY-14,105,12,"deleteTask")
      elseif state.editTarget=="text" then button("NEW LINE",128,keyY-14,105,12,"newline") end
      local keys=state.symbols and {"1234567890",".,!?-:;()/","äöüß@+\""} or {"qwertzuiop","asdfghjkl","yxcvbnm"}
      for row,letters in ipairs(keys) do
        local cells={};for char in letters:gmatch("[%z\1-\127\194-\244][\128-\191]*") do cells[#cells+1]=state.shift and char:upper() or char end
        local cell=math.floor(((row==1 and 226 or row==2 and 210 or 186)-(#cells-1)*3)/#cells)
        local left=math.floor((240-(#cells*cell+(#cells-1)*3))/2)
        for i,char in ipairs(cells) do button(char,left+(i-1)*(cell+3),keyY+(row-1)*32,cell,27,"char",char,false,true) end
      end
      button(state.shift and "abc" or "ABC",7,184,32,27,"shift",nil,false,true)
      button(state.symbols and "ABC" or "123",43,184,30,27,"symbols",nil,false,true)
      button("SPACE",77,184,65,27,"space")
      button("DEL",146,184,37,27,"backspace",nil,false,true)
      button("OK",187,184,46,27,"finish",nil,true)
    elseif state.view=="draw" then
      self:panel(7,33,226,142);self:notesInk(state,10,36,220,136)
      local tools={{"PEN","pen","pen"},{"ERASER","pen","eraser"},{"COLOR","colors"},{state.penWidth==2 and "THIN" or "THICK","width"},{"REVERT","undo"}}
      for i,t in ipairs(tools) do button(t[1],7+(i-1)*46,183,42,28,t[2],t[3],t[2]=="pen" and state.tool==t[3]) end
      if state.colorOpen then
        -- Modal hit regions replace the controls beneath the palette.
        state.hits={};self:panel(16,53,208,119);label(translate("PEN COLOR"),16,57,208,14,c.green)
        for i,color in ipairs(state.colors) do
          local x,y=24+((i-1)%3)*65,77+math.floor((i-1)/3)*43
          self:panel(x,y,62,38,state.color==i)
          G.setColor(color.tint or c.ink);G.rectangle("fill",x+24,y+5,14,12)
          label(translate(color.label),x,y+23,62,11);hit(x,y,62,38,"color",i)
        end
      end
    elseif n then
      self:panel(7,33,226,27)
      self:partyInfo(self:fitPartyInfo(n.title,210),15,35,c.ink)
      self:partyInfo(self:fitPartyInfo(n.area and n.areaName or translate("GENERAL"),210),15,47,c.green)
      hit(7,33,226,14,"edit","title");hit(7,47,226,13,"area")
      if state.view=="text" then
        local rows=state:wrapped(n.text,210);pager(math.ceil(#rows/6),153)
        self:panel(7,66,226,82)
        for i=1,6 do local row=rows[(state.page-1)*6+i];if row then self:partyInfo(row.text,15,70+(i-1)*12,c.ink) end end
        if n.text=="" then label(translate("YOUR NOTE"),7,66,226,82,c.green) end
        button("EDIT",7,174,110,17,"edit","text",true);button("DELETE",123,174,110,17,"delete")
      elseif state.view=="tasks" then
        pager(math.ceil(#n.tasks/3),153)
        for row=1,3 do local index=(state.page-1)*3+row;local task=n.tasks[index]
          if task then
            local y=66+(row-1)*28;self:panel(7,y,226,24)
            self:panel(14,y+7,10,10)
            if task.done then G.setColor(c.green);G.rectangle("fill",17,y+10,4,4) end
            self:partyInfo(self:fitPartyInfo(task.text,192),33,y+6,task.done and c.green or c.ink)
            hit(7,y,25,24,"check",index);hit(33,y,200,24,"task",index)
          end
        end
        if #n.tasks==0 then label(translate("NO TASKS YET"),7,72,226,62,c.green) end
        button("+ TASK",7,174,226,17,"addTask",nil,true)
      else
        self:panel(7,66,226,102);self:notesInk(state,10,69,220,96)
        button(#n.strokes>0 and "EDIT DRAWING" or "DRAW",7,174,226,17,"view","draw",true)
      end
      for i,t in ipairs({{"TEXT","text"},{"TASKS","tasks"},{"DRAWING","sketch"}}) do button(t[1],7+(i-1)*77,194,72,17,"view",t[2],state.view==t[2]) end
    end
    if state.error then
      state.hits = {}
      self:panel(7,153,226,38);label(translate(state.error),10,155,220,14,c.red)
      button("OK",83,173,74,15,"dismiss")
    end
  end
end
