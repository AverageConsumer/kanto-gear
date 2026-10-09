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
    Page.layout(rows,{1,3,5})
    T.same(rows[2].rect,{Page.rect(3)},"native compact rows map to actual move slots")
    T.same(rows[3].rect,{0,0,27,28},"native cancellation uses the shared header back button")
  end
  H:setVariant(false)
end
