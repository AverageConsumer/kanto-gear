return function(T, display, H)
  local Page = display.SafariPage
  for _, ids in ipairs({ { "ball", "bait", "rock", "run" }, { "ball", "pokeblock", "go_near", "run" } }) do
    local model = Page.model({ safariBalls = 23, safariActions = ids })
    for index, id in ipairs(ids) do
      local x, y, w, h = Page.rect(index)
      T.eq(Page.action(model, H:safariHit(x + w / 2, y + h / 2)), id, "Safari touch keeps the actual native action")
      T.eq(Page.action(model, Page.hit(x + w, y + h)), nil, "Safari gaps never trigger a neighboring card")
    end
    T.eq(model.actions[1].detail, "x23", "Safari uses the live ball count")
    T.check(pcall(H.battleSafari, H, model, {}, {}), "both Safari action sets render on the shared page")
    model = Page.model({ safariBalls = 0, safariActions = ids })
    T.eq(Page.action(model, 1), nil, "an empty ball stock cannot be tapped")
    local count, original = 0, H.beginPress
    H.beginPress = function(self, ...)
      local pressed = original(self, ...)
      if pressed then count = count + 1 end
      return pressed
    end
    H:setTouch(62 / 1.5, 76 / 1.5)
    H:battleSafari(model, {}, {})
    H.beginPress = original; H:setTouch(nil)
    T.eq(count, 0, "unavailable Safari balls do not animate")
    T.check(not H.pressActive, "Safari cards balance their graphics stack")
  end
  local legacy = Page.model({ safariBalls = 30 })
  T.eq(Page.action(legacy, 2), "bait", "Gen 1 keeps bait in the native second slot")
  T.eq(Page.action(legacy, 3), "rock", "Gen 1 keeps rock in the native third slot")
end
