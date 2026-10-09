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
  end
  H:setVariant(false)
end
