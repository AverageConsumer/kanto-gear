-- Raster assertions use the real image fonts and both complete skin renderers.
return function(H, output)
  local G = love.graphics
  local canvas = G.newCanvas(240, 24, { dpiscale = 1 })
  local checks, oldSkin, oldDark = 0, H.skinName, H.dark
  G.push("all")
  for _, skin in ipairs({ "pokegear", "cgear" }) do
    H:setSkin(skin)
    for _, dark in ipairs({ false, true }) do
      H:setVariant(dark)
      for _, value in ipairs({ "0:00", "1:11", "9:05AM", "12:00PM", "20:04", "23:59" }) do
        for _, period in ipairs({ "DAY", "MORN", "NITE", false, "UNKNOWN" }) do
          G.setCanvas(canvas); G.origin(); G.setScissor(); G.clear(0, 0, 0, 0)
          H:headerClock(value, period, 139, 72, 6)
          G.setCanvas()
          local image = canvas:newImageData()
          local left, right = 240, -1
          for y = 4, 18 do for x = 139, 210 do
            local r, g, b, a = image:getPixel(x, y)
            local function matches(c)
              return math.abs(r-c[1]) < 1/255 and math.abs(g-c[2]) < 1/255
                and math.abs(b-c[3]) < 1/255
            end
            local painted = skin == "cgear" and a > 0
              or skin == "pokegear" and (matches(H.tok.lcdOn) or matches(H.tok.lcdGhost))
            if painted then left, right = math.min(left, x), math.max(right, x) end
          end end
          image:release()
          local start, width = skin == "pokegear" and 146 or 139, skin == "pokegear" and 61 or 72
          assert(right >= left, "clock fixture has visible pixels")
          local leftGap, rightGap = left-start, start+width-right-1
          assert(leftGap >= 0 and rightGap >= 0 and math.abs(leftGap-rightGap) <= 1,
            string.format("%s dark=%s %s %s: clock gaps %d/%d", skin, tostring(dark),
              value, tostring(period), leftGap, rightGap))
          checks = checks + 1
        end
      end
    end
  end
  G.pop(); canvas:release(); H:setSkin(oldSkin); H:setVariant(oldDark)
  if output then
    local file = assert(io.open(output, "wb"))
    file:write(tostring(checks) .. " real clock raster cases passed\n"); file:close()
  end
  print(checks .. " real clock raster cases passed")
end
