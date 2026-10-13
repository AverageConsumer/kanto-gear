-- Image-font advances include blank bearings. Keep visible key glyphs centered.
return function(image, glyphs)
  if not image.getPixel then return nil end
  local r, g, b, a = image:getPixel(0, 0)
  local width, height = image:getDimensions()
  local metrics, index, start = {}, 0
  for x = 0, width do
    local separator = x == width
    if not separator then
      local rr, gg, bb, aa = image:getPixel(x, 0)
      separator = rr == r and gg == g and bb == b and aa == a
    end
    if separator and start then
      index = index + 1
      local bounds = { advance = x - start, left = x - start, top = height, right = -1, bottom = -1 }
      for xx = start, x - 1 do
        for y = 0, height - 1 do
          local _, _, _, alpha = image:getPixel(xx, y)
          if alpha > 0 then
            bounds.left, bounds.right = math.min(bounds.left, xx - start), math.max(bounds.right, xx - start)
            bounds.top, bounds.bottom = math.min(bounds.top, y), math.max(bounds.bottom, y)
          end
        end
      end
      metrics[glyphs[index]], start = bounds, nil
    elseif not separator and not start then start = x end
  end
  return metrics
end
