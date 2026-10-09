return function(T, display, H)
  local Page = display.MovePage
  local model = { name = "TESTMON", prompt = "CHOOSE MOVE", moves = {
    { name = "TACKLE", type = "NORMAL", typeLabel = "NORMAL", ppText = "0/35" },
    { name = "GROWL", type = "NORMAL", typeLabel = "NORMAL", ppText = "40/40" },
  } }
  for _, dark in ipairs({ false, true }) do
    H:setVariant(dark)
    T.check(pcall(Page.draw, H, model), "attack selection renders in both themes")
    T.eq(Page.hit(model, 15, 15), "back", "back has the shared header target")
    T.eq(Page.hit(model, 120, 40), nil, "context is static information")
    for index = 1, 4 do
      local x,y,w,h = Page.rect(index)
      T.eq(Page.hit(model,x+w/2,y+h/2), index <= 2 and index or nil, "only actual moves have targets")
      T.eq(Page.hit(model,x+w/2,y+h), nil, "one-pixel gaps never select a move")
    end
    model.enabled = false
    T.eq(Page.hit(model, 120, 80), nil, "busy native chooser never accepts a move")
    T.eq(Page.hit(model, 15, 15), nil, "busy chooser never accepts cancellation")
    model.enabled = true
    model.moves[1].available = false
    T.eq(Page.hit(model, 120, 80), nil, "disabled moves never accept touches")
    model.moves[1].available = true
    model.newMove, model.details = model.moves[1], true
    T.eq(Page.hit(model,120,40),"new","new move opens details without selecting a replacement")
    local action,slot=Page.hit(model,220,80)
    T.eq(action,"info","row chevron opens move information")
    T.eq(slot,1,"row information retains its real move slot")
    T.eq(Page.hit(model,200,80),1,"row body still selects the move")
    model.message="HM moves cannot be forgotten!"
    T.eq(Page.hit(model,120,40),nil,"native refusal is static information")
    T.check(pcall(Page.draw,H,model),"native refusal renders without shifting the rows")
    model.message,model.newMove,model.details=nil,nil,false
    local sparse={moves={[3]=model.moves[1]}}
    T.eq(Page.hit(sparse,120,150),3,"sparse slots retain their actual card position")
    T.eq(Page.hit(sparse,120,80),nil,"missing early slots have no actions")
    local rows={{},{},{}}
    T.same({Page.window(9,5)},{5,4,2,3},"long attack lists retain their native page indices")
    T.same({Page.window(9,10)},{9,1,3,3},"native cancellation keeps the final attack page")
    T.same({Page.window(0,1)},{1,0,1,1},"empty attack lists invent no move targets")
    local catalogue={}
    for i=1,10 do catalogue[i]={} end
    Page.listLayout(catalogue,9)
    T.same(catalogue[9].rect,{Page.rect(1)},"last native move uses the first visible card")
    T.eq(catalogue[5].rect,nil,"off-page moves cannot be touched")
    T.same(catalogue[10].rect,{0,0,27,28},"long lists retain the common cancellation target")
    model.page,model.pages=1,3
    T.eq(Page.hit(model,20,50),nil,"first page has no previous action")
    T.eq(Page.hit(model,220,50),"next","long lists can advance using the context strip")
    model.page=3
    T.eq(Page.hit(model,220,50),nil,"last page has no next action")
    T.eq(Page.hit(model,20,50),"previous","long lists can return using the context strip")
    model.enabled=false
    T.eq(Page.hit(model,20,50),nil,"busy long lists never turn a page")
    model.enabled,model.page,model.pages=true,nil,nil
    Page.layout(rows,{1,3,5})
    T.same(rows[2].rect,{Page.rect(3)},"native compact rows map to actual move slots")
    T.same(rows[3].rect,{0,0,27,28},"native cancellation uses the shared header back button")
    local prompt={mon={},newMove=model.moves[1],details=true,choices={"YES","NO"},
      prompt={"Stop learning this move?"}}
    local ok,err=pcall(Page.drawPrompt,H,prompt)
    T.check(ok,"learning question renders in both themes: "..tostring(err))
    T.eq(Page.promptHit(prompt,120,105),"new","prompt exposes new move information")
    T.eq(Page.promptHit(prompt,120,140),nil,"question has no touch action")
    T.eq(Page.promptHit(prompt,120,187),nil,"equal center gap has no touch action")
    Page.promptLayout(rows)
    for index=1,2 do
      local x,y,w,h=Page.promptRect(index)
      T.eq(Page.promptHit(prompt,x+w/2,y+h/2),index,"prompt touches match the native answer")
      T.same(rows[index].rect,{x,y,w,h},"native answers share prompt hit geometry")
      T.eq(Page.promptHit(prompt,x+w/2,y+h),nil,"prompt lower edge does not select")
    end
    prompt.enabled=false
    T.eq(Page.promptHit(prompt,60,187),nil,"busy prompt cannot answer")
    T.eq(Page.promptHit(prompt,120,105),nil,"busy prompt cannot open covered details")
    prompt.enabled,prompt.choices=true,nil
    T.eq(Page.promptHit(prompt,60,187),nil,"unready prompt cannot answer")
    T.check(pcall(Page.drawPrompt,H,prompt),"unready prompt renders dimmed without answers")
  end
  H:setVariant(false)
end
