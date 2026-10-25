-- Window-space modal, with shared paint/hit rectangles and whole-pixel ink
-- centering. All buttons fit above the native touch pad in portrait/landscape.
local View = {}
local function rgb(hex)
  return tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255, tonumber(hex:sub(5,6),16)/255, 1
end
function View.draw(G, viewport, model, theme)
  theme = theme or {}
  local width, height = viewport.width, viewport.height
  local font, small = theme.font or G.getFont(), theme.small or theme.font or G.getFont()
  local scale = math.max(1, math.floor(math.min(width / 640, height / 540)))
  local pad, gap = 8 * scale, 4 * scale
  local rowH = math.max(28, font:getHeight() * scale + 12 * scale)
  local rows, title, description
  if model.stage == "output" then
    title, description, rows = "SECOND SCREEN FOUND", "Confirm on the game screen.", {}
  elseif model.stage == "test" then
    title, description = "SECOND SCREEN TEST", "Do you see the test on your other screen?"
    rows = { { label="YES, USE TWO SCREENS", enabled=model.healthy }, { label="BACK TO ONE SCREEN", enabled=true } }
  elseif model.stage == "recovery" then
    title, description = "USING ONE SCREEN", "Your second display is not ready."
    rows = { {label="KEEP ONE SCREEN",enabled=true}, {label="TRY SECOND SCREEN",enabled=true} }
  else
    title, description = "WELCOME TO KANTO GEAR", "Choose how to show the game and Gear."
    rows = { {label="ONE SCREEN",enabled=true}, {label=model.candidate and "TWO SCREENS (DETECTED)" or "TWO SCREENS",enabled=true},
      {label="FULLSCREEN SWAP (Y / F6)",enabled=true}, {label="PHONE / BROWSER",enabled=true} }
  end
  local cardW = math.min(width - 16 * scale, 352 * scale)
  local headerH = (font:getHeight() + small:getHeight()) * scale + 3 * gap
  local footerH = small:getHeight() * scale + 2 * gap
  local cardH = 2 * pad + headerH + #rows * rowH + (#rows - 1) * gap + footerH
  local x = math.floor((width - cardW) / 2)
  local y = math.max(6 * scale, math.floor((height * .7 - cardH) / 2))
  local dark = theme.dark == true
  local c = dark and { body="212a33",ink="e2edf4",muted="9aa8b8",accent="4cc8f0",row="303e4b",line="607582" }
    or {body="f8f8f0",ink="283036",muted="55675d",accent=theme.skin=="cgear" and "1894c4" or "2f8c76",row="e8efe6",line="9abaa7"}
  local function rect(col,rx,ry,w,h) G.setColor(rgb(col)); G.rectangle("fill",rx,ry,w,h) end
  local function centered(f,s,rx,ry,w,h,col,metrics)
    local left,right,top,bottom=0,f:getWidth(s)-1,0,f:getHeight()-1
    if metrics then
      local l,r,t,b=math.huge,-1,math.huge,-1
      for i=1,#s do
        local m=metrics[s:sub(i,i)]
        if m and m.right>=m.left then
          local advance=f:getWidth(s:sub(1,i-1))
          l,r=math.min(l,advance+m.left),math.max(r,advance+m.right)
          t,b=math.min(t,m.top),math.max(b,m.bottom)
        end
      end
      if r>=l then left,right,top,bottom=l,r,t,b end
    end
    G.setFont(f); G.setColor(rgb(col))
    G.print(s,rx+math.floor((w-(right-left+1)*scale)/2)-left*scale,
      ry+math.floor((h-(bottom-top+1)*scale)/2)-top*scale,0,scale,scale)
  end
  G.push("all"); G.origin(); G.setShader(); G.setScissor()
  G.setColor(0,0,0,.84); G.rectangle("fill",0,0,width,height)
  rect(c.line,x-scale,y-scale,cardW+2*scale,cardH+2*scale)
  rect(c.body,x,y,cardW,cardH)
  centered(font,title,x+pad,y+pad,cardW-2*pad,font:getHeight()*scale+gap,c.ink,theme.fontMetrics)
  centered(small,description,x+pad,y+pad+(font:getHeight()*scale)+gap,cardW-2*pad,
    small:getHeight()*scale+gap,c.muted,theme.smallMetrics)
  local buttons = {}
  for i,row in ipairs(rows) do
    local b={x=x+pad,y=y+pad+headerH+(i-1)*(rowH+gap),w=cardW-2*pad,h=rowH,enabled=row.enabled}
    buttons[i]=b
    local selected=i==model.selected and row.enabled
    rect(selected and c.accent or c.row,b.x,b.y,b.w,b.h)
    centered(font,row.label,b.x,b.y,b.w,b.h,row.enabled and (selected and (dark and c.body or "ffffff") or c.ink) or c.muted,theme.fontMetrics)
  end
  local footer = model.stage=="output" and "KANTO GEAR"
    or model.stage=="test" and ("Returns in "..math.max(0,math.ceil(model.remaining)).."s  /  B: Back")
    or "D-Pad: Choose   A: Confirm   B: One screen"
  centered(small,footer,x+pad,y+cardH-pad-footerH,cardW-2*pad,footerH,c.muted,theme.smallMetrics)
  G.pop()
  return { buttons=buttons, width=width, height=height, stage=model.stage }
end

function View.test(G, theme)
  return View.draw(G,{width=240,height=216},{stage="output",selected=0},theme)
end
return View
